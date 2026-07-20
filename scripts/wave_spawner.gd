extends Node
## WaveSpawner — 波次生成管理器
## 负责每波敌人的配置、生成、清理、难度递增

# ─── 公开属性 ─────────────────────────────────────────
# @export var pool_node_path: String = "ObjectPool"  # Deprecated, using relative path

# ─── 敌人类型配置 ─────────────────────────────────────
# 每种敌人: { name, hp, speed, body_radius, color, capture_value, flee_radius, flee_speed_mult, wander_speed_mult }
var _enemy_configs: Dictionary = {
	"basic": {
		"hp": 1,
		"speed": 80.0,
		"body_radius": 15.0,
		"color": Color(0.3, 0.8, 0.3),  # 绿色
		"capture_value": 1.0,
		"flee_radius": 200.0,
		"flee_speed_mult": 1.3,
		"wander_speed_mult": 0.3,
	},
	"swift": {
		"hp": 1,
		"speed": 140.0,
		"body_radius": 12.0,
		"color": Color(0.9, 0.8, 0.2),  # 黄色
		"capture_value": 0.5,
		"flee_radius": 250.0,
		"flee_speed_mult": 1.5,
		"wander_speed_mult": 0.2,
	},
	"heavy": {
		"hp": 3,
		"speed": 50.0,
		"body_radius": 25.0,
		"color": Color(0.9, 0.3, 0.3),  # 红色
		"capture_value": 3.0,
		"flee_radius": 150.0,
		"flee_speed_mult": 1.0,
		"wander_speed_mult": 0.4,
	},
	"split": {
		"hp": 2,
		"speed": 90.0,
		"body_radius": 18.0,
		"color": Color(0.6, 0.3, 0.9),  # 紫色
		"capture_value": 1.5,
		"flee_radius": 220.0,
		"flee_speed_mult": 1.4,
		"wander_speed_mult": 0.25,
	},
	"decoy": {
		"hp": 1,
		"speed": 60.0,
		"body_radius": 30.0,
		"color": Color(0.9, 0.5, 0.7),  # 粉色
		"capture_value": 0.0,
		"flee_radius": 300.0,
		"flee_speed_mult": 2.0,
		"wander_speed_mult": 0.1,
	},
	"boss": {
		"hp": 20,
		"speed": 40.0,
		"body_radius": 50.0,
		"color": Color(1.0, 0.8, 0.0),  # 金色
		"capture_value": 10.0,
		"flee_radius": 400.0,
		"flee_speed_mult": 1.2,
		"wander_speed_mult": 0.2,
	},
}

# ─── 波次配置 ─────────────────────────────────────────
# 每波: Array of { type, count }
var _wave_configs: Array = [
	# Wave 1: 5 个小兵
	[{"type": "basic", "count": 5}],
	# Wave 2: 8 小兵 + 2 迅捷
	[{"type": "basic", "count": 8}, {"type": "swift", "count": 2}],
	# Wave 3: 10 小兵 + 3 迅捷 + 1 重装
	[{"type": "basic", "count": 10}, {"type": "swift", "count": 3}, {"type": "heavy", "count": 1}],
	# Wave 4: 12 小兵 + 3 迅捷 + 2 重装 + 1 分裂
	[{"type": "basic", "count": 12}, {"type": "swift", "count": 3}, {"type": "heavy", "count": 2}, {"type": "split", "count": 1}],
	# Wave 5: Boss
	[{"type": "boss", "count": 1}],
]

# ─── 内部状态 ─────────────────────────────────────────
var _current_wave: int = 0
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.5  # 每 0.5 秒生成一个敌人
var _is_generating: bool = false
var _all_spawned: bool = false
var _captured_count: int = 0  # 本波已吞噬数

# ─── 信号 ─────────────────────────────────────────
signal wave_starting(wave_number: int)
signal wave_complete(wave_number: int)
signal all_waves_complete

# ─── 引用 ─────────────────────────────────────────
var _pool: Node
var _gm: Node
var _player: Node2D

func _ready() -> void:
	_pool = get_node_or_null("../ObjectPool")
	_gm = get_node_or_null("/root/GameManager")
	_player = get_node_or_null("/root/MainGame/Player")
	
	if _pool == null:
		print("[WaveSpawner] 警告: ObjectPool 节点未找到，将在 _process 中重试")
	
	print("[WaveSpawner] 初始化完成 — 预定义 ", _wave_configs.size(), " 波")

func _process(delta: float) -> void:
	if _pool == null:
		_pool = get_node_or_null("../ObjectPool")
		if _pool == null:
			return
	
	if not _is_generating:
		return
	
	# 生成队列中的敌人
	_spawn_timer -= delta
	if _spawn_timer <= 0 and not _spawn_queue.is_empty():
		_spawn_next_enemy()
		_spawn_timer = _spawn_interval
	
	# 检查波次是否完成
	if _spawn_queue.is_empty() and _all_spawned:
		_check_wave_complete()

