# CLAUDE.md — Gemesis

Simulateur divin 2D (pixel art, ton sarcastique façon BitLife). Godot **4.7**, GDScript typé, rendu Compatibility.
L'utilisateur parle français et ne code pas : docs, commits et textes du jeu en français.
Ne pas changer l'identifiant Android `com.sokie777.gemesis` (sinon nouvelle appli, sauvegarde perdue).

## Priorité n°1 : la fluidité
L'ancien projet (SoKie777/genesis-divine-sim) ramait au point d'être injouable. Le PC de l'utilisateur
passe en ANGLE (GPU modeste) : ~9 ms par image de base. Règles :
- Pas de `_draw()` qui trace beaucoup de primitives : utiliser MultiMesh / shader (un appel GPU).
- La simulation reste sous ~2 ms par mois dans un monde mûr (`tests/prof.gd`), avec budget adaptatif dans main.gd.
- Tout travail annuel est réparti sur 12 mois (`id % 12`).
- Les PackedArray sont partagés par référence : `.duplicate()` à l'export/import.
- Vérifier les temps d'image avec le mode capture (voir README) avant de livrer.

## Le PC de l'utilisateur
- Godot : `D:\Kleros\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe` (`_console.exe` pour les tests).
- Clé de signature Android : `D:\Claude\gemesis-signature.keystore` (alias `gemesis`, mot de passe dans
  `D:\Claude\gemesis-signature.txt`), copiée dans les secrets GitHub `ANDROID_KEYSTORE_B64` / `ANDROID_KEYSTORE_PASSWORD`.

## Règles du code
- `scripts/core/` ne dépend jamais de l'affichage. Toute règle se teste dans `tests/run_tests.gd`.
- Le hasard de la simulation passe uniquement par `World.rng` (déterminisme testé).
- Avant chaque commit : `godot --headless --path . --script res://tests/run_tests.gd` (0 échec).

## Livraison
Fin d'une étape = incrémenter `VERSION` et pousser sur `main`. GitHub Actions publie l'APK et l'EXE Windows
dans la Release `vX.Y.Z` et dans `derniere`. Vérifier le run et donner le lien à l'utilisateur.
