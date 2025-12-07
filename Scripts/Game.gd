extends Control

class_name RhythmGame

# 读取谱面和音乐
@export_group("Resources")
@export var osu_file_path: String = Global.selected_song_path + "/music.txt"
@export var audio_file_path: String = Global.selected_song_path + "/audio.mp3"

# 指示箭头的参数
@export var arrow_fade_duration: float = 0.5   # 箭头淡入/淡出时间
@export var arrow_move_distance: float = 50.0 # 箭头向下移动的距离
@export var arrow_spawn_offset_y: float = -70.0

# 大头贴 Note
@export_group("Note Textures")
var note_textures: Array[Texture2D] = [
	preload("res://Sprites/notes/1.png"),
	preload("res://Sprites/notes/2.png"),
	preload("res://Sprites/notes/3.png"),
	preload("res://Sprites/notes/4.png"),
	preload("res://Sprites/notes/5.png"),
	preload("res://Sprites/notes/6.png"),
	preload("res://Sprites/notes/7.png"),
	preload("res://Sprites/notes/8.png")
]

# 各种乱七八糟的参数
@export_group("Gameplay Settings")
@export var start_delay: float = 1.0
@export var lanes_count: int = 4
@export var travel_time: float = 1.5
@export var spawn_buffer: float = 0.05
@export var hit_line_ratio: float = 0.9 

@export_group("Judgement (ms)")
@export var perfect_ms: float = 40.0
@export var great_ms: float = 70.0
@export var good_ms: float = 100.0
@export var miss_ms: float = 150.0

@export_group("System")
@export var latency_offset: float = 0.0

# 本来想做成类似 fnf那种东西的，但是感觉有点不太对（？）
@export_group("Character Visuals")
@export var character_texture_0: Texture2D = preload("res://Sprites/wll1.png")
@export var character_texture_1: Texture2D = preload("res://Sprites/wll2.png")
@export var character_texture_2: Texture2D = preload("res://Sprites/wll3.png")
@export var character_texture_3: Texture2D = preload("res://Sprites/wll4.png")
@export var character_margin_ratio: float = 0.2

# 全是节点
@onready var audio: AudioStreamPlayer2D = $Audio
@onready var note_pool: Node = $NotePool
@onready var lane_container: Control = $UI_Layer/MainLayout/LaneContainer
@onready var hitline: Control = $UI_Layer/MainLayout/LaneContainer/HitLine
@onready var score_label: RichTextLabel = $UI_Layer/MainLayout/RightPanel/Label_Score
@onready var acc_label: RichTextLabel = $UI_Layer/MainLayout/RightPanel/Label_Accuracy

@onready var accuracy_meter_area: TextureRect = $UI_Layer/MainLayout/RightPanel/AccuracyMeterArea
@onready var acc_indicator: ColorRect = $UI_Layer/MainLayout/RightPanel/AccuracyMeterArea/AccIndicator
@export var meter_y_top: float = 10.0
@export var meter_y_bottom: float = 200.0

@onready var left_panel: Control = $UI_Layer/MainLayout/LeftPanel
@onready var character_image: TextureRect = $UI_Layer/MainLayout/LeftPanel/CharacterImage

@onready var track_lost_image: TextureRect = $UI_Layer/MainLayout/LaneContainer/TrackLostImage
@onready var arrow_mark: TextureRect = $UI_Layer/MainLayout/LaneContainer/ArrowMark

@onready var cri_label: Label = $UI_Layer/MainLayout/LaneContainer/Criterion

# 给加了个判定显示用的
var _cri_seq: int = 0

# 过程中用的
var chart_notes: Array = []
var next_note_index: int = 0
var active_notes: Array = [] 
var lane_xs: Array = []
var lane_width_px: float = 0.0
var hit_y_local: float = 0.0
var is_playing: bool = false

var current_score: int = 0
var total_hits: int = 0
var total_notes_count: int = 0

