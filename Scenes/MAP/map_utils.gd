class_name Map_utils
extends Node


# Les 6 directions constantes en coordonnées axiales (q, r)
# Cela ne change JAMAIS, peu importe la parité de la ligne.
static var _axial_directions = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]



func _init():
	# permet de rajouter l'objet dans le groupe avant le passage du GameManager
	add_to_group("map")


# =========================
# Hex -> Iso conversion (Visuel)
# =========================
static func hex_to_pixel_iso(col: int, row: int) -> Vector2:
	# Ajuste ces valeurs selon la taille exacte de tes sprites
	var x := col * (Map_data.hex_width * 0.75 - 65)
	var y := row * (74 + 128 + 1)
	if col % 2 == 1:
		y += 101
	return Vector2(x, y)


# =========================
# CONVERSIONS COORDONNEES
static func monde_vers_case(pos: Vector2) -> Vector2i:
	# Approche simplifiée rectangulaire (attention aux bords des hexagones)
	# Pour être parfait, il faudrait une matrice de rotation, mais gardons ton approche :
	
	var x = pos.x
	# Largeur approximative d'une colonne
	var col_width = Map_data.hex_width * 0.75 - 65 
	var q = int(round(x / col_width))
	
	var y = pos.y
	# Si on est sur une colonne impaire, on décale le Y inversement au visuel pour retrouver la grille
	if q % 2 == 1:
		y -= 101
		
	var row_height = 74 + 128 + 1
	var r = int(round(y / row_height))
	
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

# Calcule la distance réelle en cases entre deux hexagones (offset coords)
static func get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	# 1. On convertit les coordonnées Offset (col, row) en Axial (q, r)
	# On reprend la formule de ton HexGrid.gd
	var aq = a.x - int((a.y - (a.y % 2)) / 2)
	var ar = a.y
	
	var bq = b.x - int((b.y - (b.y % 2)) / 2)
	var br = b.y
	
	# 2. On calcule la distance en coordonnées axiales
	# La distance est la moitié de la somme des différences absolues
	# (équivalent de la distance Manhattan en 3D cubique)
	var d_q = abs(aq - bq)
	var d_r = abs(ar - br)
	var d_s = abs((-aq - ar) - (-bq - br))
	
	return int((d_q + d_r + d_s) / 2)


static func get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	
	# 1. Conversion Offset -> Axial (Maths pures)
	# Note: On réutilise la logique de ta grille ici pour éviter une dépendance circulaire
	var q = c.x - int((c.y - (c.y % 2)) / 2)
	var r = c.y
	
	for d in _axial_directions:
		# 2. Application du voisin en Axial
		var neighbor_q = q + d.x
		var neighbor_r = r + d.y
		
		# 3. Conversion Axial -> Offset (Retour vers le système de stockage)
		var col = neighbor_q + int((neighbor_r - (neighbor_r % 2)) / 2)
		var row = neighbor_r
		var neighbor_offset = Vector2i(col, row)
		
		# 4. Vérifications
		if is_case_navigable(neighbor_offset):
			res.append(neighbor_offset)
			
	return res

# Nouvelle fonction pour gérer le coût du terrain
static func get_movement_cost(c: Vector2i) -> float:
	if not is_case_valid(c): return INF
	
	var type = Map_data.tiles[c.y][c.x]
	
	match type:
		"deepwater": return 1.0 # Autoroute maritime
		"water": return 1.0     # Eau côtière (plus lent, on préfère le large)
		_: return 1.0
#static func get_neighbors(c: Vector2i) -> Array:
	#var res := []
	#
	## Directions pour les lignes PAIRES (y % 2 == 0)
	#var dirs_even = [
		#Vector2i(1, 0), Vector2i(-1, 0),  # Droite, Gauche
		#Vector2i(0, -1), Vector2i(-1, -1), # Haut-Droit, Haut-Gauche
		#Vector2i(0, 1), Vector2i(-1, 1)    # Bas-Droit, Bas-Gauche
	#]
	#
	## Directions pour les lignes IMPAIRES (y % 2 == 1)
	#var dirs_odd = [
		#Vector2i(1, 0), Vector2i(-1, 0),  # Droite, Gauche
		#Vector2i(1, -1), Vector2i(0, -1),  # Haut-Droit, Haut-Gauche
		#Vector2i(1, 1), Vector2i(0, 1)     # Bas-Droit, Bas-Gauche
	#]
	#
	#var directions = dirs_even if c.y % 2 == 0 else dirs_odd
#
	#for d in directions:
		#var n = c + d
		#
		## 1. Vérifier les limites de la carte
		#if not Map_utils.is_case_valid(n):
			#continue
			#
		## 2. Vérifier si c'est navigable (Eau)
		## J'utilise ta fonction statique existante, c'est plus performant
		## que de convertir en world pos puis re-convertir en case
		#if not Map_utils.is_case_navigable(n): 
			#continue
			#
		#res.append(n)
		#
	#return res
