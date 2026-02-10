# HexGrid.gd
class_name HexGrid
extends Node

const SQRT3 := sqrt(3.0)

var cells := {}   # clé = Vector3(q, r, s), valeur = HexCell

# ============================================================
# Génération rectangulaire (odd-r offset)
# ============================================================

func generate_hex_grid_rectangular():
	var width = Map_data.map_width
	var height = Map_data.map_height

	for row in range(height):
		for col in range(width):
			var axial = offset_to_axial(col, row)
			var q = int(axial.x)
			var r = int(axial.y)
			var s = -q - r
			
			var cell = HexCell.new(q, r, s, Vector2i(col, row))
			add_cell(cell)

# ============================================================
# Gestion des cellules
# ============================================================

func add_cell(cell: HexCell):
	var key = Vector3(cell.q, cell.r, cell.s)
	cells[key] = cell

func get_cell(q: int, r: int, s: int) -> HexCell:
	return cells.get(Vector3(q, r, s), null)

# ============================================================
# Offset → Axial (odd-r)
# ============================================================

func offset_to_axial(col: int, row: int) -> Vector2:
	var q = col - int((row - (row % 2)) / 2)
	var r = row
	return Vector2(q, r)

# ============================================================
# Axial → Offset (odd-r)
# ============================================================

func axial_to_offset(q: int, r: int) -> Vector2:
	var col = q + int((r - (r % 2)) / 2)
	var row = r
	return Vector2(col, row)

# ============================================================
# Conversion Monde → Offset
# ============================================================

func world_to_offset(pos: Vector2) -> Vector2:
	var hex_w = Map_data.hex_width
	var hex_h = Map_data.hex_height

	var col_width = SQRT3 * hex_w * 0.5
	var row_height = hex_h * 0.75

	var col = int(pos.x / col_width)
	var row = int(pos.y / row_height)

	return Vector2(col, row)

# ============================================================
# Conversion Monde → Cellule
# ============================================================

func get_cell_from_world(pos: Vector2) -> HexCell:
	var offset = world_to_offset(pos)
	var col = offset.x
	var row = offset.y

	var axial = offset_to_axial(col, row)
	var q = int(axial.x)
	var r = int(axial.y)
	var s = -q - r

	return get_cell(q, r, s)

func import_from_map_data():
	if Map_data.tiles.is_empty():
		push_warning("Map_data.tiles est vide, rien à importer.")
		return

	var height = Map_data.tiles.size()
	var width = Map_data.tiles[0].size()

	for row in range(height):
		for col in range(width):

			var terrain = Map_data.tiles[row][col]

			# Conversion offset → axial
			var axial = offset_to_axial(col, row)
			var q = int(axial.x)
			var r = int(axial.y)
			var s = -q - r

			# Création de la cellule
			var cell = HexCell.new(q, r, s, Vector2i(col, row), terrain)

			# Enregistrement dans la grille
			add_cell(cell)

func spawn_all_tiles(map_manager: Node):
	for cell in cells.values():
		map_manager.spawn_tile(cell.terrain_type, cell.offset_coords.x, cell.offset_coords.y)
