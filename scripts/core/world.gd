class_name World
extends RefCounted
## Simulation complète du monde, au pas d'un mois. Aucune dépendance à l'affichage :
## tout se teste en headless (tests/run_tests.gd). Le hasard passe uniquement par `rng`,
## donc même graine + mêmes actions = même histoire.

enum { ABYSSE, MER, SABLE, PRAIRIE, FORET, COLLINE, MONTAGNE, NEIGE, LAVE, CENDRE, DESERT }

## Nourriture potentielle d'une tuile possédée, par type.
const RENDEMENT := [0.0, 0.35, 0.15, 1.0, 0.6, 0.45, 0.1, 0.0, 0.0, 0.1, 0.08]
const NIVEAU_MER := 0.42
## Savoir cumulé nécessaire pour atteindre chaque ère.
const SEUILS := [0.0, 30.0, 90.0, 220.0, 500.0, 1100.0, 2300.0, 4500.0]
const PRIERES_MAX := 4
const VERSION_SAUVEGARDE := 1

var w := 220
var h := 130
var graine := 0
var rng := RandomNumberGenerator.new()
var mois := 0

var hauteur := PackedFloat32Array()
var humid := PackedFloat32Array()
var humid_base := PackedFloat32Array()
var type := PackedByteArray()
var feu := PackedByteArray()
var lave := PackedByteArray()
var cendre := PackedByteArray()
var champ := PackedByteArray()
var proprio := PackedInt32Array()
var en_feu := PackedInt32Array()
## Tuiles dont la lave ou la cendre doivent évoluer (indice -> true).
var speciaux := {}
var curseur_humid := 0

var villages: Array[Village] = []
## Les villages vivants seulement (les boucles chaudes ne parcourent pas les ruines).
var vivants: Array[Village] = []
const CELLULE := 16
var _grille := {}
var _grille_sale := true
## id -> {nom, couleur, capitale}
var royaumes := {}
var prochain_royaume := 0
## {a, b, mois} : guerre entre deux royaumes.
var guerres: Array = []
var _ennemis := {}
## {v, genre, cible, delai, texte}
var prieres: Array = []
## {an, texte, genre}
var journal: Array = []

# --- Sorties pour l'affichage (vidées par l'UI, plafonnées en headless) ---
var sales := PackedInt32Array()
var proprio_sales := PackedInt32Array()
var tout_sale := true
var villages_sale := true
var nouvelles: Array = []
var effets: Array = []


# ======================================================================
# Génération
# ======================================================================

func generer(graine_: int, nb_tribus := 7) -> void:
	graine = graine_
	rng.seed = graine_
	var n := w * h
	hauteur.resize(n)
	humid.resize(n)
	humid_base.resize(n)
	type.resize(n)
	feu.resize(n)
	lave.resize(n)
	cendre.resize(n)
	champ.resize(n)
	proprio.resize(n)
	proprio.fill(-1)

	var relief := FastNoiseLite.new()
	relief.seed = graine_
	relief.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	relief.frequency = 0.022
	relief.fractal_octaves = 5
	var pluie := FastNoiseLite.new()
	pluie.seed = graine_ + 77
	pluie.frequency = 0.03
	pluie.fractal_octaves = 3

	var cretes := FastNoiseLite.new()
	cretes.seed = graine_ + 131
	cretes.frequency = 0.035
	cretes.fractal_octaves = 2

	var centres: Array[Vector3] = []
	for i in rng.randi_range(2, 4):
		centres.append(Vector3(rng.randf_range(w * 0.2, w * 0.8), rng.randf_range(h * 0.25, h * 0.75),
			rng.randf_range(34.0, 62.0)))

	for y in h:
		for x in w:
			var b := 0.0
			for c in centres:
				var d := Vector2(x - c.x, (y - c.y) * 1.35).length() / c.z
				b = maxf(b, 1.0 - d * d)
			var bord := clampf(minf(minf(x, w - 1 - x), minf(y, h - 1 - y)) / 10.0, 0.0, 1.0)
			var cr := pow(1.0 - absf(cretes.get_noise_2d(x, y)), 5.0)
			var v := (0.23 + b * 0.4 + relief.get_noise_2d(x, y) * 0.42 + cr * b * 0.38) * bord
			var i := y * w + x
			hauteur[i] = clampf(v, 0.0, 1.0)
			humid_base[i] = clampf(0.52 + pluie.get_noise_2d(x, y) * 0.8, 0.0, 1.0)
			humid[i] = humid_base[i]
	for i in n:
		type[i] = _classer(i)

	for t in nb_tribus:
		var p := _site_libre(60, 16.0)
		if p.x >= 0:
			creer_village(p.x, p.y, rng.randf_range(12.0, 25.0), -1, null)
	for v in villages:
		_scanner(v)
	_annoncer(Textes.choisir(rng, "debut"), "divin")
	tout_sale = true


func _classer(i: int) -> int:
	if lave[i] > 0:
		return LAVE
	var hh := hauteur[i]
	if hh < 0.30:
		return ABYSSE
	if hh < NIVEAU_MER:
		return MER
	if cendre[i] > 0:
		return CENDRE
	if hh < 0.45:
		return SABLE
	if hh < 0.70:
		var m := humid[i]
		if m < 0.22:
			return DESERT
		if m < 0.55:
			return PRAIRIE
		return FORET
	if hh < 0.79:
		return COLLINE
	if hh < 0.92:
		return MONTAGNE
	return NEIGE


func _reclasser(i: int) -> void:
	var t := _classer(i)
	if t != type[i]:
		type[i] = t
		_sale(i)


func _sale(i: int) -> void:
	if tout_sale:
		return
	sales.append(i)
	if sales.size() > 20000:
		sales.clear()
		tout_sale = true


func _sale_proprio(i: int) -> void:
	proprio_sales.append(i)
	if proprio_sales.size() > 40000:
		proprio_sales.clear()


func _site_libre(essais: int, dmin: float) -> Vector2i:
	var meilleur := Vector2i(-1, -1)
	var score_max := -1.0
	for k in essais:
		var x := rng.randi_range(4, w - 5)
		var y := rng.randi_range(4, h - 5)
		var t := type[y * w + x]
		if t != PRAIRIE and t != FORET and t != COLLINE:
			continue
		if village_proche(x, y, dmin) != null:
			continue
		var s := _score_site(x, y)
		if s > score_max:
			score_max = s
			meilleur = Vector2i(x, y)
	return meilleur


