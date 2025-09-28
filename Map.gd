extends Control

@onready var background: ColorRect = $Background
@onready var map_display: Control = $MapDisplay
@onready var close_label: Label = $CloseLabel

var environment: GameEnviroment
var player: Player
var tile_size: int = 20  # Small size for map tiles

# Colors for different elements
var tile_colors = {
	GameEnviroment.TileType.DRY: Color.GREEN,
	GameEnviroment.TileType.ROCKY: Color.BROWN,
	GameEnviroment.TileType.DIGGED: Color.BLACK
}

var player_color = Color.WHITE
var enemy_color = Color.RED
var npc_color = Color.BLUE
var fog_color = Color(0.1, 0.1, 0.1, 0.8)  # Dark semi-transparent

func _ready():
	# Set process mode so map works when game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Initially hidden
	visible = false
	
	# Setup UI elements
	setup_ui()

func setup_ui():
	"""Configure the UI elements"""
	# Setup background
	if background:
		background.color = Color(0.0, 0.0, 0.0, 0.7)  # Semi-transparent black
	
	# Setup close label
	if close_label:
		close_label.text = "Press M to close"
		close_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Connect map_display's draw signal
	if map_display:
		map_display.draw.connect(_draw_map)

func setup(game_environment: GameEnviroment, game_player: Player):
	"""Call this from your main game to setup references"""
	environment = game_environment
	player = game_player
	print("Map setup complete")

func _input(event):
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_M:
		close_map()
		get_viewport().set_input_as_handled()

func open_map():
	"""Call this to show the map"""
	if not environment or not player:
		print("ERROR: Map not properly setup - missing environment or player reference")
		return
	
	visible = true
	get_tree().paused = true
	
	# Trigger redraw of map display
	if map_display:
		map_display.queue_redraw()

func close_map():
	"""Call this to hide the map"""
	visible = false
	get_tree().paused = false

func _draw_map():
	"""This function draws on the MapDisplay control"""
	if not environment or not player or not map_display:
		return
	
	# Calculate map dimensions
	var map_width = environment.WIDTH * tile_size
	var map_height = environment.HEIGHT * tile_size
	
	# Center the map in the display area
	var display_center = map_display.size / 2
	var map_start = display_center - Vector2(map_width, map_height) / 2
	
	# Draw legend first
	draw_legend(map_display, Vector2(20, 20))
	
	# Draw tiles
	draw_tiles(map_display, map_start)
	
	# Draw entities
	draw_entities(map_display, map_start)

func draw_legend(control: Control, start_pos: Vector2):
	"""Draw a simple legend explaining the colors"""
	var font = get_theme_default_font()
	var font_size = 16
	var line_height = 20
	var y = start_pos.y
	
	# Legend items
	var legend_items = [
		[Color.GREEN, "Dry Ground"],
		[Color.BROWN, "Rocky Ground"], 
		[Color.BLACK, "Dug Tunnels"],
		[Color.WHITE, "Player"],
		[Color.RED, "Enemies"],
		[Color.BLUE, "NPCs"]
	]
	
	for item in legend_items:
		var color = item[0]
		var text = item[1]
		
		# Draw color square
		control.draw_rect(Rect2(start_pos.x, y - 8, 12, 12), color)
		
		# Draw text
		control.draw_string(font, Vector2(start_pos.x + 20, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
		y += line_height

func draw_tiles(control: Control, map_start: Vector2):
	"""Draw the tile grid"""
	if not environment.fog_of_war:
		return
	
	var fog_tiles = environment.fog_of_war.get_fog_tiles()
	
	for y in range(environment.HEIGHT):
		for x in range(environment.WIDTH):
			var tile_pos = Vector2(x, y)
			var screen_pos = map_start + Vector2(x * tile_size, y * tile_size)
			var tile_rect = Rect2(screen_pos, Vector2(tile_size, tile_size))
			
			# Check if tile is fogged
			if tile_pos in fog_tiles:
				# Draw fog
				control.draw_rect(tile_rect, fog_color)
			else:
				# Draw actual tile
				var tile_type = environment.get_tile_at(x, y)
				var tile_color = tile_colors.get(tile_type, Color.GRAY)
				control.draw_rect(tile_rect, tile_color)

func draw_entities(control: Control, map_start: Vector2):
	"""Draw player, enemies, and NPCs"""
	
	# Draw player
	var player_grid = environment.get_player_grid_position()
	var player_screen_pos = map_start + Vector2(player_grid.x * tile_size, player_grid.y * tile_size)
	var player_rect = Rect2(player_screen_pos, Vector2(tile_size, tile_size))
	control.draw_rect(player_rect, player_color)
	
	# Draw a border around player for better visibility
	control.draw_rect(player_rect, Color.BLACK, false, 1.0)
	
	# Draw enemies
	for enemy in environment.enemies:
		var enemy_grid = enemy.get_grid_position()
		var enemy_screen_pos = map_start + Vector2(enemy_grid.x * tile_size, enemy_grid.y * tile_size)
		var enemy_rect = Rect2(enemy_screen_pos, Vector2(tile_size, tile_size))
		
		# Only draw if not fogged
		if not is_position_fogged(enemy_grid):
			control.draw_rect(enemy_rect, enemy_color)
	
	# Draw NPCs
	for npc in environment.npcs:
		var npc_grid = npc.get_grid_position()
		var npc_screen_pos = map_start + Vector2(npc_grid.x * tile_size, npc_grid.y * tile_size)
		var npc_rect = Rect2(npc_screen_pos, Vector2(tile_size, tile_size))
		
		# Only draw if not fogged
		if not is_position_fogged(npc_grid):
			control.draw_rect(npc_rect, npc_color)

func is_position_fogged(pos: Vector2i) -> bool:
	"""Check if a position is covered by fog of war"""
	if not environment.fog_of_war:
		return false
	
	var fog_tiles = environment.fog_of_war.get_fog_tiles()
	return Vector2(pos.x, pos.y) in fog_tiles
