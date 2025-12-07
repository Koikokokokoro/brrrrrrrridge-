# ai script
extends Button

# 在 Inspector 中指定要切换到的场景
@export var game_scene_file: PackedScene = preload("res://Game.tscn")

# 点击时是否播放音效
@export var play_click_sound: bool = true
@export var click_sound_stream: AudioStream

# 菜单音乐淡出时间（秒）- 建议设为 0.5 以配合转场动画
@export var fade_out_time: float = 0.5

var _click_player: AudioStreamPlayer = null
var _pressed_once: bool = false

func _ready() -> void:
	_pressed_once = false
	pressed.connect(_on_pressed)

	if play_click_sound and click_sound_stream:
		_click_player = AudioStreamPlayer.new()
		_click_player.stream = click_sound_stream
		add_child(_click_player)

func _on_pressed() -> void:
	if _pressed_once:
		return
	_pressed_once = true
	
	# 禁用按钮，防止多次点击
	disabled = true 

	# 1. 播放点击音效 (UI音效不淡出)
	if _click_player:
		_click_player.play()

	# 2. 获取主菜单的背景音乐并淡出
	# 这里的 "AudioPreview" 需要和你 MainMenu 场景里的节点名一致
	var menu_audio: AudioStreamPlayer = null
	if get_tree().current_scene:
		menu_audio = get_tree().current_scene.get_node_or_null("Control/AudioStreamPlayer2D")
	
	if menu_audio:
		_fade_out_bgm(menu_audio, fade_out_time)

	# 3. 调用转场动画切换场景
	if game_scene_file:
		# 确保你已经设置了 Autoload SceneTransition
		SceneTransition.change_scene(game_scene_file)
	else:
		push_error("StartButton: game_scene_file 未设置！")
		_pressed_once = false
		disabled = false

# 音频淡出逻辑
func _fade_out_bgm(audio: AudioStreamPlayer, duration: float) -> void:
	var tween = create_tween()
	# 线性或指数淡出到 -80dB (静音)
	tween.tween_property(audio, "volume_db", -80.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# 淡出结束后停止播放 (虽然场景马上要切换了，但这更是个好习惯)
	tween.tween_callback(audio.stop)
