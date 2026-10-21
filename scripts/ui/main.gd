extends Node2D
## Racine du jeu : horloge de simulation, caméra, entrées (souris + tactile), pouvoirs divins
## et liaison entre la simulation (World) et son affichage.

const TUILE := 8.0
var VITESSES := [0.0, 2.0, 8.0, 24.0 if OS.has_feature("mobile") else 40.0]
## Bornes du temps de simulation par image (µs) ; le budget réel s'adapte à la durée des images.
const BUDGET_MIN := 800
const BUDGET_MAX := 6000
const PINCEAUX := ["pluie", "secheresse", "elever", "creuser"]
const FICHIER := "user://gemesis.sav"

var monde: World
var carte: Sprite2D
var img_donnees: Image
var tex_donnees: ImageTexture
var img_proprio: Image
var tex_proprio: ImageTexture
var vue_villages: VueVillages
var foule: Foule
var fx: Effets
var sons: Sons
var hud: Hud
var cam: Camera2D

var vitesse := 1
var budget_us := 3000
var accu := 0.0
var pouvoir := ""
var zoom_cible := 1.0
var zoom_min := 0.5
var pos_cible := Vector2.ZERO
var trauma := 0.0
var inertie := Vector2.ZERO
var territoires := true

var _touches := {}
var _appui := false
var _deplace := false
var _depart := Vector2.ZERO
var _pan_souris := false
var _pinceau_pos := Vector2.ZERO
var _pinceau_t := 0.0
var _pincement := 0.0
var _hud_t := 0.0
var _foule_mois := 0
var _sauvegarde_t := 0.0
var _noms := false
var _mesure: Array[float] = []
var _mesurer := false


func _ready() -> void:
	var police_monde: FontFile = (load("res://assets/fonts/Fredoka-Variable.ttf") as FontFile).duplicate()
	police_monde.multichannel_signed_distance_field = true

	carte = Sprite2D.new()
	carte.centered = false
	carte.scale = Vector2(TUILE, TUILE)
	carte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	carte.material = mat
	add_child(carte)

	vue_villages = VueVillages.new()
	vue_villages.police = police_monde
	add_child(vue_villages)
	foule = Foule.new()
	add_child(foule)
	fx = Effets.new()
	fx.police = load("res://assets/fonts/LilitaOne-Regular.ttf")
	add_child(fx)
	cam = Camera2D.new()
	cam.ignore_rotation = false
	add_child(cam)
	cam.make_current()
	sons = Sons.new()
	add_child(sons)
	hud = Hud.new()
	add_child(hud)
	hud.pouvoir_choisi.connect(_choisir_pouvoir)
	hud.vitesse_choisie.connect(_choisir_vitesse)
	hud.aller_a.connect(func(x: int, y: int) -> void: _aller_a(x, y))
	hud.ignorer_priere.connect(func(i: int) -> void: monde.ignorer_priere(i))
	hud.menu_action.connect(_menu)

	var m := _charger()
	if m == null:
		m = World.new()
		m.generer(randi() % 1000000)
	_installer(m)
	_choisir_vitesse(1)
	get_tree().root.size_changed.connect(_calculer_zoom_min)
	_capture_auto()


