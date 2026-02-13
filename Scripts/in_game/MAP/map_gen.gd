class_name Map_gen
extends Node2D


# =========================
# Terrain tuning
# =========================
@export var water_ratio := 0.55

# =========================
# Internal data
# =========================
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var noise: FastNoiseLite = FastNoiseLite.new()
var height_map := []
var islands := []


func _init():
	pass
func _enter_tree():
	pass
func _ready():
	pass



func generate()-> bool:
	rng.randomize()
	init_maps()
	init_noise()
	generate_island_centers()
	generate_islands()
	generate_tiles()
	compute_ocean_cases()
	return true
	


# =========================
# Init arrays
# =========================
func init_maps():
	height_map.clear()
	Map_data.tiles.clear()

	for y in range(Map_data.map_height):
		height_map.append([])
		Map_data.tiles.append([])
		for x in range(Map_data.map_width):
			height_map[y].append(0.0)
			Map_data.tiles[y].append("water")

# =========================
# Noise configuration
# =========================
func init_noise():
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = Map_data.gen_seed if Map_data.gen_seed != 0 else randi()
	noise.frequency = Map_data.noise_scale
	noise.fractal_octaves = Map_data.octaves
	noise.fractal_lacunarity = Map_data.lacunarity
	noise.fractal_gain = Map_data.gain

# =========================
# Island helpers
# =========================
func add_island(radius_range: Vector2, power_range: Vector2):
	islands.append({
		"pos": Vector2(
			rng.randf_range(25, Map_data.map_width - 25),
			rng.randf_range(25, Map_data.map_height - 25)
		),
		"radius": rng.randf_range(radius_range.x, radius_range.y),
		"power": rng.randf_range(power_range.x, power_range.y)
	})

# =========================
# Create islands
# =========================
func generate_island_centers():
	islands.clear()

	for i in range(Map_data.small_island_count):
		add_island(Map_data.small_radius, Map_data.small_power)

	for i in range(Map_data.medium_island_count):
		add_island(Map_data.medium_radius, Map_data.medium_power)

	for i in range(Map_data.large_island_count):
		add_island(Map_data.large_radius, Map_data.large_power)

# =========================
# Heightmap generation
# =========================
func generate_islands():
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
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
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			var h: float = height_map[y][x]

			if h < water_ratio - 0.08:
				Map_data.tiles[y][x] = "deepwater"
			elif h < water_ratio:
				Map_data.tiles[y][x] = "water"
			elif h < water_ratio + 0.07:
				Map_data.tiles[y][x] = "sand"
			elif h < 0.72:
				Map_data.tiles[y][x] = "earth"
			elif h < 0.85:
				Map_data.tiles[y][x] = "forest"
			else:
				Map_data.tiles[y][x] = "mountain"


# =========================
# Préparation de la navigation
# =========================
## Computes and stores all water tiles connected to the map borders (ocean).
func compute_ocean_cases() -> void:
	Map_data.ocean_cases.clear()
	var visited := {}
	var queue := []

	# 1. On initialise avec les bordures
	for x in range(Map_data.map_width):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, Map_data.map_height - 1))
	for y in range(Map_data.map_height):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(Map_data.map_width - 1, y))

	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if visited.has(c): continue
		visited[c] = true
		
		# On ne traite que si c'est de l'eau
		if not Map_utils.is_case_water(c): continue
		
		Map_data.ocean_cases.append(c)
		
		# 2. UTILISE LA NOUVELLE FONCTION ICI
		var neighbors = Map_utils.get_neighbors_water_only(c)
		for n in neighbors:
			if not visited.has(n):
				queue.append(n)
