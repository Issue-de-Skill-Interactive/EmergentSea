class_name MapManager
extends Node


# Permettra de signaler la fin de la génération de la map
signal map_generated

@export var map_gen : Map_gen
@export var map_utils : Map_utils

func _enter_tree():
	add_to_group("Map_manager")
	
	Map_data.new()
	map_gen = Map_gen.new()
	map_utils = Map_utils.new()
	add_child(map_gen)
	
func _ready():
	await get_tree().process_frame
	var is_map_gen = map_gen.generate()
	if(is_map_gen):
		print(">>> Map générée")
		render_map()
		print(">>> Rendu de la map effectué")
		#permet de signaler au moteur que la map est générée
		await get_tree().process_frame
		emit_signal("map_generated")
	pass


# =========================
# Rendering
# =========================
func render_map():
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			spawn_tile(Map_data.tiles[y][x], x, y)

func spawn_tile(t: String, q: int, r: int):
	var s := Sprite2D.new()
	match t:
		"deepwater": s.texture = Map_data.TileDeepWater
		"water": s.texture = Map_data.TileWater
		"sand": s.texture = Map_data.TileSand
		"earth": s.texture = Map_data.TileEarth
		"forest": s.texture = Map_data.TileForest
		"mountain": s.texture = Map_data.TileMountain
	s.position = Map_utils.hex_to_pixel_iso(q, r)
	var scale_x = Map_data.hex_width / s.texture.get_width()
	var scale_y = Map_data.hex_height / s.texture.get_height()
	s.scale = Vector2(scale_x, scale_y)
	add_child(s)
