###===================================================================###
##								GameManager							   ##
# Ce script permet de coordonner le reste du jeu						#
# Parmi les fonctions proposées, il y a :								#
#  - la gestion de l'apparition des nouveaux bateaux					#
#  - la distinction entre navires joueurs et navires ennemis			#
#  - des fonctions utilitaires pour récupérer les navires				#
##																	   ##
###===================================================================###
extends Node

# Scène du navire
var navire_scene := preload("res://Scenes/navires/Navires.tscn")

@onready var map
@onready var data
@onready var map_manager

# Ce qui sera dans cette fonction sera exécuté en premier (avant que le reste soit prêt)
func _enter_tree():
	
	map_manager = get_tree().get_first_node_in_group("Map_manager")
	data = get_tree().get_first_node_in_group("shared_entities")
	if map_manager:
		# Permet de récupérer le signal plus tard pour pouvoir faire spawn les bateaux
		map_manager.map_generated.connect(_on_map_generated)
		if not data:
			push_error(">>> ERREUR : Aucune donnée partagée n'est accessible !")
			
	else:
		push_error(">>> ERREUR : Aucune carte trouvée dans le groupe 'map' !")


func _ready():
	pass # circulez y'a rien à voir

# faire apparaître un bateau sur la carte
# le bateau est attaché à un joueur et a une position
# is_player détermine si c'est le navire contrôlable par le joueur
func spawn_navire(joueur_id: int, position: Vector2, is_player: bool = false):
	var navire := navire_scene.instantiate()
	
	# Définir les propriétés avant ajout à la scène
	navire.joueur_id = joueur_id
	navire.global_position = position
	navire.is_player_ship = is_player  # IMPORTANT : Définir si c'est le navire du joueur
	
	# ajout du navire dans le jeu
	add_child(navire)
	
	# Ajouter au groupe "ships" pour faciliter la détection et l'affichage des stats
	navire.add_to_group("ships")
	
	# on enregistre le navire dans un tableau pour plus tard
	data.addNavireToData(navire)
	
	print(">>> Navire créé pour joueur ", joueur_id, " (Joueur: ", is_player, ") à position ", position)


# cette fonction se déclenche à la réception d'un signal
# indiquant que la génération de la map est terminée
func _on_map_generated():
	map = map_manager.map_gen
	# Maintenant la carte existe, on peut faire spawn les navires

	var joueurs = data.getPlayerList()
	for player_id in joueurs:
		# Récupérer si c'est un joueur humain ou un ennemi
		var is_player = joueurs[player_id].get("is_player", false)
		# normalement, un bateau spawn par joueur
		spawn_navire_random(player_id, is_player)

# permet de faire spawn le bateau à une position aléatoire
func spawn_navire_random(joueur_id: int, is_player: bool = false):
	# on prend une tuile navigable au hasard
	var pos = map.get_random_ocean_position()
	# et on y met le bateau
	spawn_navire(joueur_id, pos, is_player)

# Fonction optionnelle pour spawn un navire à une position spécifique
func spawn_navire_at(joueur_id: int, case_pos: Vector2i, is_player: bool = false):
	var world_pos = map.case_vers_monde(case_pos)
	spawn_navire(joueur_id, world_pos, is_player)

# Fonction pour obtenir le navire du joueur
func get_player_ship():
	for navire in data.navires.values():
		if navire.is_player_ship:
			return navire
	return null

# Fonction pour obtenir tous les navires ennemis
func get_enemy_ships() -> Array:
	var enemies := []
	for navire in data.navires.values():
		if not navire.is_player_ship:
			enemies.append(navire)
	return enemies
