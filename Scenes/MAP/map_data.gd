class_name Map_data
extends Node

# =========================
# Textures
# =========================
@export var TileWater: Texture2D = preload("res://textures/tiles/TileWater.png")
@export var TileDeepWater: Texture2D = preload("res://textures/tiles/TileDeepWater.png")
@export var TileSand: Texture2D = preload("res://textures/tiles/TileSand.png")
@export var TileEarth: Texture2D = preload("res://textures/tiles/TileEarth.png")
@export var TileForest: Texture2D = preload("res://textures/tiles/TileForest.png")
@export var TileMountain: Texture2D = preload("res://textures/tiles/TileMountain.png")


# =========================
# Map parameters
# =========================
@export var map_width : int = 256
@export var map_height : int = 128
@export var hex_width : int = 256
@export var hex_height : int = 128

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

func _init():
	add_to_group("map_data")
