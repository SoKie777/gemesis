class_name Hud
extends CanvasLayer
## Interface complète, construite en code : barre du haut, palette des pouvoirs, notifications,
## fiche de village, prières, chroniques et menu.

signal pouvoir_choisi(nom: String)
signal vitesse_choisie(i: int)
signal aller_a(x: int, y: int)
signal ignorer_priere(i: int)
signal menu_action(action: String)

const POUVOIRS := [
	["", "regarder", "Regarder"], ["humains", "humains", "Humains"], ["pluie", "pluie", "Pluie"],
	["secheresse", "secheresse", "Sécheresse"], ["foudre", "foudre", "Foudre"],
	["meteore", "meteore", "Météore"], ["benir", "benir", "Bénir"], ["peste", "peste", "Peste"],
	["signe", "signe", "Signe"], ["discorde", "discorde", "Discorde"], ["elever", "elever", "Élever"],
	["creuser", "creuser", "Creuser"],
]
const COULEURS_GENRE := {
	"naissance": Color("5fd37a"), "mort": Color("9aa0ad"), "guerre": Color("ff5a4f"),
	"divin": Color("ffd23a"), "priere": Color("b48cff"), "vie": Color("ff8fc8"),
	"catastrophe": Color("ff9a3c"), "ere": Color("4fd8ff"),
}

var monde: World
var police: Font
var police_titre: Font
var racine: Control
var lbl_annee: Label
var lbl_ere: Label
var lbl_stats: Label
var btn_prieres: Button
var btns_vitesse: Array[Button] = []
var btns_pouvoir := {}
var lbl_info: Label
var pile_toasts: VBoxContainer
var panneau_fiche: PanelContainer
var fiche_texte: RichTextLabel
var fiche_barres := {}
var fiche_id := -1
var panneau_prieres: PanelContainer
var liste_prieres: VBoxContainer
var panneau_chroniques: PanelContainer
var chroniques_texte: RichTextLabel
var panneau_menu: PanelContainer
var lbl_graine: Label
var btn_son: Button
var btn_territoires: Button
var flash_rect: ColorRect
var banniere: Label
var _file_toasts: Array = []
var _delai_toast := 0.0
var _info_t := 0.0
var _nb_prieres := 0
var _bloquants: Array[Control] = []


func _ready() -> void:
	layer = 10
	police = load("res://assets/fonts/Fredoka-Variable.ttf")
	police_titre = load("res://assets/fonts/LilitaOne-Regular.ttf")
	racine = Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	racine.theme = _theme()
	add_child(racine)
	_barre_haut()
	_barre_pouvoirs()
	_toasts()
	_fiche()
	_prieres()
	_chroniques()
	_menu()
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	racine.add_child(flash_rect)
	banniere = Label.new()
	banniere.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banniere.position = Vector2(-500, 120)
	banniere.size = Vector2(1000, 60)
	banniere.pivot_offset = Vector2(500, 30)
	banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banniere.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banniere.add_theme_font_override("font", police_titre)
	banniere.add_theme_font_size_override("font_size", 34)
	banniere.add_theme_constant_override("outline_size", 10)
	banniere.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banniere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banniere.modulate.a = 0.0
	racine.add_child(banniere)
	choisir_pouvoir("")
	_prechauffer_police()


## Pré-rastérise les glyphes courants pour éviter un à-coup à leur première apparition.
func _prechauffer_police() -> void:
	var jeu := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" 		+ "àâäéèêëîïôöùûüçÀÂÉÈÊÎÔÙÇœŒ'’«»—–-.,;:!?()%+×·…"
	for taille in [12, 14, 15, 16, 17, 22, 24]:
		var l := _label(jeu, taille)
		l.modulate.a = 0.01
		racine.add_child(l)
		get_tree().create_timer(0.5).timeout.connect(l.queue_free)
	for taille in [22, 24, 34]:
		var l := _label(jeu, taille, true)
		l.modulate.a = 0.01
		racine.add_child(l)
		get_tree().create_timer(0.5).timeout.connect(l.queue_free)


# ----------------------------------------------------------------------
# Construction
# ----------------------------------------------------------------------

