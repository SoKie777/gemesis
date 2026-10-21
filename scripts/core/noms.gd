class_name Noms
extends RefCounted
## Générateurs de noms (villages, chefs, noms donnés au joueur).

const DEBUTS := ["Bou", "Gri", "Pla", "Mou", "Cra", "Tro", "Fli", "Zou", "Bre", "Glu", "Pou", "Ka",
	"Mor", "Vil", "Sal", "Ber", "Tou", "Chi", "Lou", "Ra", "Que", "Nan", "Bi", "Go"]
const MILIEUX := ["", "ze", "lo", "ri", "ba", "nou", "che", "pi", "gna", "ta", "vo", "mi"]
const FINS := ["zou", "ville", "court", "ac", "on", "eux", "ard", "y", "ette", "ombe", "ix", "ane"]
const SUFFIXES := ["-sur-Flaque", "-les-Bains", "-la-Moite", "-en-Bouse", "-le-Petit", "-les-Oies",
	"-sous-Caillou", "-la-Venteuse", "-le-Vieux", "-sur-Mer"]

const PRENOMS := ["Gérard", "Bertrude", "Jean-Gaspard", "Huguette", "Ragnar", "Kevinus", "Brunehaut",
	"Fulbert", "Ghislaine", "Théodebert", "Josiane", "Gontran", "Ermengarde", "Patrick", "Odile",
	"Childéric", "Raymonde", "Bernadin", "Cunégonde", "Thibaud", "Mireille", "Ursule", "Marcel", "Brenda"]
const EPITHETES := ["le Moite", "la Vaillante", "le Pas-Très-Malin", "l'Insomniaque", "la Bavarde",
	"le Chauve", "Trois-Orteils", "le Magnifique", "la Têtue", "le Distrait", "la Terrible",
	"le Frileux", "Grosse-Voix", "le Sage (selon lui)", "la Rancunière", "Main-Moite"]

const DIEUX := ["le Grand Pédalo", "Celui-Qui-Clique", "la Main Céleste", "Môssieur Nuage",
	"l'Ingénieur du Ciel", "le Grand Lézard Lumineux", "le Pigeon Suprême", "Tata Cosmos",
	"le Doigt", "l'Administrateur", "Kevin d'En-Haut", "la Grande Chaussette", "Bob",
	"le Souffleur de Vent", "l'Œil Qui Juge", "la Patate Éternelle", "le Curseur Sacré"]


static func village(rng: RandomNumberGenerator) -> String:
	var n: String = DEBUTS[rng.randi() % DEBUTS.size()] + MILIEUX[rng.randi() % MILIEUX.size()] \
		+ FINS[rng.randi() % FINS.size()]
	if rng.randf() < 0.35:
		n += SUFFIXES[rng.randi() % SUFFIXES.size()]
	return n


static func chef(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [PRENOMS[rng.randi() % PRENOMS.size()], EPITHETES[rng.randi() % EPITHETES.size()]]


static func dieu(rng: RandomNumberGenerator) -> String:
	return DIEUX[rng.randi() % DIEUX.size()]
