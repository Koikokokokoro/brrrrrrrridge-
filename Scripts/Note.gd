# ai script
extends Node2D

class_name Note

# --- 核心数据 (保持不变) ---
var target_time: float = 0.0
var lane_index: int = 0
var travel_time: float = 0.0
var start_y: float = 0.0
var end_y: float = 0.0
var lane_width: float = 0.0

var is_hit: bool = false
var is_active: bool = false
var pool_ref: Node = null # 对象池引用

# --- 节点引用 ---
@onready var note_sprite: Sprite2D = $Sprite2D 
# ‼️ 移除 @onready var animation_player: AnimationPlayer = $AnimationPlayer


## 1. 初始化和设置
func setup(t_time: float, lane: int, x_pos: float, s_y: float, e_y: float, t_time_total: float, l_width: float, texture: Texture2D):
	# 状态赋值
	target_time = t_time
	lane_index = lane
	start_y = s_y
	end_y = e_y
	travel_time = t_time_total
	lane_width = l_width
	is_hit = false
	is_active = true
	
	visible = true
	position.x = x_pos 
	
	# --- 贴图设置 ---
	if is_instance_valid(texture):
		note_sprite.texture = texture
		
		var texture_width = texture.get_width()
		
		if texture_width > 0:
			var scale_factor = l_width / texture_width
			note_sprite.scale = Vector2(scale_factor, scale_factor)

	# ‼️ 移除 animation_player.stop()

## 2. 运动更新
func update_visuals(current_time: float):
	if not is_active: return
	
	var time_diff = target_time - current_time
	var t = 1.0 - (time_diff / travel_time)
	
	t = clamp(t, -0.1, 1.1)
	
	position.y = lerp(start_y, end_y, t)

## 3. 击中/错过处理 (使用 queue_free 替代动画逻辑)
func on_hit(is_successful: bool):
	is_active = false
	
	if is_successful:
		queue_free()
	else:
		queue_free()

func on_miss():
	is_active = false
	# ‼️ 移除动画逻辑
	# 如果使用对象池，应调用 pool_ref.return_note(self)
	queue_free()

## 4. 对象池重置
func reset():
	target_time = 0.0
	lane_index = 0
	is_hit = false
	is_active = false
	visible = false
	position = Vector2.ZERO
