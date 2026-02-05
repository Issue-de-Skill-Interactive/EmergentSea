class_name MapManager
extends Node


# Permettra de signaler la fin de la génération de la map
signal map_generated

@export var map_gen : Map_gen
@export var map_data : Map_data
@onready var map_utils

func _enter_tree():
	add_to_group("Map_manager")
	
	map_data = Map_data.new()
	map_gen = Map_gen.new({
		"map_data"=map_data
	})
	
	map_gen.map_data = map_data
	add_child(map_gen)
	
func _ready():
	await get_tree().process_frame
	var is_map_gen = map_gen.generate()
	if(is_map_gen):
		print(">>> Map générée")
		render_map()
		print(">>> Rendu de la map effectué")
		#permet de signaler au moteur que la map est générée
		emit_signal("map_generated")
	pass


# =========================
# Rendering
# =========================
func render_map():
	for y in range(map_data.map_height):
		for x in range(map_data.map_width):
			spawn_tile(map_gen.tiles[y][x], x, y)

func spawn_tile(t: String, q: int, r: int):
	var s := Sprite2D.new()

	match t:
		"deepwater": s.texture = map_data.TileDeepWater
		"water": s.texture = map_data.TileWater
		"sand": s.texture = map_data.TileSand
		"earth": s.texture = map_data.TileEarth
		"forest": s.texture = map_data.TileForest
		"mountain": s.texture = map_data.TileMountain

	s.position = map_gen.hex_to_pixel_iso(q, r)
	add_child(s)