func _score_site(x: int, y: int) -> float:
	var s := 0.0
	for yy in range(maxi(0, y - 3), mini(h, y + 4)):
		for xx in range(maxi(0, x - 3), mini(w, x + 4)):
			s += RENDEMENT[type[yy * w + xx]]
	return s


# ======================================================================
# Villages et royaumes
# ======================================================================

func creer_village(x: int, y: int, pop: float, roy: int, parent: Village) -> Village:
	var v := Village.new()
	v.id = villages.size()
	v.nom = Noms.village(rng)
	v.x = x
	v.y = y
	v.pop = pop
	v.nourriture = pop
	v.fonde = annee()
	v.chef_nom = Noms.chef(rng)
	v.chef_age = rng.randi_range(18, 45)
	v.chef_trait = Textes.TRAITS[rng.randi() % Textes.TRAITS.size()]
	if parent != null:
		v.culture = parent.culture
		v.dieu = parent.dieu
		v.ere = parent.ere
		v.savoir = parent.savoir * 0.7
		v.foi = parent.foi
		if rng.randf() < 0.12:
			v.dieu = Noms.dieu(rng)
	else:
		v.culture = Textes.CULTURES[rng.randi() % Textes.CULTURES.size()]
		v.dieu = Noms.dieu(rng)
		v.foi = rng.randf_range(20.0, 45.0)
	if roy < 0 or not royaumes.has(roy):
		roy = prochain_royaume
		prochain_royaume += 1
		royaumes[roy] = {
			"nom": v.nom,
			"couleur": Color.from_hsv(rng.randf(), rng.randf_range(0.6, 0.85), rng.randf_range(0.85, 1.0)),
			"capitale": v.id,
		}
	v.royaume = roy
	villages.append(v)
	vivants.append(v)
	_grille_sale = true
	villages_sale = true
	return v


func _cellule(x: int, y: int) -> int:
	return floori(y / float(CELLULE)) * 1000 + floori(x / float(CELLULE))


func _indexer_grille() -> void:
	_grille.clear()
	for v in vivants:
		var c := _cellule(v.x, v.y)
		if not _grille.has(c):
			_grille[c] = []
		_grille[c].append(v)
	_grille_sale = false


func village_proche(x: int, y: int, rmax: float) -> Village:
	if _grille_sale:
		_indexer_grille()
	var meilleur: Village = null
	var d2max := rmax * rmax
	var cx0 := floori((x - rmax) / CELLULE)
	var cx1 := floori((x + rmax) / CELLULE)
	var cy0 := floori((y - rmax) / CELLULE)
	var cy1 := floori((y + rmax) / CELLULE)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			for v: Village in _grille.get(cy * 1000 + cx, []):
				var d2 := float((v.x - x) * (v.x - x) + (v.y - y) * (v.y - y))
				if d2 <= d2max:
					d2max = d2
					meilleur = v
	return meilleur


func _village_proche_lent(x: int, y: int, rmax: float) -> Village:
	var meilleur: Village = null
	var d2max := rmax * rmax
	for v in vivants:
		if not v.vivant:
			continue
		var d2 := float((v.x - x) * (v.x - x) + (v.y - y) * (v.y - y))
		if d2 <= d2max:
			d2max = d2
			meilleur = v
	return meilleur


func villages_du_royaume(roy: int) -> Array[Village]:
	var res: Array[Village] = []
	for v in vivants:
		if v.vivant and v.royaume == roy:
			res.append(v)
	return res


func couleur_royaume(roy: int) -> Color:
	var r: Dictionary = royaumes.get(roy, {})
	return r.get("couleur", Color.GRAY)


func nom_royaume(roy: int) -> String:
	if not royaumes.has(roy):
		return "un royaume oublié"
	var membres := villages_du_royaume(roy)
	var ere_max := 0
	for v in membres:
		ere_max = maxi(ere_max, v.ere)
	var titre := "Tribu"
	if membres.size() >= 8:
		titre = "Empire"
	elif membres.size() >= 4:
		titre = "Royaume"
	elif membres.size() >= 2:
		titre = "Chefferie"
	if ere_max >= 5:
		titre = "République" if membres.size() < 8 else "Fédération"
	return "%s de %s" % [titre, royaumes[roy]["nom"]]


func en_guerre(roy: int) -> bool:
	return _ennemis.has(roy)


func ennemi_de(roy: int) -> int:
	return _ennemis.get(roy, -1)


## Reconstruit l'index royaume -> ennemi après toute modification de `guerres`.
func _indexer_guerres() -> void:
	_ennemis.clear()
	for g: Dictionary in guerres:
		if not _ennemis.has(g["a"]):
			_ennemis[g["a"]] = g["b"]
		if not _ennemis.has(g["b"]):
			_ennemis[g["b"]] = g["a"]


func _guerre_entre(a: int, b: int) -> bool:
	for g: Dictionary in guerres:
		if (g["a"] == a and g["b"] == b) or (g["a"] == b and g["b"] == a):
			return true
	return false


## Revendique les tuiles autour du village et calcule son rendement agricole.
func _scanner(v: Village) -> void:
	var nouveau := clampf(2.5 + sqrt(maxf(v.pop, 0.0)) * 0.5, 3.0, 11.0)
	var r := int(ceil(maxf(nouveau, v.rayon_scan))) + 1
	v.rayon = nouveau
	v.rayon_scan = nouveau
	var r2 := nouveau * nouveau
	var champs := 1.5 + v.ere * 0.6 if v.ere >= 1 else -1.0
	var c2 := champs * champs
	var somme := 0.0
	for yy in range(maxi(0, v.y - r), mini(h, v.y + r + 1)):
		var dy := yy - v.y
		var dy2 := dy * dy
		var ligne := yy * w
		for xx in range(maxi(0, v.x - r), mini(w, v.x + r + 1)):
			var i := ligne + xx
			var o := proprio[i]
			var d2 := (xx - v.x) * (xx - v.x) + dy2
			var dedans := d2 <= r2
			if not dedans and o != v.id:
				continue
			var t := type[i]
			if v.vivant and dedans and t != ABYSSE and t != LAVE and (o == -1 or o == v.id):
				if o != v.id:
					proprio[i] = v.id
					_sale_proprio(i)
				somme += RENDEMENT[t]
				var c := 1 if t == PRAIRIE and d2 <= c2 else 0
				if champ[i] != c:
					champ[i] = c
					_sale(i)
			elif o == v.id:
				proprio[i] = -1
				_sale_proprio(i)
				if champ[i] != 0:
					champ[i] = 0
					_sale(i)
	v.rendement = somme
	villages_sale = true


