class_name Effets
extends Node2D
## Effets visuels « juicy » en coordonnées du monde : particules, éclairs, météores, anneaux, textes.

var police: Font
## Zoom courant de la caméra : les textes gardent une taille constante à l'écran.
var zoom := 1.0
var _batailles := {}


class Anneau:
	extends Node2D
	var r := 2.0
	var couleur := Color.WHITE
	var epaisseur := 2.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, couleur, epaisseur)


class Rayon:
	extends Node2D
	var a := 1.0
	var largeur := 16.0

	func _draw() -> void:
		var c := Color(1.0, 0.95, 0.6, a * 0.55)
		draw_rect(Rect2(-largeur * 0.5, -420.0, largeur, 420.0), c)
		draw_rect(Rect2(-largeur * 0.2, -420.0, largeur * 0.4, 420.0), Color(1, 1, 0.9, a * 0.8))
		draw_circle(Vector2.ZERO, largeur * 0.9, Color(1.0, 0.95, 0.6, a * 0.5))


class Rocher:
	extends Node2D

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.55, 0.15, 0.5))
		draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.25, 0.2))
		draw_circle(Vector2(-1.5, -1.5), 2.0, Color(0.55, 0.42, 0.33))


func particules(pos: Vector2, n: int, couleur: Color, vitesse: float, duree: float, gravite := 0.0,
		taille := 2.0, direction := Vector2.UP, etalement := 180.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = maxi(n, 1)
	p.lifetime = duree
	p.direction = direction
	p.spread = etalement
	p.initial_velocity_min = vitesse * 0.35
	p.initial_velocity_max = vitesse
	p.damping_min = vitesse * 0.4
	p.damping_max = vitesse * 0.9
	p.gravity = Vector2(0.0, gravite)
	p.scale_amount_min = taille * 0.6
	p.scale_amount_max = taille
	var g := Gradient.new()
	g.set_color(0, couleur)
	g.set_color(1, Color(couleur, 0.0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


func anneau(pos: Vector2, couleur: Color, rayon_max := 40.0, duree := 0.45, epaisseur := 2.0) -> void:
	var a := Anneau.new()
	a.position = pos
	a.couleur = couleur
	a.epaisseur = epaisseur
	add_child(a)
	var tw := a.create_tween().set_parallel()
	tw.tween_method(func(r: float) -> void:
		a.r = r
		a.queue_redraw(), 2.0, rayon_max, duree).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(a, "modulate:a", 0.0, duree).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(a.queue_free)


func texte(pos: Vector2, s: String, couleur: Color, taille := 18) -> void:
	var l := Label.new()
	l.text = s
	var ls := LabelSettings.new()
	ls.font = police
	ls.font_size = taille
	ls.font_color = couleur
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(300, 40)
	l.pivot_offset = Vector2(150, 20)
	var n := Node2D.new()
	n.position = pos
	n.scale = Vector2.ONE / zoom
	l.position = Vector2(-150, -40)
	n.add_child(l)
	add_child(n)
	l.scale = Vector2(0.2, 0.2)
	var tw := n.create_tween()
	tw.tween_property(l, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(n, "position:y", pos.y - 26.0 / zoom, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 0.0, 0.35)
	tw.tween_callback(n.queue_free)


func eclair(pos: Vector2) -> void:
	var pts := PackedVector2Array()
	var y := -320.0
	var x := randf_range(-60.0, 60.0)
	while y < 0.0:
		pts.append(pos + Vector2(x, y))
		y += randf_range(18.0, 36.0)
		x = lerpf(x, 0.0, 0.25) + randf_range(-14.0, 14.0)
	pts.append(pos)
	for k in 2:
		var ligne := Line2D.new()
		ligne.points = pts
		ligne.width = 9.0 if k == 0 else 3.0
		ligne.default_color = Color(0.6, 0.75, 1.0, 0.45) if k == 0 else Color(1, 1, 1)
		ligne.joint_mode = Line2D.LINE_JOINT_ROUND
		add_child(ligne)
		var tw := ligne.create_tween()
		tw.tween_property(ligne, "modulate:a", 0.0, 0.28).set_delay(0.06)
		tw.tween_callback(ligne.queue_free)
	particules(pos, 26, Color(1.0, 0.95, 0.6), 160.0, 0.5, 220.0, 2.0)
	anneau(pos, Color(0.8, 0.9, 1.0), 34.0, 0.35, 3.0)


func meteore(pos: Vector2, impact: Callable) -> void:
	var r := Rocher.new()
	var depart := pos + Vector2(-260.0, -460.0)
	r.position = depart
	add_child(r)
	var trainee := CPUParticles2D.new()
	trainee.amount = 70
	trainee.lifetime = 0.45
	trainee.local_coords = false
	trainee.direction = Vector2(-0.5, -1.0)
	trainee.spread = 25.0
	trainee.initial_velocity_min = 20.0
	trainee.initial_velocity_max = 60.0
	trainee.scale_amount_min = 2.0
	trainee.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.4))
	g.set_color(1, Color(0.5, 0.2, 0.1, 0.0))
	trainee.color_ramp = g
	r.add_child(trainee)
	var tw := r.create_tween()
	tw.tween_property(r, "position", pos, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		impact.call()
		explosion(pos, 1.0)
		r.queue_free())


func explosion(pos: Vector2, force: float) -> void:
	particules(pos, int(60 * force), Color(1.0, 0.75, 0.25), 260.0 * force, 0.7, 120.0, 3.0)
	particules(pos, int(40 * force), Color(0.45, 0.32, 0.22), 200.0 * force, 1.0, 340.0, 2.5)
	particules(pos, int(30 * force), Color(0.35, 0.33, 0.33, 0.8), 50.0 * force, 1.8, -30.0, 5.0)
	anneau(pos, Color(1, 1, 1, 0.9), 70.0 * force, 0.5, 4.0)
	anneau(pos, Color(1.0, 0.6, 0.2, 0.8), 110.0 * force, 0.8, 2.0)


func pluie(pos: Vector2, seche := false) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, -36)
	p.one_shot = true
	p.explosiveness = 0.3
	p.amount = 22
	p.lifetime = 0.35
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(30, 6)
	p.direction = Vector2(0.15, 1.0)
	p.spread = 4.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 190.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1.0, 0.7, 0.3, 0.8) if seche else Color(0.7, 0.85, 1.0, 0.85)
	if seche:
		p.direction = Vector2.UP
		p.gravity = Vector2(0, -60)
		p.position = pos
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 40.0
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func benediction(pos: Vector2) -> void:
	particules(pos, 40, Color(1.0, 0.88, 0.35), 90.0, 1.2, -60.0, 2.5)
	anneau(pos, Color(1.0, 0.85, 0.3), 46.0, 0.7, 3.0)
	anneau(pos, Color(1, 1, 0.8, 0.7), 26.0, 0.5, 2.0)


