class_name Navires
extends Node2D

# Permettra de signaler au moteur différents évènements
signal sig_show_stats
signal sig_navire_died(navire: Navires)
signal sig_navire_damaged(navire: Navires, damage: int)
signal ship_clicked(ship: Navires)
signal ship_destroyed(ship: Navires)
signal sig_show_fishing

# =========================
# PROPRIÉTAIRE ET IDENTITÉ
# =========================
## Référence directe au joueur propriétaire (remplace joueur_id)
var player_owner: Player = null

## ID unique du navire
@export var id: int = 0

## Détermine si c'est le navire contrôlé par le joueur humain actuel
var is_player_controlled: bool = false

## Indique si ce navire est actuellement sélectionné
var is_selected: bool = false


# =========================
# TEXTURES
# =========================
@export var rendu0: Texture2D
@export var rendu60: Texture2D
@export var rendu120: Texture2D
@export var rendu180: Texture2D
@export var rendu240: Texture2D
@export var rendu300: Texture2D


# =========================
# STATS
# =========================
var stats_panel : UI_stats_navire
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 3000
@export var maxenergie: int = 3000
@export var vitesse: float = 800.0
@export var nrbequipage: int = 0
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5
@export var tir: int = 10		# Portée d'un tir
@export var dgt_tir: int = 2	# Dégâts d'un tir

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")
@onready var data := get_tree().get_first_node_in_group("shared_entities")
@onready var players_manager: PlayersManager = get_tree().get_first_node_in_group("players_manager")


# =========================
# PÊCHE
# =========================
@export var nourriture: int = 0
@export var fish_energy_cost: int = 1
@export var fish_duration: float = 1.2
@export var fish_yield_min: int = 1
@export var fish_yield_max: int = 3

var is_fishing := false
var fish_timer := 0.0


# =========================
# FEEDBACK PÊCHE
# =========================
var fish_feedback_label: UI_fish_navires
@export var fish_feedback_duration: float = 0.8
var fish_feedback_timer: float = 0.0


# =========================
# UI STATS - DEUX PANNEAUX
# =========================
# Panneau pour navire allié (à droite)
var stats_panel_ally: Panel
var vie_label_ally: Label
var energie_label_ally: Label
var equipage_label_ally: Label
var nourriture_label_ally: Label

# Panneau pour navire ennemi (à gauche)
var stats_panel_enemy: Panel
var vie_label_enemy: Label
var energie_label_enemy: Label
var equipage_label_enemy: Label
var nourriture_label_enemy: Label

var stats_timer := 0.0
var stats_visible := false


# =========================
# DÉPLACEMENT
# =========================
var path := []
var is_moving := false
var case_actuelle: Vector2i
var target_position: Vector2 = Vector2.ZERO
var show_arrow: bool = false


# =========================
# FLÈCHE DE DÉPLACEMENT
# =========================
@export var arrow_color: Color = Color(1, 1, 0, 1.0)
@export var arrow_outline_color: Color = Color(0, 0, 0, 1.0)
@export var arrow_width: float = 12.0
@export var arrow_head_size: float = 60.0
@export var arrow_height: float = 100.0


# =========================
# SÉLECTION VISUELLE
# =========================
@export var selection_color: Color = Color(0, 1, 0, 0.7)  # Vert
@export var selection_thickness: float = 4.0
@export var selection_radius: float = 50.0


# =========================
# CAMÉRA
# =========================
@onready var camera: Camera2D = get_node_or_null("Camera2D")


# =========================
# INITIALIZATION
# =========================
func _init() -> void:
	add_to_group("ships")


func _ready():
	await get_tree().process_frame
	
	case_actuelle = Map_utils.monde_vers_case(global_position)

	# Configuration de la caméra pour le navire contrôlé par le joueur
	_setup_camera()
	
	# Configuration des inputs selon le type de contrôle
	_setup_input_handling()
	
	# Initialisation de l'UI
	if ui_layer:
		_init_stats_ui()
	else:
		push_warning("ATTENTION : Pas de ui_layer trouvé!")
	
	# Debug
	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	print(">>> Navire [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s" % [
		id, owner_name, control_type, case_actuelle
	])


