extends Node

# Scène du navire
var navire_scene := preload("res://Scenes/navires/Navires.tscn")

# Liste des navires créés
var navires := {}

@onready var map := get_tree().get_first_node_in_group("map")


func _enter_tree():
	map = get_tree().get_first_node_in_group("map")

	if map:
		map.map_generated.connect(_on_map_generated)
	else:
		push_error(">>> ERREUR : Aucune carte trouvée dans le groupe 'map' !")



# Liste des joueurs (pour le futur multijoueur)
var joueurs := {
	1: { "nom": "Joueur 1", "couleur": Color.BLUE },
	2: { "nom": "Joueur 2", "couleur": Color.RED }
}

func _ready():
	pass

func spawn_navire(joueur_id: int, position: Vector2):
	var navire := navire_scene.instantiate()

	# Définir les propriétés avant ajout à la scène
	navire.joueur_id = joueur_id
	navire.global_position = position

	add_child(navire)

	# Stocker dans un dictionnaire
	navires[joueur_id] = navire


func _on_map_generated():
	# Maintenant la carte existe, on peut spawn les navires
	spawn_navire_random(1)
	spawn_navire_random(2)



func spawn_navire_random(joueur_id: int):
	var pos = map.get_random_ocean_position()

	spawn_navire(joueur_id, pos)
