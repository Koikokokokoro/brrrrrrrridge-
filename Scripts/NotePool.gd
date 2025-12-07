# part ai script
extends Node

@export var note_scene: PackedScene 
@export var initial_pool_size: int = 50
@export var parent_node: Node = null # 接收 LaneContainer

var available_notes: Array = []

func _ready():
	# 移除自动创建逻辑，等待 Game.gd 调用 initialize_pool
	pass 

# 初始化函数，由 Game.gd 调用
func initialize_pool():
	if not note_scene:
		push_error("NotePool: 未分配 Note Scene！")
		return
	
	if not is_instance_valid(parent_node):
		push_error("NotePool: 无法初始化，parent_node 为空或无效！")
		return
		
	# 开始创建初始对象
	for i in range(initial_pool_size):
		var n = _create_new_note()
		_reset_note(n)
		available_notes.append(n)

func get_note() -> Node:
	if available_notes.is_empty():
		return _create_new_note()
	
	var n = available_notes.pop_back()
	n.set_process(true)
	n.visible = true
	return n

func release_note(n: Node):
	_reset_note(n)
	available_notes.append(n)

func _create_new_note() -> Node:
	var n = note_scene.instantiate()
	if is_instance_valid(parent_node):
		parent_node.add_child(n) 
	else:
		add_child(n) 
		push_error("NotePool: parent_node 未设置，音符层级可能错误。Note 将被添加到 NotePool.")
	n.pool_ref = self 
	return n

func _reset_note(n: Node):
	n.set_process(false)
	n.visible = false
	n.is_active = false
