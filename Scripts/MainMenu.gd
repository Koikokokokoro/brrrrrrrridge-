extends Control

# 引用背景音乐播放器
@onready var bgm_player: AudioStreamPlayer = $Control/AudioStreamPlayer
@onready var background_image: TextureRect = $Control/Background
@onready var title_image: TextureRect = $Control/Title

# 淡入持续时间
@export var fade_in_duration: float = 2.0

# 动画参数
@export_group("Animation Settings")
@export var fade_duration: float = 0.5 
@export var menu_delay: float = 0.3 # 角色开始淡入前的延迟
@export var spacing_x: float = 300.0 # 角色之间的水平间距
@export var overlap_x: float = 150.0 #

# 布局参数
@export_group("Layout Settings")
@export var character_scale_factor: float = 0.8 # 整体立绘在屏幕上的占比
@export var char2_scale: float = 1.05 # 2 号角色的额外放大比例
@export var side_char_scale: float = 0.90 # 1, 3, 4 号角色的缩小比例
@export var angle_offset: float = 5.0 # 左右倾斜角度
@export var cluster_offset_x: float = -150.0

# 节点
@onready var character_scaler: Control = $CharacterScaler
@onready var character_pivot: Node2D = $CharacterScaler/CharacterPivot
@onready var button_panel: VBoxContainer = $ButtonPanel

# BUTTONS
@export_group("UI Button Settings")
@export var button_font: Font = preload("res://Fonts/SanJiHuaChaoTi-Cu-2.ttf") # 本地字体路径
@export var normal_color: Color = Color("#FFFFFF")  # 默认颜色
@export var hover_color: Color = Color("#FFD700")   # 悬停颜色 (金色)
@export var hover_duration: float = 0.2           # 颜色渐变时长 (秒)
@export var button_outline_color: Color = Color("#FFD700") # 描边颜色
@export var button_outline_size: int = 8
var button_tweens: Dictionary = {}

@export_group("Background Settings")
@export var background_texture: Texture2D = preload("res://Textures/bridge.png") # 背景图片路径
@export var background_fade_target_alpha: float = 0.8 # 最终背景透明度
@export var background_fade_duration: float = 1.0   # 背景淡入时长

@export_group("Title Settings")
@export var title_fade_duration: float = 1.0   # 标题淡入时长

# 所有立绘的数组
var all_chars: Array[TextureRect] = []

# 淡入顺序：1 -> 3 -> 4 -> 2
const FADE_ORDER = [1, 3, 4, 2]

const CHAR_RECT_SIZE = Vector2(700, 800) 
const CHAR_RECT_HALF_SIZE = CHAR_RECT_SIZE / 4

