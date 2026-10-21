class_name Sons
extends Node
## Effets sonores synthétisés au lancement (aucun fichier audio à fournir).

const TAUX := 22050
const NOMS := ["clic", "pop", "boom", "tonnerre", "pluie", "carillon", "gong", "grondement",
	"fanfare", "glas", "ding", "sifflement", "clang", "plouf", "toux"]

var actif := true
var _flux := {}
var _lecteurs: Array[AudioStreamPlayer] = []
var _suivant := 0
var _derniers := {}


func _ready() -> void:
	for nom: String in NOMS:
		_flux[nom] = _synth(nom)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_lecteurs.append(p)


## Joue un son ; `ecart` évite qu'un même son se répète trop vite (en secondes).
func jouer(nom: String, volume_db := 0.0, ecart := 0.05) -> void:
	if not actif or not _flux.has(nom):
		return
	var t := Time.get_ticks_msec() / 1000.0
	if t - float(_derniers.get(nom, -10.0)) < ecart:
		return
	_derniers[nom] = t
	var p := _lecteurs[_suivant]
	_suivant = (_suivant + 1) % _lecteurs.size()
	p.stream = _flux[nom]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


func _synth(nom: String) -> AudioStreamWAV:
	var duree := 0.25
	match nom:
		"clic":
			duree = 0.05
		"pop":
			duree = 0.12
		"boom":
			duree = 1.3
		"tonnerre":
			duree = 1.1
		"pluie":
			duree = 0.45
		"carillon":
			duree = 1.0
		"gong":
			duree = 1.5
		"grondement":
			duree = 0.5
		"fanfare":
			duree = 0.75
		"glas":
			duree = 1.4
		"ding":
			duree = 0.35
		"sifflement":
			duree = 0.6
		"clang":
			duree = 0.18
		"plouf":
			duree = 0.4
		"toux":
			duree = 0.35
	var n := int(TAUX * duree)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = nom.hash()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / TAUX
		var u := t / duree
		var bruit := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match nom:
			"clic":
				lp = lerpf(lp, bruit, 0.35)
				v = (lp * 0.6 + sin(TAU * 1400.0 * t) * 0.4) * exp(-t * 90.0)
			"pop":
				v = sin(TAU * lerpf(320.0, 950.0, u) * t) * exp(-t * 28.0)
			"boom":
				lp = lerpf(lp, bruit, 0.07)
				var crack := bruit * exp(-t * 40.0) * 0.5
				v = (lp * 2.2 * exp(-t * 2.8) + sin(TAU * lerpf(70.0, 28.0, u) * t) * 0.7 * exp(-t * 3.0) + crack)
			"tonnerre":
				lp = lerpf(lp, bruit, 0.1)
				var crack := bruit * exp(-t * 30.0) * 0.8
				v = crack + lp * 2.0 * exp(-t * 2.4) * (0.6 + 0.4 * sin(t * 23.0))
			"pluie":
				lp = lerpf(lp, bruit, 0.5)
				v = (bruit - lp) * 0.7 * sin(PI * u)
			"carillon":
				for k in 3:
					var debut := k * 0.08
					if t >= debut:
						var f: float = [1046.5, 1318.5, 1568.0][k]
						v += sin(TAU * f * (t - debut)) * exp(-(t - debut) * 4.5) * 0.33
			"gong":
				v = (sin(TAU * 180.0 * t) * 0.5 + sin(TAU * 361.3 * t) * 0.3 + sin(TAU * 527.0 * t) * 0.2) \
					* exp(-t * 2.2) * (1.0 + 0.2 * sin(TAU * 3.0 * t))
			"grondement":
				lp = lerpf(lp, bruit, 0.04)
				v = lp * 3.0 * sin(PI * u)
			"fanfare":
				var note := mini(int(t / 0.15), 3)
				var f: float = [523.25, 659.25, 783.99, 1046.5][note]
				var tl := t - note * 0.15
				var onde := signf(sin(TAU * f * tl)) * 0.3 + sin(TAU * f * tl) * 0.4
				v = onde * exp(-tl * (6.0 if note < 3 else 2.5)) * 0.7
			"glas":
				v = (sin(TAU * 220.0 * t) * 0.5 + sin(TAU * 440.0 * t) * 0.25 + sin(TAU * 587.0 * t) * 0.2) \
					* exp(-t * 2.0)
			"ding":
				v = (sin(TAU * 1760.0 * t) * 0.5 + sin(TAU * 2640.0 * t) * 0.25) * exp(-t * 11.0)
			"sifflement":
				lp = lerpf(lp, bruit, 0.3)
				v = (sin(TAU * lerpf(1900.0, 420.0, u) * t) * 0.35 + lp * 0.3) * u * u
			"clang":
				v = (sin(TAU * 2100.0 * t) * 0.4 + sin(TAU * 3150.0 * t) * 0.3 + bruit * 0.3) * exp(-t * 32.0)
			"plouf":
				lp = lerpf(lp, bruit, 0.2)
				v = (sin(TAU * lerpf(650.0, 140.0, u) * t) * 0.6 + lp * 0.4) * exp(-t * 7.0)
			"toux":
				lp = lerpf(lp, bruit, 0.25)
				lp2 = lerpf(lp2, lp, 0.3)
				var e := exp(-t * 28.0) + (exp(-(t - 0.16) * 28.0) if t > 0.16 else 0.0)
				v = lp2 * 2.5 * e
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 22000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAUX
	w.data = data
	return w
