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
	# ─── v1.2 多大关: 大关风格新增怪 (chapter_style.gd §3.0) ───
	# 腐沼风格 (慢速/群体/分裂) — 毒囊之核 专属怪
	"toxin_swarmer": {
		"hp": 2,
		"speed": 55.0,
		"body_radius": 16.0,
		"color": Color(0.4, 0.85, 0.3),  # 毒绿
		"capture_value": 1.2,
		"flee_radius": 180.0,
		"flee_speed_mult": 1.0,
		"wander_speed_mult": 0.3,
	},
	# 熔金矿洞风格 (快速/切割/金元素) — 金甲残片 专属怪
	"phase_cutter": {
		"hp": 1,
		"speed": 160.0,
		"body_radius": 12.0,
		"color": Color(0.95, 0.7, 0.2),  # 金
		"capture_value": 0.8,
		"flee_radius": 260.0,
		"flee_speed_mult": 1.6,
		"wander_speed_mult": 0.2,
	},
	# 虚空回廊风格 (镜像/分身/佯攻) — 虚空碎片 专属怪
	"decoy_wraith": {
		"hp": 1,
		"speed": 70.0,
		"body_radius": 22.0,
		"color": Color(0.5, 0.5, 0.95),  # 虚空蓝
		"capture_value": 0.5,
		"flee_radius": 300.0,
		"flee_speed_mult": 2.0,
		"wander_speed_mult": 0.15,
	},
	# P1: 独立贴图风格新怪 — enemy_base.textures 有对应键 (toxin_pod/split_body/phase_slash/feint), 走贴图渲染
	"toxin_pod": {
		"hp": 2,
		"speed": 55.0,
		"body_radius": 16.0,
		"color": Color(0.4, 0.85, 0.3),  # 毒绿
		"capture_value": 1.2,
		"flee_radius": 180.0,
		"flee_speed_mult": 1.0,
		"wander_speed_mult": 0.3,
	},
	"split_body": {
		"hp": 1,
		"speed": 95.0,
		"body_radius": 14.0,
		"color": Color(0.7, 0.4, 0.9),  # 紫
		"capture_value": 0.8,
		"flee_radius": 220.0,
		"flee_speed_mult": 1.4,
		"wander_speed_mult": 0.25,
	},
	"phase_slash": {
		"hp": 1,
		"speed": 160.0,
		"body_radius": 12.0,
		"color": Color(0.95, 0.7, 0.2),  # 金
		"capture_value": 0.8,
		"flee_radius": 260.0,
		"flee_speed_mult": 1.6,
		"wander_speed_mult": 0.2,
	},
	"feint": {
		"hp": 1,
		"speed": 70.0,
		"body_radius": 20.0,
		"color": Color(0.5, 0.5, 0.95),  # 虚空紫
		"capture_value": 0.5,
		"flee_radius": 300.0,
		"flee_speed_mult": 2.0,
		"wander_speed_mult": 0.15,
	},
	# ─── v1.2 多大关: 专属 Boss (黑神话法宝, 每大关不同) ───
	"boss_swamp": {
		"hp": 25,
		"speed": 38.0,
		"body_radius": 60.0,
		"color": Color(0.3, 0.8, 0.3),  # 腐绿
		"capture_value": 10.0,
		"flee_radius": 400.0,
		"flee_speed_mult": 1.2,
		"wander_speed_mult": 0.2,
	},
	"boss_gold_beast": {
		"hp": 30,
		"speed": 55.0,
		"body_radius": 65.0,
		"color": Color(1.0, 0.8, 0.0),  # 金甲
		"capture_value": 10.0,
		"flee_radius": 400.0,
		"flee_speed_mult": 1.3,
		"wander_speed_mult": 0.25,
	},
	"boss_void_devourer": {
		"hp": 35,
		"speed": 45.0,
		"body_radius": 70.0,
		"color": Color(0.6, 0.6, 1.0),  # 虚空
		"capture_value": 10.0,
		"flee_radius": 420.0,
		"flee_speed_mult": 1.4,
		"wander_speed_mult": 0.3,
	},
	"boss_abyss_echo": {
		"hp": 45,
		"speed": 50.0,
		"body_radius": 80.0,
		"color": Color(0.8, 0.3, 0.9),  # 深渊紫
		"capture_value": 15.0,
		"flee_radius": 450.0,
		"flee_speed_mult": 1.5,
		"wander_speed_mult": 0.35,
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
var _spawn_interval: float = 0.5  # 每 0.5 秒生成一个敌人
var _is_generating: bool = false
var _all_spawned: bool = false
var _captured_count: int = 0  # 本波已吞噬数

# ─── 信号 ─────────────────────────────────────────
signal wave_starting(wave_number: int)
signal wave_complete(wave_number: int)
var _wave_cleared_fired: bool = false

## v1.2: 层清反馈 (GDD 七) — 本层全部吞噬时发一次, HUD 横幅据此 3s 窗口显示
signal wave_cleared(wave_number: int)
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
	
	# 生成队列中的敌人 (v1.2: 队列有空位时刷怪, 被吞噬后自动补位)
	if not _spawn_queue.is_empty() and _pool.get_active_count() < _wave_spawn_total:
		_spawn_next_enemy()
	
	# v1.2: 清层判定 — 本层剩余(队列+活跃)归零即清层, 不要求队列排空
	if get_remaining_enemies() <= 0:
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
	# v1.2: 记录本层生成总数 (HUD 剩余提示)
	_wave_spawn_total = _spawn_queue.size()
	
	# 通知
	if _gm:
		_gm.start_wave(wave_number)
	wave_starting.emit(wave_number)
	
	print("[WaveSpawner] 波次 ", wave_number, " 开始 — 生成 ", _spawn_queue.size(), " 个敌人")

## 路线化关卡入口 (GDD 7.2 / 5.3)
## pack: 来自 RouteGenerator.pick_option 的节点数据包
## 非战斗节点（营地/商店/剧情事件）不刷怪，直接完成 → 进下一层决策
func start_node(pack: Dictionary) -> void:
	var floor: int = pack.get("floor", _current_wave)
	var node_type: int = pack.get("node_type", 0)
	_current_wave = floor
	_captured_count = 0
	_wave_cleared_fired = false

	if _gm:
		_gm.current_floor = floor
		_gm.current_node_type = node_type

	# 非战斗节点：营地(2)/商店(3)/剧情事件 → 无敌人，立即结算
	if node_type == 2 or node_type == 3 or _is_event_story(pack):
		_is_generating = false
		_all_spawned = true
		_spawn_queue.clear()
		if _gm:
			_gm.end_wave()
		wave_complete.emit(floor)
		print("[WaveSpawner] 层 ", floor, " (非战斗节点) 完成 → 下一层决策")
		_request_next_decision(floor)
		return

	# 战斗节点：按 pack 编队包生成
	_is_generating = true
	_all_spawned = false
	_spawn_queue.clear()
	var entries = pack.get("enemies", [])
	for entry in entries:
		var type_id: String = entry.get("type", "basic")
		var config = _enemy_configs.get(type_id, _enemy_configs["basic"]).duplicate(true)
		config = _apply_node_overrides(config, pack, type_id)
		for i in range(entry.get("count", 1)):
			_spawn_queue.push_back({"type": type_id, "config": config})
	_shuffle_queue()
	# v1.2: 记录本层生成总数 (HUD 剩余提示)
	_wave_spawn_total = _spawn_queue.size()
	if _gm:
		_gm.start_wave(floor)
	wave_starting.emit(floor)
	print("[WaveSpawner] 层 ", floor, " (节点 ", node_type, ") — 生成 ", _spawn_queue.size(), " 个敌人")

## 事件是否剧情型（不刷怪）
func _is_event_story(pack: Dictionary) -> bool:
	if pack.get("node_type", 0) != 4:
		return false
	var eid: String = pack.get("event_id", "")
	# v1.2 P2: 元素谜题也是非战斗事件 (不刷怪, HUD 侧显示答题)
	return eid in ["time_rift", "mystery_merchant", "element_puzzle"]

## 按节点类型覆盖敌人属性（精英/Boss 体型 + 层号缩放）
func _apply_node_overrides(config: Dictionary, pack: Dictionary, type_id: String) -> Dictionary:
	var node_type: int = pack.get("node_type", 0)
	var floor: int = pack.get("floor", 1)
	var diff := 1.0
	var rg = get_node_or_null("../RouteGenerator")
	if rg and rg.has_method("get_difficulty"):
		diff = rg.get_difficulty(floor, node_type)
	# 数量按层号系数缩放（仅普通波）
	if node_type == 0:
		config["hp"] = int(config.get("hp", 1) * diff + 0.5)
	# 精英特殊体型 (GDD 7.3 精英表)
	match type_id:
		"elite_tearer":   config["body_radius"] = 45.0; config["hp"] = 6
		"elite_toxin":    config["body_radius"] = 38.0; config["hp"] = 4
		"elite_mirror":   config["body_radius"] = 30.0; config["hp"] = 3
		"elite_fortress": config["body_radius"] = 50.0; config["hp"] = 10
		"boss_swamp":       config["body_radius"] = 60.0; config["hp"] = 25
		"boss_gold_beast":   config["body_radius"] = 65.0; config["hp"] = 30
		"boss_void_devourer":  config["body_radius"] = 70.0; config["hp"] = 40
		# v1.2 多大关: 无尽深渊 Boss (大关 4+)
		"boss_abyss_echo":  config["body_radius"] = 80.0; config["hp"] = 45
	# 章节属性放大（GDD 7.5）
	if rg and rg.has_method("get_chapter_stat_scale"):
		var cscale: float = rg.get_chapter_stat_scale()
		config["speed"] = config.get("speed", 80.0) * cscale
		config["hp"] = int(config.get("hp", 1) * cscale + 0.5)
	return config

## 层完成后进入「决策时刻」：请求 RouteUI 显示下一层 3 选 1
signal decision_needed(floor: int)

func _request_next_decision(cleared_floor: int) -> void:
	var next_floor: int = cleared_floor + 1
	if next_floor > 13:
		# 章节完成（Boss 后结算 / 无尽模式后续扩展）
		all_waves_complete.emit()
		print("[WaveSpawner] 章节完成（13 层清空）")
		return
	decision_needed.emit(next_floor)

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
	var edge: int = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
	var margin: float = 10.0
	
	match edge:
		0:  # 上边缘
			return Vector2(randf() * 720.0, margin)
		1:  # 右边缘
			return Vector2(720.0 - margin, randf() * 1280.0)
		2:  # 下边缘
			return Vector2(randf() * 720.0, 1280.0 - margin)
		3:  # 左边缘
			return Vector2(margin, randf() * 1280.0)
	
	return Vector2.ZERO

## 敌人被吞噬时调用
func on_enemy_captured() -> void:
	_captured_count -= 1
	if _is_generating and _spawn_queue.is_empty() and _all_spawned:
		_check_wave_complete()

## v1.2: 本层剩余敌人 (供 HUD 提示), 含已生成未吞噬 + 排队中
func get_remaining_enemies() -> int:
	var q: int = _spawn_queue.size()
	var active: int = 0
	if _pool and _pool.has_method("get_active_count"):
		active = _pool.get_active_count()
	return q + active

## v1.2: 本层已生成总数 (含已吞噬), 供 HUD 显示 剩余/总数
var _wave_spawn_total: int = 0

func get_wave_spawn_total() -> int:
	return _wave_spawn_total

## v1.2: 当前层号 (供 main 控制器清层奖励链放行到路线 3选1)
func get_current_wave() -> int:
	return _current_wave

## 清层判定 (v1.2)
func _check_wave_complete() -> void:
	# 清层判定 (v1.2): 本层剩余(生成队列+活跃敌人)归零 即清层,
	# 不再要求生成队列排空 — 修复 最后几只还在队列时 清层判定断的问题
	if not _is_generating:
		return
	if _pool == null:
		_pool = get_node_or_null("../ObjectPool")
		if _pool == null:
			return
	var remaining: int = _spawn_queue.size() + _pool.get_active_count()
	if remaining > 0:
		return
	_is_generating = false
	if _gm:
		_gm.end_wave()
	wave_complete.emit(_current_wave)
	# v1.2: 层清反馈信号 (GDD 七) — 本层全部吞噬时发一次
	if not _wave_cleared_fired:
		_wave_cleared_fired = true
		wave_cleared.emit(_current_wave)
	print("[WaveSpawner] 层 " + str(_current_wave) + " 清层!")
	if _gm.has_method("tick_inscribed_cards"):
		_gm.tick_inscribed_cards()
	# v1.2 P1 警报机制: 精英层清完护卫 → 警报清零 (奖励干净清场, §3.5)
	if _gm.current_node_type == 1:
		_notify_alarm_elite_cleared()
	_grant_evolution_card_choice()

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
	_wave_cleared_fired = false

## 精英掉落结算：若本层是精英节点且已清空，roll 掉落 (GDD 7.3)
func _grant_elite_reward_if_any() -> void:
	if _gm == null:
		return
	var node_type: int = _gm.current_node_type
	if node_type != 1:  # 仅精英节点
		return
	if randf() < 0.6:
		# 遗物：从遗物池随机 1 个
		var relic_pool = load("res://scripts/card_database.gd").get_cards_by_rarity("Relic")
		if relic_pool.size() > 0:
			var pick = relic_pool[randi() % relic_pool.size()]
			if not _gm.relics.has(pick.get("id", "")):
				_gm.relics.append(pick.get("id", ""))
			print("[WaveSpawner] 精英掉落遗物: ", pick.get("name", "?"))
	else:
		# 传说卡：从传说池随机 1 张进牌组
		var leg_pool = load("res://scripts/card_database.gd").get_cards_by_rarity("Legendary")
		if leg_pool.size() > 0:
			var pick = leg_pool[randi() % leg_pool.size()]
			_gm.add_card_to_deck(pick.get("id", ""))
			print("[WaveSpawner] 精英掉落传说卡: ", pick.get("name", "?"))

## v1.2 P1 警报机制: 精英层清完护卫 → 通知 RouteGenerator.alarm 清零 (§3.5)
func _notify_alarm_elite_cleared() -> void:
	var rg = get_node_or_null("../RouteGenerator")
	if rg and rg.alarm != null and rg.alarm.has_method("on_elite_cleared"):
		rg.alarm.on_elite_cleared()

## v1.1: 进化卡 4 选 1 — 所有层通关后弹出
## 从 55 张进化卡池 (11 技能 × 5 材质) 随机抽 4 张, 玩家选 1 张进技能栏
func _grant_evolution_card_choice() -> void:
	if _gm == null:
		return
	# 进化卡池 (v1.1: 11 技能 × 5 材质 = 55 张)
	# 简化: 从 CardDatabase 的所有非遗物卡中抽取
	var evo_pool = load("res://scripts/card_database.gd").get_all_cards()
	# 过滤出非 Relic 类
	var filtered: Array[Dictionary] = []
	for card in evo_pool:
		if card.get("category", "") != "Relic":
			filtered.append(card)
	if filtered.size() < 4:
		print("[WaveSpawner] 进化卡池不足 4 张, 跳过")
		return
	# 随机抽 4 张
	var drawn: Array[Dictionary] = []
	var available = filtered.duplicate()
	for i in range(4):
		if available.is_empty():
			break
		var idx = randi() % available.size()
		drawn.append(available[idx])
		available.remove_at(idx)
	# 弹出进化卡选择 UI
	UpgradePopup.show_upgrade(drawn)
	# 暂停游戏
	_gm.set_state(GameManager.GameState.LEVEL_UP)
	print("[WaveSpawner] 进化卡 4 选 1 弹出: ", drawn.size(), " 张")

## v1.1: 遗物卡 3 选 1 — 仅精英层/Boss 层通关后弹出
## 稀有度按关卡 roll: 普通 60% / 罕见 30% / 史诗 9% / 传说 1% (精英)
## Boss 层保底 1 张史诗以上
## v1.2: 进化卡 4选1 确认完成后调用 (GDD 七 清层奖励链)
## 普通层 → 直接放行路线 3选1; 精英/Boss → 弹遗物 3选1
func on_evolution_card_confirmed() -> void:
	if _gm == null:
		return
	var node_type: int = _gm.current_node_type
	if node_type != 1 and node_type != 5:
		# 普通层无遗物, 直接进路线 3选1
		_request_next_decision(_current_wave)
		return
	# 精英/Boss: 弹遗物 3选1 (完成后再由 all_rewards_done 放行路线)
	_grant_relic_card_choice()

func _grant_relic_card_choice() -> void:
	if _gm == null:
		return
	var node_type: int = _gm.current_node_type
	# 仅精英(1) / Boss(5) 节点掉遗物卡
	if node_type != 1 and node_type != 5:
		# 普通层无遗物, 直接放行到路线 3选1
		_request_next_decision(_current_wave)
		return
	# 按稀有度 roll 3 张遗物卡
	# v1.2: 遗物 = 道具类, 按关卡稀有度 roll (GDD 六)
	var rs = load("res://scripts/relic_system.gd")
	var drawn: Array[Dictionary] = rs.roll_relics(node_type)
	if drawn.size() == 0:
		return
	# 弹出遗物卡选择 UI (复用 UpgradePopup, 传标识区分)
	UpgradePopup.show_relic_choices(drawn)
	print("[WaveSpawner] 遗物卡 3 选 1 弹出: ", drawn.size(), " 张 (节点 ", node_type, ")")

## 按关卡 roll 遗物稀有度 (返回中文稀有度名: 普通/罕见/史诗/传说/神器)
func _roll_relic_rarity_cn(is_boss: bool, card_index: int) -> String:
	if is_boss:
		if card_index == 0:
			# 保底史诗以上
			var r = randf()
			if r < 0.35: return "史诗"
			elif r < 0.70: return "传说"
			else: return "神器"
		else:
			var r2 = randf()
			if r2 < 0.50: return "罕见"
			elif r2 < 0.85: return "史诗"
			else: return "传说"
	else:
		# 精英层稀有度分布
		var r3 = randf()
		if r3 < 0.60: return "普通"
		elif r3 < 0.90: return "罕见"
		elif r3 < 0.99: return "史诗"
		else: return "传说"