## Signale à l'affichage que toutes les tuiles du village ont changé de couleur.
func _marquer_territoire(v: Village) -> void:
	var r := int(ceil(v.rayon_scan)) + 1
	for yy in range(maxi(0, v.y - r), mini(h, v.y + r + 1)):
		for xx in range(maxi(0, v.x - r), mini(w, v.x + r + 1)):
			var i := yy * w + xx
			if proprio[i] == v.id:
				_sale_proprio(i)


func _detruire(v: Village, cle: String) -> void:
	if not v.vivant:
		return
	v.vivant = false
	v.ruine = true
	vivants.erase(v)
	_grille_sale = true
	v.pop = 0.0
	_scanner(v)
	for o in vivants:
		if absi(o.x - v.x) + absi(o.y - v.y) < 30:
			o.scan_requis = true
	_annoncer(Textes.choisir(rng, cle, {"v": v.nom}), "mort", v)
	effets.append({"genre": "ruine", "x": v.x, "y": v.y})
	prieres = prieres.filter(func(p: Dictionary) -> bool: return p["v"] != v.id)
	_verifier_royaume(v.royaume)
	if population_totale() <= 0.0:
		_annoncer(Textes.choisir(rng, "extinction"), "mort")


func _verifier_royaume(roy: int) -> void:
	if not royaumes.has(roy):
		return
	var membres := villages_du_royaume(roy)
	if membres.is_empty():
		var nom := nom_royaume(roy)
		_annoncer(Textes.choisir(rng, "chute", {"r": nom}), "guerre")
		guerres = guerres.filter(func(g: Dictionary) -> bool: return g["a"] != roy and g["b"] != roy)
		_indexer_guerres()
		royaumes.erase(roy)
		return
	var cap: int = royaumes[roy]["capitale"]
	if not villages[cap].vivant or villages[cap].royaume != roy:
		var plus_grand := membres[0]
		for m in membres:
			if m.pop > plus_grand.pop:
				plus_grand = m
		royaumes[roy]["capitale"] = plus_grand.id
		royaumes[roy]["nom"] = plus_grand.nom


func _conquerir(v: Village, roy: int) -> void:
	var ancien := v.royaume
	v.royaume = roy
	v.pop *= 0.8
	v.humeur = 30.0
	_marquer_territoire(v)
	_annoncer(Textes.choisir(rng, "conquete", {"v": v.nom, "r": nom_royaume(roy)}), "guerre", v)
	effets.append({"genre": "conquete", "x": v.x, "y": v.y})
	villages_sale = true
	_verifier_royaume(ancien)


# ======================================================================
# Temps
# ======================================================================

func annee() -> int:
	return floori(mois / 12.0)


func pas() -> void:
	mois += 1
	var m := mois % 12
	_maj_humidite()
	_maj_feux()
	_maj_speciaux()
	for v in vivants.duplicate():
		if not v.vivant:
			continue
		_mois_village(v)
		if v.vivant and v.id % 12 == m:
			_annee_village(v)
	_maj_guerres()
	_tensions(m)
	if m == 0:
		_annee_monde()
	_maj_prieres()
	if nouvelles.size() > 60:
		nouvelles = nouvelles.slice(-60)
	if effets.size() > 60:
		effets = effets.slice(-60)


func _maj_humidite() -> void:
	# Seules les terres de moyenne altitude changent de biome avec l'humidité.
	var n := w * h
	var fin := mini(curseur_humid + ceili(n / 48.0), n)
	for i in range(curseur_humid, fin):
		var hh := hauteur[i]
		if hh < 0.45 or hh >= 0.70:
			continue
		var m := humid[i] + (humid_base[i] - humid[i]) * 0.06
		humid[i] = m
		if lave[i] > 0 or cendre[i] > 0:
			continue
		var t := DESERT if m < 0.22 else (PRAIRIE if m < 0.55 else FORET)
		if t != type[i]:
			type[i] = t
			_sale(i)
	curseur_humid = 0 if fin >= n else fin


func _allumer(i: int) -> void:
	if feu[i] > 0:
		return
	var t := type[i]
	if t == FORET or t == PRAIRIE or t == COLLINE:
		feu[i] = 4 if t == FORET else 2
		en_feu.append(i)
		_sale(i)


func _maj_feux() -> void:
	if en_feu.is_empty():
		return
	var suivants := PackedInt32Array()
	for i in en_feu:
		if feu[i] == 0:
			_sale(i)
			continue
		feu[i] -= 1
		var x := i % w
		var y := floori(i / float(w))
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx := x + d.x
			var yy := y + d.y
			if not dans(xx, yy):
				continue
			var j := yy * w + xx
			if feu[j] > 0:
				continue
			var t := type[j]
			var p := 0.24 if t == FORET else (0.1 if t == PRAIRIE else 0.0)
			if p > 0.0 and rng.randf() < p * (1.25 - humid[j]):
				feu[j] = 4 if t == FORET else 2
				suivants.append(j)
				_sale(j)
		var o := proprio[i]
		if o >= 0:
			var v := villages[o]
			if v.vivant and absi(v.x - x) <= 2 and absi(v.y - y) <= 2:
				v.pop -= v.pop * 0.03
				v.humeur -= 1.0
				_annoncer_rare(v, "incendie", "catastrophe")
		if feu[i] == 0:
			cendre[i] = 18
			humid[i] = minf(1.0, humid[i] + 0.05)
			speciaux[i] = true
			_reclasser(i)
			_sale(i)
		else:
			suivants.append(i)
	en_feu = suivants


func _maj_speciaux() -> void:
	if speciaux.is_empty():
		return
	var finis := []
	for i: int in speciaux:
		if lave[i] > 0:
			lave[i] -= 1
			if lave[i] == 0:
				hauteur[i] = maxf(hauteur[i], NIVEAU_MER + 0.04) + 0.02
				cendre[i] = 24
				_reclasser(i)
				_sale(i)
		elif cendre[i] > 0:
			cendre[i] -= 1
			if cendre[i] == 0:
				finis.append(i)
				_reclasser(i)
		else:
			finis.append(i)
	for i: int in finis:
		speciaux.erase(i)


