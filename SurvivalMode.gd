extends Node2D

var next_spawn_y = 400
var started = false
var base_speed = 50.0
var lava_speed = 50.0

onready var player = $Player
onready var lava = $Lava
onready var sky_color = $BackgroundLayer/SkyColor
onready var score_label = $UI/LabelScore
onready var timer_label = $UI/LabelTimer
onready var anim_label = $UI/LabelEpic

var time_elapsed = 0.0
var last_milestone = 0

func _ready():
	for i in range(10):
		spawn_chunk(i * 100)
	lava.connect("body_entered", self, "_on_Lava_body_entered")
	anim_label.hide()

func _process(delta):
	if started:
		time_elapsed += delta
		lava.position.y -= lava_speed * delta
		update_ui()
	
	if not started and player.velocity.y < 0:
		started = true
	
	if player.position.y < next_spawn_y + 800:
		spawn_chunk(0)

func update_ui():
	timer_label.text = "Temps: %02d:%02d" % [int(time_elapsed / 60), int(fmod(time_elapsed, 60))]
	var height = int(max(0, -player.position.y + 400))
	score_label.text = "Hauteur: %d" % height
	
	# Transition du ciel vers l'espace
	var progress = clamp(float(height) / 5000.0, 0.0, 1.0)
	sky_color.color = Color(0.2, 0.5, 0.9).linear_interpolate(Color(0.0, 0.0, 0.05), progress)
	$BackgroundLayer/StarsParticles.modulate.a = progress
	
	lava_speed = base_speed + (height / 1000) * 10
	
	var current_milestone = (height / 1000) * 1000
	if current_milestone > 0 and current_milestone > last_milestone:
		last_milestone = current_milestone
		show_epic_milestone(current_milestone)

func show_epic_milestone(dist):
	anim_label.text = str(dist) + " M !"
	anim_label.show()
	var tween = Tween.new()
	add_child(tween)
	anim_label.rect_scale = Vector2(0.5, 0.5)
	tween.interpolate_property(anim_label, "rect_scale", Vector2(0.5, 0.5), Vector2(2, 2), 0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	tween.interpolate_property(anim_label, "modulate:a", 1.0, 0.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.0)
	tween.start()
	tween.connect("tween_all_completed", anim_label, "hide", [], 4)

func _on_Lava_body_entered(body):
	if body.name == "Player":
		get_tree().reload_current_scene()

func spawn_chunk(vertical_offset = 0):
	var platform = StaticBody2D.new()
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
	next_spawn_y -= 100
