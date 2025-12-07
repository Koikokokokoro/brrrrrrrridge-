# 绘制结算画面的射线，part ai script
extends Node2D

@export var center_ratio: Vector2 = Vector2(0.5, 0.9)     # anchor (0..1)
@export var default_line_color: Color = Color(1,1,1,1)
@export var default_line_width: float = 4.0
@export var auto_update_on_resize: bool = true           # 视口大小变时自动重建

# 最近一次创建射线的参数
var _last_sorted_angles: Array = []
var _last_ray_length: float = 0.0

func _ready() -> void:
	var vp: Viewport = get_viewport()
	if vp and vp.has_signal("size_changed"):
		vp.connect("size_changed", Callable(self, "_on_viewport_size_changed"))

# 创建射线
func create_rays(sorted_angles_rad: Array, ray_length: float, center_override = null) -> void:
	_last_sorted_angles = sorted_angles_rad.duplicate()
	_last_ray_length = ray_length

	clear_rays()

	var center_global: Vector2 = Vector2.ZERO
	if center_override != null:
		center_global = center_override
	else:
		center_global = _get_viewport_center_global()
	var local_center: Vector2 = to_local(center_global)

	for a_rad in sorted_angles_rad:
		var dir_screen: Vector2 = Vector2(cos(a_rad), sin(a_rad))
		var end_global: Vector2 = center_global + dir_screen * ray_length
		var local_end: Vector2 = to_local(end_global)

		var line: Line2D = Line2D.new()
		line.default_color = default_line_color
		line.width = default_line_width

		if "begin_cap_mode" in line:
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		if "end_cap_mode" in line:
			line.end_cap_mode = Line2D.LINE_CAP_ROUND

		line.add_point(local_center)
		line.add_point(local_end)
		line.set_meta("target_end", local_end)
		line.points[1] = local_center

		add_child(line)

# 清空已有射线
func clear_rays() -> void:
	for child in get_children():
		if child and child.get_parent() == self:
			child.queue_free()

# 调试绘制标记
func debug_draw_markers(sorted_angles_rad: Array, ray_length: float, center_override = null) -> void:
	var center_global: Vector2 = Vector2.ZERO
	if center_override != null:
		center_global = center_override
	else:
		center_global = _get_viewport_center_global()

	var _local_center: Vector2 = to_local(center_global)
	var i: int = 0

	for a_rad in sorted_angles_rad:
		var dir_screen: Vector2 = Vector2(cos(a_rad), sin(a_rad))
		var pt_global: Vector2 = center_global + dir_screen * (ray_length * 0.6)
		var pt_local: Vector2 = to_local(pt_global)

		var dot: ColorRect = ColorRect.new()
		dot.color = Color(1, 0, 0)
		dot.rect_size = Vector2(6,6)
		dot.pivot_offset = dot.rect_size * 0.5
		dot.position = pt_local
		add_child(dot)

		var label: Label = Label.new()
		label.text = str(i)
		label.position = pt_local + Vector2(8, -8)
		add_child(label)

		i += 1

# 计算视口中心（全局像素坐标）
func _get_viewport_center_global() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp:
		if vp.has_method("get_visible_rect"):
			var rect: Rect2 = vp.get_visible_rect()
			return rect.size * center_ratio
		if "size" in vp:
			return vp.size * center_ratio
		if vp.has_method("get_size"):
			return vp.get_size() * center_ratio
	return Vector2.ZERO

# viewport resize 回调
func _on_viewport_size_changed() -> void:
	if not auto_update_on_resize:
		return
	if _last_sorted_angles.size() > 0 and _last_ray_length > 0.0:
		# 重新生成射线，使用新的中心
		create_rays(_last_sorted_angles, _last_ray_length, null)

# 可选：统一修改线条样式
func set_line_style(width: float, color: Color) -> void:
	default_line_width = width
	default_line_color = color
