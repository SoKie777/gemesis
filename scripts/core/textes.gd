class_name Textes
extends RefCounted
## Tous les textes du jeu. Les balises {v} (village), {c} (chef), {d} (nom du dieu), {k} (nombre)…
## sont remplacées par String.format().

const ERES := [
	"Âge de pierre", "Âge du bronze", "Âge du fer", "Moyen Âge",
	"Renaissance", "Ère industrielle", "Ère moderne", "Ère des selfies",
]

const CULTURES := ["pacifique", "belliqueuse", "pieuse", "sceptique", "marchande"]

const TRAITS := [
	"paranoïaque", "généreux", "ambitieux", "flemmard", "mystique",
	"colérique", "génie incompris", "romantique",
]

const POUVOIRS := {
	"": "Regarder — Touche un village pour lire sa fiche. Comme la télé-réalité, en plus éthique.",
	"humains": "Humains — Pose une tribu. Elle fera le reste. Surtout des bêtises.",
	"pluie": "Pluie — Arrose les cultures. Avec modération, sinon : lac.",
	"secheresse": "Sécheresse — Pour ceux qui trouvaient le désert trop petit.",
	"foudre": "Foudre — Un argument théologique très persuasif.",
	"meteore": "Météore — Résout tous les problèmes. Surtout la démographie.",
	"benir": "Bénédiction — Récoltes, bonheur, guérison. Ils vont vite s'y habituer.",
	"peste": "Peste — Les éternuements de Dieu.",
	"signe": "Signe divin — Un message limpide. Ils le comprendront de travers.",
	"discorde": "Discorde — Une petite rumeur. Une grosse guerre.",
	"elever": "Élever — Fais pousser des montagnes. Les alpinistes te remercient.",
	"creuser": "Creuser — Creuse des mers. L'Atlantide, c'était toi ?",
}