func _setup_camera() -> void:
	"""Configure la caméra pour suivre le navire si c'est celui du joueur"""
	if not is_selected:
		return
		
	var cam = get_tree().get_first_node_in_group("camera_controller")
	if cam and cam.has_method("set_target"):
		cam.set_target(self)


func _setup_input_handling() -> void:
	"""Configure la gestion des inputs selon le type de navire"""
	# Tous les navires du joueur peuvent recevoir des inputs pour être sélectionnés
	if player_owner and player_owner.is_human:
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		set_process_input(false)
		set_process_unhandled_input(false)
    
    # ---------- UI STATS (pour TOUS les navires) ----------
	if ui_layer:
		stats_panel = UI_stats_navire.new(self)
		fish_feedback_label = UI_fish_navires.new(self)
		#_init_stats_ui()
	else:
		# Masquer uniquement le panneau allié si ce navire est désélectionné
		if stats_panel_ally:
			stats_panel_ally.visible = false
	
	print(">>> Navire %d %s" % [id, "SÉLECTIONNÉ" if selected else "désélectionné"])


# =========================
# GESTION DU PROPRIÉTAIRE
# =========================
func set_owner_player(player: Player) -> void:
	"""Définit le joueur propriétaire de ce navire"""
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	
	player_owner = player
	
	if player != null and player.has_method("add_navire"):
		player.add_navire(self)
	
	# Reconfigurer les inputs
	_setup_input_handling()


func get_owner_player() -> Player:
	"""Retourne le joueur propriétaire"""
	return player_owner


func is_owned_by(player: Player) -> bool:
	"""Vérifie si ce navire appartient au joueur spécifié"""
	return player_owner == player


func is_enemy_of(other_navire: Navires) -> bool:
	"""Vérifie si ce navire est ennemi d'un autre navire"""
	if player_owner == null or other_navire.player_owner == null:
		return false
	return player_owner != other_navire.player_owner


# =========================
# SÉLECTION
# =========================
func set_selected(selected: bool) -> void:
	"""Définit si ce navire est sélectionné"""
	is_selected = selected
	queue_redraw()
	
	# Activer/désactiver la caméra selon la sélection
	if selected and player_owner and player_owner.is_human:
		_setup_camera()
		# Afficher les stats du navire sélectionné
		show_stats()
	else:
		# Masquer uniquement le panneau allié si ce navire est désélectionné
		if stats_panel_ally:
			stats_panel_ally.visible = false
	
	print(">>> Navire %d %s" % [id, "SÉLECTIONNÉ" if selected else "désélectionné"])


# =========================
# ÉTAT DU NAVIRE
# =========================
func is_alive() -> bool:
	"""Vérifie si le navire est encore en vie"""
	return vie > 0


func take_damage(damage: int) -> void:
	"""Applique des dégâts au navire"""
	if not is_alive():
		return
	
	vie = max(vie - damage, 0)
	emit_signal("sig_navire_damaged", self, damage)
	
	# Afficher les stats du navire touché (ennemi)
	show_stats()
	
	if vie <= 0:
		die()


func die() -> void:
	"""Gère la mort du navire"""
	print(">>> Navire [%d] en train de mourir..." % id)
	
	# IMPORTANT : Émettre le signal AVANT toute modification
	emit_signal("ship_destroyed", self)
	emit_signal("sig_navire_died", self)
	
	# Désélectionner visuellement le navire
	if is_selected:
		set_selected(false)
	
	# Masquer TOUS les panneaux de stats
	hide_all_stats()
	
	# Masquer le feedback de pêche
	if fish_feedback_label and is_instance_valid(fish_feedback_label):
		fish_feedback_label.visible = false
	
	# Notifier le propriétaire
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	
	# Libération des ressources
	print(">>> Navire [%d] détruit" % id)
	queue_free()


