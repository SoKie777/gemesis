class_name VueVillages
extends Node2D
## Dessine les villages : le nombre de maisons suit la population, leur style suit l'ère,
## avec drapeau du royaume, temple, marqueurs de guerre, de maladie et de bénédiction.
## Tout passe par un seul MultiMesh (un appel GPU) et un atlas de sprites généré au lancement ;
## chaque village possède PLACES emplacements, réécrits seulement quand son apparence change.

const TUILE := 8.0
const PLACES := 22
const CADRES := 11
enum { TENTE, MAISON, PIERRE, IMMEUBLE, TEMPLE, DRAPEAU, DRAPEAU_CAPITALE, GUERRE, MALADE, BENI, RUINE }
const CACHE := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2(-100000, -100000))

var monde: World
var police: Font
var noms_visibles := false
var selection := -1
var _mm: MultiMesh
var _rendu: MultiMeshInstance2D
var _cles: Array = []
var _noms: Array[Etiquette] = []
var _anneau: Node2D


class Etiquette:
	extends Node2D
	var texte := ""
	var police: Font

	func _draw() -> void:
		var pos := Vector2(-80, 13)
		draw_string_outline(police, pos, texte, HORIZONTAL_ALIGNMENT_CENTER, 160, 6, 2, Color(0, 0, 0, 0.8))
		draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_CENTER, 160, 6, Color(1, 1, 1))


class Anneau:
	extends Node2D

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, Color(1, 1, 1, 0.85), 1.5)


func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_custom_data = true
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-8, -14), Vector2(8, -14), Vector2(8, 2), Vector2(-8, 2)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mm.mesh = am
	_rendu = MultiMeshInstance2D.new()
	_rendu.multimesh = _mm
	_rendu.texture = _atlas()
	_rendu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