## 开始指定波次
func start_wave(wave_number: int) -> void:
	_current_wave = wave_number
	_captured_count = 0
	_is_generating = true
	_all_spawned = false
	
	# 获取波次配置
	var config_index: int = wave_number - 1
	var wave_entries = []
	
	if config_index < _wave_configs.size():
		wave_entries = _wave_configs[config_index]
	else:
		# 超出预设波次，动态生成
		wave_entries = _generate_dynamic_wave(wave_number)
	
	# 构建生成队列
	_spawn_queue.clear()
	for entry in wave_entries:
		var config = _enemy_configs.get(entry.get("type", "basic"), _enemy_configs["basic"])
		for i in range(entry.get("count", 1)):
			_spawn_queue.push_back({
				"type": entry.get("type", "basic"),
				"config": config.duplicate(true),
			})
	
	# 打乱队列 (随机生成顺序)
	_shuffle_queue()
	
	# 通知
	if _gm:
		_gm.start_wave(wave_number)
	wave_starting.emit(wave_number)
	
	print("[WaveSpawner] 波次 ", wave_number, " 开始 — 生成 ", _spawn_queue.size(), " 个敌人")

## 动态生成超出预设的波次
func _generate_dynamic_wave(wave_num: int) -> Array:
	var entries = []
	var difficulty: float = 1.0
	if _gm:
		difficulty = _gm.difficulty_multiplier
	
	# 基础小兵数量递增
	var basic_count: int = int(5 + wave_num * 2 * difficulty)
	entries.push_back({"type": "basic", "count": basic_count})
	
	# 迅捷和重装按比例出现
	if wave_num >= 2:
		entries.push_back({"type": "swift", "count": int(wave_num * 0.5)})
	if wave_num >= 3:
		entries.push_back({"type": "heavy", "count": int(wave_num * 0.3)})
	if wave_num >= 4:
		entries.push_back({"type": "split", "count": int(wave_num * 0.2)})
	
	# 每5波出现Boss
	if wave_num % 5 == 0:
		entries.push_back({"type": "boss", "count": 1})
	
	return entries

## 打乱生成队列
func _shuffle_queue() -> void:
	for i in range(_spawn_queue.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp = _spawn_queue[i]
		_spawn_queue[i] = _spawn_queue[j]
		_spawn_queue[j] = temp

## 生成下一个敌人
func _spawn_next_enemy() -> void:
	if _spawn_queue.is_empty():
		_all_spawned = true
		return
	
	var entry = _spawn_queue.pop_front()
	var type_data = entry.config
	type_data["enemy_type"] = entry.get("type", "basic")
	
	# 生成位置：屏幕边缘随机点
	var spawn_pos = _get_random_edge_position()
	
	# 从对象池生成
	var enemy = _pool.spawn(spawn_pos, type_data)
	if enemy:
		pass  # 实际吞噬计数在 enemy_captured 信号中处理

## 获取屏幕边缘随机位置
func _get_random_edge_position() -> Vector2:
	var screen_size = _get_screen_size()
	var edge: int = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
	
	match edge:
		0:  # 上边缘
			return Vector2(randf() * screen_size.x, -30.0)
		1:  # 右边缘
			return Vector2(screen_size.x + 30.0, randf() * screen_size.y * 0.6)
		2:  # 下边缘
			return Vector2(randf() * screen_size.x, screen_size.y + 30.0)
		3:  # 左边缘
			return Vector2(-30.0, randf() * screen_size.y * 0.6)
	
	return Vector2.ZERO

## 敌人被吞噬时调用
func on_enemy_captured() -> void:
	_captured_count -= 1
	if _spawn_queue.is_empty() and _all_spawned:
		_check_wave_complete()

## 检查波次是否完成
func _check_wave_complete() -> void:
	# 等待一小段时间确保所有敌人都被处理
	var active_count: int = 0
	if _pool:
		active_count = _pool.get_active_count()
	if active_count <= 0:
		_is_generating = false
		if _gm:
			_gm.end_wave()
		wave_complete.emit(_current_wave)
		print("[WaveSpawner] 波次 ", _current_wave, " 完成!")
		
		# 自动开始下一波 (延迟2秒)
		var tween = create_tween()
		tween.tween_delay(2.0)
		_start_next_wave(_current_wave + 1)

## 启动下一波（命名闭包替代 func: lambda）
func _start_next_wave(next_wave_num: int) -> void:
	start_wave(next_wave_num)

## 获取屏幕尺寸
func _get_screen_size() -> Vector2:
	var viewport = get_viewport()
	if viewport:
		return viewport.get_visible_rect().size
	return Vector2(720, 1280)

## 立即清除所有敌人 (用于切换波次)
func clear_all() -> void:
	if _pool:
		_pool.despawn_all()
	_spawn_queue.clear()
	_is_generating = false
	_all_spawned = true
