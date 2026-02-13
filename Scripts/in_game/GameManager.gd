###===================================================================###
##								GameManager							   ##
# Ce script permet de coordonner le reste du jeu						#
# Parmi les fonctions proposées, il y a :								#
#  - la gestion de l'apparition des nouveaux bateaux					#
#  - la distinction entre navires joueurs et navires ennemis			#
#  - des fonctions utilitaires pour récupérer les navires				#
#  - la gestion de la sélection des navires du joueur					#
##																	   ##
###===================================================================###
extends Node
 

# Scène du navire
var navire_scene := preload("res://Scenes/in_game/Navires.tscn")

@onready var map
@onready var data
@onready var map_manager
var players_manager: PlayersManager = null

# Stockage des joueurs créés
var player1: Player = null
var player2: Player = null

# NOUVEAU : Gestion de la sélection
var selected_ship: Navires = null
signal ship_selected(ship: Navires)
signal ship_deselected()


# Ce qui sera dans cette fonction sera exécuté en premier (avant que le reste soit prêt)
func _enter_tree():
	add_to_group("game_manager")  # Important pour que les navires puissent trouver le GameManager
	
	map_manager = get_tree().get_first_node_in_group("Map_manager")
	data = get_tree().get_first_node_in_group("shared_entities")
	
	if not map_manager:
		push_error(">>> ERREUR : Aucune carte trouvée dans le groupe 'Map_manager' !")
		return
	
	if not data:
		push_error(">>> ERREUR : Aucune donnée partagée n'est accessible !")
	
	# Connecter le signal de génération de map
	map_manager.map_generated.connect(_on_map_generated)


func _ready():
	# Attendre un frame pour que tout soit bien initialisé
	await get_tree().process_frame
	
	# Récupérer le PlayersManager
	_try_get_players_manager()


# Fonction utilitaire pour récupérer le PlayersManager
# Essaie plusieurs noms de groupes possibles
func _try_get_players_manager() -> bool:
	if players_manager:
		return true
	
	# Essayer différents noms de groupes (CORRIGÉ : ajout de "players_manager" avec underscore)
	var possible_groups = ["players_manager", "playersManager", "PlayersManager", "playerManager", "PlayerManager"]
	
	for group_name in possible_groups:
		players_manager = get_tree().get_first_node_in_group(group_name)
		if players_manager:
			print(">>> PlayersManager trouvé dans le groupe: ", group_name)
			return true
	
	# Si toujours pas trouvé, chercher par type de nœud
	var all_nodes = get_tree().get_nodes_in_group("players_manager")
	if all_nodes.size() == 0:
		# Essayer de trouver un nœud PlayerManager dans l'arbre
		var root = get_tree().root
		players_manager = _find_players_manager_recursive(root)
		
		if players_manager:
			print(">>> PlayersManager trouvé par recherche récursive")
			return true
	
	return false


# Fonction récursive pour trouver le PlayersManager dans l'arbre
func _find_players_manager_recursive(node: Node) -> Node:
	if node is PlayersManager:
		return node
	
	for child in node.get_children():
		var result = _find_players_manager_recursive(child)
		if result:
			return result
	
	return null


# Faire apparaître un bateau sur la carte
# Le bateau est attaché à un joueur Player et a une position
# is_player_controlled détermine si c'est le navire contrôlable par le joueur humain
func spawn_navire(player: Player, position: Vector2, is_player_controlled: bool = false) -> Navires:
	if player == null:
		push_error(">>> ERREUR : Impossible de créer un navire sans joueur propriétaire !")
		return null
	
	var navire: Navires = navire_scene.instantiate()
	
	# Définir les propriétés avant ajout à la scène
	navire.global_position = position
	navire.is_player_controlled = is_player_controlled
	
	# Ajout du navire dans le jeu
	add_child(navire)
	
	# Définir le propriétaire (cela appelle automatiquement player.add_navire())
	navire.set_owner_player(player)
	
	# Ajouter au groupe "ships" pour faciliter la détection et l'affichage des stats
	if not navire.is_in_group("ships"):
		navire.add_to_group("ships")
	
	# Connecter le signal de clic du navire
	if navire.has_signal("ship_clicked"):
		navire.ship_clicked.connect(_on_ship_clicked)
	
	# Connecter le signal de destruction du navire
	if navire.has_signal("ship_destroyed"):
		navire.ship_destroyed.connect(_on_ship_destroyed)
	
	# On enregistre le navire dans un tableau pour plus tard
	if data and data.has_method("addNavireToData"):
		data.addNavireToData(navire)
	
	print(">>> Navire créé avec ID: ", navire.id if navire.has_method("get") else "N/A")
	
	return navire


