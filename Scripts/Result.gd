# 结算界面
extends Control

# labels
@onready var score_label: Label = $InfoContainer/ScoreLabel
@onready var accuracy_label: Label = $InfoContainer/AccuracyLabel
@onready var note_label: RichTextLabel = $InfoContainer/NoteLabel
@onready var combo_label: Label = $InfoContainer/ComboLabel

const SCORE_LABEL_SECTOR_IDX = 5
const ACC_LABEL_SECTOR_IDX = 3

# 动画参数
const LABEL_MOVE_DISTANCE = 300.0  # 从中心沿射线移动的像素距离
const LABEL_ANIM_TIME = 0.8        # 秒

# 节点
@onready var background_rect: ColorRect = $BackgroundLayer
@onready var rays_container: Node2D = $RaysContainer
@onready var rank_image: TextureRect = $RankImage
@onready var center_point: TextureRect = $CenterPoint
@onready var character_art: TextureRect = $CharacterArt

# 参数
const CENTER_RATIO: Vector2 = Vector2(0.5, 0.9)
const SECTOR_COUNT: int = 6
const RAY_LENGTH: float = 1500.0

const RAY_ANGLES_DEGREE: Array = [-135.0, -45.0, -15.0, 15.0, 165.0, -165.0]
const BLANK_SECTOR_INDEX: int = 3

@export var debug_draw: bool = false

var _sorted_angles_rad: Array = []
var _shader_target_radius: float = 1.0

# buttons
@onready var btn_retry: Button = $RetryButton
@onready var btn_exit: Button = $ExitButton
@export var game_scene_path: String = "res://Game.tscn"
@export var menu_scene_path: String = "res://Scenes/SelectMusic.tscn"

func _ready() -> void:
	# 布局
	_setup_layout()

	# 准备 shader material
	var mat: ShaderMaterial = background_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("center", CENTER_RATIO)
		mat.set_shader_parameter("animation_progress", 0.0)

	_prepare_angles()

	# 生成射线
	rays_container.create_rays(_sorted_angles_rad, RAY_LENGTH)

	_set_shader_boundaries_and_radius()

	# 调试绘制
	if debug_draw:
		rays_container.debug_draw_markers(_sorted_angles_rad, RAY_LENGTH)
	
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	btn_retry.anchor_left = 0.5
	btn_retry.anchor_right = 0.5
	btn_retry.anchor_top = 0.9
	btn_retry.anchor_bottom = 0.9

	btn_exit.anchor_left = 0.5
	btn_exit.anchor_right = 0.5
	btn_exit.anchor_top = 0.9
	btn_exit.anchor_bottom = 0.9

	# 设置初始位置
	var screen_size = get_viewport_rect().size
	btn_retry.position = Vector2(-btn_retry.size.x, screen_size.y * 0.9)
	btn_exit.position = Vector2(screen_size.x + btn_exit.size.x, screen_size.y * 0.9)
	
	# 动画入口
	_play_entry_animation()

# 计算中心像素位置
func viewport_get_center() -> Vector2:
	return get_viewport_rect().size * CENTER_RATIO

func _setup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var center_pos: Vector2 = viewport_size * CENTER_RATIO

	center_point.pivot_offset = center_point.size * 0.5
	center_point.position = center_pos - center_point.pivot_offset

	# rank_image.pivot_offset = rank_image.size * 0.5
	# rank_image.position = center_pos + rank_image.pivot_offset

	character_art.position.x = (viewport_size.x - character_art.size.x) * -0.2
	character_art.position.y = center_pos.y - 550.0

# 规范化并排序角度
func _prepare_angles() -> void:
	_sorted_angles_rad.clear()
	for deg in RAY_ANGLES_DEGREE:
		var a: float = deg_to_rad(float(deg))
		var norm: float = fmod(a, PI * 2.0)
		if norm < 0.0:
			norm += PI * 2.0
		_sorted_angles_rad.append(norm)
	_sorted_angles_rad.sort()

# shader 边界 & 最大半径
func _set_shader_boundaries_and_radius() -> void:
	var mat: ShaderMaterial = background_rect.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("angle_boundaries", _sorted_angles_rad)
	mat.set_shader_parameter("blank_sector_index", BLANK_SECTOR_INDEX)

	var dx: float = max(CENTER_RATIO.x, 1.0 - CENTER_RATIO.x)
	var dy: float = max(CENTER_RATIO.y, 1.0 - CENTER_RATIO.y)
	_shader_target_radius = sqrt(dx * dx + dy * dy) * 1.05

