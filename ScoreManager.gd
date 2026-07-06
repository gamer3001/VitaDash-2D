extends Node

var high_score_campaign = 0
var high_score_infinite = 0

const SAVE_PATH = "user://savegame.save"

func _ready():
    load_game()

func save_game():
    var file = File.new()
    file.open(SAVE_PATH, File.WRITE)
    file.store_var(high_score_campaign)
    file.store_var(high_score_infinite)
    file.close()

func load_game():
    var file = File.new()
    if file.file_exists(SAVE_PATH):
        file.open(SAVE_PATH, File.READ)
        high_score_campaign = file.get_var()
        high_score_infinite = file.get_var()
        file.close()
