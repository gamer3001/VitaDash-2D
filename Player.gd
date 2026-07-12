extends KinematicBody2D

export var gravity = 1000
export var speed = 400
export var jump_force = -700
export var dash_speed = 800
export var dash_duration = 0.15
export var wall_slide_speed = 120
export var wall_jump_push = 450
export var wall_jump_up = -650
export var wall_jump_lock_duration = 0.15

# Endurance d'accrochage au mur
export var wall_stamina_max = 100.0
export var wall_stamina_drain_rate = 45.0     # perdue par seconde pendant l'accrochage
export var wall_stamina_regen_rate = 55.0     # regagnée par seconde au sol (progressif)
export var weak_jump_multiplier = 0.6         # pénalité de hauteur de saut quand la barre est vide

var velocity = Vector2.ZERO
var can_dash = true
var is_dashing = false
var last_dir = 1
var is_wall_sliding = false
var wall_jump_lock_timer = 0.0
var wall_stamina = wall_stamina_max
var last_wall_dir = 0.0  # direction "vers l'extérieur" du dernier mur touché (cache car is_on_wall() est fragile sans mouvement)

onready var coyote_timer = $CoyoteTimer
onready var jump_buffer_timer = $JumpBufferTimer
onready var dash_timer = $DashTimer
onready var ghost_timer = $DashGhostTimer

var stamina_bar_bg
var stamina_bar_fill
const STAMINA_BAR_WIDTH = 28.0

func _ready():
	# Connexion explicite des signaux pour garantir le fonctionnement
	if not dash_timer.is_connected("timeout", self, "_on_DashTimer_timeout"):
		dash_timer.connect("timeout", self, "_on_DashTimer_timeout")
	if not ghost_timer.is_connected("timeout", self, "_on_DashGhostTimer_timeout"):
		ghost_timer.connect("timeout", self, "_on_DashGhostTimer_timeout")

	# Configuration des timers
	dash_timer.one_shot = true
	ghost_timer.one_shot = false

	setup_stamina_bar()

func setup_stamina_bar():
	stamina_bar_bg = ColorRect.new()
	stamina_bar_bg.rect_size = Vector2(STAMINA_BAR_WIDTH, 5)
	stamina_bar_bg.rect_position = Vector2(-STAMINA_BAR_WIDTH / 2, -34)
	stamina_bar_bg.color = Color(0, 0, 0, 0.5)
	stamina_bar_bg.visible = false
	add_child(stamina_bar_bg)

	stamina_bar_fill = ColorRect.new()
	stamina_bar_fill.rect_size = Vector2(STAMINA_BAR_WIDTH, 5)
	stamina_bar_fill.rect_position = Vector2(-STAMINA_BAR_WIDTH / 2, -34)
	stamina_bar_fill.color = Color(0.3, 0.9, 0.4, 1)
	stamina_bar_fill.visible = false
	add_child(stamina_bar_fill)

func get_current_wall_normal():
	# Godot 3.5 n'a pas de get_wall_normal() (ça, c'est du Godot 4) :
	# on retrouve la normale du mur via les collisions du dernier move_and_slide.
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if abs(collision.normal.x) > 0.5:
			return collision.normal
	return Vector2.ZERO

func update_stamina_bar():
	var ratio = wall_stamina / wall_stamina_max
	var is_full = ratio >= 1.0
	stamina_bar_bg.visible = not is_full
	stamina_bar_fill.visible = not is_full
	stamina_bar_fill.rect_size.x = STAMINA_BAR_WIDTH * ratio

	if wall_stamina <= 0.0:
		stamina_bar_fill.color = Color(0.9, 0.2, 0.2, 1)
	elif ratio < 0.35:
		stamina_bar_fill.color = Color(0.9, 0.6, 0.2, 1)
	else:
		stamina_bar_fill.color = Color(0.3, 0.9, 0.4, 1)

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

	# Un mur n'est considéré "accrochable" que si on est en l'air
	var on_wall_now = is_on_wall() and not is_on_floor()
	is_wall_sliding = false

	if on_wall_now:
		last_wall_dir = get_current_wall_normal().x
	elif is_on_floor():
		last_wall_dir = 0.0

	# Si la barre d'endurance est vide, impossible de s'accrocher et le saut est affaibli
	var stamina_exhausted = wall_stamina <= 0.0
	var can_cling = on_wall_now and not stamina_exhausted
	var current_jump_force = jump_force
	var current_wall_jump_up = wall_jump_up
	if stamina_exhausted:
		current_jump_force = jump_force * weak_jump_multiplier
		current_wall_jump_up = wall_jump_up * weak_jump_multiplier

	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta
	elif can_cling and move_input == 0 and last_wall_dir != 0.0:
		# Sans ça, dès que la vitesse horizontale retombe à 0, move_and_slide ne re-détecte
		# plus le mur (is_on_wall() redevient faux) et le personnage décroche tout seul.
		# On maintient donc une légère pression vers le mur pour rester accroché sans avoir à tenir une direction.
		velocity.x = -sign(last_wall_dir) * 20
	else:
		velocity.x = move_input * speed

	if can_cling and Input.is_action_just_pressed("ui_accept"):
		# Wall jump : on repousse le joueur à l'opposé du mur
		var wall_dir = last_wall_dir
		velocity.x = sign(wall_dir) * wall_jump_push
		velocity.y = current_wall_jump_up
		wall_jump_lock_timer = wall_jump_lock_duration
		can_dash = true
		jump_buffer_timer.stop()
		coyote_timer.stop()
	else:
		velocity.y += gravity * delta

		# Wall slide/cling : dès qu'on touche un mur en l'air (et qu'on a de l'endurance), on s'accroche et on ralentit la chute
		if can_cling and velocity.y > 0:
			velocity.y = min(velocity.y, wall_slide_speed)
			is_wall_sliding = true
			can_dash = true
			wall_stamina = max(0.0, wall_stamina - wall_stamina_drain_rate * delta)

		if is_on_floor():
			coyote_timer.start()
			# La barre d'endurance ne se recharge que progressivement, au sol
			wall_stamina = min(wall_stamina_max, wall_stamina + wall_stamina_regen_rate * delta)

		if Input.is_action_just_pressed("ui_accept"):
			jump_buffer_timer.start()

		if not jump_buffer_timer.is_stopped() and not coyote_timer.is_stopped():
			velocity.y = current_jump_force
			jump_buffer_timer.stop()
			coyote_timer.stop()

		if Input.is_action_just_released("ui_accept") and velocity.y < 0:
			velocity.y *= 0.5

	velocity = move_and_slide(velocity, Vector2.UP)
	update_stamina_bar()

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
