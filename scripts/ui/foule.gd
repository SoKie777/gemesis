class_name Foule
extends MultiMeshInstance2D
## Les petits habitants visibles. Purement visuel : leur nombre suit la population réelle des villages,
## ils errent dans leur territoire, partent au front en temps de guerre et fuient les catastrophes.
## Tout est dessiné en un seul appel GPU (MultiMesh).

const TUILE := 8.0

var max_agents := 1400
var monde: World
var pos := PackedVector2Array()
var cible := PackedVector2Array()
var vid := PackedInt32Array()
var vitesse := PackedFloat32Array()
var panique := PackedFloat32Array()
var attente := PackedFloat32Array()
var phase := PackedFloat32Array()
var _fronts := {}
var _parite := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if OS.has_feature("mobile"):
		max_agents = 900
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1.5, -4), Vector2(1.5, -4), Vector2(1.5, 0),
		Vector2(-1.5, 0)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mm.mesh = am
	mm.instance_count = max_agents
	mm.visible_instance_count = 0
	multimesh = mm
	texture = _texture_bonhomme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
varying vec4 teinte;
void vertex() { teinte = INSTANCE_CUSTOM; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.g < 0.5 ? vec3(0.97, 0.8, 0.62) : teinte.rgb * t.r;
	COLOR = vec4(c, t.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material = mat


func _texture_bonhomme() -> ImageTexture:
	var img := Image.create(3, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var peau := Color(1, 0, 1)
	img.set_pixel(1, 0, peau)
	img.set_pixel(0, 1, Color(1, 1, 1))
	img.set_pixel(1, 1, Color(1, 1, 1))
	img.set_pixel(2, 1, Color(0.75, 0.75, 0.75))
	img.set_pixel(1, 2, Color(0.9, 0.9, 0.9))
	img.set_pixel(0, 3, Color(0.55, 0.55, 0.55))
	img.set_pixel(2, 3, Color(0.55, 0.55, 0.55))
	return ImageTexture.create_from_image(img)


func _centre(v: Village) -> Vector2:
	return Vector2(v.x + 0.5, v.y + 0.5) * TUILE


## Ajuste le nombre d'habitants visibles à la population réelle et rafraîchit leurs couleurs.
func synchroniser() -> void:
	if monde == null:
		return
	var voulus := {}
	var total := 0
	for v in monde.villages:
		if v.vivant:
			var k := clampi(int(v.pop / 4.0), 1, 28)
			voulus[v.id] = k
			total += k
	var echelle := minf(1.0, float(max_agents) / maxf(total, 1.0))
	_fronts.clear()
	for g: Dictionary in monde.guerres:
		var paire := monde.front(g["a"], g["b"])
		if paire.size() == 2:
			var va: Village = paire[0]
			var vb: Village = paire[1]
			var milieu := (_centre(va) + _centre(vb)) * 0.5
			_fronts[va.id] = milieu
			_fronts[vb.id] = milieu
	var groupes := {}
	for i in pos.size():
		if not groupes.has(vid[i]):
			groupes[vid[i]] = []
		groupes[vid[i]].append(i)
	var n_pos := PackedVector2Array()
	var n_cible := PackedVector2Array()
	var n_vid := PackedInt32Array()
	var n_vit := PackedFloat32Array()
	var n_pan := PackedFloat32Array()
	var n_att := PackedFloat32Array()
	var n_pha := PackedFloat32Array()
	for id: int in voulus:
		var v := monde.villages[id]
		var k := maxi(1, int(voulus[id] * echelle))
		var anciens: Array = groupes.get(id, [])
		for j in k:
			if j < anciens.size():
				var i: int = anciens[j]
				n_pos.append(pos[i])
				n_cible.append(cible[i])
				n_vit.append(vitesse[i])
				n_pan.append(panique[i])
				n_att.append(attente[i])
				n_pha.append(phase[i])
			else:
				var p := _centre(v) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
				n_pos.append(p)
				n_cible.append(p)
				n_vit.append(_rng.randf_range(7.0, 13.0))
				n_pan.append(0.0)
				n_att.append(_rng.randf_range(0.0, 2.0))
				n_pha.append(_rng.randf() * TAU)
			n_vid.append(id)
	pos = n_pos
	cible = n_cible
	vid = n_vid
	vitesse = n_vit
	panique = n_pan
	attente = n_att
	phase = n_pha
	var n := pos.size()
	multimesh.visible_instance_count = n
	for i in n:
		var c := monde.couleur_royaume(monde.villages[vid[i]].royaume)
		multimesh.set_instance_custom_data(i, c)


## Fait jaillir des colons qui marchent d'un village à l'autre.
func colons(depuis: Village, vers: Village) -> void:
	var n := mini(6, max_agents - pos.size())
	for k in n:
		pos.append(_centre(depuis) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)))
		cible.append(_centre(vers) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6)))
		vid.append(vers.id)
		vitesse.append(_rng.randf_range(14.0, 20.0))
		panique.append(0.0)
		attente.append(0.0)
		phase.append(_rng.randf() * TAU)
		multimesh.set_instance_custom_data(pos.size() - 1, monde.couleur_royaume(vers.royaume))
	multimesh.visible_instance_count = pos.size()


