extends Node2D

var next_spawn_y = 400
var started = false

onready var player = $Player
onready var camera = $Camera2D
onready var score_label = $UI/LabelScore
onready var timer_label = $UI/LabelTimer

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
	score_label.text = "Hauteur: %d" % [max(0, -player.position.y + 400)]

func spawn_chunk(vertical_offset = 0):
	var platform = StaticBody2D.new()
	# Espace horizontal plus restreint pour rester atteignable
	platform.position = Vector2(rand_range(200, 760), next_spawn_y - vertical_offset)
	add_child(platform)
	
	var rect = ColorRect.new()
	rect.rect_size = Vector2(120, 20)
	rect.rect_position = Vector2(-60, -10)
	rect.color = Color(0.4, 0.4, 0.4, 1)
	platform.add_child(rect)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(60, 10)
	col.shape = shape
	platform.add_child(col)
	
	# Espace vertical entre les nouveaux segments
	next_spawn_y -= 100
