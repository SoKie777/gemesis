class_name Village
extends RefCounted
## Un établissement humain. Son id est aussi son indice dans World.villages.

var id := 0
var nom := ""
var x := 0
var y := 0
var royaume := 0
var pop := 10.0
var nourriture := 10.0
var humeur := 60.0
var foi := 30.0
var savoir := 0.0
var ere := 0
var culture := "pacifique"
var dieu := ""
var chef_nom := ""
var chef_age := 30
var chef_trait := ""
var vivant := true
var ruine := false
var fonde := 0
var malade := 0
var beni := 0
var rendement := 0.0
var rayon := 3.0
var rayon_scan := 3.0
## Le territoire doit être recalculé (voisin disparu, nouvelle ère…).
var scan_requis := true
var temple := false
var faim := false
var histoire: Array = []
## Dernière année où une nouvelle d'un type donné a été publiée (anti-spam).
var annonces := {}
