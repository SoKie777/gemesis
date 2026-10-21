extends SceneTree
## Tests de la simulation (headless) :
## godot --headless --path . --script res://tests/run_tests.gd

var echecs := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()

	# 1. Même graine = même histoire.
	var a := World.new()
	a.generer(42)
	var b := World.new()
	b.generer(42)
	var t_sim := Time.get_ticks_usec()
	for i in 1200:
		a.pas()
		_vider(a)
	var ms_mois := (Time.get_ticks_usec() - t_sim) / 1200000.0
	for i in 1200:
		b.pas()
		_vider(b)
	_verifier(a.empreinte() == b.empreinte(), "déterminisme (100 ans, graine 42)")

	# 2. Le monde vit sans le joueur.
	_verifier(a.journal.size() > 15, "le monde produit son histoire seul (%d entrées)" % a.journal.size())
	_verifier(a.villages.size() > 7, "des villages sont fondés sans aide (%d)" % a.villages.size())
	print("  après 100 ans : %d habitants, %d villages vivants, %d royaumes, ère max %s" % [
		int(a.population_totale()), a.nb_vivants(), a.royaumes.size(), Textes.ERES[a.ere_max()]])

	# 3. Deux graines proches donnent des mondes différents.
	var c := World.new()
	c.generer(43)
	for i in 1200:
		c.pas()
		_vider(c)
	_verifier(c.empreinte() != a.empreinte(), "graines 42 et 43 divergent")

	# 4. Les pouvoirs agissent vraiment sur l'état du monde.
	var d := World.new()
	d.generer(7)
	for i in 60:
		d.pas()
	var v: Village = null
	for x in d.villages:
		if x.vivant:
			v = x
			break
	var p0 := v.pop
	var r := d.pouvoir("meteore", v.x, v.y)
	_verifier(not v.vivant and r["morts"] > 0, "un météore rase le village visé (%d morts)" % r["morts"])
	var i0 := 60 * d.w + 60
	var m0 := d.humid[i0]
	d.pouvoir("pluie", 60, 60)
	_verifier(d.humid[i0] > m0, "la pluie humidifie le sol")
	var h0 := d.hauteur[i0]
	d.pouvoir("creuser", 60, 60)
	_verifier(d.hauteur[i0] < h0, "creuser abaisse le terrain")
	var nb := d.villages.size()
	var ok := false
	for k in 40:
		var x := d.rng.randi_range(10, d.w - 10)
		var y := d.rng.randi_range(10, d.h - 10)
		if d.type[y * d.w + x] == World.PRAIRIE and d.village_proche(x, y, 6.0) == null:
			d.pouvoir("humains", x, y)
			ok = d.villages.size() == nb + 1
			break
	_verifier(ok, "poser des humains crée un village")
	print("  (pop du village frappé avant impact : %d)" % int(p0))

	# 5. Sauvegarde / chargement : la suite de l'histoire est identique.
	var e := World.new()
	e.generer(9)
	for k in 240:
		e.pas()
	var f := World.importer(e.exporter())
	for k in 240:
		e.pas()
		f.pas()
	_verifier(f != null and e.empreinte() == f.empreinte(), "sauvegarde puis chargement fidèles")

	print("  simulation : %.3f ms par mois (%d mois/s possibles)" % [ms_mois, int(1000.0 / maxf(ms_mois, 0.001))])
	print("Terminé en %d ms, %d échec(s)." % [Time.get_ticks_msec() - t0, echecs])
	quit(echecs)


func _vider(m: World) -> void:
	m.nouvelles.clear()
	m.effets.clear()
	m.sales.clear()
	m.proprio_sales.clear()


func _verifier(cond: bool, nom: String) -> void:
	if cond:
		print("OK    " + nom)
	else:
		echecs += 1
		print("ÉCHEC " + nom)
