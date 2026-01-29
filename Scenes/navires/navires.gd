class_name Navires
extends Node2D

# =========================
# ID
@export var id: int = 0
@export var joueur_id: int = 0

# =========================
# Textures

@export var rendu0: Texture2D
@export var rendu60: Texture2D
@export var rendu120: Texture2D
@export var rendu180: Texture2D
@export var rendu240: Texture2D
@export var rendu300: Texture2D


# Stats
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 30
@export var maxenergie: int = 30
@export var vitesse: float = 300.0
@export var nrbequipage: int = 0
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")


# =========================
# Pêche
@export var nourriture: int = 0
@export var fish_energy_cost: int = 1
@export var fish_duration: float = 1.2
@export var fish_yield_min: int = 1
@export var fish_yield_max: int = 3

var is_fishing := false
var fish_timer := 0.0


# =========================
# Feedback pêche
var fish_feedback_label: Label
@export var fish_feedback_duration: float = 0.8
var fish_feedback_timer: float = 0.0


# =========================
# UI stats
var stats_panel: Panel
var vie_label: Label
var energie_label: Label
var nourriture_label: Label
var stats_timer := 0.0
var stats_visible := false

# =========================
# Déplacement
var path := []
var is_moving := false
var case_actuelle: Vector2i

# =========================
# Référence map
@onready var map: Node2D = get_tree().get_first_node_in_group("map") as Node2D

# =========================
# Caméra
@onready var camera: Camera2D = $Camera2D


# =========================
# READY
# =========================

func _ready():
	# On attend un tout petit délai pour être sûr que :
	# - la carte est générée
	# - le GameManager a placé le navire
	# - global_position est correct
	await get_tree().process_frame
	case_actuelle = map.monde_vers_case(global_position)

	# ---------- Caméra ----------
	# Trouver la caméra indépendante
	var cam = get_tree().get_first_node_in_group("camera_controller")
	if cam:
		cam.set_target(self)

	# ---------- UI STATS (haut droite) ----------
	_init_stats_ui()

# Permet d'initialiser l'UI
func _init_stats_ui():
	stats_panel = Panel.new()
	stats_panel.visible = false

	stats_panel.anchor_left = 1
	stats_panel.anchor_top = 0
	stats_panel.anchor_right = 1
	stats_panel.anchor_bottom = 0
	stats_panel.offset_left = -160
	stats_panel.offset_top = 20
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 110

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
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

	vie_label = Label.new()
	energie_label = Label.new()
	nourriture_label = Label.new()
	nourriture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label)
	vbox.add_child(energie_label)
	vbox.add_child(nourriture_label)

	ui_layer.add_child(stats_panel)
	_init_fish_feedback()


#
#func _ready():
	#case_actuelle = monde_vers_case(global_position)
#
	#if camera:
		#camera.make_current()
		#target_zoom = camera.zoom
#
	## ---------- UI STATS (haut droite) ----------
	#stats_panel = Panel.new()
	#stats_panel.visible = false
#
	#stats_panel.anchor_left = 1
	#stats_panel.anchor_top = 0
	#stats_panel.anchor_right = 1
	#stats_panel.anchor_bottom = 0
	#stats_panel.offset_left = -160
	#stats_panel.offset_top = 20
	#stats_panel.offset_right = -20
	#stats_panel.offset_bottom = 80
#
	#var style := StyleBoxFlat.new()
	#style.bg_color = Color(0, 0, 0, 0.7)
	#style.corner_radius_top_left = 6
	#style.corner_radius_top_right = 6
	#style.corner_radius_bottom_left = 6
	#style.corner_radius_bottom_right = 6
	#stats_panel.add_theme_stylebox_override("panel", style)
#
	#var vbox := VBoxContainer.new()
	#vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	#vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#stats_panel.add_child(vbox)
#
	#vie_label = Label.new()
	#energie_label = Label.new()
	#vie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#energie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#
	#vbox.add_child(vie_label)
	#vbox.add_child(energie_label)
#
	#ui_layer.add_child(stats_panel)


