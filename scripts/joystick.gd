extends Control
## VirtualJoystick — 底部居中的虚拟摇杆
## 
## 功能：
##   · 外圈固定不动，内圈跟随手指拖动
##   · 返回归一化的方向向量 (Vector2)
##   · 手指离开后内圈回弹到中心
##   · 支持多点触控 (只响应第一个触摸点)
##
## 使用方式：
##   joystick.direction  → 获取方向向量
##   joystick.active     → 是否正在被拖动
##   连接信号: joystick_moved(direction), joystick_released()

# ─── 手势常量 ─────────────────────────────────────────
## SizeFlags 兼容值 (Godot 4.x/4.7)

# ─── 公开信号 ─────────────────────────────────────────
signal moved(direction: Vector2)
signal released

# ─── 公开属性 ─────────────────────────────────────────
var direction: Vector2 = Vector2.ZERO
var active: bool = false
var touch_id: int = -1

# ─── 配置参数 ─────────────────────────────────────────
@export var outer_radius: float = 60.0    # 外圈半径
@export var inner_radius: float = 25.0    # 内圈半径
@export var dead_zone: float = 10.0       # 死区半径
@export var outer_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var inner_color: Color = Color(0.6, 0.6, 0.6, 0.8)
@export var bg_color: Color = Color(0.1, 0.1, 0.15, 0.3)

var tex_outer = preload("res://assets/ui/joystick/ui_joystick_outer.png")
var tex_inner = preload("res://assets/ui/joystick/ui_joystick_inner.png")

# ─── 内部状态 ─────────────────────────────────────────
var _center := Vector2.ZERO
var _inner_pos := Vector2.ZERO
var _drag_offset := Vector2.ZERO

func _ready() -> void:
    # 设置锚点为底部居中
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_top = 1.0
    anchor_bottom = 1.0
    
    # 设置大小
    var size = outer_radius * 2.5
    custom_minimum_size = Vector2(size, size)
    
    # 设置相对于底部居中锚点的位置偏移 (居中，并距离屏幕底部留出 50 像素边距)
    offset_left = -size / 2.0
    offset_right = size / 2.0
    offset_top = -size - 50.0
    offset_bottom = -50.0
    
    # 计算中心点 (相对于控件)
    _center = Vector2(size / 2.0, size / 2.0)
    _inner_pos = _center
    
    # 启用鼠标/触摸事件响应
    mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    # If textures are loaded, draw them. Otherwise, fall back to vector drawing.
    if tex_outer:
        var rect_outer = Rect2(_center - Vector2(outer_radius, outer_radius), Vector2(outer_radius * 2, outer_radius * 2))
        draw_texture_rect(tex_outer, rect_outer, false)
    else:
        # 背景半透明圆
        draw_circle(_center, outer_radius, bg_color)
        # 外圈
        draw_arc(_center, outer_radius, 0, TAU, 64, outer_color, 2.0, true)
    
    if tex_inner:
        var rect_inner = Rect2(_inner_pos - Vector2(inner_radius, inner_radius), Vector2(inner_radius * 2, inner_radius * 2))
        draw_texture_rect(tex_inner, rect_inner, false)
    else:
        # 内圈 (跟随手指的位置)
        draw_circle(_inner_pos, inner_radius, inner_color)
        
    # 中心点
    draw_circle(_center, 3.0, Color.WHITE * 0.3)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb = event as InputEventMouseButton
        var local_pos = mb.position
        var dist_to_center = local_pos.distance_to(_center)
        var in_range = dist_to_center < outer_radius * 1.5
        
        if mb.pressed and in_range and touch_id == -1:
            touch_id = 999 # 鼠标虚拟ID
            active = true
            _drag_offset = local_pos - _inner_pos
            if dist_to_center < dead_zone:
                _inner_pos = _center
                direction = Vector2.ZERO
            else:
                _inner_pos = local_pos - _drag_offset
                _clamp_inner_position()
                direction = (_inner_pos - _center).normalized()
            moved.emit(direction)
            queue_redraw()
        elif not mb.pressed and touch_id == 999:
            _release()
            
    elif event is InputEventMouseMotion:
        var mm = event as InputEventMouseMotion
        if touch_id == 999 and active:
            var local_pos = mm.position
            _inner_pos = local_pos - _drag_offset
            _clamp_inner_position()
            var dir = (_inner_pos - _center).normalized()
            var dist = _inner_pos.distance_to(_center)
            if dist > dead_zone:
                direction = dir
                moved.emit(direction)
            else:
                direction = Vector2.ZERO
            queue_redraw()
            
    elif event is InputEventScreenTouch:
        var touch = event as InputEventScreenTouch
        var local_pos = touch.position
        var dist_to_center = local_pos.distance_to(_center)
        var in_range = dist_to_center < outer_radius * 1.5
        
        if touch.pressed and in_range and touch_id == -1:
            touch_id = touch.index
            active = true
            _drag_offset = local_pos - _inner_pos
            if dist_to_center < dead_zone:
                _inner_pos = _center
                direction = Vector2.ZERO
            else:
                _inner_pos = local_pos - _drag_offset
                _clamp_inner_position()
                direction = (_inner_pos - _center).normalized()
            moved.emit(direction)
            queue_redraw()
        elif not touch.pressed and touch.index == touch_id:
            _release()
            
    elif event is InputEventScreenDrag:
        var drag = event as InputEventScreenDrag
        if drag.index == touch_id and active:
            var local_pos = drag.position
            _inner_pos = local_pos - _drag_offset
            _clamp_inner_position()
            var dir = (_inner_pos - _center).normalized()
            var dist = _inner_pos.distance_to(_center)
            if dist > dead_zone:
                direction = dir
                moved.emit(direction)
            else:
                direction = Vector2.ZERO
            queue_redraw()

func _clamp_inner_position() -> void:
    var offset = _inner_pos - _center
    var dist: float = offset.length()
    if dist > outer_radius:
        _inner_pos = _center + offset.normalized() * outer_radius

func _release() -> void:
    active = false
    direction = Vector2.ZERO
    _inner_pos = _center
    touch_id = -1
    released.emit()
    queue_redraw()

## 获取摇杆中心的世界坐标
func get_world_center() -> Vector2:
    var parent = get_parent() as Node2D
    if parent:
        return parent.to_global(_center)
    return _center
