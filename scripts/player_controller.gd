extends CharacterBody2D
## PlayerController — 玩家移动 + 吞噬判定
##
## 职责：
##   · 接收摇杆方向信号，更新移动速度
##   · 接收手势识别结果，触发技能
##   · 碰撞检测：吞噬/弹开敌人
##   · 管理玩家状态 (HP/体型/速度)
##
## 依赖：
##   · GameManager (读取全局数据)
##   · GestureDetector (手势解析)
##   · EventBus (发送吞噬事件)

# ─── 公开属性 ─────────────────────────────────────────
@export var base_speed: float = 200.0       # 基础移动速度
@export var capture_radius: float = 40.0    # 吞噬判定半径
@export var body_radius: float = 20.0       # 身体渲染半径
@export var hp: int = 100                   # 生命值
@export var max_hp: int = 100               # 最大生命值

# ─── 内部状态 ─────────────────────────────────────────
var _gesture_detector: Object
var _current_direction: Vector2 = Vector2.ZERO
var _speed_multiplier: float = 1.0
var _invincible_timer: float = 0.0
var _body_color: Color = Color(0.3, 0.8, 0.4)
var _gm: Node
var _event_bus: Node
var _pool: Node2D
var _last_capture_check: float = 0.0

# ─── 信号 ─────────────────────────────────────────
signal player_captured_enemy(enemy_type: String, value: float)

func _ready() -> void:
    # 获取全局引用
    _gm = get_node_or_null("/root/GameManager")
    _event_bus = get_node_or_null("/root/EventBus")
    _pool = get_node_or_null("../ObjectPool")
    
    # 初始化身体视觉
    _update_body_visuals()
    
    print("[Player] 初始化完成 — HP:", hp, " 速度:", base_speed, " 半径:", body_radius)

func _process(delta: float) -> void:
    # 无敌计时器
    if _invincible_timer > 0:
        _invincible_timer -= delta
    
    # 平滑移动
    velocity = _current_direction * base_speed * _speed_multiplier
    move_and_slide()
    
    # 定期执行吞噬判定 (每 0.1s 一次，避免每帧计算)
    _last_capture_check -= delta
    if _last_capture_check <= 0:
        _last_capture_check = 0.1
        _check_and_capture()

func _on_joystick_moved(dir: Vector2) -> void:
    """摇杆移动信号"""
    _current_direction = dir

func _on_joystick_released() -> void:
    """摇杆释放信号"""
    _current_direction = Vector2.ZERO

## 连接摇杆信号 (由 MainGame 调用)
func connect_joystick(joystick_node) -> void:
    joystick_node.moved.connect(_on_joystick_moved)
    joystick_node.released.connect(_on_joystick_released)

## 处理手势事件 (由 MainGame 调用)
func handle_gesture(gesture_type: int, data: Dictionary) -> void:
    """
    gesture_type: 0=NONE, 1=MOVE, 2=SWIPE, 3=DOUBLE_CLICK
    """
    match gesture_type:
        1:  # MOVE — 已在 _on_joystick_moved 中处理
            pass
        2:  # SWIPE — 指向性技能
            if _gm and _gm.is_playing():
                print("[Player] 划屏技能! 方向:", data.get("direction", Vector2.ZERO))
                _cast_skill("swipe", data)
        3:  # DOUBLE_CLICK — 非指向性技能
            if _gm and _gm.is_playing():
                print("[Player] 双击技能!")
                _cast_skill("double_click", data)

## 释放技能
func _cast_skill(skill_type: String, data: Dictionary) -> void:
    var direction = Vector2.ZERO
    if skill_type == "swipe":
        direction = data.get("direction", Vector2.RIGHT)
    
    if _event_bus:
        _event_bus.emit_signal("skill_cast", skill_type, direction)

## 吞噬判定 — 每 0.1s 执行一次
func _check_and_capture() -> void:
    if _gm == null or not _gm.is_playing():
        return
    
    var enemies = _pool.get_active_enemies() if _pool else []
    
    for enemy in enemies:
        if enemy == null or not enemy.active:
            continue
        
        var dist = global_position.distance_to(enemy.global_position)
        
        # 安全获取 enemy body_radius
        var enemy_radius: float = 15.0
        if enemy.has_meta("body_radius"):
            enemy_radius = enemy.get_meta("body_radius")
        
        if dist <= capture_radius + enemy_radius:
            # 距离足够近，检查能否吞噬
            if _can_capture(enemy_radius):
                _execute_capture(enemy)
                break  # 每次只吞噬一个，避免瞬间吞太多

## 判断能否吞噬该敌人
func _can_capture(enemy_size: float) -> bool:
    return body_radius >= enemy_size * 0.8

## 执行吞噬
func _execute_capture(enemy) -> void:
    # 安全获取 enemy_type
    var enemy_type: String = "basic"
    if enemy.has_meta("enemy_type"):
        enemy_type = enemy.get_meta("enemy_type")
    
    # 安全获取 enemy body_radius
    var enemy_size: float = 15.0
    if enemy.has_meta("body_radius"):
        enemy_size = enemy.get_meta("body_radius")
    
    var capture_value = _get_capture_value(enemy_type, enemy_size)
    
    # 通知 GameManager
    if _gm:
        _gm.on_enemy_captured(enemy_type, capture_value)
    
    # 通知 EventBus
    if _event_bus:
        _event_bus.emit_signal("player_captured_enemy", enemy_type, capture_value)
    
    # 触发信号
    player_captured_enemy.emit(enemy_type, capture_value)
    
    # 更新玩家体型
    body_radius += capture_value * 0.5
    capture_radius = body_radius + 10.0
    _update_body_visuals()
    
    # 从对象池回收敌人
    if _pool:
        _pool.despawn(enemy)
    
    print("[Player] 吞噬了 ", enemy_type, " (+", round(capture_value), ")")

## 获取吞噬收益值
func _get_capture_value(enemy_type: String, enemy_size: float) -> float:
    var values: Dictionary = {
        "basic": 1.0,
        "swift": 0.5,
        "heavy": 3.0,
        "split": 1.5,
        "decoy": 0.0,
        "boss": 10.0,
    }
    return values.get(enemy_type, 1.0)

## 受到伤害
func take_damage(amount: int) -> void:
    if _invincible_timer > 0:
        return
    
    hp -= amount
    _invincible_timer = 0.5  # 0.5s 无敌帧
    
    if _event_bus:
        _event_bus.emit_signal("player_hit", amount)
    
    if hp <= 0:
        hp = 0
        print("[Player] 玩家阵亡!")
        if _gm:
            _gm.player_died.emit()

## 更新身体视觉
func _update_body_visuals() -> void:
    # 根据体型调整颜色和大小
    var scale: float = body_radius / 20.0  # 以初始大小为单位
    scale = clamp(scale, 0.8, 3.0)
    scale_node(scale)
    
    # 体型越大颜色越深
    var brightness: float = clamp(1.0 / scale, 0.3, 1.0)
    _body_color = Color(0.3 * brightness, 0.8 * brightness, 0.4 * brightness)
    
    # 更新身体颜色
    var body = get_node_or_null("Body")
    if body and body is ColorRect:
        body.color = _body_color

## 缩放节点
func scale_node(new_scale: float) -> void:
    scale = Vector2(new_scale, new_scale)
