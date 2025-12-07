# SceneTransition.gd
extends CanvasLayer

# 引用节点
@onready var left_rect: TextureRect = $TransitionControl/LeftTexture
@onready var right_rect: TextureRect = $TransitionControl/RightTexture

# 图片的原始尺寸
const SRC_L_SIZE = Vector2(1216, 965)
const SRC_R_SIZE = Vector2(425, 965)
# 两张图拼合后的总视觉宽度
const VISUAL_TOTAL_WIDTH = 1290.0 
# 重叠部分的宽度
const OVERLAP_WIDTH = (1216 + 425) - 1290 

# 动画时间
@export var transition_duration: float = 0.5
@export var stay_duration: float = 0.2 # 合拢后停留多久

# 保存你的图片资源
@export var tex_left: Texture2D
@export var tex_right: Texture2D

func _ready() -> void:
	# 初始化图片
	if tex_left: left_rect.texture = tex_left
	if tex_right: right_rect.texture = tex_right
	
	# 初始化位置到屏幕外
	_update_positions(0.0)
	
	# 监听窗口大小变化（处理运行时调整分辨率）
	get_tree().root.size_changed.connect(func(): _update_positions(0.0))

# 切换场景的入口函数
func change_scene(target_scene_packed: PackedScene) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_positions, 0.0, 1.0, transition_duration)
	
	await tween.finished
	
	if stay_duration > 0:
		await get_tree().create_timer(stay_duration).timeout
	
	get_tree().change_scene_to_packed(target_scene_packed)
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_positions, 1.0, 0.0, transition_duration)
	
	await tween.finished

# 核心计算逻辑：progress 0.0 = 打开(屏幕外), 1.0 = 合拢(屏幕中)
func _update_positions(progress: float) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	var scale_h = viewport_size.y / SRC_L_SIZE.y
	var scale_w = viewport_size.x / VISUAL_TOTAL_WIDTH
	var s = max(scale_h, scale_w)
	
	left_rect.size = SRC_L_SIZE * s
	right_rect.size = SRC_R_SIZE * s
	
	var total_scaled_width = VISUAL_TOTAL_WIDTH * s
	var overlap_scaled = OVERLAP_WIDTH * s
	
	var start_x = (viewport_size.x - total_scaled_width) / 2.0
	
	var target_l_pos = Vector2(start_x, (viewport_size.y - left_rect.size.y) / 2.0)
	# 右图位置 = 左图起点 + 左图现宽 - 重叠部分
	var target_r_pos = Vector2(target_l_pos.x + left_rect.size.x - overlap_scaled, target_l_pos.y)
	
	# 左图往左飞，右图往右飞
	var off_l_pos = Vector2(-left_rect.size.x, target_l_pos.y)
	var off_r_pos = Vector2(viewport_size.x, target_r_pos.y)
	
	left_rect.position = off_l_pos.lerp(target_l_pos, progress)
	right_rect.position = off_r_pos.lerp(target_r_pos, progress)
