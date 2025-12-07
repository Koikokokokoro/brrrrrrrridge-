extends Control

@onready var score_label: Label = $ScoreLabel
@onready var acc_label: Label = $AccuracyLabel
@onready var note_label: RichTextLabel = $NoteLabel
@onready var combo_label: Label = $ComboLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score_label.text = "分数  %07d" % Global.last_score # 补零格式化
	acc_label.text = "精准度  %.2f%%" % Global.last_accuracy
	combo_label.text = "最大连击数  %d" % Global.max_combo
	
	note_label.bbcode_enabled = true
	var p = Global.last_counts["perfect"]
	var g = Global.last_counts["great"]
	var gd = Global.last_counts["good"]
	var m = Global.last_counts["miss"]
	note_label.text = """
	[table=4]
	[cell]Perfect:[/cell][cell]  %d  [/cell][cell]Great:[/cell][cell]  %d[/cell]\n
	[cell]Good:[/cell][cell]  %d  [/cell][cell] Miss:[/cell][cell]  %d[/cell]
	""" % [p, g, gd, m]
	var content_x = note_label.get_content_width()
	note_label.size.x = content_x * 2


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
