extends Node2D

# Permettra de signaler la fin de la génération de la map
signal map_generated

# =========================
# Textures
# =========================
@export var TileWater: Texture2D
@export var TileDeepWater: Texture2D
@export var TileSand: Texture2D
@export var TileEarth: Texture2D
@export var TileForest: Texture2D
@export var TileMountain: Texture2D

# =========================
# Map parameters
# =========================
@export var map_width : int = 256
@export var map_height : int = 128
@export var hex_width : int = 256
@export var hex_height : int = 128

# =========================
# Camera parameters
# =========================
@export var camera_speed := 600
@export var camera_zoom := Vector2(0.5, 0.5)

# =========================
# Terrain tuning
# =========================
@export var water_ratio := 0.55

# =========================
# Noise parameters
# =========================
@export var noise_scale := 0.035
@export var octaves := 4
@export var lacunarity := 2.0
@export var gain := 0.5
@export var seed := 0

# =========================
# Island counts 
# =========================
@export var small_island_count := 20
@export var medium_island_count := 30
@export var large_island_count := 40

# =========================
# Island size ranges 
# =========================
@export var small_radius := Vector2(22.0, 36.0)
@export var medium_radius := Vector2(48.0, 70.0)
@export var large_radius := Vector2(85.0, 120.0)

@export var small_power := Vector2(1.4, 1.9)
@export var medium_power := Vector2(1.1, 1.5)
@export var large_power := Vector2(0.75, 1.05)

# =========================
# Internal data
# =========================
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var noise: FastNoiseLite = FastNoiseLite.new()
var height_map := []
var tiles := []
var camera: Camera2D
var islands := []
var ocean_cases: Array = []	#liste des cases navigables


# permet de rajouter l'objet dans le groupe avant le passage du GameManager
func _enter_tree():
	add_to_group("map")


# =========================
# Ready
# =========================
func _ready():
	rng.randomize()
	init_camera()
	init_maps()
	init_noise()
	generate_island_centers()
	generate_islands()
	generate_tiles()
	render_tiles()
	compute_ocean_cases()
	#permet de signaler au moteur que la map est générée
	emit_signal("map_generated")


# =========================
# Camera setup
# =========================
func init_camera():
	camera = Camera2D.new()        
	
	camera.enabled = true          
	camera.zoom = camera_zoom      
	add_child(camera)              
	camera.make_current()  

# =========================
# Init arrays
# =========================
func init_maps():
	height_map.clear()
	tiles.clear()

	for y in range(map_height):
		height_map.append([])
		tiles.append([])
		for x in range(map_width):
			height_map[y].append(0.0)
			tiles[y].append("water")

# =========================
# Noise configuration
# =========================
func init_noise():
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = seed if seed != 0 else randi()
	noise.frequency = noise_scale
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain

# =========================
# Island helpers
# =========================
func add_island(radius_range: Vector2, power_range: Vector2):
	islands.append({
		"pos": Vector2(
			rng.randf_range(25, map_width - 25),
			rng.randf_range(25, map_height - 25)
		),
		"radius": rng.randf_range(radius_range.x, radius_range.y),
		"power": rng.randf_range(power_range.x, power_range.y)
	})

# =========================
# Create islands
# =========================
func generate_island_centers():
	islands.clear()

	for i in range(small_island_count):
		add_island(small_radius, small_power)

	for i in range(medium_island_count):
		add_island(medium_radius, medium_power)

	for i in range(large_island_count):
		add_island(large_radius, large_power)

# =========================
# Heightmap generation
# =========================
func generate_islands():
	for y in range(map_height):
		for x in range(map_width):
			var n: float = noise.get_noise_2d(x, y)
			n = (n + 1.0) * 0.5

			var mask := 0.0

			for island in islands:
				var pos: Vector2 = island["pos"]
				var radius: float = island["radius"]
				var power: float = island["power"]

				var dx := x - pos.x
				var dy := y - pos.y
				var d := sqrt(dx * dx + dy * dy)

				if d < radius:
					var local := 1.0 - (d / radius)
					mask = max(mask, pow(local, power))

			height_map[y][x] = clamp(n * mask, 0.0, 1.0)

# =========================
# Tile classification
# =========================
func generate_tiles():
	for y in range(map_height):
		for x in range(map_width):
			var h: float = height_map[y][x]

			if h < water_ratio - 0.08:
				tiles[y][x] = "deepwater"
			elif h < water_ratio:
				tiles[y][x] = "water"
			elif h < water_ratio + 0.07:
				tiles[y][x] = "sand"
			elif h < 0.72:
				tiles[y][x] = "earth"
			elif h < 0.85:
				tiles[y][x] = "forest"
			else:
				tiles[y][x] = "mountain"

# =========================
# Rendering
# =========================
func render_tiles():
	for y in range(map_height):
		for x in range(map_width):
			spawn_tile(tiles[y][x], x, y)