func _ready() -> void:
	
	if bgm_player:
		# 记录检查器里设置的目标音量
		var target_db = bgm_player.volume_db
		# 初始设为静音
		bgm_player.volume_db = -80.0
		# 开始播放
		bgm_player.play()
		
		_setup_existing_buttons()
		
		_update_shader_params()
		get_tree().root.size_changed.connect(_on_viewport_size_changed)
		
		# 创建 Tween 动画实现淡入
		var tween = create_tween()
		# 将音量从 -80 平滑过渡到 target_db
		tween.tween_property(bgm_player, "volume_db", target_db, fade_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		push_warning("MainMenu: 未找到 AudioPreview 节点，无法播放背景音乐。")
		
	all_chars = [
		$CharacterScaler/CharacterPivot/Char3, 
		$CharacterScaler/CharacterPivot/Char1, 
		$CharacterScaler/CharacterPivot/Char4, 
		$CharacterScaler/CharacterPivot/Char2
	]
	
	# 设置所有角色的初始姿态和尺寸
	_setup_character_layout()
	
	# 按钮初始透明
	button_panel.modulate.a = 0.0
	
	# 开始菜单动画
	_animate_menu_entry()
	
	button_panel.mouse_behavior_recursive = MOUSE_BEHAVIOR_INHERITED
	
func _setup_character_layout() -> void:
	
	# 整体响应式缩放
	# 调整 CharacterScaler 的宽度，使其占据大半画面
	var screen_width = get_viewport_rect().size.x
	var target_scaler_width = screen_width * character_scale_factor
	
	# 调整 CharacterScaler 的 Offsets 以达到目标宽度
	character_scaler.offset_left = screen_width - target_scaler_width
	character_scaler.offset_right = 0
	
	# 设置 CharacterPivot (旋转中心) 的位置
	# 确保旋转中心在 CharacterScaler 的中心
	await get_tree().process_frame # 等待 CharacterScaler 尺寸更新
	character_pivot.position = character_scaler.size / 2.0
	
	# 计算所有角色的位置、旋转和缩放
	
	const offset_to_center = -CHAR_RECT_HALF_SIZE

	# 修正后的中心 X 坐标
	var center_x_pos = 0.0 + cluster_offset_x
	
	var base_position = Vector2(center_x_pos, 0.0) + offset_to_center
	
	# 设置 Char2 的属性
	var char2: TextureRect = $CharacterScaler/CharacterPivot/Char2
	char2.scale = Vector2.ONE * char2_scale
	char2.rotation_degrees = 0
	# char2.position = Vector2(base_x, base_y)
	char2.position = base_position
	
	# 设置 Char1, Char3, Char4 的属性
	
	# Char1 (左侧，中层)
	var char1: TextureRect = $CharacterScaler/CharacterPivot/Char1
	char1.scale = Vector2.ONE * side_char_scale
	char1.rotation_degrees = -angle_offset
	# char1.position = Vector2(base_x - spacing_x, base_y)
	var char1_center_offset = -spacing_x + overlap_x 
	char1.position = base_position + Vector2(char1_center_offset, 0)
	
	# Char4 (右侧，中层)
	var char4: TextureRect = $CharacterScaler/CharacterPivot/Char4
	char4.scale = Vector2.ONE * side_char_scale
	char4.rotation_degrees = angle_offset
	# char4.position = Vector2(base_x + spacing_x, base_y)
	var char4_center_offset = spacing_x * 1.2 
	char4.position = base_position + Vector2(char4_center_offset, 0)
	
	# Char3 (左侧，最底层)
	var char3: TextureRect = $CharacterScaler/CharacterPivot/Char3
	char3.scale = Vector2.ONE * side_char_scale
	char3.rotation_degrees = -(angle_offset - 5.0)
	# char3.position = Vector2(base_x - spacing_x * 1.5, base_y)
	var char3_center_offset = spacing_x * 0.5
	char3.position = base_position + Vector2(char3_center_offset, 0)

func _animate_menu_entry() -> void:
	
	# button_panel.mouse_behavior_recursive = MOUSE_BEHAVIOR_DISABLED
	# 初始化主 Tween
	var main_tween = get_tree().create_tween()
	
	if not is_instance_valid(main_tween):
		push_error("无法创建 Tween 实例，菜单动画失败。")
		return
	
	#if is_instance_valid(background_image):
	#	background_image.modulate.a = 0.0
	
	if is_instance_valid(title_image):
		title_image.modulate.a = 0.0
		
	if not background_image.texture:
		push_error("背景图片节点没有分配纹理资源！")
	
	main_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# main_tween.tween_interval(menu_delay*2)
	
	if is_instance_valid(background_image) and background_image.texture:
		main_tween.tween_property(background_image, "modulate:a", background_fade_target_alpha, background_fade_duration)
	
	if is_instance_valid(title_image) and title_image.texture:
		main_tween.tween_property(title_image, "modulate:a", 1.0, title_fade_duration)
	
	# 延迟开始角色动画
	main_tween.tween_interval(menu_delay)
	
	# 淡入序列 (1 -> 3 -> 4 -> 2)
	var current_delay = 0.0
	
	for char_index in FADE_ORDER:
		var char_node: TextureRect
		
		match char_index:
			1: char_node = $CharacterScaler/CharacterPivot/Char1
			3: char_node = $CharacterScaler/CharacterPivot/Char3
			4: char_node = $CharacterScaler/CharacterPivot/Char4
			2: char_node = $CharacterScaler/CharacterPivot/Char2
			
		# 淡入当前角色，并等待
		main_tween.tween_property(char_node, "modulate:a", 1.0, fade_duration)\
			.set_delay(current_delay)
			
		current_delay += fade_duration * 0.2 # 每个角色淡入后，等待 0.2 淡入时间再开始下一个

	# 按钮面板淡入
	var button_delay = current_delay - fade_duration * 0.5 # 在 4 号淡入完成时开始按钮淡入
	
	main_tween.tween_property(button_panel, "modulate:a", 1.0, fade_duration)\
		.set_delay(button_delay)
	
	await main_tween.finished
	print("主菜单动画完成。")

# 按钮
func _setup_existing_buttons() -> void:
	# 移除按钮边框的 StyleBox
	var button_style_empty = StyleBoxEmpty.new()
	
	for button in button_panel.get_children():
		# 仅处理 Button 类型的子节点
		if button is Button:
			# 样式设置：移除边框并设置字体
			button.add_theme_stylebox_override("normal", button_style_empty)
			button.add_theme_stylebox_override("hover", button_style_empty)
			button.add_theme_stylebox_override("pressed", button_style_empty)
			button.add_theme_stylebox_override("focus", button_style_empty)
			
			# 设置本地字体和字号
			if button_font:
				button.add_theme_font_override("font", button_font)
				button.add_theme_font_size_override("font_size", 48)
				button.add_theme_color_override("font_outline_color", button_outline_color)
				button.add_theme_constant_override("outline_size", button_outline_size)
				
			# 初始颜色
			button.modulate = normal_color
			
			# 垂直居中等分
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL 
			# 水平居中
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER 
			
			# 确保按钮有 name 属性用于跟踪 Tween
			if button.name == "":
				button.name = button.text # 临时使用文本作为名字
				
			#button.disabled = true
				
			button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
			button.mouse_exited.connect(_on_button_mouse_exited.bind(button))

func _on_button_mouse_entered(button: Button) -> void:
	_transition_button_color(button, hover_color)

func _on_button_mouse_exited(button: Button) -> void:
	_transition_button_color(button, normal_color)

func _transition_button_color(button: Button, target_color: Color) -> void:
	# 检查并杀死当前正在运行的颜色渐变，以避免冲突
	if button_tweens.has(button.name) and is_instance_valid(button_tweens[button.name]):
		button_tweens[button.name].kill()
		button_tweens.erase(button.name)
		
	var tween = button.create_tween()
	button_tweens[button.name] = tween
	
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	# 对 modulate 属性进行平滑过渡
	tween.tween_property(button, "modulate", target_color, hover_duration)
	
	# 渐变完成后，清理字典
	await tween.finished
	if button_tweens.has(button.name):
		button_tweens.erase(button.name)

func _on_viewport_size_changed() -> void:
	# 确保在尺寸改变后立即更新 Shader 参数
	_update_shader_params()
	
func _update_shader_params() -> void:
	var current_screen_width = get_viewport_rect().size.x
	
	if is_instance_valid(background_image) and background_image.material is ShaderMaterial:
		var shader_material: ShaderMaterial = background_image.material
		shader_material.set_shader_parameter("screen_width", current_screen_width)
		
		shader_material.set_shader_parameter("fade_start_x_ratio", 0.5)
