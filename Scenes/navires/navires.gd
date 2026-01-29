class_name Navires
extends Node2D

# =========================
# ID
@export var id: int = 0
@export var joueur_id: int = 0
@export var is_player_ship: bool = false  # NOUVEAU : Détermine si c'est le navire du joueur

# =========================
# Stats
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 3000
@export var maxenergie: int = 3000
@export var vitesse: float = 800.0
@export var nrbequipage: int = 0
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5
@export var tir: int = 10		#Portée d'un tir
@export var dgt_tir: int = 2	#Dégât d'un tir

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")
@onready var data := get_tree().get_first_node_in_group("shared_entities")


# =========================
# UI stats
var stats_panel: Panel
var vie_label: Label
var energie_label: Label
var equipage_label: Label  # NOUVEAU : Afficher l'équipage
var stats_timer := 0.0
var stats_visible := false

# =========================
# Déplacement
var path := []
var is_moving := false
var case_actuelle: Vector2i
var target_position: Vector2 = Vector2.ZERO  # Position cible du clic
var show_arrow: bool = false  # Afficher la flèche ou non

# =========================
# Flèche de déplacement
@export var arrow_color: Color = Color(1, 1, 0, 1.0)  # Jaune vif
@export var arrow_outline_color: Color = Color(0, 0, 0, 1.0)  # Contour noir
@export var arrow_width: float = 12.0  # Doublé
@export var arrow_head_size: float = 60.0  # Doublé
@export var arrow_height: float = 100.0  # Hauteur totale de la flèche augmentée

# =========================
# Référence map
@onready var map: Node2D = get_tree().get_first_node_in_group("map") as Node2D

# =========================
# Caméra (optionnelle)
@onready var camera: Camera2D = get_node_or_null("Camera2D")


# =========================
# READY
# =========================

func _ready():
	# On attend un tout petit délai pour être sûr que :
	# - la carte est générée
	# - le GameManager a placé le navire
	# - global_position est correct
	await get_tree().process_frame
	
	# Vérifier que la map existe
	if not map:
		push_error("ERREUR : Aucune map trouvée pour le navire!")
		return
		
	case_actuelle = map.monde_vers_case(global_position)

	# ---------- Caméra ----------
	# Trouver la caméra indépendante (système existant)
	var cam = get_tree().get_first_node_in_group("camera_controller")
	if cam:
		# Seul le navire joueur contrôle la caméra
		if is_player_ship:
			cam.set_target(self)

	# ---------- Configuration selon le type de navire ----------
	if is_player_ship:
		# NAVIRE JOUEUR
		# Activer le traitement des inputs
		set_process_input(true)
		set_process_unhandled_input(true)
		
		print(">>> Navire JOUEUR initialisé à position ", global_position)
	else:
		# NAVIRE ENNEMI
		# Désactiver complètement les inputs
		set_process_input(false)
		set_process_unhandled_input(false)
		
		print(">>> Navire ENNEMI initialisé à position ", global_position)

	# ---------- UI STATS (pour TOUS les navires) ----------
	if ui_layer:
		_init_stats_ui()
	else:
		push_warning("ATTENTION : Pas de ui_layer trouvé!")


# Permet d'initialiser l'UI
func _init_stats_ui():
	if not ui_layer:
		push_error("ERREUR : ui_layer est null, impossible de créer l'UI des stats!")
		return
		
	stats_panel = Panel.new()
	stats_panel.visible = false

	stats_panel.anchor_left = 1
	stats_panel.anchor_top = 0
	stats_panel.anchor_right = 1
	stats_panel.anchor_bottom = 0
	stats_panel.offset_left = -180
	stats_panel.offset_top = 20
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 100

	var style := StyleBoxFlat.new()
	if is_player_ship:
		style.bg_color = Color(0, 0.2, 0.4, 0.8)  # Bleu pour le joueur
	else:
		style.bg_color = Color(0.4, 0, 0, 0.8)  # Rouge pour l'ennemi
	
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(vbox)

	# Titre (JOUEUR ou ENNEMI)
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_player_ship:
		title_label.text = "🚢 JOUEUR"
		title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	else:
		title_label.text = "☠️ ENNEMI"
		title_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(title_label)

	vie_label = Label.new()
	energie_label = Label.new()
	equipage_label = Label.new()
	vie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label)
	vbox.add_child(energie_label)
	vbox.add_child(equipage_label)

	ui_layer.add_child(stats_panel)
	
	print(">>> UI Stats créée pour navire ", "JOUEUR" if is_player_ship else "ENNEMI")


