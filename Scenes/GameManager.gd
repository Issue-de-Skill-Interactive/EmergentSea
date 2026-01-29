###===================================================================###
##								GameManager							   ##
# Ce script permet de coordonner le reste du jeu						#
# Parmi les fonctions proposées, il y a :								#
#  - la gestion de l'apparition des nouveaux bateaux					#
#  - 																	#
#  - 																	#
##																	   ##
###===================================================================###

extends Node

# Scène du navire
var navire_scene := preload("res://Scenes/navires/Navires.tscn")

@onready var map := get_tree().get_first_node_in_group("map")
@onready var listes := get_tree().get_first_node_in_group("shared_entities")

# Ce qui sera dans cette fonction sera exécuté en premier (avant que le reste soit prêt)
func _enter_tree():
	map = get_tree().get_first_node_in_group("map")
	listes = get_tree().get_first_node_in_group("shared_entities")

	if map:
		# Permet de récupérer le signal plus tard pour pouvoir faire spawn les bateaux
		map.map_generated.connect(_on_map_generated)
	else:
		push_error(">>> ERREUR : Aucune carte trouvée dans le groupe 'map' !")


func _ready():
	pass # circulez y'a rien à voir

# faire apparaître un bateau sur la carte
# le bateau est attaché à un joueur et a une position
func spawn_navire(joueur_id: int, position: Vector2):
	var navire := navire_scene.instantiate()

	# Définir les propriétés avant ajout à la scène
	navire.joueur_id = joueur_id
	navire.global_position = position

	# ajout du navire dans le jeu
	add_child(navire)

	# on enregistre le navire dans un tableau pour plus tard
	listes.navires[joueur_id] = navire

# cette fonction se déclenche à la réception d'un signal
# indiquant que la génération de la map est terminée
func _on_map_generated():
	# Maintenant la carte existe, on peut faire spawn les navires
	for player in listes.joueurs:
		# normalement, un bateau spawn par joueur
		spawn_navire_random(player)


# permet de faire spawn le bateau à une position aléatoire
func spawn_navire_random(joueur_id: int):
	# on prend une tuile navigable au hasard
	var pos = map.get_random_ocean_position()
	# et on y met le bateau
	spawn_navire(joueur_id, pos)
