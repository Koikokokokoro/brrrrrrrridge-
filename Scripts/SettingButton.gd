# 感觉相对来说太简陋了点
extends Button

# 预加载 SettingsOverlay 场景
@export var overlay_scene_file: PackedScene = preload("res://Scenes/SettingsOverlay.tscn")

# 动画时长
const ANIM_DURATION: float = 0.35

# 内部状态
var _overlay_instance: Control = null
var _locked: bool = false

func _ready():
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed():
	_open_overlay()

func _open_overlay():
	if _locked:
		return
	_locked = true

	# 如果已经有实例，直接显示（可选动画）
	if _overlay_instance != null:
		_slide_in_overlay(_overlay_instance)
		_locked = false
		return

	# 实例化 overlay
	var inst: Node = overlay_scene_file.instantiate()
	if not inst is Control:
		push_error("SettingsOverlay must be a Control node!")
		_locked = false
		return
	_overlay_instance = inst as Control

	# 挂载到顶层
	get_tree().root.add_child(_overlay_instance)

	# 填满屏幕
	var c := _overlay_instance
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.position = Vector2(0, 0) # 先置 0，下面再调整动画起点

	# 确保布局完成
	await get_tree().process_frame

	# 初始位置：屏幕下方
	var screen_size = get_viewport().get_visible_rect().size
	c.position = Vector2(0, screen_size.y)

	# 播放滑入动画
	_slide_in_overlay(c)

	_locked = false

# 滑入动画（从下到正常位置）
func _slide_in_overlay(c: Control):
	var tween := get_tree().create_tween()
	tween.tween_property(c, "position", Vector2(0, 0), ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# 滑出动画（向上飞出）
func slide_out_overlay():
	if _overlay_instance == null:
		return
	var c := _overlay_instance
	var screen_size = get_viewport().get_visible_rect().size
	var tween := get_tree().create_tween()
	tween.tween_property(c, "position", Vector2(0, -screen_size.y), ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.connect("finished", Callable(self, "_on_overlay_closed"))

func _on_overlay_closed():
	if _overlay_instance != null:
		_overlay_instance.queue_free()
		_overlay_instance = null
