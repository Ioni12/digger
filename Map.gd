extends Control

@onready var background: ColorRect = $Background
@onready var map_display: Control = $MapDisplay
@onready var close_label: Label = $CloseLabel

var environment: GameEnviroment
var player: Player
var tile_size: int = 2

# Viewport settings
var viewport_tiles: Vector2i = Vector2i(300, 300)  # 50x50 tiles viewport
var camera_offset: Vector2 = Vector2.ZERO  # Offset from player position

# Mouse panning
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_start_offset: Vector2

# Colors for different elements
var tile_colors = {
	GameEnviroment.TileType.DRY: Color.GREEN,
	GameEnviroment.TileType.ROCKY: Color.BROWN,
	GameEnviroment.TileType.DIGGED: Color.BLACK
}

var player_color = Color.WHITE
var enemy_color = Color.RED
var npc_color = Color.BLUE
var fog_color = Color(0.1, 0.1, 0.1, 0.8)

# Structure debug colors
var structure_colors = {
	"ROOM": Color.GREEN,
	"TUNNEL": Color.CYAN,
	"CHAMBER": Color.YELLOW,
	"L-CORRIDOR": Color.MAGENTA
}
var structure_outline_color = Color.WHITE

# Debug toggles
var show_structures: bool = true

# MultiMesh rendering using CanvasItem draw calls
var tile_batches: Dictionary = {}
var map_dirty: bool = true
var map_start: Vector2

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	setup_ui()

func setup_ui():
	if background:
		background.color = Color(0.0, 0.0, 0.0, 0.7)
	
	if close_label:
		close_label.text = "Press M to close | Click and drag to pan | S to toggle structures"
		close_label.add_theme_color_override("font_color", Color.WHITE)
	
	if map_display:
		map_display.draw.connect(_draw_map)

func setup(game_environment: GameEnviroment, game_player: Player):
	environment = game_environment
	player = game_player
	print("Map setup complete with viewport rendering and structure debug")

func _input(event):
	if not visible:
		return
	
	# Close map with M key
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		close_map()
		get_viewport().set_input_as_handled()
		return
	
	# Toggle structure visibility with S key
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		show_structures = !show_structures
		if map_display:
			map_display.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	
	# Mouse panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				drag_start_offset = camera_offset
			else:
				is_dragging = false
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_start_pos
		camera_offset = drag_start_offset + delta / tile_size
		
		# Clamp camera offset to map bounds
		var player_grid = environment.get_player_grid_position()
		var half_viewport = Vector2(viewport_tiles) / 2.0
		
		var min_offset = Vector2.ZERO - Vector2(player_grid) + half_viewport
		var max_offset = Vector2(environment.WIDTH, environment.HEIGHT) - Vector2(player_grid) - half_viewport
		
		camera_offset.x = clamp(camera_offset.x, min_offset.x, max_offset.x)
		camera_offset.y = clamp(camera_offset.y, min_offset.y, max_offset.y)
		
		if map_display:
			map_display.queue_redraw()
		get_viewport().set_input_as_handled()

func open_map():
	if not environment or not player:
		print("ERROR: Map not properly setup - missing environment or player reference")
		return
	
	visible = true
	get_tree().paused = true
	
	# Reset camera to center on player
	camera_offset = Vector2.ZERO
	is_dragging = false
	
	# Update tile batches when opening map
	map_dirty = true
	update_tile_batches()
	
	if map_display:
		map_display.queue_redraw()

func close_map():
	visible = false
	get_tree().paused = false