const MODELES := {
	"debut": [
		"Le monde est né. Il ne t'a rien demandé, mais le voilà.",
		"Création terminée. Aucun manuel fourni. Bonne chance.",
	],
	"creation": [
		"Tu crées {v}. Premier réflexe des habitants : se disputer sur ton nom.",
		"{v} voit le jour. Les habitants te remercient et réclament déjà des congés.",
		"Tu poses dix humains à {v}. Ils ont l'air perdus. C'est normal, ils le sont.",
	],
	"renfort": [
		"Tu ajoutes du monde à {v}. Le chef {c} parle de « miracle démographique ».",
		"Des nouveaux arrivent à {v}. Personne ne sait d'où. Personne ne pose de questions.",
	],
	"fondation": [
		"Des colons de {p} fondent {v}. Ils jurent de ne pas refaire les mêmes erreurs. Ils mentent.",
		"{v} est fondé par des gens de {p} qui en avaient marre de leurs voisins.",
		"Nouveau village : {v}. Spécialité locale : les problèmes de {p}, en plus petit.",
	],
	"independance": [
		"Les colons de {v} déclarent leur indépendance. Motif : « marre de {p} ».",
		"{v} fait sécession. Leur constitution tient sur une feuille. Recto seulement.",
	],
	"famine": [
		"Famine à {v}. Les habitants regardent les chèvres d'un œil nouveau.",
		"{v} a faim. Le chef {c} propose de manger « moins, mais mieux ».",
		"Les greniers de {v} sont vides. Les souris aussi sont parties.",
	],
	"ere": [
		"{v} entre dans l'{e}. Les anciens disent que c'était mieux avant.",
		"{v} passe à l'{e}. Premier réflexe : trouver de nouvelles façons de se taper dessus.",
		"Progrès ! {v} atteint l'{e}. Les impôts aussi progressent.",
	],
	"guerre": [
		"{a} déclare la guerre à {b}. Motif officiel : {m}.",
		"Guerre entre {a} et {b} ! Cause : {m}. L'Histoire jugera. Toi aussi.",
		"{a} attaque {b} pour {m}. Les deux camps prient pour ta victoire. Bon courage.",
	],
	"motif": [
		"une histoire de chèvre", "un regard de travers", "la recette de la soupe",
		"une frontière mal dessinée", "« parce que »", "un désaccord sur ton prénom",
		"une poule volée il y a trois générations", "un concours de chant truqué",
		"une rumeur divine",
	],
	"paix": [
		"{a} et {b} signent la paix. Personne ne se souvient pourquoi ils se battaient.",
		"Paix entre {a} et {b}. Ils vont pouvoir se détester poliment.",
	],
	"conquete": [
		"{v} est conquis par {r}. Les nouveaux maîtres changent surtout les impôts.",
		"{r} s'empare de {v}. Les habitants changent de drapeau, pas d'avis.",
	],
	"chute": [
		"{r} s'effondre. Il n'en reste que des ruines et des souvenirs embellis.",
		"Fin de {r}. Les historiens du futur vont adorer en exagérer la grandeur.",
	],
	"ruine": [
		"{v} n'est plus qu'une ruine. Les archéologues du futur te remercient.",
		"{v} est rayé de la carte. Littéralement : il y a un cratère.",
	],
	"desertion": [
		"Le dernier habitant de {v} est parti. Il a éteint la lumière.",
	],
	"mort_chef": [
		"{c}, chef de {v}, meurt à {k} ans. Cause : {m}.",
		"Décès de {c} ({k} ans) à {v}. Cause officielle : {m}. Cause réelle : personne n'ose le dire.",
	],
	"cause": [
		"la vieillesse", "une chute de cheval (il n'y a pas de chevaux)", "trop de fromage",
		"a voulu caresser un loup", "a parié qu'il savait voler", "un complot, évidemment",
		"des champignons « sûrs »", "une crise de rire mal placée",
	],
	"nouveau_chef": [
		"{c} ({k} ans, {t}) prend la tête de {v}. Ça va bien se passer. Probablement.",
		"Nouveau chef à {v} : {c}, {t}. Les paris sont ouverts.",
	],
	"vie": [
		"{c} de {v} a épousé une chèvre. Le couple est très heureux.",
		"{c} a inventé la roue. Elle est carrée. C'est un début.",
		"{c} affirme t'avoir vu dans une tartine grillée.",
		"{c} déclare que le monde est plat. Vu d'en haut, c'est vexant.",
		"Un enfant de {v} demande si {d} existe. Ses parents changent de sujet.",
		"{c} lance la mode des chapeaux en pain. Pénurie de pain à {v}.",
		"Les poètes de {v} écrivent des odes pour « {d} ». Elles riment très mal.",
		"{c} a tenté de négocier avec un ours. L'ours a gagné.",
		"Un philosophe de {v} doute de ton existence. Il est très populaire en soirée.",
		"{v} invente les impôts. Tout le monde est ravi, sauf tout le monde.",
		"{c} organise un concours de lancer de cailloux. 3 blessés, 1 champion.",
		"{c} a écrit ses mémoires. 400 pages. Personne ne sait lire.",
		"{c} a adopté un corbeau qu'il présente comme son ministre. Le corbeau est compétent.",
	],
	"priere_pluie": [
		"{v} implore {d} pour de la pluie. Ils ont essayé la danse, sans succès.",
		"{c} demande de la pluie. Il a déjà sorti le parapluie, par optimisme.",
	],
	"priere_nourriture": [
		"{v} prie pour de meilleures récoltes. Les chèvres prient pour que ça marche.",
		"{c} réclame « un petit coup de main côté greniers ». Destinataire : {d}.",
	],
	"priere_guerison": [
		"{v} supplie {d} de chasser la maladie. Les sangsues n'ont rien donné.",
	],
	"priere_victoire": [
		"{v} demande la victoire contre {x}. Ils promettent un temple. Encore.",
		"{c} veut écraser {x}. Il compte sur toi. Une frappe, ou une bénédiction ?",
	],
	"priere_paix": [
		"{v} est épuisé par la guerre et prie pour un signe de paix.",
	],
	"priere_foudre": [
		"{c} demande que tu foudroies {x}. Raison : « ils m'ont regardé bizarrement ».",
		"{v} voudrait voir {x} un peu plus… carbonisé. Ce sont tes fidèles, hein.",
	],
	"priere_fortune": [
		"{c} réclame « une bénédiction, n'importe laquelle, on n'est pas difficiles ».",
	],
	"priere_signe": [
		"{c} demande un signe. N'importe lequel. Même un petit.",
		"{v} attend un signe divin. Ils fixent le ciel depuis trois jours.",
	],
	"priere_ok": [
		"{v} est exaucé ! La foi explose. Le chef s'attribue une partie du mérite.",
		"Prière exaucée à {v}. Ils vont en parler pendant des siècles. En exagérant.",
		"{v} n'en revient pas : ça a marché. Ils ne savent pas quoi faire de leur scepticisme.",
	],
	"priere_ko": [
		"{v} n'a pas été exaucé. Ils en concluent que {d} est en vacances.",
		"Silence divin. {v} commence à regarder d'autres dieux sur le catalogue.",
		"{c} explique que ton silence est « un test ». Personne n'y croit.",
	],
	"meteore": [
		"Un météore frappe {v}. {k} victimes. On appelle ça « la manière forte ».",
		"Impact sur {v} ! {k} habitants rejoignent les étoiles. Littéralement.",
	],
	"meteore_vide": [
		"Un météore s'écrase au milieu de nulle part. Les lézards locaux sont choqués.",
		"Boum. Nouveau cratère. Les géologues du futur vont adorer.",
	],
	"foudre_vide": [
		"La foudre frappe un arbre. L'arbre ne l'avait pas vu venir.",
		"Un éclair dans le vide. Effet dramatique : 10/10. Utilité : 0/10.",
	],
	"tsunami": [
		"Le météore tombe en mer. La vague frappe {v} : {k} noyés.",
	],
	"foudre": [
		"La foudre frappe {v} : {k} morts. Les survivants deviennent soudain très pieux.",
		"Zap. {k} habitants de {v} en moins. Message reçu, apparemment.",
	],
	"inondation": [
		"{v} est inondé. Ils voulaient de la pluie, pas un lac.",
	],
	"secheresse": [
		"{v} cuit sous la sécheresse. Les cactus, eux, adorent.",
	],
	"incendie": [
		"{v} brûle ! Les pompiers n'ont pas encore été inventés.",
		"Incendie à {v}. Le chef {c} conseille de « souffler très fort ».",
	],
	"peste": [
		"La peste frappe {v}. Les médecins conseillent… des sangsues. Évidemment.",
	],
	"peste_propage": [
		"La maladie passe de {p} à {v}. Personne ne se lave les mains. Personne.",
	],
	"peste_fin": [
		"{v} se remet de l'épidémie. Les sangsues réclament le mérite.",
	],
	"benir": [
		"Tu bénis {v}. Récoltes géantes, moral au top, ego du chef démesuré.",
		"{v} reçoit ta bénédiction. Ils vont la mentionner dans chaque conversation.",
	],
	"signe": [
		"{v} voit ton signe et l'interprète comme {m}.",
		"Ton signe illumine {v}. Interprétation officielle : {m}.",
	],
	"interpretation": [
		"une recette de soupe", "l'ordre de bâtir un temple", "une déclaration d'amour",
		"un avertissement contre les voisins", "la preuve que les chèvres sont sacrées",
		"un message codé que seul le chef comprend (bizarrement)", "une demande d'impôts divins",
		"un compliment sur leur coiffure",
	],
	"schisme": [
		"Schisme à {v} ! Désormais, ils affirment que tu t'appelles {d}. Débats… animés.",
		"Une secte de {v} décide que ton vrai nom est {d}. Les anciens fidèles sont vexés.",
	],
	"temple": [
		"{v} t'a bâti un temple. Il est moche, mais c'est l'intention qui compte.",
	],
	"discorde": [
		"Tu glisses une rumeur à l'oreille de {c}. La rumeur, ton pouvoir le plus sous-coté.",
	],
	"discorde_vide": [
		"Personne à détester dans le coin. Reviens quand ils auront des voisins.",
	],
	"noyade": [
		"{v} est englouti par les flots. Une attraction touristique pour poissons est née.",
	],
	"extinction": [
		"Plus personne. Silence absolu. C'était ça, le plan ?",
	],
}


static func choisir(rng: RandomNumberGenerator, cle: String, p: Dictionary = {}) -> String:
	var liste: Array = MODELES.get(cle, [cle])
	var s: String = liste[rng.randi() % liste.size()]
	return s.format(p)
