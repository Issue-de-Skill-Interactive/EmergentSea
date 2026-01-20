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

# =========================
# Déplacement
var path := []
var target_position: Vector2
var is_moving: bool = false
var case_actuelle: Vector2i

# =========================
# Référence map
@onready var map: Node2D = get_tree().get_first_node_in_group("map") as Node2D

# =========================
# Caméra externe
@onready var camera: Camera2D = $Camera2D as Camera2D
var energie_label: Label

# =========================
# Zoom caméra
@export var zoom_step: float = 0.1
@export var camera_speed: float = 600.0

func _ready():
	target_position = global_position
	case_actuelle = monde_vers_case(global_position)

	if camera != null:
		camera.make_current()

	energie_label = Label.new()
	energie_label.position = Vector2(20, 20)
	energie_label.z_index = 1000
	if camera != null:
		camera.add_child(energie_label)
	else:
		add_child(energie_label)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if energie > 0 and not is_moving and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click_pos: Vector2 = get_global_mouse_position()
			if is_on_water(click_pos):
				# Calculer le chemin le plus court
				path = calculer_chemin(case_actuelle, monde_vers_case(click_pos))
				if path.size() > 0:
					is_moving = true
			else:
				print("Impossible d'aller sur la terre")

		# Zoom caméra
		if camera != null:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				var new_zoom = camera.zoom - Vector2(zoom_step, zoom_step)
				camera.zoom = Vector2(max(new_zoom.x, 0.01), max(new_zoom.y, 0.01))
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				var new_zoom = camera.zoom + Vector2(zoom_step, zoom_step)
				camera.zoom = Vector2(max(new_zoom.x, 0.01), max(new_zoom.y, 0.01))

func _process(delta):
	# Déplacement navire via pathfinding
	if is_moving and path.size() > 0:
		var next_case: Vector2i = path[0]
		var next_pos: Vector2 = Vector2((next_case.x + 0.5) * map.hex_width, (next_case.y + 0.5) * map.hex_height)
		var direction: Vector2 = next_pos - global_position
		var dist: float = direction.length()

		if dist < 5:
			global_position = next_pos
			path.remove_at(0)
			case_actuelle = next_case
			if energie > 0:
				energie -= 1
			if path.size() == 0:
				is_moving = false
		else:
			global_position += direction.normalized() * vitesse * delta

	# Déplacement caméra manuelle
	if camera != null:
		var move: Vector2 = Vector2.ZERO
		if Input.is_action_pressed("ui_up"):
			move.y -= camera_speed * delta
		if Input.is_action_pressed("ui_down"):
			move.y += camera_speed * delta
		if Input.is_action_pressed("ui_left"):
			move.x -= camera_speed * delta
		if Input.is_action_pressed("ui_right"):
			move.x += camera_speed * delta
		camera.position += move

	# Mise à jour label énergie
	if energie_label != null:
		energie_label.text = "Énergie : %d/%d" % [energie, maxenergie]

# =========================
# A* sur la map hex
func calculer_chemin(start: Vector2i, goal: Vector2i) -> Array:
	var open_set := [start]
	var came_from := {}
	var g_score := {}
	var f_score := {}

	g_score[start] = 0
	f_score[start] = start.distance_to(goal)

	while open_set.size() > 0:
		open_set.sort_custom(func(a, b): return int(f_score[a] - f_score[b]))
		var current = open_set[0]
		if current == goal:
			# reconstruire chemin
			var total_path := []
			while came_from.has(current):
				total_path.insert(0, current)
				current = came_from[current]
			total_path.insert(0, start)
			return total_path

		open_set.remove_at(0)
		for neighbor in get_neighbors(current):
			if not is_on_water(case_vers_monde(neighbor)):
				continue
			var tentative_g = g_score.get(current, 999999) + 1
			if tentative_g < g_score.get(neighbor, 999999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + neighbor.distance_to(goal)
				if neighbor not in open_set:
					open_set.append(neighbor)
	return []

# =========================
# Obtenir voisins (hex 4 ou 6 directions)
func get_neighbors(c: Vector2i) -> Array:
	var neighbors := []
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var n = c + d
		if n.x >= 0 and n.y >= 0 and n.x < map.map_width and n.y < map.map_height:
			neighbors.append(n)
	return neighbors

# =========================
# Vérifie si la position est sur l'eau
func is_on_water(world_pos: Vector2) -> bool:
	if map == null:
		return false
	var tile_x = int(world_pos.x / map.hex_width)
	var tile_y = int(world_pos.y / map.hex_height)
	tile_x = clamp(tile_x, 0, map.map_width - 1)
	tile_y = clamp(tile_y, 0, map.map_height - 1)
	var tile_type = str(map.tiles[tile_y][tile_x])
	return tile_type == "water" or tile_type == "deepwater"

# =========================
# Conversion monde -> case
func monde_vers_case(pos: Vector2) -> Vector2i:
	var x = int(pos.x / map.hex_width)
	var y = int(pos.y / map.hex_height)
	x = clamp(x, 0, map.map_width - 1)
	y = clamp(y, 0, map.map_height - 1)
	return Vector2i(x, y)

func case_vers_monde(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * map.hex_width, (c.y + 0.5) * map.hex_height)

func reset_energie():
	energie = maxenergie

func heal(amount: int):
	vie = min(vie + amount, maxvie)
