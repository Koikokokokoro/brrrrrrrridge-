extends Node

# 用于在场景之间传递结算数据
var last_score: int = 0
var last_accuracy: float = 0.0
var last_counts: Dictionary = {
	"perfect": 0,
	"great": 0,
	"good": 0,
	"miss": 0
}

var max_combo: int = 0

var speed: float = 6

var selected_song_path: String = ""

# 先写着说不定有用
func reset_data():
	last_score = 0
	last_accuracy = 0.0
	last_counts = {"perfect": 0, "great": 0, "good": 0, "miss": 0}
