extends Node
## MainGame — 主游戏场景控制器
## 负责初始化各系统、连接信号、协调游戏流程

var _player: CharacterBody2D
var _joystick: Control
var _gesture_detector: Object
var _wave_spawner: Node

var _route_ui: CanvasLayer
var _run_over: CanvasLayer
var _route_generator: Node
var _pool: Node2D
var _skill_system: Node2D
var _captured_this_wave: int = 0
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

func _ready() -> void:
	# 动态创建固定场地背景 (720x1280)
	var bg_sprite = Sprite2D.new()
	bg_sprite.name = "Background"
	bg_sprite.texture = load("res://assets/backgrounds/bg_gameplay.png")
	bg_sprite.centered = true
	bg_sprite.position = Vector2(360, 640)
	bg_sprite.z_index = -10 # 确保在最底层渲染
	add_child(bg_sprite)

	_player = get_node("Player") as CharacterBody2D
	_joystick = get_node("JoystickLayer/Joystick") as Control
	_wave_spawner = get_node("WaveSpawner")
	_route_generator = get_node_or_null("RouteGenerator")
	_route_ui = get_node_or_null("RouteUI")
	_run_over = get_node_or_null("RunOver")
	_pool = get_node("ObjectPool") as Node2D

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
	_wave_spawner.decision_needed.connect(_on_decision_needed)
	if _route_ui:
		_route_ui.node_chosen.connect(_on_route_chosen)

	# 连接屏幕抖动信号
	var bus = get_node_or_null("EventBus")
	if bus and bus.has_signal("screen_shake"):
		bus.screen_shake.connect(_on_screen_shake)
	
	# 连接吞噬信号
	_player.player_captured_enemy.connect(_on_player_captured)
	
	# 设置游戏状态
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_state(GameManager.GameState.PLAYING)
		print("[MainGame] 游戏状态: PLAYING")
	
	# 路线化开局：roll 13 层路线 → 第 1 层固定普通波
	await get_tree().create_timer(1.0).timeout
	if _route_generator:
		_route_generator.generate_run()
	if _route_ui and _route_generator:
		_route_ui.bind(_wave_spawner, _route_generator)
	if _run_over:
		_run_over.bind(_wave_spawner, _route_generator)
	# 第 1 层固定普通波：直接生成 pack 启动
	if _route_generator:
		var p1 = _route_generator.pick_option(1, 0)
		if _wave_spawner:
			_wave_spawner.start_node(p1)
	
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
	# 处理全局输入
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
				gm.set_state(GameManager.GameState.PAUSED)
			elif gm.current_state == 2:
				gm.set_state(GameManager.GameState.PLAYING)
## 响应屏幕抖动 (来自 EventBus)
func _on_screen_shake(duration: float, intensity: float) -> void:
	_shake_timer = duration
	_shake_intensity = intensity
func _get_player_camera() -> Node:
	if _player and _player.has_node("Camera2D"):
		return _player.get_node("Camera2D")
	return null

## 路线：下一层决策时刻
func _on_decision_needed(floor: int) -> void:
	if _route_generator == null or _route_ui == null:
		return
	var rec = null
	for r in _route_generator.get_run_route():
		if r.floor == floor:
			rec = r
			break
	if rec == null:
		return
	_route_ui.show_decision(floor, rec.options)

func _on_route_chosen(pack: Dictionary) -> void:
	# pack 已交给 spawner.start_node（RouteUI 内部调用）；这里仅记录
	pass
