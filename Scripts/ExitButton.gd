# ai script
# 没做确认窗口
extends Button

# 是否在退出前弹出确认对话（在 MainMenu 场景里可放一个 ConfirmationDialog 并命名为 ExitConfirm）
@export var confirm_before_exit: bool = false
@export var confirm_dialog_name: String = "ExitConfirm"  # ConfirmationDialog 的节点名（相对于 current_scene）

# 是否播放点击音效 & 在 Inspector 中设置 AudioStream（可不设置）
@export var play_click_sound: bool = true
@export var click_sound_stream: AudioStream

# 菜单音乐淡出时间（秒）
@export var fade_out_time: float = 0.5

# 内部变量
var _click_player: AudioStreamPlayer
var _pressed_once: bool = false
# var _connected_confirm: bool = false

func _ready() -> void:
	_pressed_once = false
	connect("pressed", Callable(self, "_on_pressed"))

	if play_click_sound and click_sound_stream:
		_click_player = AudioStreamPlayer.new()
		_click_player.stream = click_sound_stream
		add_child(_click_player)


func _on_pressed() -> void:
	# 防重复按
	if _pressed_once:
		return

	_pressed_once = true
	disabled = true
	_perform_exit()


# 当 ConfirmationDialog 发出 confirmed 信号时会调用这里
func _on_confirmed() -> void:
	# 确认后执行退出
	if _pressed_once:
		return
	_pressed_once = true
	disabled = true
	_perform_exit()


func _perform_exit() -> void:
	# 播放点击音效（非阻塞）
	if _click_player:
		_click_player.play()

	# 尝试淡出菜单音乐（场景中名为 AudioPreview 的 AudioStreamPlayer，会自动查找）
	var menu_audio: AudioStreamPlayer
	if get_tree().current_scene:
		menu_audio = get_tree().current_scene.get_node_or_null("AudioPreview")
	if menu_audio:
		# 等待淡出完成再退出
		await _fade_out_audio(menu_audio, fade_out_time)

	# 实际退出（deferred 更稳妥）
	get_tree().call_deferred("quit")


# 平滑淡出音频到 -80dB 并停止播放
func _fade_out_audio(audio: AudioStreamPlayer, duration: float) -> void:
	if duration <= 0.0:
		audio.stop()
		return

	var from_db: float = audio.volume_db
	var raw_steps: float = duration / 0.05
	var steps: int = max(1, int(ceil(raw_steps)))

	for i in range(steps):
		var t: float = float(i + 1) / float(steps)
		audio.volume_db = lerp(from_db, -80.0, t)
		await get_tree().create_timer(duration / steps).timeout

	audio.stop()
	audio.volume_db = from_db


# 尝试获取场景内的 ConfirmationDialog（如果不存在