var count_perfect: int = 0
var count_great: int = 0
var count_good: int = 0
var count_miss: int = 0
var game_over_triggered: bool = false # 一局游戏只能结束一次
var combo: int = 0
var max_combo: int = 0

func _ready() -> void:
	# 随机头生成器（）
	randomize() 
	_setup_default_input_map()
	
	# 初始隐藏判定内容
	if is_instance_valid(cri_label):
		cri_label.visible = false
		cri_label.modulate.a = 1.0
	
	if is_instance_valid(note_pool):
		note_pool.parent_node = lane_container
		
	$UI_Layer/MainLayout.queue_sort()
	await get_tree().process_frame
	
	if is_instance_valid(note_pool) and note_pool.has_method("initialize_pool"):
		note_pool.initialize_pool()
	
	_calculate_lanes_from_container()
	_setup_track_lost_layout()
	
	get_tree().root.size_changed.connect(func(): 
		await get_tree().process_frame
		_calculate_lanes_from_container()
		_setup_track_lost_layout()
	)
	
	_update_score_ui(0, "0.00%")
	
	# 试图制造一种空两拍谱面才开始的效果，但是没处理好谱面的下落速度的关系，先丢着了
	print("等待 %.1f 秒..." % start_delay)
	await get_tree().create_timer(start_delay).timeout
	
	if audio:
		audio.finished.connect(_on_audio_finished)

	_load_and_start()
	
# 显示判定内容
func _show_criterion_temporarily() -> void:
	# 增加序号，旧的等待失效
	_cri_seq += 1
	var my_seq = _cri_seq

	if not is_instance_valid(cri_label):
		return

	cri_label.visible = true
	cri_label.modulate.a = 1.0

	# 判定呈现 0.5s
	await get_tree().create_timer(0.5).timeout

	# 只有当当前等待对应的序号仍然是最新序号时才隐藏
	if my_seq == _cri_seq and is_instance_valid(cri_label):
		cri_label.visible = false

func _setup_track_lost_layout() -> void:
	if not is_instance_valid(track_lost_image):
		return
		
	track_lost_image.anchor_left = 0.0
	track_lost_image.anchor_right = 1.0
	track_lost_image.anchor_top = 0.5
	track_lost_image.anchor_bottom = 0.5
	
	track_lost_image.offset_left = 0
	track_lost_image.offset_right = 0
	
	track_lost_image.grow_horizontal = Control.GROW_DIRECTION_BOTH
	track_lost_image.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	track_lost_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	track_lost_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	track_lost_image.modulate.a = 0.0
	
# 随机获取一个大头贴
func get_random_note_texture() -> Texture2D:
	if note_textures.is_empty():
		push_warning("Note textures array is empty!")
		return null
	# 获得一个随机索引
	var index = randi() % note_textures.size()
	return note_textures[index]

# 生成 Note，基本就是把每个 Note 的位置都随机一个大头贴
func _spawn_note(data: Dictionary) -> void:
	var lane_idx = data["lane"]
	if lane_idx >= lane_xs.size(): return
	
	var n = note_pool.get_note()
	if not n: return
	
	var target_x_local = lane_xs[lane_idx]
	var hit_y_local_for_spawn = hit_y_local
	var spawn_y_local = -100.0
	
	var random_texture = get_random_note_texture()
	
	var eff_travel := _effective_travel_time()
	n.setup(data["time"], lane_idx, target_x_local, spawn_y_local, hit_y_local_for_spawn, eff_travel, lane_width_px, random_texture)
	active_notes.append(n)

func _setup_character_layout() -> void:
	if not is_instance_valid(left_panel) or not is_instance_valid(character_image):
		return

	character_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 控制左侧人物位置的一些东西
	# var panel_width = left_panel.size.x
	var panel_height = left_panel.size.y
	
	# var margin_x = panel_width * character_margin_ratio
	var margin_y = panel_height * character_margin_ratio
	
	character_image.size.y = panel_height - margin_y * 2
	
	#character_image.offset_left = margin_x
	character_image.offset_top = margin_y
	#character_image.offset_right = -margin_x 
	character_image.offset_bottom = panel_height-margin_y

