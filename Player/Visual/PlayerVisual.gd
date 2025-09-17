# PlayerVisual.gd
extends Node
class_name PlayerVisual

var environment: GameEnviroment
var player_stats: PlayerStats
var stamina_system: StaminaSystem
var movement: PlayerMovement
var player_sprite: Sprite2D

# Colors
var normal_color: Color = Color.BLUE
var digging_color: Color = Color.RED

func _ready():
	# Get references to other components
	player_stats = get_parent().get_node("PlayerStats") if get_parent().has_node("PlayerStats") else null
	stamina_system = get_parent().get_node("StaminaSystem") if get_parent().has_node("StaminaSystem") else null
	movement = get_parent().get_node("PlayerMovement") if get_parent().has_node("PlayerMovement") else null
	
	# Wait a frame to ensure environment is set
	call_deferred("setup_player_sprite")

func setup_player_sprite():
	"""Create and setup the player sprite"""
	if not environment:
		print("Environment not ready for sprite setup")
		return
	
	player_sprite = Sprite2D.new()
	get_parent().add_child(player_sprite)
	
	var image = Image.create(environment.SIZE - 4, environment.SIZE - 4, false, Image.FORMAT_RGBA8)
	image.fill(normal_color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	player_sprite.texture = texture
	
	player_sprite.position = Vector2(environment.SIZE / 2, environment.SIZE / 2)

func _process(_delta: float):
	"""Update visual state based on current conditions"""
	if not player_sprite or not environment:
		return
		
	update_player_color_based_on_state()

func update_player_color_based_on_state():
	"""Update player color based on current state and stamina level"""
	var color_to_use: Color
	
	if movement and movement.current_state == movement.PlayerState.DIGGING:
		color_to_use = digging_color
	elif stamina_system:
		color_to_use = stamina_system.get_stamina_color()
	else:
		color_to_use = normal_color
	
	change_player_color(color_to_use)

func change_player_color(color: Color):
	"""Change the player sprite color"""
	if not player_sprite or not environment:
		return
	
	var image = Image.create(environment.SIZE - 4, environment.SIZE - 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	player_sprite.texture = texture

func apply_digging_effect(bob_offset: float):
	"""Apply visual digging effect (bobbing/shaking)"""
	if not player_sprite or not environment:
		return
		
	player_sprite.position.y = (environment.SIZE / 2) + bob_offset

func reset_digging_effect():
	"""Reset visual effects after digging"""
	if not player_sprite or not environment:
		return
		
	player_sprite.position.y = environment.SIZE / 2

func set_environment(env: GameEnviroment):
	"""Set environment reference"""
	environment = env
	if player_sprite:
		setup_player_sprite()
	else:
		call_deferred("setup_player_sprite")
