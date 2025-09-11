# Your main game scene script (the one that extends Node2D)
extends Node2D

var environment: GameEnviroment
var player: Player
var camera: Camera2D

func _ready() -> void:
	setup_game()

func _process(delta: float) -> void:
	if EncounterManager and EncounterManager.is_in_battle:
		return
		
	if player and camera:
		var target_pos = player.position + Vector2(environment.SIZE/2, environment.SIZE/2)
		
		var viewport_size = get_viewport().get_visible_rect().size
		var half_viewport = viewport_size / 2
		
		target_pos.x = max(target_pos.x, half_viewport.x)
		target_pos.y = max(target_pos.y, half_viewport.y)
		
		var env_width = environment.WIDTH * environment.SIZE
		var env_height = environment.HEIGHT * environment.SIZE
		target_pos.x = min(target_pos.x, env_width - half_viewport.x)
		target_pos.y = min(target_pos.y, env_height - half_viewport.y)
		
		camera.position = camera.position.lerp(target_pos, 0.1)

func setup_game():
	# Create environment first
	environment = GameEnviroment.new()
	environment.position = Vector2.ZERO
	add_child(environment)
	
	# Create player and give it the environment reference
	player = Player.new()
	player.environment = environment  # <- This is the key fix!
	add_child(player)
	
	setup_camera()

func setup_camera():
	camera = Camera2D.new()
	add_child(camera)
	
	camera.enabled = true
	
	var env_width = environment.WIDTH * environment.SIZE
	var env_height = environment.HEIGHT * environment.SIZE
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = max(env_width, viewport_size.x)
	camera.limit_bottom = max(env_height, viewport_size.y)
