extends Node2D

func _on_Obstacles_body_entered(body):
	if body.name == "Player":
		get_tree().reload_current_scene()

func _on_Goal_body_entered(body):
	if body.name == "Player":
		$UI/LabelVictory.show()
		get_tree().paused = true
