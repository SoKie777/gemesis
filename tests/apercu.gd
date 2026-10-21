extends SceneTree
const PAL := [Color("1b3a6b"), Color("2f6fae"), Color("e8d48b"), Color("6dbb4f"), Color("2f7d3a"), Color("7f9b4e"), Color("8a8079"), Color("f2f5f8"), Color("ff5a1f"), Color("4a4442"), Color("d9b25f")]
func _init():
	var imgs := []
	for g in [42, 43, 7, 1234]:
		var m := World.new()
		m.generer(g)
		for k in 360: m.pas()
		var img := Image.create(m.w, m.h, false, Image.FORMAT_RGB8)
		for i in m.w * m.h:
			var c: Color = PAL[m.type[i]]
			if m.proprio[i] >= 0: c = c.lerp(m.couleur_proprio(i), 0.35)
			img.set_pixel(i % m.w, i / m.w, c)
		for v in m.villages:
			if v.vivant: img.set_pixel(v.x, v.y, Color.BLACK)
		img.resize(m.w * 3, m.h * 3, Image.INTERPOLATE_NEAREST)
		imgs.append(img)
	var out := Image.create(660 * 2 + 10, 390 * 2 + 10, false, Image.FORMAT_RGB8)
	for k in 4:
		out.blit_rect(imgs[k], Rect2i(0, 0, 660, 390), Vector2i((k % 2) * 670, (k / 2) * 400))
	out.save_png(OS.get_environment("OUT"))
	quit()