func _style(fond: Color, rayon := 14, bord := Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(rayon)
	s.border_color = bord
	s.set_border_width_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = police
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", _style(Color(0.07, 0.08, 0.14, 0.88)))
	t.set_stylebox("normal", "Button", _style(Color(0.16, 0.18, 0.28, 0.95), 12))
	t.set_stylebox("hover", "Button", _style(Color(0.22, 0.25, 0.38, 0.95), 12, Color(1, 1, 1, 0.25)))
	t.set_stylebox("pressed", "Button", _style(Color(0.35, 0.3, 0.12, 0.95), 12, Color("ffd23a")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.95, 0.95, 1))
	t.set_color("font_color", "Label", Color(0.95, 0.95, 1))
	t.set_color("default_color", "RichTextLabel", Color(0.92, 0.93, 1))
	var fond_barre := StyleBoxFlat.new()
	fond_barre.bg_color = Color(1, 1, 1, 0.1)
	fond_barre.set_corner_radius_all(5)
	var rempli := StyleBoxFlat.new()
	rempli.bg_color = Color("5fd37a")
	rempli.set_corner_radius_all(5)
	t.set_stylebox("background", "ProgressBar", fond_barre)
	t.set_stylebox("fill", "ProgressBar", rempli)
	return t


func _label(texte := "", taille := 17, titre := false) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	if titre:
		l.add_theme_font_override("font", police_titre)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bouton(texte: String, rappel: Callable, icone := "") -> Button:
	var b := Button.new()
	b.text = texte
	if icone != "":
		b.icon = load("res://assets/icones/%s.svg" % icone)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(46, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		rebond(b)
		get_parent().sons.jouer("clic", -6.0)
		rappel.call())
	b.mouse_entered.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.08))
	b.mouse_exited.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b


func rebond(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.82, 0.82), 0.05)
	tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(c, "scale", Vector2.ONE, 0.08)


func _barre_haut() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 8
	p.offset_right = -8
	p.offset_top = 8
	racine.add_child(p)
	_bloquants.append(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -4)
	lbl_annee = _label("An 0", 24, true)
	lbl_ere = _label("Âge de pierre", 14)
	lbl_ere.add_theme_color_override("font_color", Color("4fd8ff"))
	vb.add_child(lbl_annee)
	vb.add_child(lbl_ere)
	hb.add_child(vb)
	lbl_stats = _label("", 16)
	lbl_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(lbl_stats)
	btn_prieres = _bouton("Prières", func() -> void: _basculer(panneau_prieres))
	hb.add_child(btn_prieres)
	hb.add_child(_bouton("Chroniques", func() -> void: _basculer(panneau_chroniques)))
	var icones := ["pause", "vitesse1", "vitesse2", "vitesse3"]
	for i in 4:
		var b := _bouton("", func() -> void: vitesse_choisie.emit(i), icones[i])
		b.toggle_mode = true
		btns_vitesse.append(b)
		hb.add_child(b)
	hb.add_child(_bouton("Menu", func() -> void: _basculer(panneau_menu)))