func update_tile_batches():
	"""Collect all tiles by type for batch rendering"""
	if not environment or not map_dirty:
		return
	
	# Get player position and calculate visible tile range
	var player_grid = environment.get_player_grid_position()
	var center_pos = Vector2(player_grid) + camera_offset
	var half_viewport = Vector2(viewport_tiles) / 2.0
	
	# Calculate visible tile bounds
	var start_x = int(center_pos.x - half_viewport.x)
	var start_y = int(center_pos.y - half_viewport.y)
	var end_x = int(center_pos.x + half_viewport.x)
	var end_y = int(center_pos.y + half_viewport.y)
	
	# Clamp to map bounds
	start_x = max(0, start_x)
	start_y = max(0, start_y)
	end_x = min(environment.WIDTH - 1, end_x)
	end_y = min(environment.HEIGHT - 1, end_y)
	
	# Calculate map display position (centered in viewport)
	var display_center = map_display.size / 2
	var viewport_pixel_size = Vector2(viewport_tiles) * tile_size
	map_start = display_center - viewport_pixel_size / 2
	
	# Collect tiles by type (only visible tiles)
	tile_batches = {
		GameEnviroment.TileType.DRY: [],
		GameEnviroment.TileType.ROCKY: [],
		GameEnviroment.TileType.DIGGED: [],
		"fog": []
	}
	
	# Categorize visible tiles
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			if environment.fog_of_war and not environment.fog_of_war.is_tile_visible(x, y):
				tile_batches["fog"].append(Vector2i(x, y))
			else:
				var tile_type = environment.get_tile_at(x, y)
				tile_batches[tile_type].append(Vector2i(x, y))
	
	# Store viewport bounds for entity rendering
	tile_batches["viewport_start"] = Vector2i(start_x, start_y)
	
	map_dirty = false

func _draw_map():
	if not environment or not player or not map_display:
		return
	
	# Update tile batches if needed
	if map_dirty:
		update_tile_batches()
	
	# Draw legend first
	draw_legend(map_display, Vector2(20, 20))
	
	# Draw all tiles using draw_multimesh equivalent (batched rectangles)
	draw_tile_batches(map_display)
	
	# Draw structures BEFORE entities (so entities appear on top)
	if show_structures:
		draw_structures(map_display, map_start)
	
	# Draw entities on top
	draw_entities(map_display, map_start)

func draw_tile_batches(control: Control):
	"""Draw all tiles in batches using PackedVector2Array for efficiency"""
	
	var viewport_start = tile_batches.get("viewport_start", Vector2i.ZERO)
	
	# Draw fog tiles
	if tile_batches.has("fog"):
		for tile_pos in tile_batches["fog"]:
			var relative_pos = tile_pos - viewport_start
			var world_pos = map_start + Vector2(relative_pos.x * tile_size, relative_pos.y * tile_size)
			var rect = Rect2(world_pos, Vector2(tile_size, tile_size))
			control.draw_rect(rect, fog_color)
	
	# Draw each tile type
	for tile_type in [GameEnviroment.TileType.DRY, GameEnviroment.TileType.ROCKY, GameEnviroment.TileType.DIGGED]:
		if not tile_batches.has(tile_type):
			continue
			
		var color = tile_colors.get(tile_type, Color.GRAY)
		var positions = tile_batches[tile_type]
		
		for tile_pos in positions:
			var relative_pos = tile_pos - viewport_start
			var world_pos = map_start + Vector2(relative_pos.x * tile_size, relative_pos.y * tile_size)
			var rect = Rect2(world_pos, Vector2(tile_size, tile_size))
			control.draw_rect(rect, color)

func draw_structures(control: Control, start: Vector2):
	"""Draw structure outlines and labels"""
	if not environment or not environment.structure_system:
		return
	
	var viewport_start = tile_batches.get("viewport_start", Vector2i.ZERO)
	var font = get_theme_default_font()
	var font_size = 10
	
	# Draw each structure
	for struct in environment.structure_system.debug_structures:
		var pos = struct["pos"]
		var size = struct["size"]
		var color = struct["color"]
		var type_name = struct["type"]
		
		# Check if structure is in viewport
		var struct_rect = Rect2i(pos, size)
		var viewport_rect = Rect2i(viewport_start, viewport_tiles)
		
		if not struct_rect.intersects(viewport_rect):
			continue  # Skip if not visible
		
		# Calculate screen position
		var relative_pos = pos - viewport_start
		var screen_pos = start + Vector2(relative_pos.x * tile_size, relative_pos.y * tile_size)
		var screen_size = Vector2(size.x * tile_size, size.y * tile_size)
		
		# Draw semi-transparent filled rectangle
		var fill_color = Color(color.r, color.g, color.b, 0.3)
		control.draw_rect(Rect2(screen_pos, screen_size), fill_color, true)
		
		# Draw outline
		control.draw_rect(Rect2(screen_pos, screen_size), color, false, 2.0)
		
		# Draw label (only if big enough)
		if size.x * tile_size > 20 and size.y * tile_size > 10:
			var label_pos = screen_pos + Vector2(2, font_size)
			control.draw_string(font, label_pos, type_name, HORIZONTAL_ALIGNMENT_LEFT, 
								-1, font_size, Color.WHITE)