func _mois_village(v: Village) -> void:
	var ere_mult := 1.0 + 0.3 * v.ere
	var potentiel := v.rendement * 0.12 * ere_mult * (1.6 if v.beni > 0 else 1.0)
	var travail := v.pop * 0.125 * (1.0 + 0.25 * v.ere) * (0.8 if v.chef_trait == "flemmard" else 1.0)
	var conso := v.pop * 0.1
	v.nourriture += minf(potentiel, travail) - conso
	if v.nourriture < 0.0:
		var manque := -v.nourriture
		v.nourriture = 0.0
		v.pop -= manque * 1.5
		v.humeur -= 2.0
		if not v.faim:
			v.faim = true
			_annoncer_rare(v, "famine", "catastrophe")
	else:
		if v.nourriture > v.pop * 0.6:
			v.faim = false
		if v.nourriture > v.pop * 0.3:
			v.pop += v.pop * 0.0035 * (0.5 + v.humeur / 100.0)
	v.nourriture = minf(v.nourriture, v.pop * 3.0)

	if v.malade > 0:
		v.malade -= 1
		v.pop -= v.pop * 0.018
		v.humeur -= 0.5
		if v.malade == 0:
			_annoncer(Textes.choisir(rng, "peste_fin", {"v": v.nom}), "vie", v)
	if v.beni > 0:
		v.beni -= 1

	var guerre := en_guerre(v.royaume)
	var cible := 55.0 + (v.foi - 30.0) * 0.2
	if v.chef_trait == "généreux":
		cible += 10.0
	if v.faim:
		cible -= 25.0
	if guerre:
		cible -= 10.0
	if v.beni > 0:
		cible += 20.0
	v.humeur = clampf(lerpf(v.humeur, cible, 0.05), 0.0, 100.0)

	var foi_base := 25.0
	match v.culture:
		"pieuse":
			foi_base = 40.0
		"sceptique":
			foi_base = 10.0
	if v.chef_trait == "mystique":
		foi_base += 10.0
	v.foi = clampf(lerpf(v.foi, foi_base, 0.004), 0.0, 100.0)

	var mult := 1.0
	if v.culture == "sceptique" or v.culture == "marchande":
		mult = 1.25
	if v.chef_trait == "génie incompris":
		mult *= 1.3
	elif v.chef_trait == "flemmard":
		mult *= 0.7
	v.savoir += v.pop * 0.0006 * (0.5 + v.humeur / 100.0) * mult
	if v.ere < SEUILS.size() - 1 and v.savoir >= SEUILS[v.ere + 1]:
		v.ere += 1
		v.scan_requis = true
		_annoncer(Textes.choisir(rng, "ere", {"v": v.nom, "e": Textes.ERES[v.ere]}), "ere", v)
		effets.append({"genre": "ere", "x": v.x, "y": v.y, "ere": v.ere})
		villages_sale = true
	if v.pop < 1.0:
		_detruire(v, "desertion")


func _annee_village(v: Village) -> void:
	v.chef_age += 1
	var p_mort := 0.006 + maxf(0.0, v.chef_age - 45.0) * 0.007
	if rng.randf() < p_mort:
		_annoncer(Textes.choisir(rng, "mort_chef", {"c": v.chef_nom, "v": v.nom, "k": v.chef_age,
			"m": Textes.choisir(rng, "cause")}), "mort", v)
		v.chef_nom = Noms.chef(rng)
		v.chef_age = rng.randi_range(18, 45)
		v.chef_trait = Textes.TRAITS[rng.randi() % Textes.TRAITS.size()]
		_annoncer(Textes.choisir(rng, "nouveau_chef", {"c": v.chef_nom, "v": v.nom, "k": v.chef_age,
			"t": v.chef_trait}), "vie", v)
	if rng.randf() < 0.06:
		_annoncer(Textes.choisir(rng, "vie", _params(v)), "vie", v)
		v.humeur = clampf(v.humeur + rng.randf_range(-6.0, 6.0), 0.0, 100.0)
	if not v.temple and v.foi > 75.0 and v.pop > 30.0:
		v.temple = true
		_annoncer(Textes.choisir(rng, "temple", {"v": v.nom}), "divin", v)
		effets.append({"genre": "temple", "x": v.x, "y": v.y})

	var r_voulu := clampf(2.5 + sqrt(maxf(v.pop, 0.0)) * 0.5, 3.0, 11.0)
	if v.scan_requis or absf(r_voulu - v.rayon) >= 1.0 or (annee() + v.id) % 8 == 0:
		v.scan_requis = false
		_scanner(v)

	if v.pop > 90.0 and v.nourriture > v.pop * 0.8 and rng.randf() < 0.3:
		_coloniser(v)
	if v.malade > 0:
		for o in vivants:
			if o.vivant and o != v and o.malade == 0 and absi(o.x - v.x) + absi(o.y - v.y) < 22 \
					and rng.randf() < 0.25:
				o.malade = 24
				_annoncer(Textes.choisir(rng, "peste_propage", {"v": o.nom, "p": v.nom}), "catastrophe", o)
	# Les voisins plus avancés transmettent un peu de leur savoir.
	for o in vivants:
		if o.vivant and o.ere > v.ere and absi(o.x - v.x) + absi(o.y - v.y) < 30 \
				and not _guerre_entre(o.royaume, v.royaume):
			v.savoir += (o.savoir - v.savoir) * 0.02
	if v.foi > 15.0 and prieres.size() < PRIERES_MAX and rng.randf() < 0.08 + v.foi / 600.0:
		_priere(v)


func _coloniser(v: Village) -> void:
	var meilleur := Vector2i(-1, -1)
	var score_max := -1.0
	for k in 25:
		var a := rng.randf() * TAU
		var d := rng.randf_range(9.0, 22.0)
		var x := v.x + int(cos(a) * d)
		var y := v.y + int(sin(a) * d)
		if not dans(x, y):
			continue
		var i := y * w + x
		var t := type[i]
		if t != PRAIRIE and t != FORET and t != COLLINE and t != SABLE:
			continue
		if proprio[i] != -1 or village_proche(x, y, 8.0) != null:
			continue
		var s := _score_site(x, y)
		if s > score_max:
			score_max = s
			meilleur = Vector2i(x, y)
	if meilleur.x < 0:
		return
	var colons := minf(v.pop * 0.2, 25.0)
	v.pop -= colons
	var independant := rng.randf() < 0.25
	var nv := creer_village(meilleur.x, meilleur.y, colons, -1 if independant else v.royaume, v)
	_scanner(nv)
	var cle := "independance" if independant else "fondation"
	_annoncer(Textes.choisir(rng, cle, {"v": nv.nom, "p": v.nom}), "naissance", nv)
	effets.append({"genre": "fondation", "x": nv.x, "y": nv.y, "depuis": v.id})


