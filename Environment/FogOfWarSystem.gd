# FogOfWarSystem.gd
extends RefCounted
class_name FogOfWarSystem

var visibility_radius: int = 3
var player_grid_x: int = 0
var player_grid_y: int = 0
var fog_color: Color = Color(0, 0, 0, 0.8)

func _init(p_visibility_radius: int = 3):
	visibility_radius = p_visibility_radius

func update_player_position(grid_x: int, grid_y: int):
	player_grid_x = grid_x
	player_grid_y = grid_y

func is_tile_visible(x: int, y: int) -> bool:
	var distance = max(abs(x - player_grid_x), abs(y - player_grid_y))
	return distance <= visibility_radius

func get_fog_tiles() -> Array:
	var fog_tiles: Array = []
	
	for y in range(GameEnviroment.HEIGHT):
		for x in range(GameEnviroment.WIDTH):
			if not is_tile_visible(x, y):
				fog_tiles.append(Vector2i(x, y))
	
	return fog_tiles

func set_visibility_radius(radius: int):
	visibility_radius = max(0, radius)

func set_fog_color(color: Color):
	fog_color = color

func get_fog_color() -> Color:
	return fog_color

func get_player_position() -> Vector2i:
	return Vector2i(player_grid_x, player_grid_y)

func get_visibility_radius() -> int:
	return visibility_radius
