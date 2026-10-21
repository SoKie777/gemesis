# Gemesis

**Un simulateur divin sarcastique.** Un monde qui vit très bien sans toi… et toi qui t'en mêles quand même.

Des tribus naissent, cultivent, colonisent, inventent le bronze, se déclarent la guerre pour une histoire de chèvre,
fondent des empires, s'effondrent. Elles te prient (souvent mal), te donnent des noms ridicules et interprètent
tes miracles de travers. Toi, tu as la pluie, la foudre, les météores, la peste et une patience limitée.

## Jouer

| Plateforme | Comment |
|---|---|
| **Android** | [Dernière version](../../releases/tag/derniere) → télécharger `gemesis.apk`, l'ouvrir, autoriser l'installation. |
| **PC (Windows)** | Même page → `gemesis-windows.zip`, extraire, lancer `Gemesis.exe`. Ou, avec Godot 4.7 installé : `Lancer le jeu.bat`. |

### Contrôles

| Action | PC | Tactile |
|---|---|---|
| Se déplacer | glisser (clic droit/molette ou gauche en mode Regarder), ZQSD/WASD, flèches | glisser un doigt |
| Zoomer | molette, `+` / `-` | pincer |
| Utiliser un pouvoir | clic (maintenir pour Pluie, Sécheresse, Élever, Creuser) | toucher (glisser pour les pinceaux, 2 doigts pour bouger) |
| Fiche d'un village | pouvoir « Regarder » + clic | toucher |
| Pause / vitesses | `Espace`, `1` `2` `3` | boutons en haut |

## Ce qui est simulé (vraiment, pas en décor)

- **Monde** : carte procédurale reproductible (graine), altitude, humidité, biomes qui changent avec la pluie
  et la sécheresse, incendies qui se propagent selon l'humidité, lave qui refroidit en roche, cendres fertiles.
- **Villages** : nourriture produite par le territoire réel (champs, forêts, pêche), famine, croissance,
  humeur, savoir, 8 ères (de l'Âge de pierre à l'Ère des selfies), colonies, indépendances.
- **Royaumes** : tensions de frontière (culture, chef, faim, religion), guerres avec front, conquêtes, chutes.
- **Chefs** façon BitLife : âge, trait de caractère, mort (souvent stupide), succession, petites histoires de vie.
- **Religion** : chaque village te donne un nom, schismes, temples, foi qui monte avec la peur ou les miracles.
- **Prières** : demandes liées à de vrais besoins (famine, guerre, maladie…), exaucées seulement si tu
  utilises le bon pouvoir au bon endroit — sinon ils doutent.
- **Chroniques** : tout ce qui arrive est raconté, avec mauvaise foi.

## Fluidité

Tout le terrain est dessiné par un seul shader, les villages et les habitants par deux MultiMesh
(≈ 70 appels de dessin au total). La simulation a un **budget de temps par image** qui s'adapte :
sur un appareil lent, le temps du monde ralentit au lieu de faire ramer l'affichage.

## Développement

Godot **4.7**, GDScript typé, rendu *Compatibility* (OpenGL ES 3 / ANGLE).

```
scripts/core/   simulation pure (World, Village, textes, noms) — aucune dépendance à l'affichage
scripts/ui/     affichage : main (caméra, entrées, pouvoirs), HUD, foule, villages, effets, sons
shaders/        terrain.gdshader
tests/          run_tests.gd (déterminisme, autonomie, pouvoirs, sauvegarde), prof.gd, apercu.gd
```

Tests : `godot --headless --path . --script res://tests/run_tests.gd`

Capture de vérification : `godot --path . -- --capture=x.png --graine=5 --annees=100 --zoom=2.5 [--pouvoir=meteore] [--vitesse=3]`
(affiche aussi les temps d'image).

Livraison : modifier `VERSION` et pousser sur `main` → GitHub Actions publie l'APK et l'EXE.
