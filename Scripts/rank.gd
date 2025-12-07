extends TextureRect

@export var rank_textures: Array[Texture2D] = [
	preload("res://Sprites/Rank/A.png"),	#0
	preload("res://Sprites/Rank/AA.png"),
	preload("res://Sprites/Rank/AAA.png"),
	preload("res://Sprites/Rank/B.png"),
	preload("res://Sprites/Rank/BB.png"),
	preload("res://Sprites/Rank/BBB.png"),	#5
	preload("res://Sprites/Rank/C.png"),
	preload("res://Sprites/Rank/D.png"),
	preload("res://Sprites/Rank/S.png"),
	preload("res://Sprites/Rank/Sp.png"),
	preload("res://Sprites/Rank/SS.png"),	#10
	preload("res://Sprites/Rank/SSp.png"),
	preload("res://Sprites/Rank/SSS.png"),
	preload("res://Sprites/Rank/SSSp.png"),
]

func _ready() -> void:
	if Global.last_accuracy >= 90:
		texture = rank_textures[12]
	elif Global.last_accuracy >= 80:
		texture = rank_textures[10]
	elif Global.last_accuracy >= 70:
		texture = rank_textures[8]
	elif Global.last_accuracy >= 60:
		texture = rank_textures[0]	#A
	elif Global.last_accuracy >= 50:
		texture = rank_textures[3]
	elif Global.last_accuracy >= 40:
		texture = rank_textures[6]
	else :
		texture = rank_textures[7]	# D
	
	pass


func _process(_delta: float) -> void:
	pass