func draw_legend(control: Control, start_pos: Vector2):
	var font = get_theme_default_font()
	var font_size = 16
	var line_height = 20
	var y = start_pos.y
	
	var legend_items = [
		[Color.GREEN, "Dry Ground"],
		[Color.BROWN, "Rocky Ground"], 
		[Color.BLACK, "Dug Tunnels"],
		[Color.WHITE, "Player"],
		[Color.RED, "Enemies"],
		[Color.BLUE, "NPCs"],
		[Color.DARK_GRAY, "---"],  # Separator
		[Color.GREEN, "Rooms"],
		[Color.CYAN, "Tunnels"],
		[Color.YELLOW, "Chambers"],
		[Color.MAGENTA, "L-Corridors"]
	]
	
	for item in legend_items:
		var color = item[0]
		var text = item[1]
		
		if text == "---":
			y += line_height / 2
			continue
		
		control.draw_rect(Rect2(start_pos.x, y - 8, 12, 12), color)
		control.draw_string(font, Vector2(start_pos.x + 20, y), text, 
							HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
		y += line_height
	
	# Add toggle hint at bottom
	y += 10
	var status_text = "Structures: " + ("ON" if show_structures else "OFF") + " (Press S)"
	control.draw_string(font, Vector2(start_pos.x, y), status_text, 
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GRAY)

func draw_entities(control: Control, start: Vector2):
	"""Draw player, enemies, and NPCs"""
	
	var viewport_start = tile_batches.get("viewport_start", Vector2i.ZERO)
	
	# Draw player
	var player_grid = environment.get_player_grid_position()
	var relative_player_pos = player_grid - viewport_start
	var player_screen_pos = start + Vector2(relative_player_pos.x * tile_size, relative_player_pos.y * tile_size)
	var player_size = Vector2(tile_size, tile_size)
	
	# Make player slightly larger for visibility
	if tile_size >= 2:
		player_size = Vector2(tile_size + 1, tile_size + 1)
		player_screen_pos -= Vector2(0.5, 0.5)
	
	var player_rect = Rect2(player_screen_pos, player_size)
	control.draw_rect(player_rect, player_color, true)
	control.draw_rect(player_rect, Color.BLACK, false, 1.0)
	
	# Draw enemies (only if visible in viewport)
	if environment.entity_manager and environment.entity_manager.enemies:
		for enemy in environment.entity_manager.enemies:
			var enemy_grid = enemy.get_grid_position()
			if not is_position_fogged(enemy_grid) and is_in_viewport(enemy_grid, viewport_start):
				var relative_enemy_pos = enemy_grid - viewport_start
				var enemy_screen_pos = start + Vector2(relative_enemy_pos.x * tile_size, relative_enemy_pos.y * tile_size)
				var enemy_rect = Rect2(enemy_screen_pos, Vector2(tile_size, tile_size))
				control.draw_rect(enemy_rect, enemy_color)
	
	# Draw NPCs (only if visible in viewport)
	if environment.entity_manager and environment.entity_manager.npcs:
		for npc in environment.entity_manager.npcs:
			var npc_grid = npc.get_grid_position()
			if not is_position_fogged(npc_grid) and is_in_viewport(npc_grid, viewport_start):
				var relative_npc_pos = npc_grid - viewport_start
				var npc_screen_pos = start + Vector2(relative_npc_pos.x * tile_size, relative_npc_pos.y * tile_size)
				var npc_rect = Rect2(npc_screen_pos, Vector2(tile_size, tile_size))
				control.draw_rect(npc_rect, npc_color)

func is_position_fogged(pos: Vector2i) -> bool:
	if not environment.fog_of_war:
		return false
	
	return not environment.fog_of_war.is_tile_visible(pos.x, pos.y)

func is_in_viewport(pos: Vector2i, viewport_start: Vector2i) -> bool:
	"""Check if a position is within the current viewport"""
	var relative_pos = pos - viewport_start
	return (relative_pos.x >= 0 and relative_pos.x < viewport_tiles.x and
			relative_pos.y >= 0 and relative_pos.y < viewport_tiles.y)

func mark_map_dirty():
	"""Call this when tiles change (player digs)"""
	map_dirty = true
	if visible:
		update_tile_batches()
		if map_display:
			map_display.queue_redraw()