# Cette fonction se déclenche à la réception d'un signal
# indiquant que la génération de la map est terminée
func _on_map_generated():
	await get_tree().process_frame
	# Essayer de récupérer le PlayersManager
	if not _try_get_players_manager():
		push_error(">>> ERREUR : PlayersManager introuvable dans l'arbre de scène !")
		push_error(">>> Assurez-vous que le nœud PlayerManager existe et est ajouté à un groupe")
		return
	
	# Créer les joueurs via le PlayersManager
	player1 = players_manager.create_player(1, "Joueur 1", true)
	player2 = players_manager.create_player(2, "IA", false)
	
	# Vérifier que les joueurs ont bien été créés
	if not player1 or not player2:
		push_error(">>> ERREUR : Échec de la création des joueurs !")
		return
	
	print(">>> Joueurs créés avec succès")
	
	# MODIFICATION : Créer 2 navires pour le joueur 1
	var ship1 = spawn_navire_random(player1, true)  # Premier navire
	var ship2 = spawn_navire_random(player1, true)  # Deuxième navire
	
	# Assigner des IDs uniques
	if ship1:
		ship1.id = 1
		print(">>> Ship1 créé avec succès")
	if ship2:
		ship2.id = 2
		print(">>> Ship2 créé avec succès")
	
	# Créer 1 navire ennemi
	var enemy1 = spawn_navire_random(player2, false)
	
	if enemy1:
		enemy1.id = 101
		print(">>> Enemy1 créé avec succès")
	
	# Définir le joueur actuel (celui qui commence)
	players_manager.set_current_player(player1)
	
	# Sélectionner automatiquement le premier navire du joueur
	if ship1:
		select_ship(ship1)


# Permet de faire spawn le bateau à une position aléatoire
func spawn_navire_random(player: Player, is_player_controlled: bool = false) -> Navires:
	# On prend une tuile navigable au hasard
	var pos = Map_utils.get_random_ocean_position()
	# Et on y met le bateau
	return spawn_navire(player, pos, is_player_controlled)


# Fonction optionnelle pour spawn un navire à une position spécifique
func spawn_navire_at(player: Player, case_pos: Vector2i, is_player_controlled: bool = false) -> Navires:
	var world_pos = Map_utils.case_vers_monde(case_pos)
	return spawn_navire(player, world_pos, is_player_controlled)


# ===============================
# INPUT HANDLING
# ===============================

