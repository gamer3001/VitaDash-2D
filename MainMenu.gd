extends Control

func _on_Campaign_pressed():
    get_tree().change_scene("res://World.tscn")

func _on_Infinite_pressed():
    # On pourrait charger une scène spécifique pour l'infini ou recharger World avec un flag
    get_tree().change_scene("res://InfiniteMode.tscn")
