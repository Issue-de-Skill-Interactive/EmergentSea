class_name Navires
extends Node2D

# =========================
# ID
@export var id: int = 0
@export var joueur_id: int = 0

# =========================
# Stats
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 30
@export var maxenergie: int = 30
@export var vitesse: float = 300.0
@export var nrbequipage: int = 0
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5

@onready var ui_layer: CanvasLayer = get_parent().get_node("CanvasLayer")

# =========================
# Zoom caméra
@export var min_zoom := 0.1
@export var max_zoom := 3.0
@export var zoom_step := 0.15
@export var camera_speed := 600.0

var target_zoom := Vector2.ONE

# =========================
# UI stats
var stats_panel: Panel
var vie_label: Label
var energie_label: Label
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
func _ready():
	case_actuelle = monde_vers_case(global_position)

	if camera:
		camera.make_current()
		target_zoom = camera.zoom

	# ---------- UI STATS (haut droite) ----------
	stats_panel = Panel.new()
	stats_panel.visible = false

	stats_panel.anchor_left = 1
	stats_panel.anchor_top = 0
	stats_panel.anchor_right = 1
	stats_panel.anchor_bottom = 0
	stats_panel.offset_left = -160
	stats_panel.offset_top = 20
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 80

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
	vie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label)
	vbox.add_child(energie_label)

	ui_layer.add_child(stats_panel)


# =========================
# INPUT
func _input(event: InputEvent) -> void:
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
			if energie > 0 and not is_moving:
				if is_on_water(mouse_pos):
					path = calculer_chemin(case_actuelle, monde_vers_case(mouse_pos))
					if not path.is_empty():
						is_moving = true

		# ===== ZOOM (STABLE) =====
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and camera:
			target_zoom -= Vector2(zoom_step, zoom_step)
			target_zoom = target_zoom.clamp(
				Vector2(min_zoom, min_zoom),
				Vector2(max_zoom, max_zoom)
			)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and camera:
			target_zoom += Vector2(zoom_step, zoom_step)
			target_zoom = target_zoom.clamp(
				Vector2(min_zoom, min_zoom),
				Vector2(max_zoom, max_zoom)
			)


# =========================
# PROCESS
func _process(delta):
	# ----- Zoom fluide -----
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, 0.2)

	# ----- Timer UI stats -----
	if stats_visible:
		stats_timer -= delta
		update_stats()
		if stats_timer <= 0:
			hide_stats()

	# ----- Déplacement -----
	if is_moving and not path.is_empty():
		var next_case = path[0]
		var next_pos := case_vers_monde(next_case)
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

	# ----- Caméra clavier -----
	if camera:
		var move := Vector2.ZERO
		if Input.is_action_pressed("ui_up"): move.y -= camera_speed * delta
		if Input.is_action_pressed("ui_down"): move.y += camera_speed * delta
		if Input.is_action_pressed("ui_left"): move.x -= camera_speed * delta
		if Input.is_action_pressed("ui_right"): move.x += camera_speed * delta
		camera.position += move


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
			if not is_on_water(case_vers_monde(neighbor)):
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
# WATER CHECK
func is_on_water(world_pos: Vector2) -> bool:
	var x := clampi(int(world_pos.x / map.hex_width), 0, map.map_width - 1)
	var y := clampi(int(world_pos.y / map.hex_height), 0, map.map_height - 1)
	return map.tiles[y][x] in ["water", "deepwater"]


# =========================
# CONVERSIONS
func monde_vers_case(pos: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(pos.x / map.hex_width), 0, map.map_width - 1),
		clampi(int(pos.y / map.hex_height), 0, map.map_height - 1)
	)

func case_vers_monde(c: Vector2i) -> Vector2:
	return Vector2(
		(c.x + 0.5) * map.hex_width,
		(c.y + 0.5) * map.hex_height
	)


# =========================
# UTILS
func reset_energie():
	energie = maxenergie

func heal(amount: int):
	vie = min(vie + amount, maxvie)
