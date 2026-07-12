extends Node2D

# Hauteur (en pixels) à partir de laquelle le ciel a fini sa transition
# complète (jour -> coucher de soleil -> espace). Avant, l'espace
# arrivait dès 5000 ; on le repousse ici 3x plus loin.
const SKY_TRANSITION_HEIGHT = 15000.0

var next_spawn_y = 400
var started = false

onready var player = $Player
onready var camera = $Camera2D
onready var score_label = $UI/LabelScore
onready var timer_label = $UI/LabelTimer
onready var sky_color = $BackgroundLayer/SkyColor
onready var sky_gradient = SkyGradient.build_gradient()
# stars_texture supprimé car le nœud n'existe pas

var time_elapsed = 0.0

func _ready():
	# Génère les premières plateformes beaucoup plus proches
	for i in range(10):
		spawn_chunk(i * 100) # Espacement réduit à 100 pixels

func _process(delta):
	if started:
		time_elapsed += delta
		update_ui()
	
	if not started and player.velocity.y < 0:
		started = true
	
	if player.position.y < next_spawn_y + 800:
		spawn_chunk(0)

func update_ui():
	timer_label.text = "Temps: %02d:%02d" % [int(time_elapsed / 60), int(fmod(time_elapsed, 60))]
	var height = int(max(0, -player.position.y + 400))
	score_label.text = "Hauteur: %d" % height
	
	# Transition du ciel : jour -> coucher de soleil -> espace
	var progress = clamp(float(height) / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
	sky_color.color = SkyGradient.get_sky_color(sky_gradient, progress)
	$BackgroundLayer/StarsParticles.modulate.a = SkyGradient.get_stars_alpha(progress)

func spawn_chunk(vertical_offset = 0):
	# Chance de générer un mur au lieu d'une plateforme
	var is_wall = randf() < 0.3 # 30% de chance d'avoir un mur
	
	var platform = StaticBody2D.new()
	var side = 0
	if is_wall:
		# Positionner sur les côtés
		side = 100 if randf() < 0.5 else 860
		platform.position = Vector2(side, next_spawn_y - vertical_offset)
	else:
		platform.position = Vector2(rand_range(200, 760), next_spawn_y - vertical_offset)
	add_child(platform)
	
	var rect = ColorRect.new()
	if is_wall:
		rect.rect_size = Vector2(20, 150)
		rect.rect_position = Vector2(-10, -75)
		rect.color = Color(0.6, 0.3, 0.3, 1) # Couleur différente pour les murs
	else:
		rect.rect_size = Vector2(120, 20)
		rect.rect_position = Vector2(-60, -10)
		rect.color = Color(0.4, 0.4, 0.4, 1)
	platform.add_child(rect)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	if is_wall:
		shape.extents = Vector2(10, 75)
	else:
		shape.extents = Vector2(60, 10)
	col.shape = shape
	platform.add_child(col)
	
	# Génération de plateforme à proximité pour le wall-jump
	if is_wall:
		var jump_platform = StaticBody2D.new()
		# Positionner la plateforme à une distance sautable (ex: 150px)
		var platform_x = (rand_range(200, 350) if side > 480 else rand_range(610, 760))
		jump_platform.position = Vector2(platform_x, next_spawn_y - vertical_offset + 50)
		add_child(jump_platform)
		
		var j_rect = ColorRect.new()
		j_rect.rect_size = Vector2(100, 15)
		j_rect.rect_position = Vector2(-50, -7)
		j_rect.color = Color(0.4, 0.4, 0.4, 1)
		jump_platform.add_child(j_rect)
		
		var j_col = CollisionShape2D.new()
		var j_shape = RectangleShape2D.new()
		j_shape.extents = Vector2(50, 7)
		j_col.shape = j_shape
		jump_platform.add_child(j_col)
	
	next_spawn_y -= 100