func heal(amount: int) -> void:
	"""Soigne le navire"""
	if not is_alive():
		return
	vie = min(vie + amount, maxvie)
	if is_selected:
		show_stats()


func reset_energie() -> void:
	"""Réinitialise l'énergie au maximum"""
	energie = maxenergie


# =========================
# UI INITIALIZATION
# =========================
func _init_stats_ui():
	if not ui_layer:
		push_error("ERREUR : ui_layer est null, impossible de créer l'UI des stats!")
		return
	
	# Créer le panneau allié (à droite)
	_create_ally_stats_panel()
	
	# Créer le panneau ennemi (à gauche)
	_create_enemy_stats_panel()
	
	_init_fish_feedback()
	
	print(">>> UI Stats créée pour navire [%d]" % id)


func _create_ally_stats_panel():
	"""Crée le panneau de stats pour les navires alliés (à droite)"""
	stats_panel_ally = Panel.new()
	stats_panel_ally.visible = false

	stats_panel_ally.anchor_left = 1
	stats_panel_ally.anchor_top = 0
	stats_panel_ally.anchor_right = 1
	stats_panel_ally.anchor_bottom = 0
	stats_panel_ally.offset_left = -180
	stats_panel_ally.offset_top = 20
	stats_panel_ally.offset_right = -20
	stats_panel_ally.offset_bottom = 110

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0.2, 0.4, 0.9)  # Bleu pour allié
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel_ally.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel_ally.add_child(vbox)

	# Titre
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_name = player_owner.player_name if player_owner else "???"
	title_label.text = "🚢 " + owner_name
	title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	vbox.add_child(title_label)

	# Labels de stats
	vie_label_ally = Label.new()
	energie_label_ally = Label.new()
	nourriture_label_ally = Label.new()
	equipage_label_ally = Label.new()
	
	vie_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nourriture_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label_ally)
	vbox.add_child(energie_label_ally)
	vbox.add_child(equipage_label_ally)
	vbox.add_child(nourriture_label_ally)

	ui_layer.add_child(stats_panel_ally)


func _create_enemy_stats_panel():
	"""Crée le panneau de stats pour les navires ennemis (à gauche)"""
	stats_panel_enemy = Panel.new()
	stats_panel_enemy.visible = false

	stats_panel_enemy.anchor_left = 0
	stats_panel_enemy.anchor_top = 0
	stats_panel_enemy.anchor_right = 0
	stats_panel_enemy.anchor_bottom = 0
	stats_panel_enemy.offset_left = 20
	stats_panel_enemy.offset_top = 20
	stats_panel_enemy.offset_right = 180
	stats_panel_enemy.offset_bottom = 110

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0, 0, 0.9)  # Rouge pour ennemi
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel_enemy.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel_enemy.add_child(vbox)

	# Titre
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_name = player_owner.player_name if player_owner else "???"
	title_label.text = "☠️ " + owner_name
	title_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(title_label)

	# Labels de stats
	vie_label_enemy = Label.new()
	energie_label_enemy = Label.new()
	nourriture_label_enemy = Label.new()
	equipage_label_enemy = Label.new()
	
	vie_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nourriture_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label_enemy)
	vbox.add_child(energie_label_enemy)
	vbox.add_child(equipage_label_enemy)
	vbox.add_child(nourriture_label_enemy)

	ui_layer.add_child(stats_panel_enemy)


