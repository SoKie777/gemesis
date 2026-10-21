shader_type canvas_item;
// Rend toute la carte en un seul passage. TEXTURE (1 pixel = 1 tuile) :
// R = type de terrain, G = altitude, B = drapeaux (1 feu, 2 champ cultivé).
// owner_tex : couleur du royaume propriétaire (alpha 0 = terre libre).
// Le détail pixel art (arbres, vagues, sommets…) est calculé ici, à raison de 8×8 sous-pixels par tuile.

uniform sampler2D owner_tex : filter_nearest;
uniform float saison = 0.0;
uniform float territoire = 1.0;

const vec3 PAL[11] = vec3[11](
	vec3(0.10, 0.22, 0.42), // abysse
	vec3(0.18, 0.43, 0.68), // mer
	vec3(0.91, 0.83, 0.55), // sable
	vec3(0.43, 0.73, 0.31), // prairie
	vec3(0.27, 0.55, 0.25), // forêt (sol)
	vec3(0.50, 0.61, 0.31), // colline
	vec3(0.54, 0.50, 0.47), // montagne
	vec3(0.93, 0.95, 0.97), // neige
	vec3(1.00, 0.36, 0.10), // lave
	vec3(0.29, 0.27, 0.26), // cendre
	vec3(0.85, 0.70, 0.37)  // désert
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

bool est_eau(int t) {
	return t <= 1;
}

void fragment() {
	vec2 ts = TEXTURE_PIXEL_SIZE;
	vec2 cell = UV / ts;
	vec2 tuile = floor(cell);
	vec2 l = floor(fract(cell) * 8.0);
	vec2 c = (tuile + 0.5) * ts;
	vec4 d = texture(TEXTURE, c);
	int t = int(d.r * 255.0 + 0.5);
	float alt = d.g;
	int drapeaux = int(d.b * 255.0 + 0.5);
	vec3 base = PAL[t];
	vec3 col = base;
	float rnd = hash(tuile * 1.37 + l * 0.71);
	float th = hash(tuile);
	// Taille d'une tuile à l'écran : en dessous de ~6 px, on lisse le détail pour éviter le scintillement.
	float px = 1.0 / max(fwidth(cell.x), 0.0001);
	float detail = clamp((px - 4.0) / 6.0, 0.0, 1.0);

	if (est_eau(t)) {
		col *= 0.8 + alt * 0.9;
		col += 0.025 * sin(TIME * 1.7 + tuile.x * 0.55 + tuile.y * 0.8);
		float vague = hash(tuile + floor(TIME * 0.7 + th * 3.0));
		if (vague > 0.82 && l.y == floor(2.0 + th * 4.0) && l.x > 1.0 && l.x < 6.0) {
			col += 0.13 * detail;
		}
		// Écume le long des côtes.
		float ecume = 0.0;
		if (l.x == 0.0 && !est_eau(int(texture(TEXTURE, c - vec2(ts.x, 0.0)).r * 255.0 + 0.5))) ecume = 1.0;
		if (l.x == 7.0 && !est_eau(int(texture(TEXTURE, c + vec2(ts.x, 0.0)).r * 255.0 + 0.5))) ecume = 1.0;
		if (l.y == 0.0 && !est_eau(int(texture(TEXTURE, c - vec2(0.0, ts.y)).r * 255.0 + 0.5))) ecume = 1.0;
		if (l.y == 7.0 && !est_eau(int(texture(TEXTURE, c + vec2(0.0, ts.y)).r * 255.0 + 0.5))) ecume = 1.0;
		col = mix(col, vec3(0.86, 0.94, 1.0), ecume * (0.45 + 0.25 * sin(TIME * 3.0 + tuile.x + tuile.y)));
	} else {
		vec3 motif = col;
		if (t == 2 || t == 10) {
			if (rnd > 0.86) motif *= 0.9;
			else if (rnd < 0.07) motif *= 1.07;
		} else if (t == 3) {
			float chaud = 0.5 + 0.5 * sin(saison * 6.2831);
			motif.r += 0.05 * chaud;
			if (rnd > 0.88) motif *= 1.17;
			else if (rnd < 0.06) motif *= 0.85;
			if ((drapeaux & 2) != 0) {
				vec3 ble = mix(vec3(0.55, 0.72, 0.28), vec3(0.93, 0.78, 0.32), smoothstep(0.35, 0.65, saison));
				motif = mod(l.y + floor(th * 3.0), 3.0) == 0.0 ? ble * 0.78 : ble;
			}
		} else if (t == 4) {
			motif *= 0.85;
			if (th > 0.55) {
				// Sapin
				float demi = (l.y - 0.5) * 0.55;
				if (l.y >= 1.0 && l.y <= 6.0 && abs(l.x + 0.5 - 4.0) <= demi) {
					motif = l.x < 4.0 ? vec3(0.15, 0.45, 0.22) : vec3(0.1, 0.33, 0.17);
				} else if (l.y == 7.0 && l.x == 3.0) {
					motif = vec3(0.35, 0.22, 0.12);
				}
			} else {
				// Feuillu
				vec2 cc = vec2(3.5 + (th - 0.25) * 2.0, 3.2);
				float r = length(l + 0.5 - cc);
				if (r < 3.0) {
					motif = vec3(0.2, 0.52, 0.22);
					if (l.x + l.y < cc.x + cc.y - 2.0) motif = vec3(0.32, 0.64, 0.28);
					else if (r > 2.2 && l.y > cc.y) motif = vec3(0.13, 0.38, 0.17);
				} else if (l.y >= 6.0 && abs(l.x + 0.5 - cc.x) < 1.0) {
					motif = vec3(0.38, 0.24, 0.13);
				}
			}
		} else if (t == 5) {
			float bosse = 1.0 - length((l + 0.5 - vec2(4.0, 5.0)) / vec2(4.0, 3.0));
			if (bosse > 0.0) motif *= l.x < 4.0 ? 1.12 : 0.9;
		} else if (t == 6 || t == 7) {
			float demi = (l.y - 0.5) * 0.62;
			if (abs(l.x + 0.5 - 4.0) <= demi && l.y >= 1.0) {
				motif = l.x < 4.0 ? base * 1.18 : base * 0.8;
				if (t == 7 || (l.y < 3.0 && alt > 0.85)) motif = l.x < 4.0 ? vec3(1.0) : vec3(0.82, 0.86, 0.92);
			}
		} else if (t == 8) {
			float flux = 0.5 + 0.5 * sin(TIME * 3.0 + rnd * 6.28 + tuile.x * 0.7);
			motif = mix(vec3(0.95, 0.25, 0.05), vec3(1.0, 0.82, 0.2), flux);
			if (hash(tuile + l + floor(TIME)) < 0.18) motif = vec3(0.35, 0.1, 0.05);
		} else if (t == 9) {
			if (hash(l + tuile + floor(TIME * 2.0)) > 0.97) motif = vec3(1.0, 0.45, 0.1);
			else if (rnd > 0.8) motif *= 1.2;
		}
		col = mix(base, motif, detail);
		// Relief : éclairage venant du nord-ouest.
		float voisin = texture(TEXTURE, c - ts).g;
		col *= clamp(1.0 + (alt - voisin) * 4.0, 0.85, 1.18);
	}

	if ((drapeaux & 1) != 0) {
		float f = hash(tuile + l * 0.3 + floor(TIME * 9.0));
		col = mix(col * 0.6, vec3(0.3, 0.08, 0.02), 0.4);
		if (l.y > 2.0 + 4.0 * f) col = mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.9, 0.3), f);
	}

	vec4 o = texture(owner_tex, c);
	if (o.a > 0.0 && territoire > 0.0) {
		col = mix(col, o.rgb, 0.13 * territoire);
		bool bord = false;
		if (l.x == 0.0 && texture(owner_tex, c - vec2(ts.x, 0.0)) != o) bord = true;
		if (l.x == 7.0 && texture(owner_tex, c + vec2(ts.x, 0.0)) != o) bord = true;
		if (l.y == 0.0 && texture(owner_tex, c - vec2(0.0, ts.y)) != o) bord = true;
		if (l.y == 7.0 && texture(owner_tex, c + vec2(0.0, ts.y)) != o) bord = true;
		if (bord) col = mix(col, o.rgb * 1.15, 0.8 * territoire);
	}
	COLOR = vec4(col, 1.0);
}
