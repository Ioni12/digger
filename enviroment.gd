extends Node2D
class_name GameEnviroment

const SIZE = 120
const WIDTH = 30
const HEIGHT = 30

enum TileType {
	DRY,
	ROCKY,
	DIGGED,
}

var tile_dig_speeds: Dictionary = {
	TileType.DRY: 1.2,     # Fast to dig
	TileType.ROCKY: 1.5,   # Slow to dig
	TileType.DIGGED: 0.0    # Already dug, no digging needed
}


var grid_data: Array[Array] = []
var tile_textures: Dictionary = {}
var cluster_size: float = 0.1
var noise_seed: int = 0
var dry_amount: float = -0.08
var noise: FastNoiseLite

var fog_of_war: FogOfWarSystem


func _ready() -> void:
	load_textures()
	setup_noise()
	setup_grid_with_noise()
	fog_of_war = FogOfWarSystem.new(3)

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
			if x == 0 and y == 0:
				row.append(TileType.DIGGED)
			else:
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
	# Draw tiles first
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_type = grid_data[y][x]
			var texture = tile_textures[tile_type]
			
			if texture:
				var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
				draw_texture_rect(texture, rect, false)
			else:
				print("WARNING: No texture found for tile type ", tile_type, " at ", x, ", ", y)
	var rect = Rect2(0 * SIZE, 0 * SIZE, SIZE, SIZE)
	draw_rect(rect, Color.BLUE, true)
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
	draw_fog_of_war()
	
func draw_fog_of_war():
	var fog_tiles = fog_of_war.get_fog_tiles()
	var fog_color = fog_of_war.get_fog_color()
	
	for tile_pos in fog_tiles:
		var rect = Rect2(tile_pos.x * SIZE, tile_pos.y * SIZE, SIZE, SIZE)
		draw_rect(rect, fog_color)

func update_player_position(grid_x: int, grid_y: int):
	fog_of_war.update_player_position(grid_x, grid_y)
	queue_redraw()

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

func get_dig_speed_for_tile(tile_type: TileType) -> float:
	return tile_dig_speeds.get(tile_type, 0.1)