# 类成员函数
func animate_label_along_ray(
	label_node: Node,
	angle_rad: float,
	move_distance: float,
	side_distance: float,
	side_sign: int,
	rotation_offset_deg: float,
	anim_time: float,
	attempts: int = 0
) -> void:
	var center_pos: Vector2 = get_viewport_rect().size * CENTER_RATIO
	var dir: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var actual_side_sign: int = side_sign
	if actual_side_sign == 0:
		var deg: float = rad_to_deg(angle_rad)
		while deg > 180.0:
			deg -= 360.0
		while deg <= -180.0:
			deg += 360.0
		if deg > 90.0 or deg < -90.0:
			actual_side_sign = 1
		else:
			actual_side_sign = -1

	# 目标全局点（屏幕像素）
	var target_global: Vector2 = center_pos + dir * move_distance + perp * (side_distance * float(actual_side_sign))

	# 目标旋转（规约到 [-90,90]）
	var base_deg: float = rad_to_deg(angle_rad)
	var rot_deg: float = base_deg + rotation_offset_deg
	while rot_deg > 180.0:
		rot_deg -= 360.0
	while rot_deg <= -180.0:
		rot_deg += 360.0
	if rot_deg > 90.0:
		rot_deg -= 180.0
	elif rot_deg < -90.0:
		rot_deg += 180.0
	var target_rot_rad: float = deg_to_rad(rot_deg)
	
	# ai 写的答辩
	if label_node is Control:
		var ctrl: Control = label_node as Control

		# 如果 rect_size 尚未准备好（0），延迟并重试一次或两次
		if ctrl.size == Vector2.ZERO:
			if attempts < 2:
				call_deferred("animate_label_along_ray", label_node, angle_rad, move_distance, side_distance, side_sign, rotation_offset_deg, anim_time, attempts + 1)
			return

		# 设置 pivot 为几何中心（确保绕几何中心旋转）
		var pivot: Vector2 = ctrl.size * 0.5
		ctrl.pivot_offset = pivot

		# 保留 RichTextLabel 的 bbcode/visibility 设置（不修改）
		# (不必要改动，这里仅作说明)
		# if ctrl is RichTextLabel:
		#     var rtb := ctrl as RichTextLabel
		#     var old_bb := rtb.bbcode_enabled

		# 将起点放在中心（pivot 在 center）
		ctrl.global_position = center_pos - pivot
		ctrl.rotation = target_rot_rad

		# Tween 全局位置（左上角）与 rotation
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(ctrl, "global_position", target_global - pivot, anim_time)
		t.tween_property(ctrl, "rotation", target_rot_rad, anim_time)
		return

	if label_node is Node2D:
		var node2: Node2D = label_node as Node2D
		# 设置起点与旋转
		node2.global_position = center_pos
		node2.rotation = target_rot_rad
		var t2 := create_tween()
		t2.set_parallel(true)
		t2.tween_property(node2, "global_position", target_global, anim_time)
		t2.tween_property(node2, "rotation", target_rot_rad, anim_time)
		return

	# 不支持的类型
	push_warning("animate_label_along_ray: unsupported node type: %s" % [str(typeof(label_node))])


# 动画入口
func _play_entry_animation() -> void:
	var mat: ShaderMaterial = background_rect.material as ShaderMaterial

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


	if mat:
		tween.tween_method(func(val):
			if mat:
				mat.set_shader_parameter("animation_progress", val)
		, 0.0, _shader_target_radius, 2.0)

	tween.tween_property(center_point, "scale", Vector2.ONE, 0.5)

	# 射线动画
	for child in rays_container.get_children():
		if not child or not (child is Line2D):
			continue
		var line: Line2D = child as Line2D
		if not line.has_meta("target_end"): continue
		var target: Vector2 = line.get_meta("target_end")
		var start: Vector2 = line.points[0]

		tween.tween_method(func(val):
			if line.points.size() > 1:
				line.points[1] = start.lerp(target, val)
		, 0.0, 1.0, 0.8).set_delay(0.05)

	# Rank 动画，但是好像没用
	var rank_tween = create_tween()
	rank_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rank_tween.tween_interval(0.3)
	rank_tween.set_parallel(true)
	rank_tween.tween_property(rank_image, "scale", Vector2.ONE, 0.5)
	rank_tween.tween_property(rank_image, "modulate:a", 1.0, 0.3)

	# 人物动画
	character_art.modulate.a = 0.0
	var ct = create_tween()
	ct.tween_interval(0.2)
	ct.tween_property(character_art, "modulate:a", 1.0, 0.8)
	
	# labels
	#var viewport_size = get_viewport_rect().size

	if score_label and _sorted_angles_rad.size() > 3:
		animate_label_along_ray(score_label, _sorted_angles_rad[5], LABEL_MOVE_DISTANCE*2/3, -35.0, 1, 0.0, LABEL_ANIM_TIME/2)

	if accuracy_label and _sorted_angles_rad.size() > 0:
		animate_label_along_ray(accuracy_label, _sorted_angles_rad[2], LABEL_MOVE_DISTANCE*3/2  , -75.0, -1, 0.0, LABEL_ANIM_TIME/2)
		
	if note_label:
		animate_label_along_ray(note_label, _sorted_angles_rad[2], LABEL_MOVE_DISTANCE  , -20.0, -1, 0.0, LABEL_ANIM_TIME/2)
	
	if combo_label:
		animate_label_along_ray(combo_label, _sorted_angles_rad[5], LABEL_MOVE_DISTANCE*2/3, -30, 0, 0, LABEL_ANIM_TIME/2)
	
	# retry 从左向右
	tween.tween_property(
		btn_retry, "position",
		Vector2(0, btn_retry.position.y), # 屏幕内目标位置
		0.6 # 持续时间
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(1.0)
		
	# exit 从右向左
	tween.tween_property(
		btn_exit, "position",
		Vector2(get_viewport_rect().size.x - 0 - btn_exit.size.x, btn_exit.position.y),
		0.6
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(1.0)

# buttons
func _on_retry_pressed() -> void:
	# 禁用按钮防止连点
	btn_retry.disabled = true
	SceneTransition.change_scene(load(game_scene_path))

func _on_exit_pressed() -> void:
	btn_exit.disabled = true
	SceneTransition.change_scene(load(menu_scene_path))