func _input(event: InputEvent) -> void:
	# Sélection du navire suivant avec TAB
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB and not event.shift_pressed):
		select_next_ship()
		get_viewport().set_input_as_handled()
	
	# Sélection du navire précédent avec Shift+TAB
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB and event.shift_pressed:
		select_previous_ship()
		get_viewport().set_input_as_handled()
	
	# Sélection directe avec les touches 1, 2, 3
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_select_ship_by_index(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_select_ship_by_index(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_select_ship_by_index(2)
				get_viewport().set_input_as_handled()


func _select_ship_by_index(index: int) -> void:
	"""Sélectionne un navire par son index dans la liste du joueur"""
	if not player1:
		return
	
	var player_ships = player1.get_navires()
	if index >= 0 and index < player_ships.size():
		select_ship(player_ships[index])


# ===============================
# GESTION DE LA SÉLECTION
# ===============================

func select_ship(ship: Navires) -> void:
	"""Sélectionne un navire"""
	if selected_ship == ship:
		return
	
	# Désélectionner l'ancien navire
	if selected_ship:
		selected_ship.set_selected(false)
	
	# Sélectionner le nouveau
	selected_ship = ship
	if selected_ship:
		selected_ship.set_selected(true)
		emit_signal("ship_selected", ship)
		print(">>> Navire sélectionné: ", ship.id if ship.has_method("get") else "N/A")


func deselect_ship() -> void:
	"""Désélectionne le navire actuel"""
	if selected_ship:
		print(">>> Désélection du navire: ", selected_ship.id if selected_ship.has_method("get") else "N/A")
		selected_ship.set_selected(false)
		selected_ship = null
		emit_signal("ship_deselected")


func get_selected_ship() -> Navires:
	"""Retourne le navire actuellement sélectionné"""
	return selected_ship


func _on_ship_clicked(ship: Navires) -> void:
	"""Callback quand un navire est cliqué"""
	# Vérifier que c'est un navire du joueur
	if ship.player_owner == player1:
		select_ship(ship)


func _on_ship_destroyed(ship: Navires) -> void:
	"""Callback quand un navire est détruit - NOUVEAU"""
	print(">>> Navire détruit détecté: ", ship.id if ship.has_method("get") else "N/A")
	
	# Si le navire détruit était sélectionné, le désélectionner
	if selected_ship == ship:
		print(">>> Le navire sélectionné a été détruit, désélection...")
		deselect_ship()
		
		# Essayer de sélectionner automatiquement un autre navire du joueur
		if player1:
			var remaining_ships = player1.get_navires()
			print(">>> Navires restants: ", remaining_ships.size())
			
			if remaining_ships.size() > 0:
				# Sélectionner le premier navire restant
				print(">>> Sélection automatique du navire suivant")
				select_ship(remaining_ships[0])
			else:
				print(">>> Aucun navire restant pour le joueur")


func select_next_ship() -> void:
	"""Sélectionne le navire suivant du joueur"""
	if not player1:
		return
	
	var player_ships = player1.get_navires()
	if player_ships.is_empty():
		return
	
	var current_index = -1
	if selected_ship:
		current_index = player_ships.find(selected_ship)
	
	var next_index = (current_index + 1) % player_ships.size()
	select_ship(player_ships[next_index])


func select_previous_ship() -> void:
	"""Sélectionne le navire précédent du joueur"""
	if not player1:
		return
	
	var player_ships = player1.get_navires()
	if player_ships.is_empty():
		return
	
	var current_index = -1
	if selected_ship:
		current_index = player_ships.find(selected_ship)
	
	var prev_index = (current_index - 1) if current_index > 0 else (player_ships.size() - 1)
	select_ship(player_ships[prev_index])


# ===============================
# FONCTIONS UTILITAIRES
# ===============================

# Fonction pour obtenir le navire du joueur humain
func get_player_ship() -> Navires:
	if player1:
		var navires = player1.get_navires()
		if navires.size() > 0:
			return navires[0]
	
	# Méthode alternative si nécessaire
	var all_ships = get_tree().get_nodes_in_group("ships")
	for navire in all_ships:
		if navire is Navires and navire.is_player_controlled:
			return navire
	
	return null


# Fonction pour obtenir tous les navires ennemis
func get_enemy_ships() -> Array[Navires]:
	var enemies: Array[Navires] = []
	
	# Vérifier que player1 et players_manager existent
	if not player1:
		return enemies
	
	if not _try_get_players_manager():
		return enemies
	
	# Récupérer tous les joueurs ennemis du joueur 1
	var enemy_players = players_manager.get_enemy_players(player1)
	
	for enemy_player in enemy_players:
		enemies.append_array(enemy_player.get_navires())
	
	return enemies


# Fonction pour obtenir tous les navires d'un joueur spécifique
func get_player_ships(player: Player) -> Array[Navires]:
	if player:
		return player.get_navires()
	return []


# Fonction pour obtenir un joueur par son ID
func get_player_by_id(player_id: int) -> Player:
	if _try_get_players_manager():
		return players_manager.get_player_by_id(player_id)
	return null
