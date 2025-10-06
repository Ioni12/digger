# FogOfWarSystem.gd
extends RefCounted
class_name FogOfWarSystem

var visibility_radius: int = 3
var player_grid_x: int = 0
var player_grid_y: int = 0
var fog_color: Color = Color(0, 0, 0, 0.8)

# PERFORMANCE FIX: Cache visible tiles instead of fog tiles
var cached_visible_tiles: Dictionary = {}
var tiles_need_update: bool = true

func _init(p_visibility_radius: int = 3):
	visibility_radius = p_visibility_radius
	tiles_need_update = true

func update_player_position(grid_x: int, grid_y: int):
	if grid_x != player_grid_x or grid_y != player_grid_y:
		player_grid_x = grid_x
		player_grid_y = grid_y
		tiles_need_update = true

func is_tile_visible(x: int, y: int) -> bool:
	# Use cached result if available
	if tiles_need_update:
		_recalculate_visible_tiles()
		tiles_need_update = false
	
	var key = Vector2i(x, y)
	return cached_visible_tiles.get(key, false)

func _recalculate_visible_tiles():
	cached_visible_tiles.clear()
	
	# Calculate visible area bounds
	var min_x = max(0, player_grid_x - visibility_radius)
	var max_x = min(GameEnviroment.WIDTH - 1, player_grid_x + visibility_radius)
	var min_y = max(0, player_grid_y - visibility_radius)
	var max_y = min(GameEnviroment.HEIGHT - 1, player_grid_y + visibility_radius)
	
	# Mark only visible tiles
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance = max(abs(x - player_grid_x), abs(y - player_grid_y))
			if distance <= visibility_radius:
				cached_visible_tiles[Vector2i(x, y)] = true

# OPTIMIZED: Return visible tile positions for efficient fog rendering
func get_visible_bounds() -> Rect2i:
	if tiles_need_update:
		_recalculate_visible_tiles()
		tiles_need_update = false
	
	var min_x = max(0, player_grid_x - visibility_radius)
	var max_x = min(GameEnviroment.WIDTH - 1, player_grid_x + visibility_radius)
	var min_y = max(0, player_grid_y - visibility_radius)
	var max_y = min(GameEnviroment.HEIGHT - 1, player_grid_y + visibility_radius)
	
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func set_visibility_radius(radius: int):
	visibility_radius = max(0, radius)
	tiles_need_update = true

func set_fog_color(color: Color):
	fog_color = color

func get_fog_color() -> Color:
	return fog_color

func get_player_position() -> Vector2i:
	return Vector2i(player_grid_x, player_grid_y)

func get_visibility_radius() -> int:
	return visibility_radius

func force_update():
	tiles_need_update = true

func get_fog_tiles() -> Array:
	if tiles_need_update:
		_recalculate_visible_tiles()
		tiles_need_update = false
	
	var fog_tiles: Array = []
	
	# Return all tiles that are NOT visible
	for y in range(GameEnviroment.HEIGHT):
		for x in range(GameEnviroment.WIDTH):
			var key = Vector2i(x, y)
			if not cached_visible_tiles.get(key, false):
				fog_tiles.append(Vector2i(x, y))
	
	return fog_tiles
