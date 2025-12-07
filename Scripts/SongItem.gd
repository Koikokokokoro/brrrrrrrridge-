extends Control

var _song_data: Dictionary = {}

@onready var mover: Control = $Mover
@onready var background: TextureRect = $Mover/Background
@onready var icon_container: Control = $Mover/Content/IconContainer
@onready var cover_rect: TextureRect = $Mover/Content/IconContainer/mask/CoverImage

# Info
@onready var info_box: VBoxContainer = $Mover/Content/InfoVBox
@onready var lbl_title: Label = $Mover/Content/InfoVBox/Label_Title
@onready var lbl_artist: Label = $Mover/Content/InfoVBox/Label_Artist
@onready var lbl_creator: Label = $Mover/Content/InfoVBox/Label_Creator

# 目标比例 945 : 600
const COVER_TARGET_RATIO: float = 945.0 / 600.0

# 偏移量
@export_group("Motion")
@export var slope_strength: float = 0.8
@export var base_offset_x: float = 250.0
const SLOPE_RATIO = 0.57735

func _ready() -> void:
	icon_container.size_flags_stretch_ratio = mover.size.y * COVER_TARGET_RATIO
	info_box.size_flags_stretch_ratio = mover.size.x - icon_container.size_flags_stretch_ratio
	
	# 监听背景或父级大小变化，以调整图标容器大小
	background.resized.connect(_update_layout_size)
	
	call_deferred("_update_layout_size")

func setup(data: Dictionary) -> void:
	_song_data = data
	# 面向结果的平面设计（）
	lbl_title.text = "        " + data.get("title", "Unknown Title")
	lbl_artist.text = "      " + data.get("artist", "Unknown")
	lbl_creator.text = "" + data.get("creator", "Unknown")

	if data.get("texture"):
		cover_rect.texture = data["texture"]

func _update_layout_size() -> void:
	if not background or not icon_container: return
	
	# 获取基准高度
	var base_height = background.size.y
	if base_height <= 0: return
	
	# 计算目标宽度
	var target_width = base_height * COVER_TARGET_RATIO
	
	# 设置 IconContainer 的最小尺寸
	icon_container.custom_minimum_size = Vector2(target_width, base_height)
	icon_container.size = Vector2(target_width, base_height) 

func _process(_delta: float) -> void:
	# 保持你的倾斜运动逻辑
	var current_y = global_position.y
	# 简单的视差/倾斜计算
	var target_x = base_offset_x - (current_y * SLOPE_RATIO * slope_strength)
	
	if mover:
		mover.position.x = target_x

# 选中状态逻辑保持不变
func set_selected(is_selected: bool) -> void:
	if is_selected:
		modulate = Color(1.2, 1.2, 1.2, 1.0)
		mover.scale = Vector2(1.05, 1.05)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.8)
		mover.scale = Vector2(1.0, 1.0)