# =========================
# INPUT
func _input(event: InputEvent) -> void:
	# ----- Pêche (clavier) -----
	if event.is_action_pressed("fish"):
		try_start_fishing()
		return
	
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos := get_global_mouse_position()

		# ===== CLIC DROIT → STATS =====
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_pos.distance_to(global_position) <= interaction_radius:
				show_stats()
			else:
				hide_stats()

		# ===== CLIC GAUCHE → DÉPLACEMENT =====
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if energie > 0 and not is_moving and not is_fishing:
				if map.is_on_water(mouse_pos):
					path = calculer_chemin(case_actuelle, map.monde_vers_case(mouse_pos))
					if not path.is_empty():
						is_moving = true


# =========================
# PROCESS
func _process(delta):
	# ----- Timer UI stats -----
	if stats_visible:
		stats_timer -= delta
		update_stats()
		if stats_timer <= 0:
			hide_stats()
			
	# ----- Pêche -----
	_update_fishing(delta)
	_update_fish_feedback(delta)
	
	# ----- Déplacement -----
	if is_moving and not path.is_empty():
		var next_case = path[0]
		var next_pos :Vector2= map.case_vers_monde(next_case)
		var direction := next_pos - global_position

		if direction.length() < 5:
			global_position = next_pos
			path.remove_at(0)
			case_actuelle = next_case
			energie = max(energie - 1, 0)
			if path.is_empty():
				is_moving = false
		else:
			global_position += direction.normalized() * vitesse * delta
			


# =========================
# UI FUNCTIONS
func show_stats():
	stats_visible = true
	stats_timer = stats_duration
	stats_panel.visible = true
	update_stats()

func hide_stats():
	stats_visible = false
	stats_panel.visible = false

func update_stats():
	vie_label.text = "❤️ %d / %d" % [vie, maxvie]
	energie_label.text = "⚡ %d / %d" % [energie, maxenergie]
	nourriture_label.text = "🐟 %d" % nourriture
	
# =========================
# PÊCHE FUNCTIONS
func _update_fishing(delta: float) -> void:
	if not is_fishing:
		return

	fish_timer -= delta
	if fish_timer <= 0.0:
		finish_fishing()

func try_start_fishing() -> void:
	# Pas de pêche en déplacement, ni si déjà en action
	if is_moving or is_fishing:
		return

	# Ressource énergie
	if energie < fish_energy_cost:
		return

	# Condition de terrain : uniquement sur l'eau
	if not map.is_on_water(global_position):
		return

	# Déclenchement
	is_fishing = true
	if fish_feedback_label:
		fish_feedback_label.text = "🎣 Pêche..."
		fish_feedback_label.visible = true
	fish_timer = fish_duration
	energie = max(energie - fish_energy_cost, 0)

	show_stats()

func finish_fishing() -> void:
	is_fishing = false

	var gain := randi_range(fish_yield_min, fish_yield_max)
	# Bonus léger selon équipage (facultatif, mais cohérent "efficacité")
	if nrbequipage >= 6:
		gain += 1

	nourriture += gain
	if fish_feedback_label:
		fish_feedback_label.text = "+%d 🐟" % gain
		fish_feedback_label.visible = true
	fish_feedback_timer = fish_feedback_duration
	show_stats()
	
func _init_fish_feedback() -> void:
	fish_feedback_label = Label.new()
	fish_feedback_label.visible = false
	fish_feedback_label.text = "🎣 Pêche..."
	fish_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Apparence simple
	fish_feedback_label.add_theme_color_override("font_color", Color.WHITE)
	fish_feedback_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fish_feedback_label.add_theme_constant_override("outline_size", 6)

	add_child(fish_feedback_label)
	# position au-dessus du bateau (ajuste si besoin)
	fish_feedback_label.position = Vector2(-30, -60)
	
func _update_fish_feedback(delta: float) -> void:
	if not fish_feedback_label:
		return
	# Si on est en train de pêcher, on garde "🎣 Pêche..."
	if is_fishing:
		fish_feedback_label.visible = true
		return

	# Si on vient de finir, on affiche "+X 🐟" pendant fish_feedback_duration
	if fish_feedback_timer > 0.0:
		fish_feedback_timer -= delta
		if fish_feedback_timer <= 0.0:
			fish_feedback_label.visible = false
	else:
		# sécurité : cacher hors pêche / hors gain
		fish_feedback_label.visible = false


# =========================
# A* PATHFINDING
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
# UTILS
func reset_energie():
	energie = maxenergie

func heal(amount: int):
	vie = min(vie + amount, maxvie)
