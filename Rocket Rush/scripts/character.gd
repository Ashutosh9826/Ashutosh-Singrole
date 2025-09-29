extends CharacterBody2D

@export var thrust_force: float = 950.0 # Force to push the rocket forward
@export var rotation_speed: float = 2.3 # Speed at which the rocket rotates in radians per second
@export var gravity: float = 500.0 # Constant downward pull of gravity (acceleration)
@export var drag: float = 0.03 # Reduced air resistance to allow for more acceleration
@export var friction: float = 0.5 # Reduced horizontal friction
@export var boost_multiplier: float = 2.5 # How much to multiply the thrust force by when boosting
@export var boost_duration: float = 10.0 # How long the boost lasts in seconds
@export var boost_cooldown: float = 40.0 # How long the boost takes to recharge

# Get references to the AudioStreamPlayer2D nodes in the scene tree
# Make sure the nodes are named "thrust", "left_jet", and "right_jet"
@onready var thrust_sound = $thrust
@onready var left_jet_sound = $left_jet
@onready var right_jet_sound = $right_jet
@onready var timer_label = $"../CanvasLayer/TimerLabel"
@onready var boost_bar = $"../CanvasLayer/BoostProgressBar"
@onready var pause_screen = $"../CanvasLayer/TextureRect2" # New: Reference to the pause screen element

# Get references to the flame Sprite2D nodes
# Make sure the nodes are named "flame_r" and "flame_l"
@onready var flame_r = $flame_r
@onready var flame_l = $flame_l

var total_game_time = 0.0
var next_checkpoint_index = 1
var is_on_wall = false
var time_on_wall = 0.0
var last_penalty_level = 0
var current_thrust_force = 0.0
var base_rotation_speed = 0.0
var game_started = false

var is_boosting = false
var boost_timer = 0.0
var boost_cooldown_timer = 0.0

var base_gravity = 0.0
var base_drag = 0.0
var base_friction = 0.0

func _ready() -> void:
	# CRITICAL FIX: Ensure the rocket processes input even when the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialize base values from the exported properties
	current_thrust_force = thrust_force
	base_rotation_speed = rotation_speed
	base_gravity = gravity
	base_drag = drag
	base_friction = friction
	
	# Initial score adjustment
	total_game_time -= 9.0
	
	# Setup Boost Bar initial values
	if boost_bar:
		boost_bar.max_value = boost_cooldown
		boost_bar.value = boost_cooldown
	
	# Hide the pause screen (TextureRect2) initially
	if pause_screen:
		pause_screen.hide()
		# Ensure the pause screen node itself is set to process input (it doesn't hurt)
		pause_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		
	# Start the game (after a slight delay to prevent instant wall collision penalty)
	await get_tree().create_timer(0.1).timeout
	game_started = true

# --- Pause Input Handling (Now uses _input for better pause handling) ---
func _input(event: InputEvent) -> void:
	# Check for the custom "pause" action (which you must map to 'P' key)
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


# --- Pause Toggle Function ---
func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	
	if pause_screen:
		pause_screen.visible = get_tree().paused


