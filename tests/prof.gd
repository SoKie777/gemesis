extends SceneTree
## Profil d'un mois de simulation dans un monde mûr (200 ans), section par section.
var t := {}
func _c(k: String, t0: int) -> int:
	t[k] = t.get(k, 0) + Time.get_ticks_usec() - t0
	return Time.get_ticks_usec()
func _init():
	var a := World.new()
	a.generer(5)
	for i in 2400: a.pas()
	var N := 240
	for k in N:
		a.mois += 1
		var m := a.mois % 12
		var t0 := Time.get_ticks_usec()
		a._maj_humidite(); t0 = _c("humid", t0)
		a._maj_feux(); a._maj_speciaux(); t0 = _c("feux", t0)
		for v in a.vivants.duplicate():
			if not v.vivant: continue
			var t1 := Time.get_ticks_usec()
			a._mois_village(v)
			t1 = _c("mois_village", t1)
			if v.vivant and v.id % 12 == m:
				a._annee_village(v)
				_c("annee_village", t1)
		t0 = Time.get_ticks_usec()
		a._maj_guerres(); t0 = _c("guerres", t0)
		a._tensions(m); t0 = _c("tensions", t0)
		if m == 0: a._annee_monde()
		t0 = _c("annee_monde", t0)
		a._maj_prieres(); t0 = _c("prieres", t0)
		a.nouvelles.clear(); a.effets.clear(); a.sales.clear(); a.proprio_sales.clear()
	var tot := 0.0
	for k in t: tot += t[k]
	for k in t: print("%-14s %6.3f ms/mois" % [k, t[k] / 1000.0 / N])
	print("TOTAL %.3f ms/mois — %d vivants, %d guerres" % [tot / 1000.0 / N, a.vivants.size(), a.guerres.size()])
	quit()