# =========================
# INPUT
# =========================
func _unhandled_input(event: InputEvent) -> void:
	# Vérifier que ce navire appartient au joueur humain
	if not player_owner or not player_owner.is_human:
		return
	
	# Détecter le clic sur ce navire pour le sélectionner
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		# Si on clique sur ce navire
		if distance <= interaction_radius:
			emit_signal("ship_clicked", self)
			get_viewport().set_input_as_handled()
			return
	
	# Le reste des inputs uniquement pour le navire sélectionné
	if not is_selected:
		return
	
	# Toggle stats
	if Input.is_action_just_pressed("toggle_stats"):
		#envoie un signal qui est récupéré par l'UI_stats_navires associé à ce navire
		emit_signal("sig_show_stats")
	
	# Pêche
	if event.is_action_pressed("fish"):
		try_start_fishing()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_pos := get_global_mouse_position()

		# CLIC GAUCHE → DÉPLACEMENT
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Vérifier qu'on ne clique pas sur un autre navire
			var clicked_ship = get_ship_at_position(mouse_pos)
			if clicked_ship:
				return  # On a cliqué sur un navire, ne pas se déplacer
			
			if energie > 0 and not is_moving and not is_fishing:
				if Map_utils.is_on_water(mouse_pos):
					path = calculer_chemin(case_actuelle, Map_utils.monde_vers_case(mouse_pos))
					if not path.is_empty():
						is_moving = true
						target_position = mouse_pos
						show_arrow = true
						queue_redraw()
						get_viewport().set_input_as_handled()
		
		# CLIC DROIT → TIR
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var target_case = Map_utils.monde_vers_case(mouse_pos)
			attempt_shoot(target_case)


# =========================
# COMBAT
# =========================
func attempt_shoot(target_case: Vector2i) -> void:
	"""Tente de tirer sur une case cible"""
	# Vérifications de base
	if energie < 20:
		print("Pas assez d'énergie pour tirer!")
		return
	
	if not is_in_range(target_case):
		print("Cible hors de portée!")
		return
	
	# Récupérer les navires sur la case cible
	var target_ships = get_ships_at_position(target_case)
	if target_ships.is_empty():
		print("Aucune cible sur cette case!")
		return
	
	# Tirer sur tous les navires ennemis présents
	var hit_count = 0
	for target_ship in target_ships:
		if target_ship.is_enemy_of(self):
			shoot_at(target_ship)
			hit_count += 1
	
	if hit_count > 0:
		energie = max(energie - 20, 0)
		print("Tir effectué sur %d cible(s)!" % hit_count)
		show_stats()  # Mise à jour de nos stats
	else:
		print("Aucun ennemi sur cette case!")


func shoot_at(target: Navires) -> void:
	"""Tire sur un navire spécifique"""
	if target == null or not target.is_alive():
		return
	
	print(">>> Tir sur navire [%d]" % target.id)
	target.take_damage(dgt_tir)
	
	# Effets visuels / son (à implémenter)
	# ...


func is_in_range(target_case: Vector2i) -> bool:
	"""Vérifie si une case est à portée de tir"""
	var chemin := calculer_chemin(case_actuelle, target_case)
	return chemin.size() <= tir


func get_ships_at_position(target_case: Vector2i) -> Array[Navires]:
	"""Récupère tous les navires présents sur une case"""
	var ships: Array[Navires] = []
	
	if data and data.has_method("getNavireByPosition"):
		var raw_ships = data.getNavireByPosition(target_case)
		for ship in raw_ships:
			# Vérifier que le navire est toujours valide et vivant
			if ship is Navires and is_instance_valid(ship) and ship.is_alive():
				ships.append(ship)
	
	return ships


# =========================
# HELPER FUNCTIONS
# =========================
func get_ship_at_position(pos: Vector2) -> Navires:
	"""Récupère le navire à une position donnée (dans le rayon d'interaction)"""
	var all_ships = get_tree().get_nodes_in_group("ships")
	
	for ship in all_ships:
		if ship is Navires and ship != self:
			var distance = pos.distance_to(ship.global_position)
			if distance <= ship.interaction_radius:
				return ship
	return null


func hide_all_ships_stats():
	"""Cache les stats de tous les navires"""
	var all_ships = get_tree().get_nodes_in_group("ships")
	
	for ship in all_ships:
		if ship is Navires:
			ship.hide_all_stats()
			ship.hide_stats()