# =========================
# INPUT (SEULEMENT pour le navire joueur)
func _unhandled_input(event: InputEvent) -> void:
	# Les navires ennemis n'écoutent pas les inputs du joueur
	if not is_player_ship:
		return
	
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos := get_global_mouse_position()

		# ===== CLIC DROIT → STATS =====
		#if event.button_index == MOUSE_BUTTON_RIGHT:
			## Vérifier si on clique sur NOTRE navire ou sur un autre
			#var clicked_ship = get_ship_at_position(mouse_pos)
			#
			#if clicked_ship:
				## Afficher les stats du navire cliqué
				#clicked_ship.show_stats()
				#get_viewport().set_input_as_handled()
		#else:
				## Cacher toutes les stats si on clique ailleurs
				#hide_all_ships_stats()
		# ===== TOUCHE I → STATS =====
		if event.button_index == KEY_I:		# I comme inventory
			if stats_visible == false :
				show_stats()
			else:
				# Cacher toutes les stats si on clique ailleurs
				hide_all_ships_stats()

		# ===== CLIC GAUCHE → DÉPLACEMENT =====
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if energie > 0 and not is_moving:
				if map.is_on_water(mouse_pos):
					path = calculer_chemin(case_actuelle, map.monde_vers_case(mouse_pos))
					if not path.is_empty():
						is_moving = true
						target_position = mouse_pos  # Mémoriser la position cible
						show_arrow = true  # Activer l'affichage de la flèche
						queue_redraw()  # Forcer le redessin
						get_viewport().set_input_as_handled()
		# ===== CLIC DROIT → TIR =====
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if energie > 20 :
				if on_a_ship(map.monde_vers_case(mouse_pos)):
					if is_on_range(case_actuelle, map.monde_vers_case(mouse_pos), tir):
						shoot(map.monde_vers_case(mouse_pos))


# =========================
# HELPER FUNCTIONS
func get_ship_at_position(pos: Vector2) -> Navires:
	"""Récupère le navire à une position donnée (dans le rayon d'interaction)"""
	var all_ships = get_tree().get_nodes_in_group("ships")
	
	for ship in all_ships:
		if ship is Navires:
			var distance = pos.distance_to(ship.global_position)
			if distance <= ship.interaction_radius:
				return ship
	
	return null

func hide_all_ships_stats():
	"""Cache les stats de tous les navires"""
	var all_ships = get_tree().get_nodes_in_group("ships")
	
	for ship in all_ships:
		if ship is Navires:
			ship.hide_stats()




# =========================
# PROCESS
func _process(delta):
	# ----- Animation de la flèche -----
	if show_arrow and is_player_ship:
		queue_redraw()  # Redessiner en continu pour l'animation
	
	# ----- Timer UI stats (pour TOUS les navires) -----
	if stats_visible:
		stats_timer -= delta
		update_stats()
		if stats_timer <= 0:
			hide_stats()

	# ----- Déplacement (SEULEMENT pour le navire joueur - les ennemis sont immobiles) -----
	if is_player_ship and is_moving and not path.is_empty():
		var next_case = path[0]
		var next_pos: Vector2 = map.case_vers_monde(next_case)
		var direction := next_pos - global_position

		if direction.length() < 5:
			global_position = next_pos
			path.remove_at(0)
			case_actuelle = next_case
			energie = max(energie - 1, 0)
			if path.is_empty():
				is_moving = false
				show_arrow = false  # Cacher la flèche quand on arrive
				queue_redraw()
		else:
			global_position += direction.normalized() * vitesse * delta


# =========================
# DRAW - Dessiner la flèche au-dessus de la case cible
func _draw():
	if not show_arrow or not is_player_ship:
		return
	# Convertir la position cible en position locale pour le dessin
	var local_target = target_position - global_position
	var distance = local_target.length()
	if distance < 10:  # Si on est très proche, ne pas dessiner
		return
	# Animation de pulsation (utiliser le temps)
	var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.2 + 1.0
	# Hauteur de la flèche au-dessus de la case
	var offset_y = -80 + sin(Time.get_ticks_msec() * 0.003) * 15  
	# Position de base et pointe de la flèche
	var arrow_base = local_target + Vector2(0, offset_y - arrow_height)
	var arrow_tip = local_target + Vector2(0, offset_y)
	# --- CONTOUR NOIR (pour plus de visibilité) ---
	# Ligne du contour
	draw_line(arrow_base, arrow_tip, arrow_outline_color, arrow_width + 8)
	# Tête de flèche (contour)
	var outline_size = arrow_head_size + 8
	var left_outline = arrow_tip + Vector2(-outline_size * 0.5, -outline_size * 0.7)
	var right_outline = arrow_tip + Vector2(outline_size * 0.5, -outline_size * 0.7)
	var outline_points = PackedVector2Array([arrow_tip, left_outline, right_outline])
	draw_colored_polygon(outline_points, arrow_outline_color)
	# --- FLÈCHE PRINCIPALE (jaune) ---
	# Ligne principale
	draw_line(arrow_base, arrow_tip, arrow_color, arrow_width * pulse)
	# Tête de flèche
	var head_size = arrow_head_size * pulse
	var left_point = arrow_tip + Vector2(-head_size * 0.5, -head_size * 0.7)
	var right_point = arrow_tip + Vector2(head_size * 0.5, -head_size * 0.7)
	var points = PackedVector2Array([arrow_tip, left_point, right_point])
	draw_colored_polygon(points, arrow_color)
	# Cercle lumineux à la base de la flèche 
	var glow_color = Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3)
	draw_circle(arrow_base, 16 * pulse, glow_color)
	draw_circle(arrow_base, 8, arrow_color)