## Outil de vérification : `-- --capture=fichier.png [--zoom=2] [--annees=50]`.
func _capture_auto() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("capture"):
		return
	if args.has("graine"):
		var m := World.new()
		m.generer(int(args["graine"]))
		_installer(m)
	if args.has("annees"):
		for i in int(args["annees"]) * 12:
			monde.pas()
		foule.synchroniser()
	if args.has("zoom"):
		var v: Village = null
		for x in monde.villages:
			if x.vivant and (v == null or x.pop > v.pop):
				v = x
		zoom_cible = float(args["zoom"])
		pos_cible = _centre(v.x, v.y)
		cam.zoom = Vector2.ONE * zoom_cible
		cam.position = pos_cible
	if args.has("sans"):
		for nom: String in args["sans"].split(","):
			match nom:
				"villages": vue_villages.visible = false
				"foule": foule.visible = false
				"carte": carte.visible = false
				"hud": hud.visible = false
	if args.has("vitesse"):
		_choisir_vitesse(int(args["vitesse"]))
	if args.has("inspecter"):
		var gros: Village = monde.vivants[0]
		for x in monde.vivants:
			if x.pop > gros.pop:
				gros = x
		_inspecter(_centre(gros.x, gros.y))
	if args.has("panneau"):
		match args["panneau"]:
			"prieres":
				hud._ouvrir(hud.panneau_prieres)
			"chroniques":
				hud._ouvrir(hud.panneau_chroniques)
			"menu":
				hud._ouvrir(hud.panneau_menu)
	if args.has("pouvoir"):
		await get_tree().create_timer(1.0).timeout
		var cible: Village = null
		for x in monde.vivants:
			if cible == null or x.pop > cible.pop:
				cible = x
		_choisir_pouvoir(args["pouvoir"])
		var p := _centre(cible.x + 3, cible.y + 2)
		for k in int(args.get("repete", "1")):
			_utiliser(p + Vector2(k * 10, 0))
	await get_tree().create_timer(0.6).timeout
	_mesurer = true
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_process_frames()
	var mois0 := monde.mois
	await get_tree().create_timer(float(args.get("delai", "2.5"))).timeout
	_mesure.sort()
	print("images : médiane %.1f ms, 95 %% %.1f ms, 99 %% %.1f ms, pire %.1f ms · mois simulés/s : %.1f" % [
		_mesure[_mesure.size() / 2] * 1000.0, _mesure[int(_mesure.size() * 0.95)] * 1000.0,
		_mesure[int(_mesure.size() * 0.99)] * 1000.0, _mesure[-1] * 1000.0,
		(monde.mois - mois0) * 1000.0 / (Time.get_ticks_msec() - t0)])
	print("appels de dessin : %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("FPS moyen : %.1f" % ((Engine.get_process_frames() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)))
	get_viewport().get_texture().get_image().save_png(args["capture"])
	if args.has("pouvoir"):
		print("journal : ", monde.journal.slice(-8).map(func(e: Dictionary) -> String: return e["texte"]))
	get_tree().quit()


func _installer(m: World) -> void:
	monde = m
	img_donnees = Image.create_from_data(m.w, m.h, false, Image.FORMAT_RGBA8, m.octets_donnees())
	tex_donnees = ImageTexture.create_from_image(img_donnees)
	carte.texture = tex_donnees
	img_proprio = Image.create_from_data(m.w, m.h, false, Image.FORMAT_RGBA8, m.octets_proprio())
	tex_proprio = ImageTexture.create_from_image(img_proprio)
	(carte.material as ShaderMaterial).set_shader_parameter("owner_tex", tex_proprio)
	m.tout_sale = false
	m.sales.clear()
	m.proprio_sales.clear()
	m.nouvelles.clear()
	m.effets.clear()
	vue_villages.monde = m
	vue_villages.selection = -1
	vue_villages.reinitialiser()
	foule.monde = m
	foule.pos.clear()
	foule.synchroniser()
	hud.maj(m)
	hud.fermer_tout()
	_calculer_zoom_min()
	zoom_cible = maxf(zoom_min * 1.15, 1.0)
	cam.zoom = Vector2.ONE * zoom_cible
	pos_cible = Vector2(m.w, m.h) * TUILE * 0.5
	cam.position = pos_cible
	if not m.journal.is_empty():
		hud.nouvelle({"texte": m.journal[-1]["texte"], "genre": "divin", "x": -1, "y": -1})


func _calculer_zoom_min() -> void:
	if monde == null:
		return
	var vp := get_viewport_rect().size
	zoom_min = minf(vp.x / (monde.w * TUILE), vp.y / (monde.h * TUILE)) * 0.95


# ----------------------------------------------------------------------
# Boucle
# ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if _mesurer:
		_mesure.append(delta)
	var mps: float = VITESSES[vitesse]
	if mps > 0.0:
		# Budget de temps : si la simulation est trop lourde, elle ralentit au lieu de faire ramer l'image.
		accu = minf(accu + delta * mps, 4.0)
		# Image trop longue : on rend du temps à l'affichage ; image rapide : on en reprend.
		if delta > 0.0175:
			budget_us = maxi(BUDGET_MIN, int(budget_us * 0.8))
		elif delta < 0.0155:
			budget_us = mini(BUDGET_MAX, budget_us + 150)
		var debut := Time.get_ticks_usec()
		while accu >= 1.0 and Time.get_ticks_usec() - debut < budget_us:
			monde.pas()
			accu -= 1.0
		(carte.material as ShaderMaterial).set_shader_parameter("saison", (monde.mois % 12) / 12.0)
	_vider_sorties()
	_maj_textures()
	if monde.villages_sale:
		monde.villages_sale = false
		vue_villages.actualiser()
	var ecart_foule := 4 if vitesse <= 1 else 12
	if monde.mois - _foule_mois >= ecart_foule or monde.mois < _foule_mois:
		_foule_mois = monde.mois
		foule.synchroniser()
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.25
		hud.maj(monde)
	if _appui and pouvoir in PINCEAUX:
		_pinceau_t -= delta
		if _pinceau_t <= 0.0:
			_pinceau_t = 0.07
			_utiliser(_pinceau_pos)
	_camera(delta)
	_sauvegarde_t += delta
	if _sauvegarde_t > 90.0:
		_sauvegarde_t = 0.0
		_sauver(false)


func _maj_textures() -> void:
	if monde.tout_sale:
		monde.tout_sale = false
		monde.sales.clear()
		img_donnees.set_data(monde.w, monde.h, false, Image.FORMAT_RGBA8, monde.octets_donnees())
		tex_donnees.update(img_donnees)
	elif not monde.sales.is_empty():
		for i in monde.sales:
			img_donnees.set_pixel(i % monde.w, floori(i / float(monde.w)), monde.couleur_donnee(i))
		monde.sales.clear()
		tex_donnees.update(img_donnees)
	if not monde.proprio_sales.is_empty():
		if monde.proprio_sales.size() > 6000:
			img_proprio.set_data(monde.w, monde.h, false, Image.FORMAT_RGBA8, monde.octets_proprio())
		else:
			for i in monde.proprio_sales:
				img_proprio.set_pixel(i % monde.w, floori(i / float(monde.w)), monde.couleur_proprio(i))
		monde.proprio_sales.clear()
		tex_proprio.update(img_proprio)


func _centre(x: float, y: float) -> Vector2:
	return Vector2(x + 0.5, y + 0.5) * TUILE


func _vider_sorties() -> void:
	for n: Dictionary in monde.nouvelles:
		hud.nouvelle(n)
		match n["genre"]:
			"priere":
				sons.jouer("ding", -8.0, 0.4)
			"guerre":
				sons.jouer("clang", -6.0, 0.5)
			"mort":
				sons.jouer("glas", -14.0, 1.0)
	monde.nouvelles.clear()
	var visible := _rect_visible()
	for e: Dictionary in monde.effets:
		var p := _centre(e["x"], e["y"])
		var vu := visible.has_point(p)
		match e["genre"]:
			"bataille":
				if vu and fx.bataille(p):
					sons.jouer("clang", -16.0, 0.25)
			"fondation":
				fx.anneau(p, Color("5fd37a"), 28.0, 0.5)
				var nv := monde.village_proche(e["x"], e["y"], 0.5)
				if e.has("depuis") and nv != null:
					foule.colons(monde.villages[e["depuis"]], nv)
			"exauce":
				fx.benediction(p)
				fx.texte(p, "Exaucé !", Color("ffd23a"), 20)
				sons.jouer("carillon", -4.0, 0.3)
			"ere":
				fx.anneau(p, Color("4fd8ff"), 40.0, 0.6, 3.0)
				fx.texte(p, Textes.ERES[e["ere"]], Color("4fd8ff"), 18)
				if e["ere"] > monde.ere_max() - 1 and e["ere"] >= 2:
					hud.annonce("Le monde entre dans l'%s" % Textes.ERES[e["ere"]], Color("4fd8ff"))
					sons.jouer("fanfare", -6.0, 2.0)
			"conquete":
				fx.anneau(p, Color("ff5a4f"), 40.0, 0.5, 3.0)
				fx.texte(p, "Conquis !", Color("ff5a4f"), 18)
			"ruine":
				fx.poussiere(p, Color(0.4, 0.4, 0.4, 0.8))
			"guerre":
				fx.anneau(p, Color("ff5a4f"), 30.0, 0.4)
			"temple":
				fx.benediction(p)
	monde.effets.clear()


func _rect_visible() -> Rect2:
	var t := get_canvas_transform().affine_inverse()
	return Rect2(t * Vector2.ZERO, get_viewport_rect().size / cam.zoom).grow(40.0)


# ----------------------------------------------------------------------
# Caméra
# ----------------------------------------------------------------------

func _camera(delta: float) -> void:
	var k := 1.0 - exp(-delta * 14.0)
	var clavier := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		clavier.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		clavier.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		clavier.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		clavier.y += 1
	if clavier != Vector2.ZERO:
		pos_cible += clavier.normalized() * 650.0 * delta / cam.zoom.x
	if not _appui and not _pan_souris and inertie.length() > 2.0:
		pos_cible += inertie * delta
		inertie *= exp(-delta * 5.0)
	var z := lerpf(cam.zoom.x, zoom_cible, k)
	cam.zoom = Vector2(z, z)
	pos_cible = _borner(pos_cible)
	cam.position = cam.position.lerp(pos_cible, k)
	trauma = maxf(0.0, trauma - delta * 1.8)
	var s := trauma * trauma
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * s / z
	cam.rotation = randf_range(-1, 1) * 0.025 * s
	fx.zoom = z
	var noms := z >= 1.6
	if noms != _noms:
		_noms = noms
		vue_villages.afficher_noms(noms)


func _borner(p: Vector2) -> Vector2:
	var taille := Vector2(monde.w, monde.h) * TUILE
	return p.clamp(Vector2.ZERO, taille)


func secousse(f: float) -> void:
	trauma = minf(1.0, trauma + f)


func _zoomer(facteur: float, ecran: Vector2) -> void:
	var avant := _vers_monde(ecran)
	var ancien := zoom_cible
	zoom_cible = clampf(zoom_cible * facteur, zoom_min, 7.0)
	pos_cible = avant + (pos_cible - avant) * (ancien / zoom_cible)


func _vers_monde(ecran: Vector2) -> Vector2:
	# Calcul à partir des valeurs cibles pour un zoom stable même pendant l'interpolation.
	var vp := get_viewport_rect().size
	return pos_cible + (ecran - vp * 0.5) / zoom_cible


func _vers_monde_reel(ecran: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * ecran


func _aller_a(x: int, y: int) -> void:
	pos_cible = _centre(x, y)
	zoom_cible = maxf(zoom_cible, 2.2)
	inertie = Vector2.ZERO


func _deplacer(relatif_ecran: Vector2) -> void:
	var d := relatif_ecran / cam.zoom.x
	pos_cible = _borner(pos_cible - d)
	cam.position = pos_cible


# ----------------------------------------------------------------------
# Entrées
# ----------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_tactile(e)
		return
	if e is InputEventScreenDrag:
		_glisser(e)
		return
	if e is InputEventMouse and (e as InputEventMouse).device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoomer(1.15, b.position)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoomer(1.0 / 1.15, b.position)
		elif b.button_index == MOUSE_BUTTON_RIGHT or b.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_souris = b.pressed
			if b.pressed:
				inertie = Vector2.ZERO
		elif b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed:
				_debut_appui(b.position)
			else:
				_fin_appui(b.position)
	elif e is InputEventMouseMotion:
		var m := e as InputEventMouseMotion
		if _pan_souris:
			_deplacer(m.relative)
			inertie = -m.velocity / cam.zoom.x
		elif _appui:
			_mouvement_appui(m.position, m.relative, m.velocity)
	elif e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_SPACE:
				_choisir_vitesse(0 if vitesse != 0 else 1)
			KEY_1:
				_choisir_vitesse(1)
			KEY_2:
				_choisir_vitesse(2)
			KEY_3:
				_choisir_vitesse(3)
			KEY_ESCAPE:
				if not hud.fermer_tout():
					_choisir_pouvoir("")
			KEY_EQUAL, KEY_KP_ADD:
				_zoomer(1.25, get_viewport_rect().size * 0.5)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoomer(0.8, get_viewport_rect().size * 0.5)


func _debut_appui(p: Vector2) -> void:
	_appui = true
	_deplace = false
	_depart = p
	inertie = Vector2.ZERO
	if pouvoir in PINCEAUX:
		_pinceau_pos = _vers_monde_reel(p)
		_pinceau_t = 0.0


func _mouvement_appui(p: Vector2, relatif: Vector2, vit: Vector2) -> void:
	if p.distance_to(_depart) > 12.0:
		_deplace = true
	if pouvoir in PINCEAUX:
		_pinceau_pos = _vers_monde_reel(p)
	elif _deplace:
		_deplacer(relatif)
		inertie = -vit / cam.zoom.x


func _fin_appui(p: Vector2) -> void:
	if _appui and not _deplace and not (pouvoir in PINCEAUX):
		if pouvoir == "":
			_inspecter(_vers_monde_reel(p))
		else:
			_utiliser(_vers_monde_reel(p))
	_appui = false


func _tactile(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if _touches.is_empty() and hud.bloque(e.position):
			return
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_debut_appui(e.position)
		else:
			_appui = false
			_deplace = true
			_pincement = _ecart_doigts()
	elif _touches.has(e.index):
		_touches.erase(e.index)
		if _touches.is_empty():
			_fin_appui(e.position)
		else:
			_pincement = _ecart_doigts()


func _ecart_doigts() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])


func _glisser(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	_touches[e.index] = e.position
	if _touches.size() == 1:
		_mouvement_appui(e.position, e.relative, e.velocity)
	else:
		var d := _ecart_doigts()
		var pts := _touches.values()
		var milieu: Vector2 = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
		if _pincement > 0.0 and d > 0.0:
			_zoomer(d / _pincement, milieu)
			cam.zoom = Vector2.ONE * zoom_cible
			cam.position = pos_cible
		_pincement = d
		_deplacer(e.relative * 0.5)


# ----------------------------------------------------------------------
# Pouvoirs
# ----------------------------------------------------------------------

func _choisir_pouvoir(nom: String) -> void:
	pouvoir = "" if nom == pouvoir and nom != "" else nom
	hud.choisir_pouvoir(pouvoir)


func _choisir_vitesse(i: int) -> void:
	vitesse = i
	hud.choisir_vitesse(i)


func _inspecter(p: Vector2) -> void:
	var t := Vector2i((p / TUILE).floor())
	var meilleur: Village = null
	var dmin := 4.0 * 4.0
	for v in monde.villages:
		if not v.vivant and not v.ruine:
			continue
		var d2 := float((v.x - t.x) * (v.x - t.x) + (v.y - t.y) * (v.y - t.y))
		if d2 < dmin and (v.vivant or meilleur == null):
			dmin = d2
			meilleur = v
	if meilleur != null:
		vue_villages.selection = meilleur.id
		vue_villages.actualiser()
		hud.inspecter(meilleur)
		sons.jouer("pop", -6.0)


func _utiliser(p: Vector2) -> void:
	var t := Vector2i((p / TUILE).floor())
	if not monde.dans(t.x, t.y):
		return
	var c := _centre(t.x, t.y)
	match pouvoir:
		"meteore":
			sons.jouer("sifflement", -2.0, 0.0)
			fx.meteore(c, func() -> void: _impact_meteore(t, c))
		"foudre":
			var r := monde.pouvoir("foudre", t.x, t.y)
			fx.eclair(c)
			secousse(0.35)
			hud.flash(0.35, Color(0.85, 0.9, 1.0))
			sons.jouer("tonnerre", 0.0, 0.05)
			_victimes(c, r.get("morts", 0), 20.0)
			foule.paniquer(c, 50.0)
		"pluie", "secheresse":
			monde.pouvoir(pouvoir, t.x, t.y)
			fx.pluie(c, pouvoir == "secheresse")
			sons.jouer("pluie", -12.0, 0.3)
		"elever", "creuser":
			monde.pouvoir(pouvoir, t.x, t.y)
			fx.poussiere(c, Color(0.55, 0.45, 0.32, 0.8) if pouvoir == "elever" else Color(0.6, 0.8, 1.0, 0.8))
			secousse(0.06)
			sons.jouer("grondement" if pouvoir == "elever" else "plouf", -10.0, 0.18)
		"humains":
			var r := monde.pouvoir("humains", t.x, t.y)
			if r.has("rate"):
				fx.texte(c, "Raté !", Color("ff9a3c"))
				hud.nouvelle({"texte": r["rate"], "genre": "vie", "x": -1, "y": -1})
				return
			fx.particules(c, 24, Color(1, 1, 1), 70.0, 0.6, -40.0, 2.0)
			fx.anneau(c, Color("5fd37a"), 30.0, 0.4)
			fx.texte(c, "+10" if r.get("nouveau", false) else "+8", Color("5fd37a"))
			sons.jouer("pop", 0.0, 0.05)
			foule.synchroniser()
		"benir":
			var r := monde.pouvoir("benir", t.x, t.y)
			fx.benediction(c)
			sons.jouer("carillon", -2.0, 0.2)
			if r.has("village"):
				fx.texte(_centre(monde.villages[r["village"]].x, monde.villages[r["village"]].y), "Béni !",
					Color("ffd23a"))
		"peste":
			var r := monde.pouvoir("peste", t.x, t.y)
			fx.peste(c)
			sons.jouer("toux", -2.0, 0.2)
			if r.is_empty():
				fx.texte(c, "Personne à contaminer", Color("8fdc4f"), 14)
		"signe":
			var r := monde.pouvoir("signe", t.x, t.y)
			fx.signe(c)
			hud.flash(0.15, Color(1, 0.95, 0.6))
			sons.jouer("gong", -2.0, 0.3)
			if r.is_empty():
				fx.texte(c, "Personne n'a rien vu", Color("ffd23a"), 14)
		"discorde":
			var r := monde.pouvoir("discorde", t.x, t.y)
			fx.particules(c, 20, Color("ff5a4f"), 60.0, 0.6, 0.0, 2.0)
			sons.jouer("clang", -4.0, 0.2)
			if not r.is_empty():
				secousse(0.12)
	monde.villages_sale = true


func _impact_meteore(t: Vector2i, c: Vector2) -> void:
	var r := monde.pouvoir("meteore", t.x, t.y)
	secousse(0.9)
	hud.flash(0.6, Color(1.0, 0.85, 0.6))
	sons.jouer("plouf" if r.get("mer", false) else "boom", 2.0, 0.0)
	_victimes(c, r.get("morts", 0), 70.0)
	foule.paniquer(c, 120.0)
	# Arrêt sur image : l'impact « pèse » une fraction de seconde.
	Engine.time_scale = 0.08
	get_tree().create_timer(0.09, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _victimes(c: Vector2, morts: int, rayon: float) -> void:
	if morts <= 0:
		return
	fx.texte(c + Vector2(0, -10), "-%d" % morts, Color("ff5a4f"), 22 if morts > 20 else 18)
	for p in foule.tuer(c, rayon, mini(morts, 40)):
		fx.poussiere(p, Color(0.8, 0.15, 0.1, 0.8))


# ----------------------------------------------------------------------
# Menu et sauvegarde
# ----------------------------------------------------------------------

func _menu(action: String) -> void:
	match action:
		"nouveau":
			_installer(_nouveau_monde())
			hud.annonce("Un nouveau monde !", Color("ffd23a"))
			sons.jouer("gong")
		"sauver":
			_sauver(true)
		"charger":
			var m := _charger()
			if m != null:
				_installer(m)
				hud.annonce("Monde rechargé", Color("5fd37a"))
		"son":
			sons.actif = not sons.actif
			hud.btn_son.text = "Son : oui" if sons.actif else "Son : non"
		"territoires":
			territoires = not territoires
			(carte.material as ShaderMaterial).set_shader_parameter("territoire", 1.0 if territoires else 0.0)
			hud.btn_territoires.text = "Frontières : oui" if territoires else "Frontières : non"


func _nouveau_monde() -> World:
	var m := World.new()
	m.generer(randi() % 1000000)
	return m


func _sauver(annoncer: bool) -> void:
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(monde.exporter())
	f.close()
	if annoncer:
		hud.nouvelle({"texte": "Monde sauvegardé. Tes créatures n'en savent rien.", "genre": "divin",
			"x": -1, "y": -1})


func _charger() -> World:
	if not FileAccess.file_exists(FICHIER):
		return null
	var f := FileAccess.open(FICHIER, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = f.get_var()
	f.close()
	if not d is Dictionary:
		return null
	return World.importer(d)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if monde != null:
			_sauver(false)