func _calculate_lanes_from_container() -> void:
	if not lane_container: return

	var container_w = lane_container.size.x
	var container_h = lane_container.size.y
	
	if container_w < 100:
		push_warning("LaneContainer 宽度太小 (%f)，请检查 UI 布局的 Stretch Ratio 设置！" % container_w)
		return
	
	lane_width_px = container_w / float(lanes_count)
	
	# 计算轨道中心坐标 x
	lane_xs.clear()
	for i in range(lanes_count):
		var center_x_local = (i * lane_width_px) + (lane_width_px / 2.0)
		lane_xs.append(center_x_local)
	
	# 计算判定线位置 y
	hit_y_local = container_h * hit_line_ratio
	
	if hitline:
		var line_height = hitline.size.y
		hitline.position.y = hit_y_local - (line_height / 2.0)
	
	_setup_character_layout()
	
	# debug信息
	print("轨道信息")
	print("LaneContainer 全局位置", lane_container.global_position)
	print("LaneContainer 大小", container_w, "x", container_h)
	print("轨道中心位置", lane_xs)
	print("----")

func _load_and_start() -> void:
	chart_notes = _parse_osu_hitobjects(osu_file_path, lanes_count)
	chart_notes.sort_custom(func(a, b): return a["time"] < b["time"])
	total_notes_count = chart_notes.size()
	
	if chart_notes.is_empty():
		push_error("谱面数据为空，无法开始游戏。")
		return
	
	var first_note_time = chart_notes[0]["time"]
	var first_batch_lanes: Array[int] = []
	
	for note_data in chart_notes:
		# 50ms 内的 Note 算作同时出现，很蠢但未必没用）
		if abs(note_data["time"] - first_note_time) < 0.05: 
			if not first_batch_lanes.has(note_data["lane"]):
				first_batch_lanes.append(note_data["lane"])
		else:
			break
	
	for lane_idx in first_batch_lanes:
		var lane_x_center = lane_xs[lane_idx]
		_play_arrow_mark_animation(lane_x_center)
		
	await get_tree().create_timer(arrow_fade_duration * 2 + (1.0 - arrow_fade_duration)).timeout # 等待完整的淡入+停留+淡出
	
	if FileAccess.file_exists(audio_file_path):
		var stream = load(audio_file_path)
		audio.stream = stream
		audio.play()
		is_playing = true
	else:
		push_error("音频未找到")

func _process(_delta: float) -> void:
	if not is_playing: return
	var cur_time = audio.get_playback_position() + latency_offset
	
	var spawn_y_local = -100.0
	var hit_y_local_for_process = hit_y_local 
	
	while next_note_index < chart_notes.size():
		var note_data = chart_notes[next_note_index]
		var eff_travel := _effective_travel_time()
		if note_data["time"] - eff_travel <= cur_time + spawn_buffer:
			_spawn_note(note_data)
			next_note_index += 1
		else:
			break
	
	for i in range(active_notes.size() - 1, -1, -1):
		var n = active_notes[i]
		n.start_y = spawn_y_local
		n.end_y = hit_y_local_for_process
		n.update_visuals(cur_time)
		
		if cur_time > n.target_time + (miss_ms / 1000.0):
			_handle_miss(n)


func _input(event: InputEvent) -> void:
	if not is_playing: return
	if event is InputEventKey and event.pressed and not event.echo:
		for i in range(lanes_count):
			var action_name = "lane_%d" % i
			if event.is_action_pressed(action_name):
				_update_character_visuals(i)
				_try_hit(i)

func _update_character_visuals(lane_index: int) -> void:
	if not is_instance_valid(character_image):
		return

	var target_texture: Texture2D = null
	
	match lane_index:
		0:
			target_texture = character_texture_0
		1:
			target_texture = character_texture_1
		2:
			target_texture = character_texture_2
		3:
			target_texture = character_texture_3
		_:
			return

	if is_instance_valid(target_texture):
		character_image.texture = target_texture
		
