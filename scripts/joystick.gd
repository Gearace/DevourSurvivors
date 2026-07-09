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

# ─── 内部状态 ─────────────────────────────────────────
var _center := Vector2.ZERO
var _inner_pos := Vector2.ZERO
var _drag_offset := Vector2.ZERO

func _ready() -> void:
    # 设置锚点为底部居中
    anchor_bottom = 1.0
    anchor_right = 0.5
    anchor_left = 0.5
    size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    size_flags_vertical = Control.SIZE_SHRINK_END
    
    # 设置大小
    custom_minimum_size = Vector2(outer_radius * 2.5, outer_radius * 2.5)
    
    # 计算中心点 (相对于控件)
    _center = Vector2(outer_radius * 1.25, outer_radius * 1.25)
    _inner_pos = _center
    
    # 禁用鼠标 (只接受触摸)
    mouse_filter = MOUSE_FILTER_PASS

func _process(delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    # 背景半透明圆
    draw_circle(_center, outer_radius, bg_color)
    
    # 外圈
    draw_arc(_center, outer_radius, 0, TAU, 64, outer_color, 2.0, true)
    
    # 内圈 (跟随手指的位置)
    draw_circle(_inner_pos, inner_radius, inner_color)
    
    # 中心点
    draw_circle(_center, 3.0, Color.WHITE * 0.3)

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        
        # 判断触摸是否在摇杆范围内
        var dist_to_center = touch.position.distance_to(_center)
        var in_range = dist_to_center < outer_radius * 1.5
        
        if touch.index == touch.id:
            pass  # 继续处理
        
        if touch.pressed and in_range and touch_id == -1:
            # 手指按下 — 开始拖动
            touch_id = touch.index
            active = true
            _drag_offset = touch.position - _inner_pos
            
            # 检查是否在死区内
            if dist_to_center < dead_zone:
                _inner_pos = _center
                direction = Vector2.ZERO
            else:
                _inner_pos = touch.position - _drag_offset
                _clamp_inner_position()
                direction = (_inner_pos - _center).normalized()
            
            moved.emit(direction)
            
        elif touch.pressed == false and touch.index == touch_id:
            # 手指抬起 — 释放摇杆
            _release()
            
        elif touch.pressed and touch.index == touch_id:
            # 拖动中 — 更新位置
            _inner_pos = touch.position - _drag_offset
            _clamp_inner_position()
            
            var dir = (_inner_pos - _center).normalized()
            var dist = _inner_pos.distance_to(_center)
            
            if dist > dead_zone:
                direction = dir
                moved.emit(direction)
            else:
                direction = Vector2.ZERO

func _clamp_inner_position() -> void:
    var offset = _inner_pos - _center
    var dist = offset.length()
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
    var parent = get_parent()
    if parent:
        return parent.to_global(_center)
    return _center