# =========================
# UI FUNCTIONS (pour TOUS les navires)
func show_stats():
	if not stats_panel:
		push_warning("ATTENTION : Pas de stats_panel pour afficher les stats!")
		return
		
	stats_visible = true
	stats_timer = stats_duration
	stats_panel.visible = true
	update_stats()

func hide_stats():
	if not stats_panel:
		return
		
	stats_visible = false
	stats_panel.visible = false

func update_stats():
	if not stats_panel or not vie_label or not energie_label or not equipage_label:
		return
		
	vie_label.text = "❤️ %d / %d" % [vie, maxvie]
	energie_label.text = "⚡ %d / %d" % [energie, maxenergie]
	equipage_label.text = "👥 %d" % nrbequipage


# =========================
# A* PATHFINDING (pour tous les navires)
func calculer_chemin(start: Vector2i, goal: Vector2i) -> Array:
	var open_set := [start]
	var came_from := {}
	var g_score := { start: 0 }
	var f_score := { start: start.distance_to(goal) }

	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return f_score[a] < f_score[b])
		var current = open_set.pop_front()

		if current == goal:
			var result := []
			while came_from.has(current):
				result.push_front(current)
				current = came_from[current]
			return result

		for neighbor in get_neighbors(current):
			if not map.is_on_water(map.case_vers_monde(neighbor)):
				continue

			var tentative = g_score[current] + 1
			if tentative < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				f_score[neighbor] = tentative + neighbor.distance_to(goal)
				if neighbor not in open_set:
					open_set.append(neighbor)

	return []


# =========================
# VOISINS
func get_neighbors(c: Vector2i) -> Array:
	var dirs = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	var res := []
	for d in dirs:
		var n = c + d
		if n.x >= 0 and n.y >= 0 and n.x < map.map_width and n.y < map.map_height:
			res.append(n)
	return res

# =========================
# TIR
# On va regarder s'il y a la portée, en regardant par rapport à ce que le bateau peut toucher
func is_on_range(start: Vector2i, goal: Vector2i, limit: int) -> bool :
	var chemin := calculer_chemin(start, goal)
	var result := false
	if len(chemin) < limit :
		result = true
	return result
	
# On retire les points de vie à quelqu'un qui se fait tirer dessus.
func shoot(cible: Vector2):
	# on convertit les coordonnées en coordonnées de cases
	var case_cible : Vector2i = map.monde_vers_case(cible)
	# on récupère la liste des bateaux qui sont sur cette position
	var ships_on_pos: Array =data.getNavireByPosition(cible)
	# on vérifie si il y a au moins un bateau dans la liste
	if(not ships_on_pos.is_empty()):
		# pour chaque bateau dans cette liste,
		for bateau in ships_on_pos:
			# on regarde si le bateau n'est pas celui du joueur
			if(bateau.joueur_id != self.joueur_id):
				# si le bateau n'est pas celui du joueur, alors on peut tirer
				#TODO : mieux gérer la façon dont les dégâts sont infligés (avec une méthode c'est mieux, histoire de gérer le cas vie <= 0)
				bateau.vie -= dgt_tir # vie du bateau - les dégâts = vie après attaque

# On vérifie la présence d'un bateau adverse sur la case ciblée.
#TODO: renommer la fonction parce que c'est pas terrible
func on_a_ship(cible: Vector2i) -> bool :
	var result := false
	# on récupère la liste des bateaux qui sont sur cette position
	var ships_on_pos: Array =data.getNavireByPosition(cible)
	# on vérifie si il y a au moins un bateau dans la liste
	if(not ships_on_pos.is_empty()):
		# pour chaque bateau dans cette liste,
		for bateau in ships_on_pos:
			# on regarde si le bateau n'est pas celui du joueur
			if(bateau.joueur_id != self.joueur_id):
				# si le bateau n'est pas celui du joueur, alors on peut tirer
				result = true
	return result

# =========================
# UTILS
func reset_energie():
	energie = maxenergie

func heal(amount: int):
	vie = min(vie + amount, maxvie)

#permet d'obtenir la position du bateau
func getPosition() -> Vector2i:
	return case_actuelle
