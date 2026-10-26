extends Node
## MainGame — 主游戏场景控制器
## 负责初始化各系统、连接信号、协调游戏流程

var _player: CharacterBody2D
var _joystick: Control
var _gesture_detector: Object
var _wave_spawner: Node
var _bg_sprite: Sprite2D
var _env_fx_overlay: Sprite2D
var _last_chapter: int = -1
# P1: 无尽深渊 (大关 4+) 视觉 — 切换用
var _abyss_bg_path := "res://assets/backgrounds/bg_ch4_abyss.png"
var _abyss_fx_path := "res://assets/sprites/environment/fx_env_abyss_mist.png"

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
	_bg_sprite = Sprite2D.new()
	_bg_sprite.name = "Background"
	_bg_sprite.texture = load("res://assets/backgrounds/bg_gameplay.png")
	_bg_sprite.centered = true
	_bg_sprite.position = Vector2(360, 640)
	_bg_sprite.z_index = -10 # 确保在最底层渲染
	add_child(_bg_sprite)

	# v1.2 P0: 环境特效覆盖层 (毒雾/熔岩/虚空幕, 随大关切换, 默认隐藏)
	_env_fx_overlay = Sprite2D.new()
	_env_fx_overlay.name = "EnvFXOverlay"
	_env_fx_overlay.centered = true
	_env_fx_overlay.position = Vector2(360, 640)
	_env_fx_overlay.z_index = -5
	_env_fx_overlay.visible = false
	add_child(_env_fx_overlay)

	# 应用初始大关 (GameManager.chapter 默认 1)
	var _gm0 = get_node_or_null("/root/GameManager")
	if _gm0:
		_last_chapter = int(_gm0.chapter)
		_apply_chapter_visuals(_last_chapter)

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
	# v1.2: 层清反馈 — 本层全部吞噬时, HUD 横幅开始 3s 窗口 (GDD 七)
	if _wave_spawner.has_signal("wave_cleared"): 
		_wave_spawner.wave_cleared.connect(_on_wave_cleared)
	# v1.2: 清层奖励链 (进化卡4选1 + 遗物3选1) 全部完成 → 进路线 3选1
	var _up = get_node_or_null("UpgradePopup")
	if _up and _up.has_signal("all_rewards_done"):
		_up.all_rewards_done.connect(_on_all_rewards_done)
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
	
	# M5.6 新手前 30 秒引导: 创建提示 Label + 启动计时
	_setup_tutorial()
	print("[MainGame] 场景初始化完成")

## v1.2 P0: 大关 -> 背景 + 环境特效 切换
func _apply_chapter_visuals(chapter: int) -> void:
	var bg_path := ""
	var fx_path := ""
	match chapter:
		1:
			bg_path = "res://assets/backgrounds/bg_ch1_swamp.png"
			fx_path = "res://assets/sprites/environment/fx_env_poison_mist.png"
		2:
			bg_path = "res://assets/backgrounds/bg_ch2_gold.png"
			fx_path = "res://assets/sprites/environment/fx_env_lava_patch.png"
		3:
			bg_path = "res://assets/backgrounds/bg_ch3_void.png"
			fx_path = "res://assets/sprites/environment/fx_env_void_veil.png"
		4:
			bg_path = _abyss_bg_path
			fx_path = _abyss_fx_path
		_:
			# 5+ 无尽循环: 复用深渊视觉
			bg_path = _abyss_bg_path
			fx_path = _abyss_fx_path
	if bg_path != "" and ResourceLoader.exists(bg_path):
		_bg_sprite.texture = load(bg_path)
	if fx_path != "":
		if ResourceLoader.exists(fx_path):
			_env_fx_overlay.texture = load(fx_path)
			_env_fx_overlay.modulate = Color(1, 1, 1, 0.4)
			_env_fx_overlay.visible = true
		else:
			_env_fx_overlay.visible = false

func _process_chapter_visuals() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var c: int = int(gm.chapter)
	if c != _last_chapter:
		_last_chapter = c
		_apply_chapter_visuals(c)

## M5.6 新手前 30 秒引导 (路线化后文案)
var _tutorial: RefCounted
var _tutorial_label: Label
var _tutorial_time: float = 0.0

func _setup_tutorial() -> void:
	_tutorial = load("res://scripts/tutorial_system.gd")
	if _tutorial == null:
		return
	# 第 1 条: 摇杆移动
	_show_hint(_tutorial.hint_by_trigger("floor_1_start").get("text", ""))

func _show_hint(text: String) -> void:
	if text == "":
		if _tutorial_label and is_instance_valid(_tutorial_label):
			_tutorial_label.visible = false
		return
	if _tutorial_label == null or not is_instance_valid(_tutorial_label):
		_tutorial_label = Label.new()
		_tutorial_label.name = "TutorialHint"
		_tutorial_label.position = Vector2(0, 1180)
		_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tutorial_label.size = Vector2(720, 40)
		_tutorial_label.add_theme_font_size_override("font_size", 18)
		_tutorial_label.self_modulate = Color(1.0, 0.95, 0.6, 1.0)
		add_child(_tutorial_label)
	_tutorial_label.text = text
	_tutorial_label.visible = true

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
	_process_chapter_visuals()
	# M5.6 新手引导计时 (前 30 秒 3 条轮播)
	if _tutorial != null and _tutorial_time < 30.0:
		_tutorial_time += delta
		var cur: String = _tutorial.current_hint(_tutorial_time)
		if cur != "" and _tutorial_label and is_instance_valid(_tutorial_label):
			if _tutorial_label.text != cur:
				_tutorial_label.text = cur
			_tutorial_label.visible = true
		elif _tutorial_label and is_instance_valid(_tutorial_label):
			_tutorial_label.visible = false

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

## v1.2: 层清反馈 — HUD 横幅显示 3s 再隐藏 (GDD 七)
func _on_wave_cleared(_floor: int) -> void:
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("_on_wave_cleared"):
		hud._on_wave_cleared(_floor)

func _on_route_chosen(pack: Dictionary) -> void:
	# pack 已交给 spawner.start_node（RouteUI 内部调用）；这里仅记录
	pass

## v1.2: 清层奖励 (进化卡4选1 + 遗物3选1) 全部完成 → 进路线 3选1
func _on_all_rewards_done() -> void:
	if _wave_spawner and _wave_spawner.has_method("_request_next_decision"):
		_wave_spawner._request_next_decision(_wave_spawner.get_current_wave())
	# v1.2: 隐藏层清横幅 (奖励链完成 → 进路线 3选1, GDD 七)
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("_hide_floor_banner"):
		hud._hide_floor_banner()