func paniquer(centre: Vector2, rayon: float) -> void:
	for i in pos.size():
		var d := pos[i] - centre
		var l := d.length()
		if l < rayon:
			var dir := d / l if l > 0.1 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
			cible[i] = pos[i] + dir * rayon * 1.3
			panique[i] = 1.6
			attente[i] = 0.0


## Retire jusqu'à `n` habitants proches d'un point ; renvoie leurs positions (pour les effets).
func tuer(centre: Vector2, rayon: float, n: int) -> PackedVector2Array:
	var morts := PackedVector2Array()
	var i := 0
	while i < pos.size() and morts.size() < n:
		if pos[i].distance_to(centre) < rayon:
			morts.append(pos[i])
			_retirer(i)
		else:
			i += 1
	multimesh.visible_instance_count = pos.size()
	return morts


func _retirer(i: int) -> void:
	var der := pos.size() - 1
	if i != der:
		pos[i] = pos[der]
		cible[i] = cible[der]
		vid[i] = vid[der]
		vitesse[i] = vitesse[der]
		panique[i] = panique[der]
		attente[i] = attente[der]
		phase[i] = phase[der]
		multimesh.set_instance_custom_data(i, multimesh.get_instance_custom_data(der))
	pos.resize(der)
	cible.resize(der)
	vid.resize(der)
	vitesse.resize(der)
	panique.resize(der)
	attente.resize(der)
	phase.resize(der)


func _nouvelle_cible(i: int) -> void:
	var v := monde.villages[vid[i]]
	var c := _centre(v)
	if _fronts.has(v.id) and _rng.randf() < 0.35:
		cible[i] = _fronts[v.id] + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
		return
	for essai in 4:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * v.rayon * 0.8 * TUILE
		var p := c + Vector2(cos(a), sin(a)) * r
		var tx := int(p.x / TUILE)
		var ty := int(p.y / TUILE)
		if monde.dans(tx, ty) and monde.type[ty * monde.w + tx] > World.MER:
			cible[i] = p
			return
	cible[i] = c


func _process(delta: float) -> void:
	if monde == null:
		return
	# Chaque habitant est mis à jour une image sur deux (pas doublé) : moitié moins de calcul.
	_parite = 1 - _parite
	delta *= 2.0
	var n := pos.size()
	var t := Time.get_ticks_msec() * 0.001
	for i in range(_parite, n, 2):
		var p := pos[i]
		var bouge := false
		if attente[i] > 0.0:
			attente[i] -= delta
		else:
			var d := cible[i] - p
			var l := d.length()
			var pas := vitesse[i] * (3.2 if panique[i] > 0.0 else 1.0) * delta
			if l <= pas:
				pos[i] = cible[i]
				attente[i] = _rng.randf_range(0.3, 2.5) if panique[i] <= 0.0 else 0.0
				_nouvelle_cible(i)
			else:
				pos[i] = p + d / l * pas
				bouge = true
		if panique[i] > 0.0:
			panique[i] -= delta
		var sx := -1.0 if cible[i].x < pos[i].x else 1.0
		var saut := -absf(sin(t * 12.0 + phase[i])) * 1.2 if bouge else 0.0
		multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(sx, 1.0), 0.0,
			Vector2(pos[i].x, pos[i].y + saut)))