func _barre_pouvoirs() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -8
	racine.add_child(p)
	_bloquants.append(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	for def: Array in POUVOIRS:
		var nom: String = def[0]
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		var b := Button.new()
		b.icon = load("res://assets/icones/%s.svg" % def[1])
		b.expand_icon = true
		b.custom_minimum_size = Vector2(62, 62)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			rebond(b)
			get_parent().sons.jouer("pop", -4.0)
			pouvoir_choisi.emit(nom))
		b.mouse_entered.connect(func() -> void: _info(Textes.POUVOIRS[nom]))
		var l := _label(def[2], 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(b)
		vb.add_child(l)
		hb.add_child(vb)
		btns_pouvoir[nom] = b
	lbl_info = _label("", 17)
	lbl_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_info.position = Vector2(-450, -128)
	lbl_info.size = Vector2(900, 30)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.add_theme_constant_override("outline_size", 6)
	lbl_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	racine.add_child(lbl_info)


func _toasts() -> void:
	pile_toasts = VBoxContainer.new()
	pile_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pile_toasts.offset_left = -400
	pile_toasts.offset_right = -10
	pile_toasts.offset_top = 84
	pile_toasts.add_theme_constant_override("separation", 6)
	pile_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(pile_toasts)


func _panneau(gauche: bool, largeur: float) -> PanelContainer:
	var p := PanelContainer.new()
	if gauche:
		p.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		p.offset_left = 8
		p.offset_right = 8 + largeur
	else:
		p.set_anchors_preset(Control.PRESET_CENTER)
		p.offset_left = -largeur * 0.5
		p.offset_right = largeur * 0.5
		p.offset_top = -250
		p.offset_bottom = 230
	if gauche:
		p.offset_top = 86
		p.offset_bottom = -100
	p.visible = false
	racine.add_child(p)
	_bloquants.append(p)
	return p


func _entete(p: PanelContainer, titre: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var hb := HBoxContainer.new()
	var t := _label(titre, 22, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	hb.add_child(_bouton("×", func() -> void: _fermer(p)))
	vb.add_child(hb)
	return vb


func _fiche() -> void:
	panneau_fiche = _panneau(true, 350)
	var vb := _entete(panneau_fiche, "Fiche")
	for cle: String in ["Humeur", "Foi", "Réserves"]:
		var hb := HBoxContainer.new()
		var l := _label(cle, 14)
		l.custom_minimum_size.x = 72
		hb.add_child(l)
		var b := ProgressBar.new()
		b.show_percentage = false
		b.custom_minimum_size = Vector2(0, 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var f := StyleBoxFlat.new()
		f.bg_color = {"Humeur": Color("ff8fc8"), "Foi": Color("ffd23a"), "Réserves": Color("5fd37a")}[cle]
		f.set_corner_radius_all(5)
		b.add_theme_stylebox_override("fill", f)
		hb.add_child(b)
		vb.add_child(hb)
		fiche_barres[cle] = b
	fiche_texte = RichTextLabel.new()
	fiche_texte.bbcode_enabled = true
	fiche_texte.fit_content = false
	fiche_texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fiche_texte.add_theme_font_size_override("normal_font_size", 15)
	fiche_texte.add_theme_font_size_override("bold_font_size", 15)
	vb.add_child(fiche_texte)
	vb.add_child(_bouton("Suivre", func() -> void:
		if fiche_id >= 0:
			var v := monde.villages[fiche_id]
			aller_a.emit(v.x, v.y)))


func _prieres() -> void:
	panneau_prieres = _panneau(false, 620)
	var vb := _entete(panneau_prieres, "Prières")
	var aide := _label("Exauce-les en utilisant le bon pouvoir sur le village. Ou pas. Tu es Dieu.", 14)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vb.add_child(aide)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	liste_prieres = VBoxContainer.new()
	liste_prieres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste_prieres.add_theme_constant_override("separation", 8)
	sc.add_child(liste_prieres)


func _chroniques() -> void:
	panneau_chroniques = _panneau(false, 700)
	var vb := _entete(panneau_chroniques, "Chroniques du monde")
	chroniques_texte = RichTextLabel.new()
	chroniques_texte.bbcode_enabled = true
	chroniques_texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chroniques_texte.scroll_following = false
	chroniques_texte.add_theme_font_size_override("normal_font_size", 15)
	vb.add_child(chroniques_texte)


func _menu() -> void:
	panneau_menu = _panneau(false, 380)
	panneau_menu.offset_top = -200
	panneau_menu.offset_bottom = 200
	var vb := _entete(panneau_menu, "Menu divin")
	lbl_graine = _label("", 14)
	lbl_graine.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vb.add_child(lbl_graine)
	for a: Array in [["Nouveau monde", "nouveau"], ["Sauvegarder", "sauver"], ["Charger", "charger"]]:
		var act: String = a[1]
		var b := _bouton(a[0], func() -> void:
			menu_action.emit(act)
			_fermer(panneau_menu))
		b.custom_minimum_size.y = 48
		vb.add_child(b)
	btn_son = _bouton("Son : oui", func() -> void: menu_action.emit("son"))
	btn_son.custom_minimum_size.y = 48
	vb.add_child(btn_son)
	btn_territoires = _bouton("Frontières : oui", func() -> void: menu_action.emit("territoires"))
	btn_territoires.custom_minimum_size.y = 48
	vb.add_child(btn_territoires)


# ----------------------------------------------------------------------
# Panneaux
# ----------------------------------------------------------------------

func _basculer(p: PanelContainer) -> void:
	if p.visible:
		_fermer(p)
	else:
		_ouvrir(p)


func _ouvrir(p: PanelContainer) -> void:
	for autre: PanelContainer in [panneau_prieres, panneau_chroniques, panneau_menu]:
		if autre != p and autre.visible and p != panneau_fiche:
			autre.visible = false
	p.visible = true
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	if p == panneau_prieres:
		_maj_prieres()
	elif p == panneau_chroniques:
		_maj_chroniques()


func _fermer(p: PanelContainer) -> void:
	if p == panneau_fiche:
		fiche_id = -1
		get_parent().vue_villages.selection = -1
		get_parent().vue_villages.actualiser()
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func() -> void: p.visible = false)


func fermer_tout() -> bool:
	var fait := false
	for p: PanelContainer in [panneau_prieres, panneau_chroniques, panneau_menu, panneau_fiche]:
		if p.visible:
			_fermer(p)
			fait = true
	return fait


## Vrai si la position écran est au-dessus d'un élément d'interface.
func bloque(pos: Vector2) -> bool:
	for c in _bloquants:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	for t in pile_toasts.get_children():
		if (t as Control).get_global_rect().has_point(pos):
			return true
	return false


# ----------------------------------------------------------------------
# Mises à jour
# ----------------------------------------------------------------------

func choisir_pouvoir(nom: String) -> void:
	for k: String in btns_pouvoir:
		btns_pouvoir[k].button_pressed = k == nom
	_info(Textes.POUVOIRS[nom])


func choisir_vitesse(i: int) -> void:
	for k in btns_vitesse.size():
		btns_vitesse[k].button_pressed = k == i


func _info(t: String) -> void:
	lbl_info.text = t
	lbl_info.modulate.a = 1.0
	_info_t = 4.0


func maj(m: World) -> void:
	monde = m
	lbl_annee.text = "An %d" % m.annee()
	lbl_ere.text = Textes.ERES[m.ere_max()]
	var pop := int(m.population_totale())
	lbl_stats.text = "%s habitants  ·  %s fidèles  ·  %d royaumes  ·  %d guerres" % [
		_nombre(pop), _nombre(int(m.fideles())), m.royaumes.size(), m.guerres.size()]
	var n := m.prieres.size()
	btn_prieres.text = "Prières (%d)" % n if n > 0 else "Prières"
	btn_prieres.modulate = Color(1.0, 0.85, 1.0) if n > 0 else Color.WHITE
	if n > _nb_prieres:
		rebond(btn_prieres)
	_nb_prieres = n
	if panneau_fiche.visible:
		_maj_fiche()
	if panneau_prieres.visible:
		_maj_prieres()
	lbl_graine.text = "Graine du monde : %d" % m.graine


func _nombre(n: int) -> String:
	var s := str(n)
	var res := ""
	while s.length() > 3:
		res = " " + s.substr(s.length() - 3) + res
		s = s.substr(0, s.length() - 3)
	return s + res


func inspecter(v: Village) -> void:
	fiche_id = v.id
	if not panneau_fiche.visible:
		_ouvrir(panneau_fiche)
	_maj_fiche()


func _maj_fiche() -> void:
	if fiche_id < 0 or monde == null or fiche_id >= monde.villages.size():
		return
	var v := monde.villages[fiche_id]
	var c := monde.couleur_royaume(v.royaume).to_html(false)
	var t := "[font_size=24][b]%s[/b][/font_size]\n" % v.nom
	if not v.vivant:
		t += "[color=#9aa0ad]Ruines. Fondé en l'an %d. Il ne reste que des pierres et des rumeurs.[/color]\n\n" % v.fonde
	else:
		t += "[color=#%s]%s[/color]\n" % [c, monde.nom_royaume(v.royaume)]
		t += "Fondé en l'an %d · [color=#4fd8ff]%s[/color]\n\n" % [v.fonde, Textes.ERES[v.ere]]
		t += "[b]Habitants :[/b] %d\n" % int(v.pop)
		t += "[b]Chef :[/b] %s, %d ans — [i]%s[/i]\n" % [v.chef_nom, v.chef_age, v.chef_trait]
		t += "[b]Culture :[/b] %s\n" % v.culture
		t += "[b]Religion :[/b] ils t'appellent « %s »\n" % v.dieu
		var etats := []
		var ennemi := monde.ennemi_de(v.royaume)
		if ennemi >= 0:
			etats.append("[color=#ff5a4f]en guerre contre %s[/color]" % monde.nom_royaume(ennemi))
		if v.faim:
			etats.append("[color=#ff9a3c]affamé[/color]")
		if v.malade > 0:
			etats.append("[color=#8fdc4f]malade[/color]")
		if v.beni > 0:
			etats.append("[color=#ffd23a]béni[/color]")
		if v.temple:
			etats.append("possède un temple à ta gloire")
		if not etats.is_empty():
			t += "[b]État :[/b] %s\n" % ", ".join(etats)
	if not v.histoire.is_empty():
		t += "\n[b]Ce qui leur est arrivé[/b]\n"
		var h := v.histoire.duplicate()
		h.reverse()
		for e: String in h:
			t += "[color=#c8c8dc]• %s[/color]\n" % e
	fiche_texte.text = t
	fiche_barres["Humeur"].value = v.humeur
	fiche_barres["Foi"].value = v.foi
	fiche_barres["Réserves"].value = clampf(v.nourriture / maxf(v.pop * 3.0, 1.0) * 100.0, 0.0, 100.0)


func _maj_prieres() -> void:
	for c in liste_prieres.get_children():
		c.queue_free()
	if monde.prieres.is_empty():
		var l := _label("Aucune prière. Ils se débrouillent. Ou ils ont arrêté d'y croire.", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		liste_prieres.add_child(l)
		return
	for i in monde.prieres.size():
		var p: Dictionary = monde.prieres[i]
		var v := monde.villages[p["v"]]
		var bloc := PanelContainer.new()
		bloc.add_theme_stylebox_override("panel", _style(Color(0.15, 0.12, 0.25, 0.9), 10, Color("b48cff")))
		var vb := VBoxContainer.new()
		bloc.add_child(vb)
		var d: int = p["delai"]
		var t := _label("%s — %d mois restant%s" % [v.nom, d, "s" if d > 1 else ""], 15)
		t.add_theme_color_override("font_color", Color("d9c4ff"))
		vb.add_child(t)
		var l := _label(p["texte"], 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 540
		vb.add_child(l)
		var hb := HBoxContainer.new()
		var idx := i
		var vx := v.x
		var vy := v.y
		hb.add_child(_bouton("Y aller", func() -> void:
			aller_a.emit(vx, vy)
			_fermer(panneau_prieres)))
		hb.add_child(_bouton("Ignorer", func() -> void:
			ignorer_priere.emit(idx)
			_maj_prieres()))
		vb.add_child(hb)
		liste_prieres.add_child(bloc)


func _maj_chroniques() -> void:
	var t := ""
	var j := monde.journal.duplicate()
	j.reverse()
	for e: Dictionary in j.slice(0, 120):
		var c: Color = COULEURS_GENRE.get(e["genre"], Color.WHITE)
		t += "[color=#%s]An %d[/color]  %s\n" % [c.to_html(false), e["an"], e["texte"]]
	chroniques_texte.text = t


## Ajoute une nouvelle à la file ; les toasts sont distribués au compte-gouttes.
func nouvelle(n: Dictionary) -> void:
	if _file_toasts.size() > 6:
		# Trop de nouvelles : on sacrifie d'abord les petites histoires du quotidien.
		for k in _file_toasts.size():
			if _file_toasts[k]["genre"] == "vie" or _file_toasts[k]["genre"] == "naissance":
				_file_toasts.remove_at(k)
				break
		if _file_toasts.size() > 8:
			_file_toasts.pop_front()
	_file_toasts.append(n)
	if panneau_chroniques.visible:
		_maj_chroniques()


func _toast(n: Dictionary) -> void:
	var c: Color = COULEURS_GENRE.get(n["genre"], Color.WHITE)
	var p := PanelContainer.new()
	var s := _style(Color(0.07, 0.08, 0.14, 0.92), 10)
	s.border_color = c
	s.border_width_left = 6
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := _label(n["texte"], 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 360
	p.add_child(l)
	if n["x"] >= 0:
		var x: int = n["x"]
		var y: int = n["y"]
		p.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				aller_a.emit(x, y))
	pile_toasts.add_child(p)
	while pile_toasts.get_child_count() > 4:
		var vieux := pile_toasts.get_child(0)
		pile_toasts.remove_child(vieux)
		vieux.queue_free()
	p.modulate.a = 0.0
	p.position.x += 60
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(5.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func flash(force: float, couleur := Color.WHITE) -> void:
	flash_rect.color = Color(couleur, force)
	flash_rect.create_tween().tween_property(flash_rect, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)


func annonce(texte: String, couleur := Color.WHITE) -> void:
	banniere.text = texte
	banniere.add_theme_color_override("font_color", couleur)
	banniere.scale = Vector2(0.4, 0.4)
	banniere.modulate.a = 1.0
	var tw := banniere.create_tween()
	tw.tween_property(banniere, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(banniere, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(1.6)
	tw.tween_property(banniere, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_delai_toast -= delta
	if _delai_toast <= 0.0 and not _file_toasts.is_empty():
		_toast(_file_toasts.pop_front())
		_delai_toast = 0.45
	if _info_t > 0.0:
		_info_t -= delta
		if _info_t <= 1.0:
			lbl_info.modulate.a = maxf(_info_t, 0.0)
