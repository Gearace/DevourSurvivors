extends Node
## MainGame — 主游戏场景控制器
## 负责初始化各系统、连接信号、协调游戏流程

var _player: CharacterBody2D
var _joystick: Control
var _gesture_detector: Object
var _wave_spawner: Node
var _pool: Node2D
var _skill_system: Node
var _captured_this_wave: int = 0

func _ready() -> void:
    # 获取子节点
    _player = get_node("Player") as CharacterBody2D
    _joystick = get_node("Joystick") as Control
    _wave_spawner = get_node("WaveSpawner")
    _pool = get_node("ObjectPool")
    _skill_system = get_node("SkillSystem")
    
    # 连接摇杆信号
    if _player and _joystick:
        _player.connect_joystick(_joystick)
        print("[MainGame] 摇杆已连接到玩家")
    
    # 初始化手势识别器
    _gesture_detector = preload("res://scripts/gesture_detector.gd").new()
    
    # 连接波次信号
    _wave_spawner.wave_starting.connect(_on_wave_starting)
    _wave_spawner.wave_complete.connect(_on_wave_complete)
    
    # 连接吞噬信号
    _player.player_captured_enemy.connect(_on_player_captured)
    
    # 设置游戏状态
    var gm = get_node_or_null("/root/GameManager")
    if gm:
        gm.set_state(1)
        print("[MainGame] 游戏状态: PLAYING")
    
    # 开始第一波
    await get_tree().create_timer(1.0).timeout
    if _wave_spawner:
        _wave_spawner.start_wave(1)
    
    print("[MainGame] 场景初始化完成")

func _on_wave_starting(wave_num: int) -> void:
    print("[MainGame] === 波次 ", wave_num, " ===")
    _captured_this_wave = 0

func _on_wave_complete(wave_num: int) -> void:
    print("[MainGame] 波次 ", wave_num, " 完成! 吞噬:", _captured_this_wave)

func _on_player_captured(type: String, value: float) -> void:
    _captured_this_wave += 1
    if _wave_spawner:
        _wave_spawner.on_enemy_captured()

func _process(delta: float) -> void:
    # 每帧更新敌人玩家引用
    if _player and _pool:
        var enemies = _pool.get_active_enemies()
        for enemy in enemies:
            if enemy and enemy.has_method("set_player_reference"):
                enemy.set_player_reference(_player)

const MOUSE_BUTTON_LEFT := 1
const KEY_ESCAPE := 4163

func _unhandled_input(event: InputEvent) -> void:
    """处理全局输入"""
    if _gesture_detector == null:
        return
    
    var gesture: int = 0
    var data: Dictionary = {}
    
    if event is InputEventScreenTouch:
        gesture = _gesture_detector.process_event(event)
        data = _gesture_detector.get_last_gesture_data()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        gesture = _gesture_detector.process_mouse_event(event)
        data = _gesture_detector.get_last_gesture_data()
    
    if gesture != 0 and _player:
        _player.handle_gesture(gesture, data)
    
    # ESC 暂停
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        var gm = get_node_or_null("/root/GameManager")
        if gm:
            if gm.current_state == 1:
                gm.set_state(2)
            elif gm.current_state == 2:
                gm.set_state(1)
