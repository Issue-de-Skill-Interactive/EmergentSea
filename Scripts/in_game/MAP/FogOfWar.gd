class_name FogOfWar
extends Node2D

# =========================
# CONFIGURATION
# =========================
## Rayon de vision des navires (en cases)
@export var vision_radius: int = 5

## Opacité du brouillard (0.0 = transparent, 1.0 = opaque)
@export var fog_opacity: float = 0.95

# =========================
# DONNÉES INTERNES
# =========================
## Grille de visibilité : true = visible, false = brouillard
var visibility_grid := {}

## Sprites du brouillard (un par case)
var fog_sprites := {}

## Référence à la texture de montagne
var fog_texture: Texture2D = null

var is_initialized := false


# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_of_war")
	
	# IMPORTANT : Mettre le z-index du node lui-même très haut
	z_index = 10000
	z_as_relative = false  # Ne pas hériter du parent
	
	print(">>> [FOG] FogOfWar _ready() appelé - Z-INDEX: ", z_index)
	
	# Charger la texture
	fog_texture = Map_data.TileMountain
	if not fog_texture:
		push_error(">>> [FOG] ERREUR: Texture de montagne non trouvée!")
		return
	
	print(">>> [FOG] Texture chargée: ", fog_texture)
	
	# Attendre que la map soit générée
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager:
		print(">>> [FOG] MapManager trouvé, connexion au signal...")
		if not map_manager.is_connected("map_generated", _on_map_generated):
			map_manager.connect("map_generated", _on_map_generated)
			print(">>> [FOG] Signal map_generated connecté")
	else:
		push_error(">>> [FOG] ERREUR: MapManager non trouvé!")


func _on_map_generated():
	"""Appelé quand la map est générée"""
	print(">>> [FOG] Signal map_generated reçu!")
	await get_tree().process_frame
	await get_tree().process_frame
	initialize_fog()


# =========================
# CRÉATION DU BROUILLARD
# =========================
func initialize_fog():
	"""Crée le brouillard sur toute la carte"""
	print(">>> [FOG] ========================================")
	print(">>> [FOG] INITIALISATION DU BROUILLARD")
	print(">>> [FOG] ========================================")
	print(">>> [FOG] Dimensions carte: ", Map_data.map_width, "x", Map_data.map_height)
	
	# Réinitialiser
	visibility_grid.clear()
	clear_fog_sprites()
	
	var fog_count = 0
	
	# Créer le brouillard partout
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			var pos = Vector2i(x, y)
			visibility_grid[pos] = false  # Tout est caché au départ
			create_fog_sprite(pos)
			fog_count += 1
	
	is_initialized = true
	print(">>> [FOG] ========================================")
	print(">>> [FOG] BROUILLARD CRÉÉ SUR ", fog_count, " CASES")
	print(">>> [FOG] SPRITES CRÉÉS: ", fog_sprites.size())
	print(">>> [FOG] TOUTE LA CARTE DEVRAIT ÊTRE NOIRE !")
	print(">>> [FOG] ========================================")


func create_fog_sprite(pos: Vector2i):
	"""Crée un sprite de brouillard pour une case"""
	if not fog_texture:
		return
	
	var sprite = Sprite2D.new()
	sprite.texture = fog_texture
	sprite.position = Map_utils.case_vers_monde(pos)
	
	# NOIR TRÈS OPAQUE pour être ULTRA VISIBLE
	sprite.modulate = Color(0, 0, 0, fog_opacity)
	
	# Adapter la taille pour couvrir toute la case
	var scale_x = Map_data.hex_width / fog_texture.get_width()
	var scale_y = Map_data.hex_height / fog_texture.get_height()
	sprite.scale = Vector2(scale_x * 1.1, scale_y * 1.1)  # 10% plus grand pour éviter les trous
	
	# CORRECTION : Z-index ENCORE PLUS ÉLEVÉ et absolu
	sprite.z_index = 9999
	sprite.z_as_relative = false  # IMPORTANT : Ne pas hériter du parent
	
	# Nom pour debug
	sprite.name = "Fog_%d_%d" % [pos.x, pos.y]
	
	add_child(sprite)
	fog_sprites[pos] = sprite


func clear_fog_sprites():
	"""Supprime tous les sprites de brouillard"""
	print(">>> [FOG] Suppression de ", fog_sprites.size(), " sprites de brouillard")
	for sprite in fog_sprites.values():
		if is_instance_valid(sprite):
			sprite.queue_free()
	fog_sprites.clear()