# =========================
# PROCESS
# =========================
func _process(delta):
	# Animation de la sélection et de la flèche
	if is_selected or show_arrow:
		queue_redraw()
	
	# Timer UI stats
	if stats_visible:
		stats_timer -= delta
		update_stats()
		if stats_timer <= 0:
			hide_all_stats()
	
	# Pêche
	_update_fishing(delta)
	
	# Déplacement (seulement pour le navire sélectionné)
	if is_selected and is_moving and not path.is_empty():
		_process_movement(delta)


func _process_movement(delta: float) -> void:
	"""Gère le déplacement du navire"""
	var next_case = path[0]
	var next_pos: Vector2 = Map_utils.case_vers_monde(next_case)
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
# DRAW
# =========================
func _draw():
	# Indicateur de sélection (cercle vert) - UNIQUEMENT si sélectionné
	if is_selected and player_owner and player_owner.is_human:
		# Animation de pulsation
		var pulse = sin(Time.get_ticks_msec() * 0.003) * 5.0
		var current_radius = selection_radius + pulse
		
		# Cercle extérieur (contour noir)
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, Color.BLACK, selection_thickness + 2)
		# Cercle intérieur (couleur de sélection)
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, selection_color, selection_thickness)
		
		# Halo lumineux
		var glow_alpha = (sin(Time.get_ticks_msec() * 0.004) * 0.15) + 0.2
		var glow_color = Color(selection_color.r, selection_color.g, selection_color.b, glow_alpha)
		draw_arc(Vector2.ZERO, current_radius + 8, 0, TAU, 32, glow_color, 2.0)
	
	# Flèche de déplacement (seulement pour le navire sélectionné)
	if not show_arrow or not is_selected:
		return
	
	
	var local_target = target_position - global_position
	var distance = local_target.length()
	if distance < 10:
		return
	
	var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.2 + 1.0
	var offset_y = -80 + sin(Time.get_ticks_msec() * 0.003) * 15
	
	var arrow_base = local_target + Vector2(0, offset_y - arrow_height)
	var arrow_tip = local_target + Vector2(0, offset_y)
	
	# Contour noir
	draw_line(arrow_base, arrow_tip, arrow_outline_color, arrow_width + 8)
	
	var outline_size = arrow_head_size + 8
	var left_outline = arrow_tip + Vector2(-outline_size * 0.5, -outline_size * 0.7)
	var right_outline = arrow_tip + Vector2(outline_size * 0.5, -outline_size * 0.7)
	var outline_points = PackedVector2Array([arrow_tip, left_outline, right_outline])
	draw_colored_polygon(outline_points, arrow_outline_color)
	
	# Flèche principale
	draw_line(arrow_base, arrow_tip, arrow_color, arrow_width * pulse)
	
	var head_size = arrow_head_size * pulse
	var left_point = arrow_tip + Vector2(-head_size * 0.5, -head_size * 0.7)
	var right_point = arrow_tip + Vector2(head_size * 0.5, -head_size * 0.7)
	var points = PackedVector2Array([arrow_tip, left_point, right_point])
	draw_colored_polygon(points, arrow_color)
	
	# Cercle lumineux
	var glow_color = Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3)
	draw_circle(arrow_base, 16 * pulse, glow_color)
	draw_circle(arrow_base, 8, arrow_color)


# =========================
# UI FUNCTIONS
# =========================
func show_stats():
	"""Affiche les stats du navire dans le bon panneau"""
	stats_visible = true
	stats_timer = stats_duration
	
	# Déterminer si ce navire est allié ou ennemi
	var is_ally = (player_owner and player_owner.is_human)
	
	if is_ally:
		# Afficher dans le panneau allié (droite)
		if stats_panel_ally:
			stats_panel_ally.visible = true
			update_stats()
	else:
		# Afficher dans le panneau ennemi (gauche)
		if stats_panel_enemy:
			stats_panel_enemy.visible = true
			update_stats()


