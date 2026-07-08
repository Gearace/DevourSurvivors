extends Node
## MainGame — 主游戏场景控制器
## 负责初始化各系统、连接信号、协调游戏流程

var _player: CharacterBody2D
var _joystick: Control
var _gesture_detector: GDScript

func _ready() -> void:
    # 获取子节点
    _player = get_node("Player") as CharacterBody2D
    _joystick = get_node("Joystick") as Control
    
    # 连接摇杆信号到玩家
    if _player and _joystick:
        _player.connect_joystick(_joystick)
        _joystick.moved.connect(func(dir): _player._on_joystick_moved(dir))
        _joystick.released.connect(func(): _player._on_joystick_released())
        print("[MainGame] 摇杆已连接到玩家")
    
    # 初始化手势识别器
    _gesture_detector = preload("res://scripts/gesture_detector.gd").new()
    
    # 设置游戏状态为 PLAYING
    var gm = get_node_or_null("GameManager")
    if gm:
        gm.set_state(1)  # GameState.PLAYING
        print("[MainGame] 游戏状态: PLAYING")
    
    print("[MainGame] 场景初始化完成")

func _unhandled_input(event: InputEvent) -> void:
    """处理全局输入 (用于编辑器鼠标测试)"""
    if _gesture_detector == null:
        return
    
    var gesture = 0
    var data = {}
    
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
        var gm = get_node_or_null("GameManager")
        if gm:
            if gm.current_state == 1:  # PLAYING
                gm.set_state(2)  # PAUSED
            elif gm.current_state == 2:
                gm.set_state(1)
