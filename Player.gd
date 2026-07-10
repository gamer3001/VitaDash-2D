extends KinematicBody2D

export var gravity = 1200
export var speed = 400
export var jump_force = -700
export var dash_speed = 800
export var dash_duration = 0.15
export var wall_slide_gravity = 200
export var wall_slide_acceleration = 2
export var wall_jump_force = Vector2(500, -600)

var velocity = Vector2.ZERO
var can_dash = true
var is_dashing = false
var is_wall_sliding = false
var last_dir = 1 
var wall_slide_timer = 0.0
var wall_jump_cooldown = 0.0

onready var coyote_timer = $CoyoteTimer
onready var jump_buffer_timer = $JumpBufferTimer
onready var dash_timer = $DashTimer
onready var ghost_timer = $DashGhostTimer

func _ready():
	# Connexion explicite des signaux pour garantir le fonctionnement
	if not dash_timer.is_connected("timeout", self, "_on_DashTimer_timeout"):
		dash_timer.connect("timeout", self, "_on_DashTimer_timeout")
	if not ghost_timer.is_connected("timeout", self, "_on_DashGhostTimer_timeout"):
		ghost_timer.connect("timeout", self, "_on_DashGhostTimer_timeout")
	
	# Configuration des timers
	dash_timer.one_shot = true
	ghost_timer.one_shot = false 

func _physics_process(delta):
	if is_dashing:
		move_and_slide(velocity, Vector2.UP)
		return

	var move_input = Input.get_axis("ui_left", "ui_right")
	if move_input != 0:
		last_dir = move_input

	if Input.is_action_just_pressed("dash") and can_dash:
		start_dash(last_dir)
		return

	velocity.x = move_input * speed
	
	if wall_jump_cooldown > 0:
		wall_jump_cooldown -= delta
	
	# Wall Slide Logic
	if wall_jump_cooldown <= 0 and is_on_wall() and not is_on_floor() and move_input != 0:
		is_wall_sliding = true
		wall_slide_timer += delta
		
		if wall_slide_timer > 1.0:
			velocity.y += wall_slide_gravity * (1 + (wall_slide_timer - 1.0) * wall_slide_acceleration) * delta
		else:
			velocity.y = 0
			
		# Wall Jump
		if Input.is_action_just_pressed("ui_accept"):
			# On utilise le dernier vecteur de mouvement ou la direction de slide pour déterminer le saut
			var jump_dir = -last_dir # Inverse de la direction où on glissait
			velocity = Vector2(jump_dir * wall_jump_force.x, wall_jump_force.y)
			is_wall_sliding = false
			wall_slide_timer = 0.0
			wall_jump_cooldown = 0.2
	else:
		is_wall_sliding = false
		wall_slide_timer = 0.0
		velocity.y += gravity * delta
	
	if is_on_floor():
		coyote_timer.start()
	
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer.start()
		
	if not jump_buffer_timer.is_stopped() and not coyote_timer.is_stopped():
		velocity.y = jump_force
		jump_buffer_timer.stop()
		coyote_timer.stop()
		
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= 0.5
		
	velocity = move_and_slide(velocity, Vector2.UP)

func start_dash(dir):
	is_dashing = true
	can_dash = false
	velocity = Vector2(dir * dash_speed, 0)
	dash_timer.wait_time = dash_duration
	dash_timer.start()
	ghost_timer.start()

func _on_DashTimer_timeout():
	is_dashing = false
	ghost_timer.stop()
	velocity.x = 0
	# Cooldown via timer dynamique pour éviter tout blocage de flux
	var cooldown = Timer.new()
	cooldown.wait_time = 0.3
	cooldown.one_shot = true
	add_child(cooldown)
	cooldown.start()
	yield(cooldown, "timeout")
	can_dash = true
	cooldown.queue_free()

func _on_DashGhostTimer_timeout():
	spawn_ghost()

func spawn_ghost():
	var ghost = ColorRect.new()
	ghost.rect_size = Vector2(32, 32)
	ghost.rect_position = global_position - Vector2(16, 16)
	ghost.color = Color(0, 0.5, 1, 0.6)
	get_parent().add_child(ghost)
	
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(ghost, "modulate:a", 1.0, 0.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()
	tween.connect("tween_all_completed", ghost, "queue_free", [], 4) # 4 = CONNECT_ONESHOT