## Tensions entre voisins : chaque mois traite un douzième des villages (évite les pics de calcul).
func _tensions(m: int) -> void:
	var liste := vivants.duplicate()
	var n := liste.size()
	for i in n:
		var a: Village = liste[i]
		if not a.vivant or a.id % 12 != m:
			continue
		for j in n:
			var b: Village = liste[j]
			if j == i or not b.vivant or a.royaume == b.royaume or (b.id % 12 == m and j < i):
				continue
			var portee := a.rayon + b.rayon + 4.0
			var dx := a.x - b.x
			var dy := a.y - b.y
			if dx * dx + dy * dy > portee * portee or _guerre_entre(a.royaume, b.royaume):
				continue
			var tension := 0.012 + _tension(a) + _tension(b)
			if a.dieu != b.dieu:
				tension += 0.012
			if rng.randf() < tension:
				_declarer(a, b, Textes.choisir(rng, "motif", {}))


func _annee_monde() -> void:
	for g: Dictionary in guerres.duplicate():
		if g["mois"] > 18 and rng.randf() < 0.1 + g["mois"] / 700.0:
			_paix(g)


func _tension(v: Village) -> float:
	var t := 0.0
	if v.culture == "belliqueuse":
		t += 0.03
	elif v.culture == "pacifique":
		t -= 0.006
	if v.chef_trait == "colérique" or v.chef_trait == "ambitieux" or v.chef_trait == "paranoïaque":
		t += 0.015
	if v.faim:
		t += 0.025
	return t


func _declarer(a: Village, b: Village, motif: String) -> void:
	if a.royaume == b.royaume or _guerre_entre(a.royaume, b.royaume):
		return
	guerres.append({"a": a.royaume, "b": b.royaume, "mois": 0})
	_indexer_guerres()
	_annoncer(Textes.choisir(rng, "guerre", {"a": nom_royaume(a.royaume), "b": nom_royaume(b.royaume),
		"m": motif}), "guerre", a)
	effets.append({"genre": "guerre", "x": a.x, "y": a.y})
	villages_sale = true


func _paix(g: Dictionary) -> void:
	guerres.erase(g)
	_indexer_guerres()
	_annoncer(Textes.choisir(rng, "paix", {"a": nom_royaume(g["a"]), "b": nom_royaume(g["b"])}), "naissance")
	villages_sale = true


func _force(v: Village) -> float:
	var f := v.pop * (1.0 + 0.35 * v.ere)
	if v.culture == "belliqueuse":
		f *= 1.3
	if v.beni > 0:
		f *= 1.3
	return f


## Les deux villages les plus proches de deux royaumes en guerre.
func front(a: int, b: int) -> Array:
	var meilleur: Array = []
	var dmin := 45.0 * 45.0
	for va in vivants:
		if not va.vivant or va.royaume != a:
			continue
		for vb in vivants:
			if not vb.vivant or vb.royaume != b:
				continue
			var d2 := float((va.x - vb.x) * (va.x - vb.x) + (va.y - vb.y) * (va.y - vb.y))
			if d2 < dmin:
				dmin = d2
				meilleur = [va, vb]
	return meilleur


func _maj_guerres() -> void:
	for g: Dictionary in guerres.duplicate():
		if not guerres.has(g):
			continue
		g["mois"] += 1
		# Le front est mis en cache dans la guerre ; on le recalcule s'il n'est plus valable.
		var fa: int = g.get("fa", -1)
		var fb: int = g.get("fb", -1)
		if fa < 0 or g["mois"] % 12 == 0 or not villages[fa].vivant or not villages[fb].vivant 				or villages[fa].royaume != g["a"] or villages[fb].royaume != g["b"]:
			var paire := front(g["a"], g["b"])
			fa = (paire[0] as Village).id if paire.size() == 2 else -1
			fb = (paire[1] as Village).id if paire.size() == 2 else -1
			g["fa"] = fa
			g["fb"] = fb
		if fa < 0:
			continue
		var va: Village = villages[fa]
		var vb: Village = villages[fb]
		var force_a := _force(va)
		var force_b := _force(vb)
		va.pop -= force_b * 0.012 * rng.randf_range(0.5, 1.5)
		vb.pop -= force_a * 0.012 * rng.randf_range(0.5, 1.5)
		if g["mois"] % 2 == 0:
			effets.append({"genre": "bataille", "x": (va.x + vb.x) * 0.5, "y": (va.y + vb.y) * 0.5})
		if va.pop < 8.0:
			if va.pop < 3.0:
				_detruire(va, "ruine")
			else:
				_conquerir(va, vb.royaume)
		elif vb.pop < 8.0:
			if vb.pop < 3.0:
				_detruire(vb, "ruine")
			else:
				_conquerir(vb, va.royaume)


# ======================================================================
# Prières
# ======================================================================

func _priere(v: Village) -> void:
	for p: Dictionary in prieres:
		if p["v"] == v.id:
			return
	var genre := "signe"
	var cible := -1
	var ennemi := ennemi_de(v.royaume)
	if v.faim or v.nourriture < v.pop * 0.3:
		genre = "pluie" if rng.randf() < 0.5 else "nourriture"
	elif v.malade > 0:
		genre = "guerison"
	elif ennemi >= 0:
		var paire := front(v.royaume, ennemi)
		if v.humeur < 35.0 or paire.is_empty():
			genre = "paix"
		else:
			genre = "victoire"
			cible = (paire[1] as Village).id
	else:
		var r := rng.randf()
		if r < 0.35:
			var voisin: Village = null
			var dmin := 40.0 * 40.0
			for o in vivants:
				if o.vivant and o.royaume != v.royaume:
					var d2 := float((o.x - v.x) * (o.x - v.x) + (o.y - v.y) * (o.y - v.y))
					if d2 < dmin:
						dmin = d2
						voisin = o
			if voisin != null:
				genre = "foudre"
				cible = voisin.id
		elif r < 0.6:
			genre = "fortune"
	var p := _params(v)
	if cible >= 0:
		p["x"] = villages[cible].nom
	var texte := Textes.choisir(rng, "priere_" + genre, p)
	prieres.append({"v": v.id, "genre": genre, "cible": cible, "delai": 40, "texte": texte})
	_annoncer(texte, "priere", v)


