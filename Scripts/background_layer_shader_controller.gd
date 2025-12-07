# ai script
extends ColorRect

@export var center_local: Vector2 = Vector2(0.5, 0.9) # 局部中心，0..1
@export var radius_px: float = 2000.0                 # 半径（像素）
@export var feather_px: float = 2.0                  # 边缘羽化（像素）

@export var index_output_mode: int = 0
@export var color_orange: Color = Color(1.0, 0.6, 0.2, 0.9)
@export var color_green: Color  = Color(0.2, 0.8, 0.4, 0.9)

# 如果你希望强制覆盖 shader 的 canvas_size（不常用），可以填写此项（像素）
# 留空（0,0）表示使用节点本身的 rect_size
@export var canvas_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 初次同步
	_update_shader_params()
	# 连接 resized 信号（Control 专用），额外保险
	if has_signal("resized"):
		connect("resized", Callable(self, "_on_resized"))
	# 确保在树变换时也能更新（父变换改变、旋转、缩放等）
	# _notification 会捕获 NOTIFICATION_TRANSFORM_CHANGED / NOTIFICATION_RESIZED

func _notification(what: int) -> void:
	# Resize 或 Transform Changed 时刷新 shader 参数
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_RESIZED:
		_update_shader_params()

func _on_resized() -> void:
	_update_shader_params()

func _update_shader_params() -> void:
	var mat = material
	if mat == null:
		return
	# 在不同 Godot 版本 material 可能不是 ShaderMaterial，检查类型
	if typeof(mat) != TYPE_OBJECT:
		return
	# 确认是 ShaderMaterial
	if not (mat is ShaderMaterial):
		return

	# 1) 获取本地像素尺寸（Control 使用 rect_size）
	var rect_size_px: Vector2 = size
	if canvas_size_override != Vector2.ZERO:
		rect_size_px = canvas_size_override

	# 如果 rect_size 非法（0），防护返回
	if rect_size_px.x <= 0.0 or rect_size_px.y <= 0.0:
		return

	# 2) 取全局 Transform2D（把 local_px -> global_px）
	# 支持 Godot 3.x / 4.x：get_global_transform() 在两者中都存在
	var gxf = Transform2D()
	if has_method("get_global_transform"):
		gxf = get_global_transform()
	elif has_method("get_global_transform_2d"):
		gxf = get_global_transform()
	else:
		# 兜底 identity
		gxf = Transform2D()

	# Transform2D 的列向量（列 basis_x, basis_y）和 origin（像素）
	# Godot 的 Transform2D 在 GDScript 里可以通过 .x, .y, .origin 访问
	var basis_x = Vector2(1, 0)
	var basis_y = Vector2(0, 1)
	var origin = Vector2(0, 0)
	# 防护：有些版本/情况可能返回 PoolArray 等，使用 try/catch-like 防护
	# 这里按常规 API 获取
	basis_x = gxf.x
	basis_y = gxf.y
	origin = gxf.origin

	# 3) 把计算好的值传给 shader 参数（名字必须和 shader 中一致）
	mat.set_shader_parameter("u_basis_x", basis_x)
	mat.set_shader_parameter("u_basis_y", basis_y)
	mat.set_shader_parameter("u_origin_px", origin)
	mat.set_shader_parameter("u_rect_size_px", rect_size_px)
	mat.set_shader_parameter("u_center_local", center_local)
	mat.set_shader_parameter("radius_px", radius_px)
	mat.set_shader_parameter("feather_px", feather_px)
	mat.set_shader_parameter("index_output_mode", index_output_mode)
	mat.set_shader_parameter("color_orange", color_orange)
	mat.set_shader_parameter("color_green", color_green)

	# （可选）如果你希望 shader 里显示中心点以便调试，可以传 center_global_px：
	# var center_local_px = center_local * rect_size_px
	# var center_global_px = basis_x * center_local_px.x + basis_y * center_local_px.y + origin
	# mat.set_shader_param("u_center_global_px", center_global_px)

	# Debug 输出（可注释）
	#print("Shader params updated: rect=", rect_size_px, " origin=", origin, " basis_x=", basis_x, " basis_y=", basis_y)

# 外部接口：当你在运行时通过代码改了 center / radius 等，调用此方法可立即同步到 shader
func sync_to_shader() -> void:
	_update_shader_params()