func signe(pos: Vector2) -> void:
	var r := Rayon.new()
	r.position = pos
	add_child(r)
	var tw := r.create_tween()
	tw.tween_method(func(a: float) -> void:
		r.a = a
		r.queue_redraw(), 0.0, 1.0, 0.25)
	tw.tween_interval(0.5)
	tw.tween_method(func(a: float) -> void:
		r.a = a
		r.queue_redraw(), 1.0, 0.0, 0.8)
	tw.tween_callback(r.queue_free)
	particules(pos, 30, Color(1, 1, 0.75), 70.0, 1.4, -40.0, 2.0)


func peste(pos: Vector2) -> void:
	particules(pos, 34, Color(0.45, 0.9, 0.25, 0.9), 50.0, 1.4, -35.0, 3.0)


func poussiere(pos: Vector2, couleur := Color(0.55, 0.45, 0.32, 0.8)) -> void:
	particules(pos, 14, couleur, 40.0, 0.6, 30.0, 2.5)


## Petites étincelles de combat, limitées pour ne pas saturer l'écran.
func bataille(pos: Vector2) -> bool:
	var cle := Vector2i(pos / 24.0)
	var t := Time.get_ticks_msec()
	if t - int(_batailles.get(cle, 0)) < 350:
		return false
	_batailles[cle] = t
	particules(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 8, Color(1, 0.9, 0.7), 70.0, 0.25,
		0.0, 1.5)
	particules(pos, 5, Color(0.85, 0.1, 0.1), 40.0, 0.4, 80.0, 2.0)
	return true
