extends Control

@onready var song_item_scene: PackedScene = preload("res://Scenes/SongItem.tscn")
@onready var back_button: Button = $BackButton

# 左边一半的东西
@onready var scroll_container: ScrollContainer = $MainLayout/LeftArea/ScrollContainer
@onready var song_list: VBoxContainer = $MainLayout/LeftArea/ScrollContainer/SongList
@onready var top_spacer: Control = $MainLayout/LeftArea/ScrollContainer/SongList/TopSpacer
@onready var bottom_spacer: Control = $MainLayout/LeftArea/ScrollContainer/SongList/BottomSpacer

# 右边一半的东西
@onready var label_title_big: Label = $MainLayout/RightInfoPanel/VAligner/InfoVBox/Label_Title
@onready var cover_big: TextureRect = $MainLayout/RightInfoPanel/VAligner/InfoVBox/CoverBig
@onready var label_artist_big: Label = $MainLayout/RightInfoPanel/VAligner/InfoVBox/Label_Artist

# 歌读取的位置，打包可能出问题，以后再说
const LEVELS_DIR = "res://levels/"
const AUDIO_FILE_NAME = "audio.mp3"
const BEATMAP_FILE_NAME = "music.txt"

# SongList 的参数
const ITEM_HEIGHT = 150.0 # SongItem 的 Min Height 
const ITEM_SPACING = 40.0 # VBoxContainer 的 Separation 

var song_items: Array = []
var current_selected_index: int = -1
var is_scrolling_manually: bool = false
var scroll_velocity: float = 0.0

# 选项吸附
var target_scroll_y: float = 0.0
var snap_timer: float = 0.0
var is_snapping: bool = false

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	
	# 遍历文件夹内容获得全部乐曲信息
	_scan_songs()
	
	# 计算 Spacer 的高度
	# 让第一首歌能滚到正中间
	await get_tree().process_frame
	
	var viewport_h = scroll_container.size.y
	var spacer_h = (viewport_h / 2.0) - (ITEM_HEIGHT / 2.0)
	
	if spacer_h < 0: spacer_h = 0
	
	top_spacer.custom_minimum_size.y = spacer_h
	bottom_spacer.custom_minimum_size.y = spacer_h
	
	_update_cover_big_size()
	
	# 初始选中项
	# 可以加一个记忆的功能，但是有点懒了
	_select_item_by_index(0)