func _maj_prieres() -> void:
	for p: Dictionary in prieres.duplicate():
		p["delai"] -= 1
		if p["delai"] <= 0:
			_rejeter(p, false)


func _rejeter(p: Dictionary, volontaire: bool) -> void:
	prieres.erase(p)
	var v := villages[p["v"]]
	if not v.vivant:
		return
	v.foi = maxf(0.0, v.foi - (16.0 if volontaire else 12.0))
	v.humeur -= 5.0
	_annoncer(Textes.choisir(rng, "priere_ko", _params(v)), "priere", v)


func ignorer_priere(indice: int) -> void:
	if indice >= 0 and indice < prieres.size():
		_rejeter(prieres[indice], true)


## Exauce les prières dont le genre fait partie de `genres` pour les villages listés.
func _exaucer(ids: Array, genres: Array, cible := -1) -> void:
	for p: Dictionary in prieres.duplicate():
		if not genres.has(p["genre"]):
			continue
		var ok := false
		if p["genre"] == "foudre":
			ok = p["cible"] == cible
		elif p["genre"] == "victoire":
			ok = ids.has(p["v"]) or \
				(cible >= 0 and villages[cible].royaume == ennemi_de(villages[p["v"]].royaume))
		else:
			ok = ids.has(p["v"])
		if not ok:
			continue
		prieres.erase(p)
		var v := villages[p["v"]]
		if not v.vivant:
			continue
		v.foi = minf(100.0, v.foi + 25.0)
		v.humeur = minf(100.0, v.humeur + 10.0)
		_annoncer(Textes.choisir(rng, "priere_ok", _params(v)), "divin", v)
		effets.append({"genre": "exauce", "x": v.x, "y": v.y})


# ======================================================================
# Pouvoirs divins
# ======================================================================

func pouvoir(nom: String, x: int, y: int) -> Dictionary:
	if not dans(x, y):
		return {}
	match nom:
		"humains":
			return _p_humains(x, y)
		"pluie":
			return _p_humidite(x, y, 0.06)
		"secheresse":
			return _p_humidite(x, y, -0.06)
		"foudre":
			return _p_foudre(x, y)
		"meteore":
			return _p_meteore(x, y)
		"benir":
			return _p_benir(x, y)
		"peste":
			return _p_peste(x, y)
		"signe":
			return _p_signe(x, y)
		"discorde":
			return _p_discorde(x, y)
		"elever":
			return _p_relief(x, y, 0.022)
		"creuser":
			return _p_relief(x, y, -0.022)
	return {}


func _p_humains(x: int, y: int) -> Dictionary:
	var t := type[y * w + x]
	if t == ABYSSE or t == MER or t == LAVE or t == NEIGE:
		return {"rate": "Ils ne savent pas nager. Ni survivre dans la lave. Essaie la terre ferme."}
	var v := village_proche(x, y, 4.0)
	if v != null:
		v.pop += 8.0
		_annoncer_rare(v, "renfort", "naissance")
		return {"village": v.id}
	v = creer_village(x, y, 10.0, -1, null)
	_scanner(v)
	_annoncer(Textes.choisir(rng, "creation", {"v": v.nom}), "naissance", v)
	return {"village": v.id, "nouveau": true}


func _villages_touches(x: int, y: int, r: int) -> Array:
	var ids := []
	for yy in range(maxi(0, y - r), mini(h, y + r + 1)):
		for xx in range(maxi(0, x - r), mini(w, x + r + 1)):
			var o := proprio[yy * w + xx]
			if o >= 0 and not ids.has(o):
				ids.append(o)
	return ids


func _p_humidite(x: int, y: int, delta: float) -> Dictionary:
	var r := 4
	for yy in range(maxi(0, y - r), mini(h, y + r + 1)):
		for xx in range(maxi(0, x - r), mini(w, x + r + 1)):
			var d := Vector2(xx - x, yy - y).length()
			if d > r:
				continue
			var i := yy * w + xx
			humid[i] = clampf(humid[i] + delta * (1.0 - d / (r + 1.0)), 0.0, 1.0)
			if delta > 0.0 and feu[i] > 0:
				feu[i] = 0
				_sale(i)
			if lave[i] == 0 and cendre[i] == 0:
				_reclasser(i)
	var ids := _villages_touches(x, y, r)
	for id: int in ids:
		var v := villages[id]
		if not v.vivant:
			continue
		_scanner(v)
		var m := humid[v.y * w + v.x]
		if delta > 0.0 and m > 0.93:
			v.pop *= 0.97
			_annoncer_rare(v, "inondation", "catastrophe")
		elif delta < 0.0 and m < 0.1:
			v.humeur -= 2.0
			_annoncer_rare(v, "secheresse", "catastrophe")
	if delta > 0.0:
		_exaucer(ids, ["pluie", "nourriture"])
	return {"villages": ids}


func _peur(v: Village, force: float) -> void:
	match v.culture:
		"pieuse":
			v.foi = minf(100.0, v.foi + 8.0 * force)
		"sceptique":
			v.foi = maxf(0.0, v.foi - 6.0 * force)
		_:
			v.foi = minf(100.0, v.foi + 4.0 * force)
	v.humeur = maxf(0.0, v.humeur - 6.0 * force)


func _p_foudre(x: int, y: int) -> Dictionary:
	var v := village_proche(x, y, 2.5)
	var morts := 0
	_allumer(y * w + x)
	if v == null:
		if rng.randf() < 0.15:
			_annoncer(Textes.choisir(rng, "foudre_vide"), "divin")
		return {"morts": 0}
	morts = int(minf(v.pop, rng.randi_range(1, 4) + v.pop * 0.06))
	v.pop -= morts
	_peur(v, 1.0)
	for o in vivants:
		if o.vivant and o != v and absi(o.x - v.x) + absi(o.y - v.y) < 20:
			_peur(o, 0.3)
	if rng.randf() < 0.4:
		_annoncer(Textes.choisir(rng, "foudre", {"v": v.nom, "k": morts}), "divin", v)
	_exaucer([], ["foudre", "victoire"], v.id)
	if v.pop < 1.0:
		_detruire(v, "ruine")
	return {"morts": morts, "village": v.id}