func _play_arrow_mark_animation(lane_x: float) -> void:
	if not is_instance_valid(arrow_mark):
		push_warning("未设置 arrow_mark，无法播放箭头标记动画。")
		return
	
	arrow_mark.expand_mode = TextureRect.EXPAND_FIT_WIDTH 
	arrow_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED 
	
	# 使箭头略窄于轨道宽度
	var arrow_target_width = lane_width_px * 0.8
	arrow_mark.custom_minimum_size = Vector2(arrow_target_width, 0)
	
	arrow_mark.anchor_left = 0.0
	arrow_mark.anchor_right = 0.0
	arrow_mark.anchor_top = 0.0
	arrow_mark.anchor_bottom = 0.0
	
	var initial_y_center = hit_y_local + arrow_spawn_offset_y
	
	var final_x_pos = lane_x - (arrow_target_width / 2.0)
	arrow_mark.position.x = final_x_pos
	
	arrow_mark.position.y = initial_y_center 
	arrow_mark.modulate.a = 0.0
	arrow_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 等一帧计算
	await get_tree().process_frame 
	var arrow_height = arrow_mark.size.y
	
	var final_y_pos = initial_y_center - (arrow_height / 2.0)
	arrow_mark.position.y = final_y_pos
	
	# 动画部分
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 淡入动画
	tween.tween_property(arrow_mark, "modulate:a", 1.0, arrow_fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 向下移动动画
	tween.tween_property(arrow_mark, "position:y", final_y_pos + arrow_move_distance, arrow_fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished
	
	# 停留等待
	await get_tree().create_timer(1.0 - arrow_fade_duration).timeout 
	
	# 淡出动画
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(arrow_mark, "modulate:a", 0.0, arrow_fade_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	await fade_out_tween.finished
	arrow_mark.queue_free()

func _try_hit(lane: int) -> void:
	var cur_time = audio.get_playback_position() + latency_offset
	var candidate: Node = null
	var min_diff = 999.0
	
	for n in active_notes:
		if n.lane_index == lane and not n.is_hit:
			var diff = abs(cur_time - n.target_time)
			if diff < min_diff:
				min_diff = diff
				candidate = n
	
	if candidate == null: return
	
	var diff_ms = min_diff * 1000.0
	var score_add: int = 0
	
	if diff_ms <= perfect_ms:
		score_add = 300
		count_perfect += 1
		cri_label.text = "PERFECT"
		_show_criterion_temporarily()
		_calculate_combo(true)
	elif diff_ms <= great_ms:
		score_add = 100
		count_great += 1
		cri_label.text = "GREAT"
		_show_criterion_temporarily()
		_calculate_combo(true)
	elif diff_ms <= good_ms:
		score_add = 50
		count_good += 1
		cri_label.text = "GOOD"
		_show_criterion_temporarily()
		_calculate_combo(true)
	elif diff_ms <= miss_ms:
		score_add = 0
		count_miss += 1
		cri_label.text = "MISS"
		_show_criterion_temporarily()
		_calculate_combo(false)
	else:
		return
		
	_register_hit(candidate, score_add)

func _register_hit(n: Node, score_add: int) -> void:
	n.is_hit = true
	n.on_hit(score_add > 0)
	active_notes.erase(n)
	
	current_score += score_add
	total_hits += 1
	
	var acc = 0.0
	if total_hits > 0:
		acc = float(current_score) / float(total_hits * 300) * 100.0
	
	_update_score_ui(current_score, "%.2f%%" % acc)

func _handle_miss(n: Node) -> void:
	count_miss += 1
	n.on_miss()
	active_notes.erase(n)
	total_hits += 1
	cri_label.text = "MISS"
	_show_criterion_temporarily()
	
	_calculate_combo(false)
	
	var acc = 0.0
	if total_hits > 0:
		acc = float(current_score) / float(total_hits * 300) * 100.0
	
	_update_score_ui(current_score, "%.2f%%" % acc)

func _update_score_ui(sc: int, ac: String) -> void:
	if score_label: score_label.text = "[font_size=16][left]SCORE[/left][/font_size]
	
[font_size=32][center]%d[/center][/font_size]" % sc
	if acc_label: acc_label.text = "[font_size=16][left]ACCURACY[/left][/font_size]
	
[font_size=32][center]%s[/center][/font_size]" % ac
	
	var acc_percentage = 0.0
	if total_hits > 0:
		acc_percentage = float(current_score) / float(total_hits * 300) 
		
	_update_accuracy_indicator(acc_percentage)
		
func _update_accuracy_indicator(normalized_acc: float):
	if not is_instance_valid(acc_indicator): return
	
	var t = 1.0 - normalized_acc 
	var target_y = lerp(meter_y_top, meter_y_bottom, t)
	
	acc_indicator.position.y = target_y

func _setup_default_input_map() -> void:
	var keys = [KEY_D, KEY_F, KEY_J, KEY_K]
	for i in range(lanes_count):
		var action = "lane_%d" % i
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev = InputEventKey.new()
			ev.physical_keycode = keys[i % keys.size()]
			InputMap.action_add_event(action, ev)

func _parse_osu_hitobjects(path: String, lanes: int) -> Array:
	var out = []
	if not FileAccess.file_exists(path): 
		push_error("谱面文件未找到: " + path)
		return out
		
	var f = FileAccess.open(path, FileAccess.READ)
	var section = ""
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("["):
			section = line
			continue
		if section == "[HitObjects]" and line.count(",") >= 2:
			var p = line.split(",")
			var x = int(p[0])
			var t = int(p[2])
			
			var col = int(x * lanes / 512.0)
			col = clamp(col, 0, lanes - 1)
			
			out.append({"time": float(t) / 1000.0, "lane": col})
	return out

func _on_audio_finished() -> void:
	if game_over_triggered: return
	game_over_triggered = true
	
	print("Music finished. Waiting 5 seconds...")
	
	# 计算当前精确度
	var final_acc_percentage: float = 0.0
	if total_hits > 0:
		var acc_ratio = float(current_score) / float(total_hits * 300)
		final_acc_percentage = acc_ratio * 100.0
	
	# 检查是否低于 60%
	if final_acc_percentage < 60.0:
		print("Accuracy too low (<60%), showing Track Lost.")
		if is_instance_valid(track_lost_image):
			var tween = create_tween()
			# 动画将在 LaneContainer 的中心淡入
			tween.tween_property(track_lost_image, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	print("Waiting 5 seconds before result screen...")
	
	# 等待 5 秒，感觉有点长了，缩短为3秒
	await get_tree().create_timer(3.0).timeout
	
	_go_to_result_screen()

func _go_to_result_screen() -> void:
	# 用于结果展示的数据塞进 Global
	Global.last_score = current_score
	Global.max_combo = max_combo
	
	if total_hits > 0:
		Global.last_accuracy = float(current_score) / float(total_hits * 300) * 100.0
	else:
		Global.last_accuracy = 0.0
		
	Global.last_counts = {
		"perfect": count_perfect,
		"great": count_great,
		"good": count_good,
		"miss": count_miss
	}
	
	SceneTransition.change_scene(load("res://Scenes/Result.tscn"))
	
func _calculate_combo(type: bool) -> void:
	if type == true:
		combo += 1
		if combo > max_combo:
			max_combo = combo
	else:
		combo = 0
	return

# 计算流速
func _effective_travel_time() -> float:
	var s := 1.0
	if "speed" in Global:
		s = float(Global.speed)
	# 不太会整 setting 里那个流速填空框，只能先加点保险措施了
	if s <= 0.0:
		s = 1.0
	return travel_time * 3.5 / s