varying vec4 teinte;
void vertex() {
	teinte = INSTANCE_CUSTOM;
	float cadre = floor(INSTANCE_CUSTOM.a * 255.0 + 0.5);
	UV.x = (UV.x + cadre) / %d.0;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.05) discard;
	if (t.a < 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, t.a);
	} else if (t.a < 0.85) {
		COLOR = vec4(teinte.rgb * (0.55 + 0.45 * t.r), 1.0);
	} else if (t.a < 0.95) {
		COLOR = vec4(mix(t.rgb, teinte.rgb, 0.45), 1.0);
	} else {
		COLOR = t;
	}
}
""" % CADRES
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_rendu.material = mat
	add_child(_rendu)
	_anneau = Anneau.new()
	_anneau.visible = false
	add_child(_anneau)


## Met à jour les villages dont l'apparence a changé. Appelé quand la simulation le signale.
func actualiser() -> void:
	if monde == null:
		return
	var n := monde.villages.size()
	if _mm.instance_count < n * PLACES:
		var capacite := maxi(64, n * 2)
		_mm.instance_count = capacite * PLACES
		for i in _mm.instance_count:
			_mm.set_instance_transform_2d(i, CACHE)
		_cles.clear()
	_mm.visible_instance_count = n * PLACES
	while _cles.size() < n:
		_cles.append([])
	while _noms.size() < n:
		var e := Etiquette.new()
		var v := monde.villages[_noms.size()]
		e.police = police
		e.texte = v.nom
		e.position = _centre(v)
		e.visible = noms_visibles and v.vivant
		add_child(e)
		_noms.append(e)
	for v in monde.villages:
		var cle: Array
		if v.vivant:
			cle = [_nb_maisons(v), v.ere, monde.couleur_royaume(v.royaume), v.temple, _capitale(v),
				monde.en_guerre(v.royaume), v.malade > 0, v.beni > 0]
		else:
			cle = [v.ruine]
		if cle != _cles[v.id]:
			_cles[v.id] = cle
			_ecrire(v)
			_noms[v.id].visible = noms_visibles and v.vivant
	if selection >= 0 and selection < n:
		_anneau.visible = true
		_anneau.position = _centre(monde.villages[selection])
	else:
		_anneau.visible = false


func afficher_noms(oui: bool) -> void:
	noms_visibles = oui
	if monde == null:
		return
	for e in _noms:
		e.visible = false
	for v in monde.vivants:
		if v.id < _noms.size():
			_noms[v.id].visible = oui


## Recrée tout (nouveau monde ou chargement).
func reinitialiser() -> void:
	for e in _noms:
		e.queue_free()
	_noms.clear()
	_cles.clear()
	_mm.instance_count = 0
	actualiser()


func _centre(v: Village) -> Vector2:
	return Vector2(v.x + 0.5, v.y + 0.5) * TUILE


func _nb_maisons(v: Village) -> int:
	return clampi(int(sqrt(maxf(v.pop, 1.0)) * 0.9), 1, 16)


func _capitale(v: Village) -> bool:
	return monde.royaumes.has(v.royaume) and monde.royaumes[v.royaume]["capitale"] == v.id


func _ecrire(v: Village) -> void:
	var base := v.id * PLACES
	var c := _centre(v)
	var k := 0
	var coul := monde.couleur_royaume(v.royaume)
	if not v.vivant:
		if v.ruine:
			_place(base, c, RUINE, coul)
			k = 1
	else:
		var cadre := TENTE
		if v.ere >= 5:
			cadre = IMMEUBLE
		elif v.ere >= 3:
			cadre = PIERRE
		elif v.ere >= 1:
			cadre = MAISON
		var maisons: Array[Vector2] = []
		for j in _nb_maisons(v):
			var a := j * 2.39996 + v.id
			var r := 0.0 if j == 0 else 3.0 + sqrt(j) * 4.4
			maisons.append((c + Vector2(cos(a), sin(a) * 0.75) * r + Vector2(0, 3)).round())
		maisons.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
		for p in maisons:
			_place(base + k, p, cadre, coul)
			k += 1
		if v.temple:
			_place(base + k, c + Vector2(11, -2), TEMPLE, coul)
			k += 1
		var capitale := _capitale(v)
		_place(base + k, c + Vector2(0, -1), DRAPEAU_CAPITALE if capitale else DRAPEAU, coul)
		k += 1
		if monde.en_guerre(v.royaume):
			_place(base + k, c + Vector2(-8, -12), GUERRE, coul)
			k += 1
		if v.malade > 0:
			_place(base + k, c + Vector2(9, -12), MALADE, coul)
			k += 1
		if v.beni > 0:
			_place(base + k, c + Vector2(0, -16), BENI, coul)
			k += 1
	for j in range(k, PLACES):
		_mm.set_instance_transform_2d(base + j, CACHE)


func _place(i: int, p: Vector2, cadre: int, coul: Color) -> void:
	_mm.set_instance_transform_2d(i, Transform2D(0.0, p))
	_mm.set_instance_custom_data(i, Color(coul.r, coul.g, coul.b, cadre / 255.0))


# ----------------------------------------------------------------------
# Atlas de sprites (16×16 par cadre). Alpha : <0.5 ombre, 0.8 teinte du royaume,
# 0.9 teinte partielle (toits), 1 couleur fixe.
# ----------------------------------------------------------------------

var _img: Image


func _r(cadre: int, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < 16 and yy >= 0 and yy < 16:
				_img.set_pixel(cadre * 16 + xx, yy, c)


## Triangle (toit) : sommet en (cx, haut), base de largeur 2*demi sur la ligne bas.
func _toit(cadre: int, cx: float, haut: int, bas: int, c: Color, ombre: Color) -> void:
	for y in range(haut, bas + 1):
		var demi := (y - haut + 1) * float(bas - haut + 2) / float(bas - haut + 1) * 0.5 + 0.5
		for x in range(int(cx - demi), int(cx + demi)):
			_r(cadre, x, y, 1, 1, c if x < cx else ombre)


func _atlas() -> ImageTexture:
	_img = Image.create(16 * CADRES, 16, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	var ombre := Color(0, 0, 0, 0.3)
	var toit := Color(0.72, 0.3, 0.2, 0.9)
	# Tente
	_r(TENTE, 3, 14, 10, 1, ombre)
	_toit(TENTE, 8.0, 7, 13, Color(0.82, 0.66, 0.42), Color(0.62, 0.48, 0.3))
	_r(TENTE, 7, 11, 2, 3, Color(0.25, 0.15, 0.08))
	# Maison
	_r(MAISON, 3, 14, 10, 1, ombre)
	_r(MAISON, 4, 10, 8, 4, Color(0.93, 0.85, 0.68))
	_r(MAISON, 10, 10, 2, 4, Color(0.78, 0.7, 0.55))
	_toit(MAISON, 8.0, 5, 9, toit, Color(0.55, 0.22, 0.15, 0.9))
	_r(MAISON, 6, 11, 2, 3, Color(0.35, 0.2, 0.1))
	# Pierre
	_r(PIERRE, 3, 14, 10, 1, ombre)
	_r(PIERRE, 4, 8, 8, 6, Color(0.74, 0.74, 0.76))
	_r(PIERRE, 10, 8, 2, 6, Color(0.58, 0.58, 0.62))
	_toit(PIERRE, 8.0, 3, 7, Color(0.32, 0.38, 0.6, 0.9), Color(0.24, 0.28, 0.46, 0.9))
	_r(PIERRE, 5, 10, 1, 1, Color(1.0, 0.86, 0.4))
	_r(PIERRE, 8, 10, 1, 1, Color(1.0, 0.86, 0.4))
	_r(PIERRE, 6, 12, 2, 2, Color(0.35, 0.22, 0.12))
	# Immeuble
	_r(IMMEUBLE, 4, 14, 9, 1, ombre)
	_r(IMMEUBLE, 5, 1, 6, 13, Color(0.6, 0.67, 0.78, 0.9))
	_r(IMMEUBLE, 9, 1, 2, 13, Color(0.45, 0.5, 0.6, 0.9))
	for y in range(3, 13, 2):
		_r(IMMEUBLE, 6, y, 1, 1, Color(1.0, 0.92, 0.5))
		_r(IMMEUBLE, 8, y, 1, 1, Color(1.0, 0.92, 0.5))
	# Temple
	_r(TEMPLE, 2, 14, 12, 1, ombre)
	_r(TEMPLE, 3, 9, 10, 5, Color(0.97, 0.95, 0.88))
	for x in [4, 7, 10]:
		_r(TEMPLE, x, 10, 1, 4, Color(0.8, 0.78, 0.7))
	_toit(TEMPLE, 8.0, 5, 8, Color(1.0, 0.84, 0.25), Color(0.85, 0.66, 0.15))
	# Drapeaux
	for cadre in [DRAPEAU, DRAPEAU_CAPITALE]:
		_r(cadre, 7, 3, 1, 12, Color(0.3, 0.2, 0.12))
		_r(cadre, 8, 3, 6, 4, Color(1, 1, 1, 0.8))
		_r(cadre, 8, 6, 6, 1, Color(0.7, 0.7, 0.7, 0.8))
	_r(DRAPEAU_CAPITALE, 6, 0, 3, 3, Color(1.0, 0.85, 0.2))
	# Guerre : épées croisées
	for k in 7:
		_r(GUERRE, 5 + k, 5 + k, 1, 1, Color(0.95, 0.95, 1.0))
		_r(GUERRE, 11 - k, 5 + k, 1, 1, Color(0.95, 0.95, 1.0))
	_r(GUERRE, 4, 12, 3, 1, Color(0.85, 0.15, 0.1))
	_r(GUERRE, 10, 12, 3, 1, Color(0.85, 0.15, 0.1))
	# Malade
	_r(MALADE, 6, 9, 3, 3, Color(0.5, 0.95, 0.3))
	_r(MALADE, 9, 6, 2, 2, Color(0.6, 1.0, 0.4))
	_r(MALADE, 11, 3, 1, 1, Color(0.6, 1.0, 0.4))
	# Béni : étincelle dorée
	_r(BENI, 7, 4, 1, 9, Color(1.0, 0.88, 0.35))
	_r(BENI, 3, 8, 9, 1, Color(1.0, 0.88, 0.35))
	_r(BENI, 6, 7, 3, 3, Color(1.0, 0.97, 0.75))
	# Ruine
	_r(RUINE, 2, 14, 12, 1, ombre)
	_r(RUINE, 3, 10, 2, 4, Color(0.48, 0.46, 0.45))
	_r(RUINE, 7, 8, 2, 6, Color(0.4, 0.38, 0.37))
	_r(RUINE, 11, 11, 3, 3, Color(0.48, 0.46, 0.45))
	return ImageTexture.create_from_image(_img)