func hide_all_stats():
	"""Masque tous les panneaux de stats de ce navire"""
	stats_visible = false
	
	if stats_panel_ally:
		stats_panel_ally.visible = false
	
	if stats_panel_enemy:
		stats_panel_enemy.visible = false


func update_stats():
	"""Met à jour l'affichage des stats"""
	var is_ally = (player_owner and player_owner.is_human)
	
	if is_ally:
		if vie_label_ally and energie_label_ally and equipage_label_ally:
			vie_label_ally.text = "❤️ %d / %d" % [vie, maxvie]
			energie_label_ally.text = "⚡ %d / %d" % [energie, maxenergie]
			equipage_label_ally.text = "👥 %d" % nrbequipage
			nourriture_label_ally.text = "🐟 %d" % nourriture
	else:
		if vie_label_enemy and energie_label_enemy and equipage_label_enemy:
			vie_label_enemy.text = "❤️ %d / %d" % [vie, maxvie]
			energie_label_enemy.text = "⚡ %d / %d" % [energie, maxenergie]
			equipage_label_enemy.text = "👥 %d" % nrbequipage
			nourriture_label_enemy.text = "🐟 %d" % nourriture


# =========================
# PÊCHE
# =========================
func _update_fishing(delta: float) -> void:
	if not is_fishing:
		return

	fish_timer -= delta
	if fish_timer <= 0.0:
		finish_fishing()


func try_start_fishing() -> void:
	if is_moving or is_fishing:
		return

	if energie < fish_energy_cost:
		return

	if not Map_utils.is_on_water(global_position):
		return

	# Déclenchement
	sig_show_fishing.emit()
	is_fishing = true
	fish_timer = fish_duration
	energie = max(energie - fish_energy_cost, 0)

	#show_stats()


func finish_fishing() -> void:
	is_fishing = false

	var gain := randi_range(fish_yield_min, fish_yield_max)
	if nrbequipage >= 6:
		gain += 1

	nourriture += gain
	if fish_feedback_label:
		fish_feedback_label.finished_fishing(gain)
		sig_show_stats.emit()




# =========================
# PATHFINDING
# =========================
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
			if not Map_utils.is_on_water(Map_utils.case_vers_monde(neighbor)):
				continue

			var tentative = g_score[current] + 1
			if tentative < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				f_score[neighbor] = tentative + neighbor.distance_to(goal)
				if neighbor not in open_set:
					open_set.append(neighbor)

	return []


func get_neighbors(c: Vector2i) -> Array:
	var dirs = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	var res := []
	for d in dirs:
		var n = c + d
		if n.x >= 0 and n.y >= 0 and n.x < Map_data.map_width and n.y < Map_data.map_height:
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
	var case_cible : Vector2i = Map_utils.monde_vers_case(cible)
	# on récupère la liste des bateaux qui sont sur cette position
	var ships_on_pos: Array =data.getNavireByPosition(case_cible)
	# on vérifie si il y a au moins un bateau dans la liste
	if(not ships_on_pos.is_empty()):
		# pour chaque bateau dans cette liste,
		for bateau in ships_on_pos:
			# on regarde si le bateau n'est pas celui du joueur
			if(bateau.joueur_id != self.joueur_id):
				# si le bateau n'est pas celui du joueur, alors on peut tirer
				#TODO : mieux gérer la façon dont les dégâts sont infligés (avec une méthode c'est mieux, histoire de gérer le cas vie <= 0)
				bateau.vie -= dgt_tir # vie du bateau - les dégâts = vie après attaque
				bateau.show_stats()

func show_stats():
	print("stats showed")
	emit_signal("sig_show_stats")

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
# =========================
func getPosition() -> Vector2i:
	"""Retourne la position du navire en coordonnées de case"""
	return case_actuelle
