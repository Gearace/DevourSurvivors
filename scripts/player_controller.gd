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
var _gesture_detector: GestureDetector
var _current_direction: Vector2 = Vector2.ZERO
var _speed_multiplier: float = 1.0
var _invincible_timer: float = 0.0
var _body_color: Color = Color(0.3, 0.8, 0.4)

# ─── 引用 ─────────────────────────────────────────
var _gm: Node
var _event_bus: Node

func _ready() -> void:
    # 获取全局引用
    _gm = get_tree().get_root().find_child("GameManager", true, false)
    _event_bus = get_tree().get_root().find_child("EventBus", true, false)
    
    # 初始化手势识别器
    _gesture_detector = GestureDetector.new()
    
    # 初始化身体
    _update_body_visuals()
    
    print("[Player] 初始化完成 — HP:", hp, " 速度:", base_speed)

func _process(delta: float) -> void:
    # 无敌计时器
    if _invincible_timer > 0:
        _invincible_timer -= delta
    
    # 平滑移动
    velocity = _current_direction * base_speed * _speed_multiplier
    move_and_slide()

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
    
    EventBus.skill_cast.emit(skill_type, direction)

## 吞噬判定 — 在 _physics_process 中调用
func _check_capture() -> void:
    """
    此方法由 WaveSpawner 每帧调用，传入敌人列表
    返回被吞噬的敌人 ID 列表
    """
    var captured = []
    
    # 获取场景中所有敌人
    var enemies = get_tree().get_nodes_in_group("enemies")
    
    for enemy in enemies:
        if not enemy is Node2D:
            continue
        
        var dist = global_position.distance_to(enemy.global_position)
        if dist <= capture_radius + (enemy as Node2D).get_meta("body_radius", 15.0):
            # 距离足够近，检查是否能吞噬
            var enemy_type = enemy.get_meta("enemy_type", "basic")
            var enemy_size = enemy.get_meta("body_radius", 15.0)
            
            if _can_capture(enemy_size):
                captured.append({
                    "node": enemy,
                    "type": enemy_type,
                    "size": enemy_size,
                })
    
    return captured

## 判断能否吞噬该敌人
func _can_capture(enemy_size: float) -> bool:
    return body_radius >= enemy_size * 0.8

## 执行吞噬
func execute_capture(enemy_data: Dictionary) -> void:
    var enemy_node = enemy_data["node"]
    var enemy_type = enemy_data["type"]
    var enemy_size = enemy_data["size"]
    
    # 计算吞噬收益
    var capture_value = _get_capture_value(enemy_type, enemy_size)
    
    # 通知 GameManager
    if _gm:
        _gm.on_enemy_captured(enemy_type, capture_value)
    
    # 通知 EventBus
    if _event_bus:
        _event_bus.player_captured_enemy.emit(enemy_type, capture_value)
    
    # 更新玩家体型
    body_radius += capture_value * 0.5
    capture_radius = body_radius + 10.0
    _update_body_visuals()
    
    # 移除敌人
    enemy_queue_free(enemy_node)
    
    print("[Player] 吞噬了 ", enemy_type, " (+", round(capture_value), ")")

## 获取吞噬收益值
func _get_capture_value(enemy_type: String, enemy_size: float) -> float:
    var values = {
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
        _event_bus.player_hit.emit(amount)
    
    if hp <= 0:
        hp = 0
        print("[Player] 玩家阵亡!")
        if _gm:
            _gm.player_died.emit()

## 更新身体视觉
func _update_body_visuals() -> void:
    # 根据体型调整颜色和大小
    var scale = body_radius / 20.0  # 以初始大小为单位
    scale = clamp(scale, 0.8, 3.0)
    scale_node(scale)
    
    # 体型越大颜色越深
    var brightness = clamp(1.0 / scale, 0.3, 1.0)
    _body_color = Color(0.3 * brightness, 0.8 * brightness, 0.4 * brightness)

## 缩放节点
func scale_node(new_scale: float) -> void:
    scale = Vector2(new_scale, new_scale)

## 从队列中移除敌人 (安全方式)
func enemy_queue_free(enemy_node) -> void:
    if is_instance_valid(enemy_node):
        enemy_node.queue_free()