# =========================
# MISE À JOUR DE LA VISION
# =========================
func update_vision_for_player(player: Player):
	"""Met à jour la vision pour un joueur (basé sur ses navires)"""
	print(">>> [FOG] update_vision_for_player() APPELÉE")
	
	if not is_initialized:
		print(">>> [FOG] ✗ Brouillard pas encore initialisé")
		return
	
	if player == null:
		print(">>> [FOG] ✗ Player null")
		return
		
	if not player.is_human:
		print(">>> [FOG] ✗ Player n'est pas humain: %s" % player.player_name)
		return
	
	# Récupérer tous les navires du joueur
	var player_ships = player.get_navires()
	print(">>> [FOG] Player: %s, navires: %d" % [player.player_name, player_ships.size()])
	
	var revealed_count = 0
	
	# Pour chaque navire, révéler autour de lui
	for ship in player_ships:
		if ship is Navires and ship.is_alive():
			var ship_pos = ship.case_actuelle
			print(">>> [FOG] Traitement navire ID %d à position %s" % [ship.id, ship_pos])
			var count = reveal_around_position(ship_pos)
			revealed_count += count
			print(">>> [FOG] Navire %d a révélé %d cases" % [ship.id, count])
	
	# Logger seulement si de nouvelles cases révélées
	if revealed_count > 0:
		print(">>> [FOG] ✓ Révélé %d nouvelles cases au total" % revealed_count)
	else:
		print(">>> [FOG] Aucune nouvelle case révélée (déjà toutes visibles)")


func reveal_around_position(center: Vector2i) -> int:
	"""Révèle les cases autour d'une position - retourne le nombre de cases révélées"""
	var count = 0
	
	# Parcourir toutes les cases dans le rayon de vision
	for dy in range(-vision_radius, vision_radius + 1):
		for dx in range(-vision_radius, vision_radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			
			# Vérifier que la case est valide
			if not Map_utils.is_case_valid(pos):
				continue
			
			# Vérifier la distance (vision circulaire)
			var distance = sqrt(dx * dx + dy * dy)
			if distance > vision_radius:
				continue
			
			# Révéler la case
			if reveal_tile(pos):
				count += 1
	
	return count


func reveal_tile(pos: Vector2i) -> bool:
	"""Révèle une case spécifique - retourne true si la case a été révélée"""
	if not visibility_grid.has(pos):
		return false
	
	# Si déjà visible, rien à faire
	if visibility_grid[pos]:
		return false
	
	# Marquer comme visible
	visibility_grid[pos] = true
	
	# Cacher le sprite de brouillard
	if fog_sprites.has(pos):
		var sprite = fog_sprites[pos]
		if is_instance_valid(sprite):
			sprite.queue_free()
		fog_sprites.erase(pos)
		return true
	
	return false


func hide_tile(pos: Vector2i):
	"""Cache une case (remet le brouillard)"""
	if not Map_utils.is_case_valid(pos):
		return
	
	# Si déjà cachée, rien à faire
	if visibility_grid.has(pos) and not visibility_grid[pos]:
		return
	
	# Marquer comme cachée
	visibility_grid[pos] = false
	
	# Recréer le sprite si nécessaire
	if not fog_sprites.has(pos):
		create_fog_sprite(pos)


# =========================
# REQUÊTES
# =========================
func is_tile_visible(pos: Vector2i) -> bool:
	"""Vérifie si une case est visible"""
	if not visibility_grid.has(pos):
		return false
	return visibility_grid[pos]


func is_world_position_visible(world_pos: Vector2) -> bool:
	"""Vérifie si une position monde est visible"""
	var case_pos = Map_utils.monde_vers_case(world_pos)
	return is_tile_visible(case_pos)


# =========================
# UTILITAIRES
# =========================
func reset_fog():
	"""Remet le brouillard partout"""
	print(">>> [FOG] ========================================")
	print(">>> [FOG] RESET DU BROUILLARD - TOUT REDEVIENT NOIR")
	print(">>> [FOG] ========================================")
	for pos in visibility_grid.keys():
		hide_tile(pos)


func reveal_all():
	"""Révèle toute la carte (mode triche/spectateur)"""
	print(">>> [FOG] ========================================")
	print(">>> [FOG] RÉVÉLATION TOTALE - TOUT DEVIENT VISIBLE")
	print(">>> [FOG] ========================================")
	for pos in visibility_grid.keys():
		reveal_tile(pos)


# =========================
# DEBUG VISUEL
# =========================
# Désactivé car mise à jour continue - Utiliser F3 pour les stats
#func _process(_delta):
#	if Engine.get_frames_drawn() % 300 == 0:
#		print(">>> [FOG] Status: ", fog_sprites.size(), " sprites actifs, z_index: ", z_index)


# =========================
# TESTS MANUELS
# =========================
func _input(event):
	# Appuyer sur F1 pour révéler tout (test)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		reveal_all()
		print(">>> [FOG] TEST - RÉVÉLATION TOTALE (F1)")
	
	# Appuyer sur F2 pour reset (test)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		reset_fog()
		print(">>> [FOG] TEST - RESET TOTAL (F2)")
	
	# Appuyer sur F3 pour afficher les stats (debug)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		print(">>> [FOG] ========================================")
		print(">>> [FOG] DEBUG INFO")
		print(">>> [FOG] ========================================")
		print(">>> [FOG] Initialisé: ", is_initialized)
		print(">>> [FOG] Sprites actifs: ", fog_sprites.size())
		print(">>> [FOG] Z-index node: ", z_index)
		print(">>> [FOG] Z-as-relative: ", z_as_relative)
		print(">>> [FOG] Cases visibles: ", visibility_grid.values().count(true))
		print(">>> [FOG] Cases cachées: ", visibility_grid.values().count(false))
		print(">>> [FOG] ========================================")
