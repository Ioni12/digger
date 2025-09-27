# EventSystem.gd
extends Node
class_name EventSystem

var environment: GameEnviroment

func initialize(env: GameEnviroment):
	environment = env

func trigger_initial_npc_spawn():
	await get_tree().create_timer(0.5).timeout
	spawn_guide_near_player()

func spawn_guide_near_player():
	var npc = spawn_npc_near_player_in_tunnel(WorldNPC.NPCType.NEIGHBOUR, 5, 11)
	if npc:
		print("Initial guide spawned near player!")
		show_initial_npc_popup()
	else:
		print("Could not spawn initial NPC - no suitable tunnels found")

func spawn_npc_near_player_in_tunnel(npc_type: WorldNPC.NPCType, min_distance: int = 5, max_distance: int = 15) -> WorldNPC:
	var player_grid = Vector2i(environment.WIDTH/2, 0)
	var valid_positions = []
	
	for x in range(environment.WIDTH):
		for y in range(environment.HEIGHT):
			var distance = player_grid.distance_to(Vector2i(x, y))
			
			if distance >= min_distance and distance <= max_distance:
				if environment.grid_data[y][x] == environment.TileType.DIGGED:
					if is_position_free_for_npc(x, y):
						valid_positions.append(Vector2i(x, y))
	
	if valid_positions.size() > 0:
		var spawn_pos = valid_positions[randi() % valid_positions.size()]
		return environment.spawn_npc(spawn_pos.x, spawn_pos.y, npc_type)
	
	return null

func is_position_free_for_npc(x: int, y: int) -> bool:
	for npc in environment.npcs:
		var npc_pos = npc.get_grid_position()
		if npc_pos.x == x and npc_pos.y == y:
			return false
	
	for enemy in environment.enemies:
		var enemy_pos = enemy.get_grid_position()
		if enemy_pos.x == x and enemy_pos.y == y:
			return false
	
	return true

func show_initial_npc_popup():
	var popup_scene = preload("res://ResourcePopup.tscn")
	var popup = popup_scene.instantiate()
	get_tree().current_scene.add_child(popup)
	
	var player_pos = Vector2((environment.WIDTH/2) * environment.SIZE, 0 * environment.SIZE)
	popup.show_text("A guide has appeared in the tunnels nearby!", Color.GREEN, player_pos + Vector2(0, -50))