func spawn_tile(t: String, q: int, r: int):
	var s := Sprite2D.new()

	match t:
		"deepwater": s.texture = TileDeepWater
		"water": s.texture = TileWater
		"sand": s.texture = TileSand
		"earth": s.texture = TileEarth
		"forest": s.texture = TileForest
		"mountain": s.texture = TileMountain

	s.position = hex_to_pixel_iso(q, r)
	add_child(s)

# =========================
# Hex → Iso conversion
# =========================
func hex_to_pixel_iso(q: int, r: int) -> Vector2:
	var x := q * (hex_width * 0.75 - 65)
	var y := r * (74 + 128 + 1)
	if q % 2 == 1:
		y += 101
	return Vector2(x, y)

# =========================
# Camera movement
# =========================
func _process(delta: float):
	if Input.is_action_pressed("ui_up"):
		camera.position.y -= camera_speed * delta
	if Input.is_action_pressed("ui_down"):
		camera.position.y += camera_speed * delta
	if Input.is_action_pressed("ui_left"):
		camera.position.x -= camera_speed * delta
	if Input.is_action_pressed("ui_right"):
		camera.position.x += camera_speed * delta
		


# =========================
# Préparation de la navigation
# =========================
## Computes and stores all water tiles connected to the map borders (ocean).
func compute_ocean_cases() -> void:
	ocean_cases.clear()
	var visited := {}
	var queue := []

	# Start from all border tiles
	for x in range(map_width):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, map_height - 1))

	for y in range(map_height):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(map_width - 1, y))

	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if visited.has(c):
			continue
		visited[c] = true
		if not is_case_water(c):
			continue
		ocean_cases.append(c)
		var neighbors = [
			Vector2i(c.x + 1, c.y),
			Vector2i(c.x - 1, c.y),
			Vector2i(c.x, c.y + 1),
			Vector2i(c.x, c.y - 1)
		]
		for n in neighbors:
			if is_case_valid(n) and not visited.has(n):
				queue.append(n)



# =========================
# CONVERSIONS COORDONNEES
func monde_vers_case(pos: Vector2) -> Vector2i:
	var x = pos.x
	var y = pos.y
	var q = int(round(x / (hex_width * 0.75 - 65)))
	if q % 2 == 1:
		y -= 101
	var r = int(round(y / (74 + 128 + 1)))
	return Vector2i(q, r)



func case_vers_monde(c: Vector2i) -> Vector2:
	var q = c.x
	var r = c.y
	var x = q * (hex_width * 0.75 - 65)
	var y = r * (74 + 128 + 1)
	if q % 2 == 1:
		y += 101
	return Vector2(x, y)



# ============================================================
#  VALIDITY CHECKS
# ============================================================

## Returns true if the given grid coordinate is inside the map boundaries.
# Vérification de la validité d'une case (est-ce que la position est dans la carte)
func is_case_valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < map_width and c.y >= 0 and c.y < map_height


# ============================================================
#  TERRAIN CHECKS
# ============================================================

## Returns true if the given grid coordinate corresponds to a water tile.
## This avoids checking tiles[][] outside Map.gd.
func is_case_water(c: Vector2i) -> bool:
	if not is_case_valid(c):
		return false
	return tiles[c.y][c.x] in ["water", "deepwater"]

## Returns true if the given world coordinate corresponds to a water tile.
## This avoids checking tiles[][] outside Map.gd.
func is_on_water(world_pos: Vector2) -> bool:
	var c = monde_vers_case(world_pos)
	return is_case_water(c)

## Returns true if the given grid coordinate is part of the ocean (i.e., navigable water).
## A navigable tile is a water tile that belongs to the precomputed ocean_cases list.
func is_case_navigable(c: Vector2i) -> bool:
	if not is_case_valid(c):
		return false
	return c in ocean_cases

## Returns true if the given world position corresponds to a navigable ocean tile.
func is_world_position_navigable(world_pos: Vector2) -> bool:
	var c := monde_vers_case(world_pos)
	return is_case_navigable(c)


# ============================================================
#  CLAMPING / CORRECTION
# ============================================================

## Clamps a grid coordinate so it always stays inside the map.
func clamp_case(c: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(c.x, 0, map_width - 1),
		clampi(c.y, 0, map_height - 1)
	)

## Clamps a world position so it always maps to a valid tile.
## Converts world → case (clamped) → world (center of tile).
func clamp_world_position(world_pos: Vector2) -> Vector2:
	var c := monde_vers_case(world_pos)
	c = clamp_case(c)
	return case_vers_monde(c)


# ============================================================
#  GET RANDOM POS
# ============================================================

## Returns a random world position on ocean water (never lakes).
func get_random_ocean_position() -> Vector2:
	if ocean_cases.is_empty():
		push_warning("Ocean case list is empty. Did you call compute_ocean_cases()?")
		return Vector2.ZERO

	var c: Vector2i = ocean_cases[randi() % ocean_cases.size()]
	var pos = case_vers_monde(c)
	if pos.x < 0 or pos.y < 0:
		push_error("WORLD POS OUTSIDE MAP: " + str(pos) + " from case " + str(c))
	return pos
