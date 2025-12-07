# 更加简陋了
extends Control

@onready var dialog_node_path := "Dialog"
@onready var content_node_path := "Dialog/Content"
@onready var speed_input: LineEdit = $Dialog/Content/HBox_Speed/SpeedInput
@onready var back_button: Button = $Dialog/TopBar/BackButton

# 节点
var dialog: Panel = null
var content: VBoxContainer = null

# 比例配置
const DIALOG_MARGIN_LEFT_RIGHT: float = 0.15
const CONTENT_MARGIN: float = 0.1
const ANIM_TIME := 0.45

# ？
@onready var count_but: Button = $Dialog/Content/debug_click/Button
var count: int = 0

func _ready() -> void:
	# 获取节点
	dialog = get_node_or_null(dialog_node_path) as Panel
	content = get_node_or_null(content_node_path) as VBoxContainer
	
	speed_input.text = "%0.1f" % Global.speed
	speed_input.connect("text_changed", Callable(self, "_on_speed_changed"))

	if dialog == null:
		push_warning("SettingOverlay: 未找到 Dialog 节点。请确认路径 '" + dialog_node_path + "' 是否正确，节点名大小写敏感。当前子节点列表: " + _list_children(get_path()))
		return
	if content == null:
		push_warning("SettingOverlay: 未找到 Content 节点。请确认路径 '" + content_node_path + "'.")
		return

	# 背景半透明
	var bg = get_node_or_null("Background")
	if bg and bg is ColorRect:
		bg.color = Color(0.1, 0.1, 0.1, 0.7)
	
	back_button.pressed.connect(_on_back_pressed)
	
	_update_layout()
	
	# 第一次布局需要等待一帧以保证场景完成添加/布局
	await get_tree().process_frame
	_update_layout()
	
	count_but.pressed.connect(_on_count_pressed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	if dialog == null or content == null:
		# 如果缺节点，仅打印并退出
		return

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		return

	# ========== Dialog 布局 ==========
	# 我们把 Dialog 设为一个固定宽度（屏宽 - 2*margin），垂直居中（高度可选）
	var dialog_w := screen_size.x * (1.0 - 2.0 * DIALOG_MARGIN_LEFT_RIGHT)
	# 如果你想 dialog 垂直占整屏，把下面改为 screen_size.y；这里给一个默认高度（可按需调整）
	var dialog_h := screen_size.y  # 80% 高度，可改为 1.0 表示全高

	# 计算 dialog 的左上位置，使其水平居中并垂直居中
	var dialog_x := (screen_size.x - dialog_w) * 0.5
	var dialog_y := (screen_size.y - dialog_h) * 0.5

	# 直接使用 rect_position / rect_size（避免 anchors/margins 的版本差异）
	dialog.position = Vector2(dialog_x, dialog_y)
	dialog.size = Vector2(dialog_w, dialog_h)

	# ========== Content 布局（相对于 Dialog） ==========
	# Content 在 Dialog 内部左右上下各留 CONTENT_MARGIN 比例
	var inner_left := dialog_w * CONTENT_MARGIN
	var inner_top := dialog_h * CONTENT_MARGIN
	var inner_w := dialog_w * (1.0 - 2.0 * CONTENT_MARGIN)
	var inner_h := dialog_h * (1.0 - 2.0 * CONTENT_MARGIN)

	# content 使用 rect_position / rect_size（相对于其父 Dialog）
	content.position = Vector2(inner_left, inner_top)
	content.size = Vector2(inner_w, inner_h)

	# 如果 content 是 VBoxContainer，我们可以设置其自适应参数（可选）
	# content.set("separation", 16) # 如果你想设置 separation，可以在引擎版本允许下调用

# 列出当前节点的直接子节点名，便于调试路径问题
func _list_children(_base_path: NodePath) -> String:
	var n := get_node_or_null(".")
	if n == null:
		return "（无法列出）"
	var s := ""
	for child in get_children():
		s += str(child.name) + ", "
	return s

func _on_back_pressed():
	_play_exit_animation()


func _play_exit_animation():
	# var vp = get_viewport_rect().size

	# 向上飞出动画
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(dialog, "position:y", -dialog.size.y - 100.0, ANIM_TIME)

	# 动画结束后卸载整个 overlay
	tween.finished.connect(func():
		queue_free()
	)

# 实际书写有点问题
func _on_speed_changed(new_text: String) -> void:
	var v = new_text.to_float()

	# 保留 1 位小数
	Global.speed = round(v * 10.0) / 10.0
	speed_input.text = "%0.1f" % Global.speed

func _on_count_pressed() -> void:
	count += 1
	count_but.text = str(count)
