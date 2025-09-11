extends Node2D
class_name GameEnviroment

const SIZE = 60
const WIDTH = 30
const HEIGHT = 30

enum TileType {
	DRY,
	ROCKY,
	DIGGED
}

var grid_data: Array[Array] = []
var tile_textures: Dictionary = {}
var cluster_size: float = 0.1
var noise_seed: int = 0
var dry_amount: float = -0.08
var noise: FastNoiseLite

func _ready() -> void:
	# Removed: add_to_group("environment") - no longer needed
	load_textures()
	setup_noise()
	setup_grid_with_noise()

func load_textures():
	tile_textures[TileType.DRY] = load("res://Tiles/DRY.png")
	tile_textures[TileType.ROCKY] = load("res://Tiles/ROCKY.png")
	tile_textures[TileType.DIGGED] = load("res://Tiles/DIGGED.png")

func setup_noise():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = noise_seed if noise_seed != 0 else randi()
	noise.frequency = cluster_size

func setup_grid_with_noise():
	grid_data = []
	
	for y in range(HEIGHT):
		var row: Array[TileType] = []
		for x in range(WIDTH):
			var noise_value = noise.get_noise_2d(x, y) + dry_amount
			var tile_type = TileType.DRY if noise_value < 0 else TileType.ROCKY
			row.append(tile_type)
		grid_data.append(row)

func dig_tile(x: int, y: int) -> TileType:
	if grid_data[y][x] != TileType.DIGGED:
		grid_data[y][x] = TileType.DIGGED
		queue_redraw()
		print("Tile dug at ", x, ", ", y, " - Type now: ", TileType.keys()[grid_data[y][x]])
		return grid_data[y][x]
	return grid_data[y][x]

func is_tile_digged(x: int, y: int) -> bool:
	if is_valid_position(x, y):
		return grid_data[y][x] == TileType.DIGGED
	return false

func _draw() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_type = grid_data[y][x]
			var texture = tile_textures[tile_type]
			
			if texture:
				var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
				draw_texture_rect(texture, rect, false)
			else:
				print("WARNING: No texture found for tile type ", tile_type, " at ", x, ", ", y)
	
	# Draw grid lines
	var color = Color(0.1, 0.1, 0.1, 0.5)
	
	for i in range(WIDTH + 1):
		draw_line(
			Vector2(i * SIZE, 0),
			Vector2(i * SIZE, HEIGHT * SIZE),
			color
		)
	
	for i in range(HEIGHT + 1):
		draw_line(
			Vector2(0, i * SIZE),
			Vector2(SIZE * WIDTH, i * SIZE),
			color
		)

func get_tile_at(x: int, y: int) -> TileType:
	if is_valid_position(x, y):
		return grid_data[y][x]
	return TileType.DRY

func is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

func print_grid():
	print("=== GRID STATE ===")
	for y in range(HEIGHT):
		var row_string = ""
		for x in range(WIDTH):
			match grid_data[y][x]:
				TileType.DRY:
					row_string += "D "
				TileType.ROCKY:
					row_string += "R "
				TileType.DIGGED:
					row_string += "X "
		print("Row ", y, ": ", row_string)
	print("==================")