func _p_meteore(x: int, y: int) -> Dictionary:
	var R := 5
	var en_mer := type[y * w + x] == MER or type[y * w + x] == ABYSSE
	for yy in range(maxi(0, y - R - 1), mini(h, y + R + 2)):
		for xx in range(maxi(0, x - R - 1), mini(w, x + R + 2)):
			var d := Vector2(xx - x, yy - y).length()
			if d > R + 0.5:
				continue
			var i := yy * w + xx
			if d <= 1.6:
				hauteur[i] = maxf(0.0, hauteur[i] - 0.1)
				if not en_mer:
					lave[i] = 30
			elif d <= 3.2:
				hauteur[i] = maxf(0.0, hauteur[i] - 0.05)
				if not en_mer:
					cendre[i] = 40
			else:
				hauteur[i] = minf(1.0, hauteur[i] + 0.03)
				if not en_mer:
					cendre[i] = maxi(cendre[i], 24)
					if rng.randf() < 0.35:
						_allumer(i)
			humid[i] = maxf(0.0, humid[i] - 0.1)
			feu[i] = 0 if d <= 3.2 else feu[i]
			speciaux[i] = true
			_reclasser(i)
			_sale(i)
	var total := 0
	var toucher := []
	for v in vivants.duplicate():
		if not v.vivant:
			continue
		var d := Vector2(v.x - x, v.y - y).length()
		if en_mer:
			if d < 20.0 and _cotier(v):
				var k := int(v.pop * 0.12)
				v.pop -= k
				total += k
				toucher.append(v.id)
				_annoncer(Textes.choisir(rng, "tsunami", {"v": v.nom, "k": k}), "catastrophe", v)
		elif d <= 2.5:
			total += int(v.pop)
			toucher.append(v.id)
			_detruire(v, "ruine")
			continue
		elif d <= R + 3.0:
			var k := int(v.pop * clampf((1.0 - d / (R + 3.0)) * 1.3, 0.0, 0.95))
			v.pop -= k
			total += k
			toucher.append(v.id)
			if k > 0:
				_annoncer(Textes.choisir(rng, "meteore", {"v": v.nom, "k": k}), "catastrophe", v)
		if d < 25.0:
			_peur(v, 1.0 if d < 12.0 else 0.4)
		if v.vivant:
			_scanner(v)
	if toucher.is_empty() and not en_mer:
		_annoncer(Textes.choisir(rng, "meteore_vide"), "catastrophe")
	for id: int in toucher:
		_exaucer([], ["foudre", "victoire"], id)
	for id: int in _villages_touches(x, y, R + 2):
		if villages[id].vivant:
			_scanner(villages[id])
	return {"morts": total, "mer": en_mer}


func _cotier(v: Village) -> bool:
	for yy in range(maxi(0, v.y - 3), mini(h, v.y + 4)):
		for xx in range(maxi(0, v.x - 3), mini(w, v.x + 4)):
			if type[yy * w + xx] == MER:
				return true
	return false


func _p_benir(x: int, y: int) -> Dictionary:
	var v := village_proche(x, y, 4.0)
	if v == null:
		for yy in range(maxi(0, y - 3), mini(h, y + 4)):
			for xx in range(maxi(0, x - 3), mini(w, x + 4)):
				var i := yy * w + xx
				humid[i] = lerpf(humid[i], 0.45, 0.5)
				cendre[i] = 0
				_reclasser(i)
		return {}
	v.beni = 36
	v.nourriture += v.pop
	v.humeur = minf(100.0, v.humeur + 15.0)
	v.foi = minf(100.0, v.foi + 15.0)
	v.malade = 0
	_annoncer_rare(v, "benir", "divin")
	_exaucer([v.id], ["nourriture", "guerison", "fortune", "victoire"])
	return {"village": v.id}


func _p_peste(x: int, y: int) -> Dictionary:
	var v := village_proche(x, y, 4.0)
	if v == null:
		return {}
	v.malade = 30
	_peur(v, 0.6)
	_annoncer(Textes.choisir(rng, "peste", {"v": v.nom}), "catastrophe", v)
	return {"village": v.id}


func _p_signe(x: int, y: int) -> Dictionary:
	var v := village_proche(x, y, 6.0)
	if v == null:
		return {}
	v.foi = minf(100.0, v.foi + 12.0)
	for o in vivants:
		if o.vivant and o != v and absi(o.x - v.x) + absi(o.y - v.y) < 15:
			o.foi = minf(100.0, o.foi + 5.0)
	if rng.randf() < 0.15:
		v.dieu = Noms.dieu(rng)
		_annoncer(Textes.choisir(rng, "schisme", {"v": v.nom, "d": v.dieu}), "divin", v)
	else:
		_annoncer(Textes.choisir(rng, "signe", {"v": v.nom, "m": Textes.choisir(rng, "interpretation")}),
			"divin", v)
	var ennemi := ennemi_de(v.royaume)
	if ennemi >= 0 and rng.randf() < 0.35:
		for g: Dictionary in guerres:
			if g["a"] == v.royaume or g["b"] == v.royaume:
				_paix(g)
				break
	_exaucer([v.id], ["signe", "paix"])
	return {"village": v.id}


func _p_discorde(x: int, y: int) -> Dictionary:
	var v := village_proche(x, y, 6.0)
	if v == null:
		return {}
	var cible: Village = null
	var dmin := 50.0 * 50.0
	for o in vivants:
		if o.vivant and o.royaume != v.royaume and not _guerre_entre(o.royaume, v.royaume):
			var d2 := float((o.x - v.x) * (o.x - v.x) + (o.y - v.y) * (o.y - v.y))
			if d2 < dmin:
				dmin = d2
				cible = o
	if cible == null:
		_annoncer(Textes.choisir(rng, "discorde_vide"), "divin")
		return {}
	_annoncer(Textes.choisir(rng, "discorde", _params(v)), "divin", v)
	_declarer(v, cible, "une rumeur divine")
	return {"village": v.id}


func _p_relief(x: int, y: int, delta: float) -> Dictionary:
	var r := 3
	for yy in range(maxi(0, y - r), mini(h, y + r + 1)):
		for xx in range(maxi(0, x - r), mini(w, x + r + 1)):
			var d := Vector2(xx - x, yy - y).length()
			if d > r:
				continue
			var i := yy * w + xx
			hauteur[i] = clampf(hauteur[i] + delta * (1.0 - d / (r + 1.0)), 0.0, 1.0)
			_reclasser(i)
			_sale(i)
	var ids := _villages_touches(x, y, r)
	for id: int in ids:
		var v := villages[id]
		if not v.vivant:
			continue
		if hauteur[v.y * w + v.x] < NIVEAU_MER:
			_detruire(v, "noyade")
		else:
			_scanner(v)
	return {"villages": ids}