# 遍历 levels，获取其子文件夹
func _scan_songs() -> void:
	var dir = DirAccess.open(LEVELS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				var folder_path = LEVELS_DIR + file_name
				_load_song_from_folder(folder_path)
			
			file_name = dir.get_next()
	else:
		push_error("无法打开 levels 目录，请检查路径。")

func _create_list_item(info: Dictionary) -> void:
	var item = song_item_scene.instantiate()
	song_list.add_child(item)
	song_list.move_child(item, song_list.get_child_count() - 2) 
	
	item.setup(info)
	song_items.append(item)

func _process(delta: float) -> void:
	if not is_scrolling_manually:
		var current_scroll = scroll_container.scroll_vertical
		
		# 距离很近就直接贴上去
		if abs(current_scroll - target_scroll_y) < 1.0:
			@warning_ignore("narrowing_conversion")
			scroll_container.scroll_vertical = target_scroll_y
		else:
			# 平滑滚动
			scroll_container.scroll_vertical = lerp(float(current_scroll), float(target_scroll_y), 10.0 * delta)
	
	# 检测谁在吸附位置
	_check_center_item()

func _input(event: InputEvent) -> void:
	if song_items.is_empty():
		return

	# 对鼠标滚轮的适配
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_step(-1) # 上一首
			get_viewport().set_input_as_handled() # 防止其他节点响应
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_step(1)  # 下一首
			get_viewport().set_input_as_handled()
	
	# 对键盘上下键的适配，可有可无
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("ui_up", true): 
			_scroll_step(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down", true):
			_scroll_step(1)
			get_viewport().set_input_as_handled()

func _scroll_step(dir: int) -> void:
	# 计算新索引
	var new_index = clamp(current_selected_index + dir, 0, song_items.size() - 1)
	
	# 只有当索引改变时才执行
	if new_index != current_selected_index:
		_select_item_by_index(new_index)

func _select_item_by_index(index: int) -> void:
	if index < 0 or index >= song_items.size(): return
	
	current_selected_index = index
	# 计算目标 Scroll Vertical
	target_scroll_y = index * (ITEM_HEIGHT + ITEM_SPACING)
	
	var selected_data = song_items[index]._song_data
	Global.selected_song_path = selected_data.get("folder_path", "")
	
	# 更新右侧信息
	_update_right_panel(song_items[index]._song_data)

func _check_center_item() -> void:
	# 遍历所有 Item，看谁离中心最近
	
	for i in range(song_items.size()):
		var item = song_items[i]
		if i == current_selected_index:
			item.set_selected(true)
		else:
			item.set_selected(false)

func _load_song_from_folder(folder_path: String) -> void:
	var file_path = folder_path + "/music.txt"
	var bg_path = folder_path + "/BG.jpg"
	
	# 忘了有些曲绘不是jpg，最省事的写法
	if not FileAccess.file_exists(bg_path):
		bg_path = folder_path + "/BG.png"
	
	if not FileAccess.file_exists(file_path):
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Error opening file: " + file_path)
		return
		
	var content = file.get_as_text()
	var parsed_data = _parse_ini_text(content)
	const SECTION = "Metadata" 
	# 寻找osu内的 Metadata，用来读取必要的曲名，作曲和谱师
	var meta = parsed_data.get(SECTION, {})
	
	var title = meta.get("TitleUnicode", "")
	if title.is_empty():
		title = meta.get("Title", "Unknown Title")
		
	var artist = meta.get("ArtistUnicode", "")
	if artist.is_empty():
		artist = meta.get("Artist", "Unknown Artist")
		
	var creator = meta.get("Creator", "Unknown Creator")
	
	var texture: Texture2D = null
	if FileAccess.file_exists(bg_path):
		texture = load(bg_path)
		
	var song_info = {
		"folder_path": folder_path,
		"json_path": file_path,
		"title": title,
		"artist": artist,
		"creator": creator,
		"texture": texture
	}
	
	_create_list_item(song_info)

# 返回按钮按下动作
func _on_back_pressed() -> void:
	back_button.disabled = true
	SceneTransition.change_scene(load("res://MainMenu.tscn"))

# 想无痛使用osu的谱面文件，但是godot解析不了这种看着又像ini又不像的东西，被迫重写一个函数用来解析
func _parse_ini_text(content: String) -> Dictionary:
	var data = {}
	var current_section = ""
	# 按行分割内容
	var lines = content.split("\n", false)
	for line in lines:
		var trimmed_line = line.strip_edges()
		# 忽略空行和注释行
		if trimmed_line.is_empty() or trimmed_line.begins_with("//"):
			continue 
		# 检查是否为 [SectionName]
		if trimmed_line.begins_with("[") and trimmed_line.ends_with("]"):
			# 提取 Section 名称并移除 []
			current_section = trimmed_line.trim_prefix("[").trim_suffix("]")
			data[current_section] = {} # 初始化字典
		else:
			# 寻找第一个冒号作为 Key 和 Value 的分隔符
			var parts = trimmed_line.split(":", false, 1) 
			if parts.size() == 2 and not current_section.is_empty():
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()
				
				# 塞进字典
				if data.has(current_section):
					data[current_section][key] = value
	return data
	
func _update_right_panel(data: Dictionary) -> void:
	# 更新右侧 UI
	label_title_big.text = data["title"]
	label_artist_big.text = data["artist"]
	cover_big.texture = data["texture"]

# 调整曲绘大小
func _update_cover_big_size() -> void:
	var vw := get_viewport_rect().size.x
	var side := vw * 0.25
	cover_big.size = Vector2(side, side)