func _physics_process(delta: float) -> void:
	# CRITICAL FIX: Exit the function immediately if the game is paused.
	if get_tree().paused: 
		return

	# Keep the game timer running
	total_game_time += delta
	if timer_label:
		timer_label.text = "Time: " + ("%.2f" % total_game_time)

	# --- Handle Boost and Cooldown ---
	if is_boosting:
		boost_timer += delta
		rotation_speed = base_rotation_speed * 1.5
		gravity = base_gravity / 2.0
		drag = base_drag / 2.0
		friction = base_friction / 2.0
		boost_bar.max_value = boost_duration
		boost_bar.value = boost_duration - boost_timer
		if boost_timer >= boost_duration:
			is_boosting = false
			boost_timer = 0.0
			current_thrust_force = thrust_force
			rotation_speed = base_rotation_speed
			gravity = base_gravity
			drag = base_drag
			friction = base_friction
			boost_cooldown_timer = 0.0
			boost_bar.max_value = boost_cooldown
	else:
		if boost_cooldown_timer < boost_cooldown:
			boost_cooldown_timer += delta
		boost_bar.value = boost_cooldown_timer

	if Input.is_action_just_pressed("boost") and boost_cooldown_timer >= boost_cooldown:
		is_boosting = true
	
	# Check if the rocket is on the wall and apply penalty
	if is_on_wall and game_started:
		time_on_wall += delta
		var current_penalty_level = floor(time_on_wall)
		if current_penalty_level > last_penalty_level:
			total_game_time += current_penalty_level
			last_penalty_level = current_penalty_level
			print("Penalty added: ", current_penalty_level)

	# --- 1. Handle Rotation ---
	# Calculate the rotation based on jet input
	var rotation_direction = 0
	if Input.is_action_pressed("move_left"):
		rotation_direction += 1 # Right jet fires, turn left
	if Input.is_action_pressed("move_right"):
		rotation_direction -= 1 # Left jet fires, turn right

	# Apply the rotation
	rotation += rotation_direction * rotation_speed * delta

	# --- 2. Handle Sound and Thrust ---
	var is_main_thrusting = Input.is_action_pressed("move_forward")
	var is_left_jet_firing = Input.is_action_pressed("move_left")
	var is_right_jet_firing = Input.is_action_pressed("move_right")

	var is_any_thrusting = is_main_thrusting or (is_left_jet_firing and is_right_jet_firing)

	if is_any_thrusting:
		if is_boosting:
			current_thrust_force = thrust_force * boost_multiplier
		else:
			current_thrust_force = thrust_force
	else:
		current_thrust_force = 0.0

	# Play/stop the main thrust sound
	if is_any_thrusting and not thrust_sound.playing:
		thrust_sound.play()
	elif not is_any_thrusting and thrust_sound.playing:
		thrust_sound.stop()
		
	# Play/stop the left jet sound only if the main thrust isn't on
	if is_left_jet_firing and not is_any_thrusting and not left_jet_sound.playing:
		left_jet_sound.play()
	elif not is_left_jet_firing and left_jet_sound.playing:
		left_jet_sound.stop()
		
	# Play/stop the right jet sound only if the main thrust isn't on
	if is_right_jet_firing and not is_any_thrusting and not right_jet_sound.playing:
		right_jet_sound.play()
	elif not is_right_jet_firing and right_jet_sound.playing:
		right_jet_sound.stop()
		
	# --- 3. Handle Flame Visibility ---
	flame_l.visible = is_any_thrusting or is_left_jet_firing
	flame_r.visible = is_any_thrusting or is_right_jet_firing

	# --- 4. Calculate Net Acceleration from All Forces ---
	# Start with a base acceleration from gravity
	var acceleration = Vector2(0, gravity)
	
	# Add thrust force to the acceleration if thrusting
	if is_any_thrusting or is_boosting:
		var thrust_vector = Vector2.UP.rotated(rotation) * current_thrust_force
		acceleration += thrust_vector

	# Apply drag and friction as forces that oppose motion.
	acceleration -= velocity * drag
	acceleration.x -= velocity.x * friction

	# --- 5. Update Velocity and Move ---
	# Finally, apply the net acceleration to the rocket's velocity.
	velocity += acceleration * delta

	# Move the rocket based on the calculated velocity
	move_and_slide()

# --- 6. Handle Collision with Tilemap ---
func _on_body_entered(body):
	if body is TileMap and game_started:
		is_on_wall = true
		time_on_wall = 0.0
		last_penalty_level = 0
		total_game_time += 1.0
		print("Immediate penalty: 1")
		
func _on_body_exited(body):
	if body is TileMap:
		is_on_wall = false

# --- 7. Handle Checkpoint Collision ---
func _on_checkpoint_collected(checkpoint_index_collided, is_last_checkpoint, checkpoint_node):
	# Check if the collected checkpoint is the one we are looking for
	if checkpoint_index_collided == next_checkpoint_index:
		# Hide the checkpoint
		checkpoint_node.hide()
		
		# Move to the next checkpoint
		next_checkpoint_index += 1

		# Check if the last checkpoint has been collected.
		if is_last_checkpoint:
			# Save the final time to the GameState singleton and go to the kill screen.
			GameState.final_time = total_game_time
			get_tree().change_scene_to_file("res://scenes/kill_screen_scene.tscn")