# ======================================================================
# Utilitaires
# ======================================================================

func dans(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func _params(v: Village) -> Dictionary:
	return {"v": v.nom, "c": v.chef_nom, "d": v.dieu}


func _annoncer(texte: String, genre: String, v: Village = null) -> void:
	journal.append({"an": annee(), "texte": texte, "genre": genre})
	if journal.size() > 300:
		journal = journal.slice(-300)
	var n := {"texte": texte, "genre": genre, "x": -1, "y": -1}
	if v != null:
		n["x"] = v.x
		n["y"] = v.y
		v.histoire.append("An %d : %s" % [annee(), texte])
		if v.histoire.size() > 8:
			v.histoire = v.histoire.slice(-8)
	nouvelles.append(n)


## Annonce au plus une fois par an et par village pour un même type d'événement.
func _annoncer_rare(v: Village, cle: String, genre: String) -> void:
	if v.annonces.get(cle, -1) == annee():
		return
	v.annonces[cle] = annee()
	var p := _params(v)
	_annoncer(Textes.choisir(rng, cle, p), genre, v)


func population_totale() -> float:
	var s := 0.0
	for v in vivants:
		if v.vivant:
			s += v.pop
	return s


func fideles() -> float:
	var s := 0.0
	for v in vivants:
		if v.vivant:
			s += v.pop * v.foi / 100.0
	return s


func nb_vivants() -> int:
	var n := 0
	for v in vivants:
		if v.vivant:
			n += 1
	return n


func ere_max() -> int:
	var e := 0
	for v in vivants:
		if v.vivant:
			e = maxi(e, v.ere)
	return e


## Couleur encodée pour le shader : R = type, G = hauteur, B = drapeaux (1 feu, 2 champ).
func couleur_donnee(i: int) -> Color:
	var f := (1 if feu[i] > 0 else 0) | (2 if champ[i] > 0 else 0)
	return Color8(type[i], int(hauteur[i] * 255.0), f, 255)


func octets_donnees() -> PackedByteArray:
	var n := w * h
	var o := PackedByteArray()
	o.resize(n * 4)
	for i in n:
		o[i * 4] = type[i]
		o[i * 4 + 1] = int(hauteur[i] * 255.0)
		o[i * 4 + 2] = (1 if feu[i] > 0 else 0) | (2 if champ[i] > 0 else 0)
		o[i * 4 + 3] = 255
	return o


func couleur_proprio(i: int) -> Color:
	var o := proprio[i]
	if o < 0:
		return Color(0, 0, 0, 0)
	var c := couleur_royaume(villages[o].royaume)
	c.a = 1.0
	return c


func octets_proprio() -> PackedByteArray:
	var n := w * h
	var o := PackedByteArray()
	o.resize(n * 4)
	var cache := {}
	for i in n:
		var p := proprio[i]
		if p < 0:
			continue
		var c: Color
		if cache.has(p):
			c = cache[p]
		else:
			c = couleur_royaume(villages[p].royaume)
			cache[p] = c
		o[i * 4] = c.r8
		o[i * 4 + 1] = c.g8
		o[i * 4 + 2] = c.b8
		o[i * 4 + 3] = 255
	return o


func empreinte() -> int:
	var pops := []
	for v in villages:
		pops.append(snappedf(v.pop, 0.01))
	return hash([mois, proprio, type, pops, royaumes.keys(), journal.size()])


# ======================================================================
# Sauvegarde
# ======================================================================

func exporter() -> Dictionary:
	var vs := []
	for v in villages:
		vs.append(inst_to_dict(v))
	return {
		"version": VERSION_SAUVEGARDE, "w": w, "h": h, "graine": graine, "rng": rng.state, "mois": mois,
		"hauteur": hauteur.duplicate(), "humid": humid.duplicate(), "humid_base": humid_base.duplicate(),
		"type": type.duplicate(), "feu": feu.duplicate(), "lave": lave.duplicate(),
		"cendre": cendre.duplicate(), "champ": champ.duplicate(), "proprio": proprio.duplicate(),
		"en_feu": en_feu.duplicate(),
		"speciaux": speciaux.duplicate(), "curseur_humid": curseur_humid, "villages": vs,
		"royaumes": royaumes.duplicate(true), "prochain_royaume": prochain_royaume,
		"guerres": guerres.duplicate(true), "prieres": prieres.duplicate(true),
		"journal": journal.duplicate(true),
	}


static func importer(d: Dictionary) -> World:
	if d.get("version", 0) != VERSION_SAUVEGARDE:
		return null
	var m := World.new()
	m.w = d["w"]
	m.h = d["h"]
	m.graine = d["graine"]
	m.rng.seed = m.graine
	m.rng.state = d["rng"]
	m.mois = d["mois"]
	m.hauteur = (d["hauteur"] as PackedFloat32Array).duplicate()
	m.humid = (d["humid"] as PackedFloat32Array).duplicate()
	m.humid_base = (d["humid_base"] as PackedFloat32Array).duplicate()
	m.type = (d["type"] as PackedByteArray).duplicate()
	m.feu = (d["feu"] as PackedByteArray).duplicate()
	m.lave = (d["lave"] as PackedByteArray).duplicate()
	m.cendre = (d["cendre"] as PackedByteArray).duplicate()
	m.champ = (d["champ"] as PackedByteArray).duplicate()
	m.proprio = (d["proprio"] as PackedInt32Array).duplicate()
	m.en_feu = (d["en_feu"] as PackedInt32Array).duplicate()
	m.speciaux = (d["speciaux"] as Dictionary).duplicate()
	m.curseur_humid = d["curseur_humid"]
	for vd: Dictionary in d["villages"]:
		var v := dict_to_inst(vd.duplicate(true)) as Village
		m.villages.append(v)
		if v.vivant:
			m.vivants.append(v)
	m.royaumes = (d["royaumes"] as Dictionary).duplicate(true)
	m.prochain_royaume = d["prochain_royaume"]
	m.guerres = (d["guerres"] as Array).duplicate(true)
	m._indexer_guerres()
	m.prieres = (d["prieres"] as Array).duplicate(true)
	m.journal = (d["journal"] as Array).duplicate(true)
	m.tout_sale = true
	return m
