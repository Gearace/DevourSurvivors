extends RefCounted
## GestureDetector — 手势识别器
## 核心职责：从触摸事件中解析出三种手势
##   1. MOVE (拖拽移动)
##   2. SKIPE (快速划过 → 指向性技能)
##   3. DOUBLE_CLICK (双击 → 非指向性技能)
##
## 使用方式：
##   var detector = GestureDetector.new()
##   detector.process_event(event)  # 每帧传入 InputEventScreenTouch
##   var result = detector.get_last_gesture()

# ─── 手势常量 ─────────────────────────────────────────
const MOVE_THRESHOLD        := 30.0   # 位移超过此值才可能触发技能
const SWIPE_MIN_SPEED       := 150.0  # 划屏最小速度 (px/s)
const SWIPE_MIN_DISTANCE    := 30.0   # 划屏最小位移 (px)
const SWIPE_MAX_DURATION    := 500.0  # 划屏最大耗时 (ms)
const DOUBLE_CLICK_WINDOW   := 300.0  # 双击时间窗口 (ms)
const DOUBLE_CLICK_RADIUS   := 20.0   # 双击位置容差 (px)
const TAP_RADIUS            := 15.0   # 点击 vs 拖拽的容差

# ─── 手势类型 ─────────────────────────────────────────
enum GestureType {
    NONE,          # 无手势
    MOVE,          # 拖拽移动
    SWIPE,         # 快速划过 (指向性技能)
    DOUBLE_CLICK,  # 双击 (非指向性技能)
}

# ─── 内部状态 ─────────────────────────────────────────
var _touch_down := false
var _touch_pos := Vector2.ZERO
var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0
var _last_touch_time := 0.0
var _last_touch_pos := Vector2.ZERO
var _last_gesture := GestureType.NONE
var _gesture_data := {}

# ─── 公开属性 ─────────────────────────────────────────
var debug_enabled := false

# ─── 公共 API ─────────────────────────────────────────

## 处理触摸事件，返回解析后的手势类型
func process_event(event: InputEventScreenTouch) -> GestureType:
    match event.pressed:
        true:  # 手指按下
            _on_touch_down(event.position)
        false: # 手指抬起
            return _on_touch_up(event.position)
    return GestureType.NONE

## 处理鼠标事件 (用于编辑器测试)
func process_mouse_event(event: InputEventMouseButton) -> GestureType:
    match event.button_index:
        MOUSE_BUTTON_LEFT:
            if event.pressed:
                _on_touch_down(event.position)
            else:
                return _on_touch_up(event.position)
    return GestureType.NONE

## 重置所有状态
func reset() -> void:
    _touch_down = false
    _last_gesture = GestureType.NONE
    _gesture_data = {}
    if debug_enabled:
        print("[GestureDetector] 已重置")

# ─── 私有方法 ─────────────────────────────────────────

func _on_touch_down(pos: Vector2) -> void:
    _touch_down = true
    _touch_start_pos = pos
    _touch_pos = pos
    _touch_start_time = Time.get_ticks_msec()
    
    # 双击检测：检查是否是第二次点击
    var time_since_last = Time.get_ticks_msec() - _last_touch_time
    var dist_from_last = _touch_start_pos.distance_to(_last_touch_pos)
    
    if time_since_last < DOUBLE_CLICK_WINDOW and dist_from_last < DOUBLE_CLICK_RADIUS:
        # 这是双击的第二次点击，先标记为候选，等抬起时确认
        _gesture_data["is_double_click_candidate"] = true
    else:
        _gesture_data["is_double_click_candidate"] = false

func _on_touch_up(pos: Vector2) -> GestureType:
    if not _touch_down:
        _touch_down = false
        return GestureType.NONE
    
    _touch_down = false
    var end_pos = pos
    var elapsed = Time.get_ticks_msec() - _touch_start_time
    var displacement = _touch_start_pos.distance_to(end_pos)
    var speed = 0.0
    if elapsed > 0:
        speed = displacement / (elapsed / 1000.0)
    
    var direction = Vector2.ZERO
    if displacement > 0.1:
        direction = (end_pos - _touch_start_pos).normalized()
    
    # 更新最后一次触摸位置和时间
    _last_touch_time = Time.get_ticks_msec()
    _last_touch_pos = _touch_start_pos
    
    # 判断手势类型 (优先级: 双击 > 划屏 > 移动)
    var gesture = GestureType.NONE
    
    if _gesture_data.get("is_double_click_candidate", false):
        # 双击候选 → 确认为双击
        gesture = GestureType.DOUBLE_CLICK
        _gesture_data = {
            "type": "double_click",
            "position": _touch_start_pos,
            "displacement": displacement,
            "speed": speed,
        }
    elif displacement >= SWIPE_MIN_DISTANCE and speed >= SWIPE_MIN_SPEED and elapsed <= SWIPE_MAX_DURATION:
        # 划屏
        gesture = GestureType.SWIPE
        _gesture_data = {
            "type": "swipe",
            "direction": direction,
            "speed": speed,
            "distance": displacement,
            "duration": elapsed,
        }
    else:
        # 拖拽移动
        gesture = GestureType.MOVE
        _gesture_data = {
            "type": "move",
            "direction": direction if displacement > TAP_RADIUS else Vector2.ZERO,
            "distance": displacement,
            "duration": elapsed,
        }
    
    _last_gesture = gesture
    
    if debug_enabled:
        print("[GestureDetector] ", _gesture_type_to_string(gesture), 
              " | 位移:", round(displacement), "px",
              " | 速度:", round(speed), "px/s",
              " | 耗时:", round(elapsed), "ms")
    
    return gesture

func get_last_gesture() -> GestureType:
    return _last_gesture

func get_last_gesture_data() -> Dictionary:
    return _gesture_data.duplicate()

func _gesture_type_to_string(gesture: GestureType) -> String:
    match gesture:
        GestureType.NONE: return "NONE"
        GestureType.MOVE: return "MOVE"
        GestureType.SWIPE: return "SWIPE"
        GestureType.DOUBLE_CLICK: return "DOUBLE_CLICK"
    return "UNKNOWN"
