class_name Map_utils
extends Node


func _init():
	# permet de rajouter l'objet dans le groupe avant le passage du GameManager
	add_to_group("map")


# =========================
# Hex → Iso conversion
# =========================
static func hex_to_pixel_iso(q: int, r: int) -> Vector2:
	var x := q * (Map_data.hex_width * 0.75 - 65)
	var y := r * (74 + 128 + 1)
	if q % 2 == 1:
		y += 101
	return Vector2(x, y)


# =========================
# CONVERSIONS COORDONNEES
static func monde_vers_case(pos: Vector2) -> Vector2i:
	var x = pos.x
	var y = pos.y
	var q = int(round(x / (Map_data.hex_width * 0.75 - 65)))
	if q % 2 == 1:
		y -= 101
	var r = int(round(y / (74 + 128 + 1)))
	return Vector2i(q, r)



static func case_vers_monde(c: Vector2i) -> Vector2:
	var q = c.x
	var r = c.y
	var x = q * (Map_data.hex_width * 0.75 - 65)
	var y = r * (74 + 128 + 1)
	if q % 2 == 1:
		y += 101
	return Vector2(x, y)

# ============================================================
#  VALIDITY CHECKS
# ============================================================

## Returns true if the given grid coordinate is inside the map boundaries.
# Vérification de la validité d'une case (est-ce que la position est dans la carte)
static func is_case_valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < Map_data.map_width and c.y >= 0 and c.y < Map_data.map_height


# ============================================================
#  TERRAIN CHECKS
# ============================================================

## Returns true if the given grid coordinate corresponds to a water tile.
## This avoids checking tiles[][] outside Map.gd.
static func is_case_water(c: Vector2i) -> bool:
	if not is_case_valid(c):
		return false
	return Map_data.tiles[c.y][c.x] in ["water", "deepwater"]

## Returns true if the given world coordinate corresponds to a water tile.
## This avoids checking tiles[][] outside Map.gd.
static func is_on_water(world_pos: Vector2) -> bool:
	var c = monde_vers_case(world_pos)
	return is_case_water(c)

## Returns true if the given grid coordinate is part of the ocean (i.e., navigable water).
## A navigable tile is a water tile that belongs to the precomputed ocean_cases list.
static func is_case_navigable(c: Vector2i) -> bool:
	if not is_case_valid(c):
		return false
	return c in Map_data.ocean_cases

## Returns true if the given world position corresponds to a navigable ocean tile.
static func is_world_position_navigable(world_pos: Vector2) -> bool:
	var c := monde_vers_case(world_pos)
	return is_case_navigable(c)


# ============================================================
#  CLAMPING / CORRECTION
# ============================================================

## Clamps a grid coordinate so it always stays inside the map.
static func clamp_case(c: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(c.x, 0, Map_data.map_width - 1),
		clampi(c.y, 0, Map_data.map_height - 1)
	)

## Clamps a world position so it always maps to a valid tile.
## Converts world → case (clamped) → world (center of tile).
static func clamp_world_position(world_pos: Vector2) -> Vector2:
	var c := monde_vers_case(world_pos)
	c = clamp_case(c)
	return case_vers_monde(c)


# ============================================================
#  GET RANDOM POS
# ============================================================

## Returns a random world position on ocean water (never lakes).
static func get_random_ocean_position() -> Vector2:
	if Map_data.ocean_cases.is_empty():
		push_warning("Ocean case list is empty. Did you call compute_ocean_cases()?")
		return Vector2.ZERO

	var c: Vector2i = Map_data.ocean_cases[randi() % Map_data.ocean_cases.size()]
	var pos = case_vers_monde(c)
	if pos.x < 0 or pos.y < 0:
		push_error("WORLD POS OUTSIDE MAP: " + str(pos) + " from case " + str(c))
	return pos
