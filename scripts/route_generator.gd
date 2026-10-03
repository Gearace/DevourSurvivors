extends Node
## RouteGenerator — 路线生成器 (GDD 7.2 / 5.7)
## 负责：每局 roll 出 13 层完整路线 + 各层候选卡片，
## 带模板约束（精英≤2、商店≥1、事件≤2），结果写入 GameManager.run_route。
##
## 设计原则：
##   · 纯数据层，不依赖 UI / 场景；输出可直接交给 wave_spawner / route_ui
##   · 路线 C：roll 全局，但 UI 只预览后 1-2 层（见 GDD 7.6）
##   · 每层候选卡片 3 张，玩家 3 选 1（决策时刻）

# ─── 节点类型枚举（对应 GDD 7.1）────────────────────────
enum NodeType {
	NORMAL,   # 普通波 ×1.0
	ELITE,    # 精英   ×1.6
	CAMP,     # 营地   ×0.3
	SHOP,     # 商店   ×0.5
	EVENT,    # 事件   战斗1.2 / 剧情0.5
	BOSS,     # Boss   ×2.0
}

# 节点类型中文名（供 UI 显示）
const NODE_NAMES: Dictionary = {
	0: "普通波",
	1: "精英",
	2: "营地",
	3: "商店",
	4: "事件",
	5: "章节Boss",
}

# 节点类型难度系数（GDD 7.4）
const NODE_FACTOR: Dictionary = {
	0: 1.0,
	1: 1.6,
	2: 0.3,
	3: 0.5,
	4: 1.2,   # 战斗事件；剧情事件 UI 侧按 0.5 处理
	5: 2.0,
}

# 层号系数台阶（GDD 7.4，前松后紧）
const FLOOR_FACTOR: Dictionary = {
	1: 1.0,  2: 1.0,  3: 1.0,  4: 1.0,
	5: 1.15, 6: 1.15,
	7: 1.30, 8: 1.30,
	9: 1.50, 10: 1.50,
	11: 1.75, 12: 1.75,
	13: 2.0,
}

# ─── 13 层路线模板（GDD 7.2）────────────────────────────
# 每层: { floor, fixed, type(固定层) 或 options(roll层) }
var _template: Array = [
	{ "floor": 1,  "fixed": true,  "type": 0 },
	{ "floor": 2,  "fixed": true,  "type": 0 },
	{ "floor": 3,  "fixed": false, "options": [0, 1, 2] },
	{ "floor": 4,  "fixed": true,  "type": 0 },
	{ "floor": 5,  "fixed": false, "options": [0, 1, 3] },
	{ "floor": 6,  "fixed": true,  "type": 0 },
	{ "floor": 7,  "fixed": false, "options": [1, 4, 2] },
	{ "floor": 8,  "fixed": true,  "type": 0 },
	{ "floor": 9,  "fixed": false, "options": [1, 3, 4] },
	{ "floor": 10, "fixed": false, "options": [1, 2, 0] },
	{ "floor": 11, "fixed": false, "options": [1, 4, 2] },
	{ "floor": 12, "fixed": false, "options": [1, 3, 2] },
	{ "floor": 13, "fixed": true,  "type": 5 },
]

# 章节级约束（作用于「候选可选项」总数）
const MAX_ELITE_CANDIDATES := 4   # 全章精英候选出现总次数 ≤4（约 2 次被选到的量级）
const MAX_EVENT_CANDIDATES := 4
const MIN_SHOP_CANDIDATES  := 1

# ─── 输出：本局路线（写入 GameManager.run_route）──────────
# 每层一条: { floor:int, options:Array, picked:int }
var _run_route: Array = []
var _gm: Node
var _runtime_difficulty: float = 1.0

func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	print("[RouteGenerator] 初始化完成 — 模板 ", _template.size(), " 层")

## 生成新一局的 13 层路线（约束校验通过）
## 返回: Array，每项 { floor, options:Array, picked:int }
func generate_run() -> Array:
	var attempts := 0
	_runtime_difficulty = _chapter_stat_scale(_get_chapter())
	while true:
		attempts += 1
		var route := _roll_once()
		if _satisfies_constraints(route):
			_run_route = route
			_store_to_gm()
			_print_route(route)
			return route
		if attempts >= 200:
			push_warning("[RouteGenerator] 200 次未满足约束，降级为无约束路线")
			_run_route = route
			_store_to_gm()
			return route

	# 兜底：理论上不会到这里（while 必在 ≤200 次内 return）
	return _run_route

## 内部：roll 一版路线
func _roll_once() -> Array:
	var route: Array = []
	for tpl in _template:
		var rec := { "floor": tpl.floor, "options": [], "picked": -1 }
		if tpl.fixed:
			rec.options = [tpl.type]
		else:
			rec.options = _shuffle(tpl.options)
		route.push_back(rec)
	return route

## 打乱顺序（哪张候选卡排哪边也随机）
func _shuffle(pool: Array) -> Array:
	var picked := pool.duplicate()
	for i in range(picked.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = picked[i]
		picked[i] = picked[j]
		picked[j] = tmp
	return picked

## 约束校验：精英/事件候选总数受限、商店至少 1 个、层2 不出精英
func _satisfies_constraints(route: Array) -> bool:
	var elite := 0
	var event_ := 0
	var shop := 0
	for rec in route:
		for t in rec.options:
			if t == 1:
				elite += 1
			elif t == 4:
				event_ += 1
			elif t == 3:
				shop += 1
		if rec.floor == 2:
			for t in rec.options:
				if t == 1:
					return false
	if elite > MAX_ELITE_CANDIDATES:
		return false
	if event_ > MAX_EVENT_CANDIDATES:
		return false
	if shop < MIN_SHOP_CANDIDATES:
		return false
	return true

## 写入 GameManager.run_route（随 save/load 序列化）
func _store_to_gm() -> void:
	if _gm == null:
		return
	if "run_route" in _gm:
		_gm.run_route = _run_route.duplicate(true)
	else:
		_gm.set_meta("run_route", _run_route.duplicate(true))

## 取本局路线（已生成）
func get_run_route() -> Array:
	return _run_route

## 玩家在第 floor 层选了第 index 张候选卡，返回该层节点数据包
func pick_option(floor: int, index: int) -> Dictionary:
	for rec in _run_route:
		if rec.floor == floor:
			if index < 0 or index >= rec.options.size():
				index = 0
			rec.picked = rec.options[index]
			_store_to_gm()
			return _make_node_pack(rec, rec.options[index])
	push_warning("[RouteGenerator] 未找到层 ", floor, " 的路线记录")
	return {}

## 构造节点数据包（GDD 附录 C「节点数据包」）
func _make_node_pack(rec: Dictionary, node_type: int) -> Dictionary:
	var pack := {
		"node_type": node_type,
		"floor": rec.floor,
		"enemies": _make_enemy_pack(rec.floor, node_type),
	}
	match node_type:
		1:  # ELITE
			pack["reward"] = { "relic_chance": 0.6, "legendary_chance": 0.4 }
			pack["elite_id"] = _roll_elite_id()
		2:  # CAMP
			pack["camp_options"] = _shuffle(["heal50", "evolve", "purify"])
		3:  # SHOP
			pack["shop_stock"] = _roll_shop_stock()
		4:  # EVENT
			pack["event_id"] = _roll_event_id()
		5:  # BOSS
			pack["boss_id"] = _roll_boss_id(_get_chapter())
	return pack

## 当前章节号（GDD 7.5）
func _get_chapter() -> int:
	if _gm and "chapter" in _gm:
		var c: int = int(_gm.chapter) if _gm.chapter > 0 else 1
		return c
	return 1

## 章节敌人数量放大：1 章不变，2 章 ×1.15，3 章 ×1.3，4+ 每章再 ×1.1
func _chapter_count_scale(chapter: int) -> float:
	match chapter:
		1: return 1.0
		2: return 1.15
		3: return 1.30
		_: return 1.15 * pow(1.1, maxi(0, chapter - 2))

## 章节敌人属性放大（含 GDD：速度 +20%/章、4+ 全属性 ×1.25）
func _chapter_stat_scale(chapter: int) -> float:
	match chapter:
		1: return 1.0
		2: return 1.2
		3: return 1.4
		_: return 1.4 * pow(1.25, maxi(0, chapter - 3))

## 运行中当前章节难度（供 UI/外部读取）
func get_runtime_difficulty() -> float:
	return _runtime_difficulty

## 章节 Boss：每章换形态 + 数值随章节放大
func _roll_boss_id(chapter: int) -> String:
	match chapter:
		1: return "boss_ch1"
		2: return "boss_v2_void"
		3: return "boss_v3_abyss"
		_: return "boss_ch%d" % chapter

## 普通波 / 精英护卫 的敌人编队包（GDD 7.3）
func _make_enemy_pack(floor: int, node_type: int) -> Array:
	var base := _normal_pack_for_floor(floor)
	if node_type == 1:  # ELITE：1 精英 + 2-3 护卫
		var escorts := []
		for e in base:
			if escorts.size() >= 3:
				break
			var seen := false
			for s in escorts:
				if s.type == e.type:
					seen = true
			if not seen:
				escorts.push_back({ "type": e.type, "count": 1 })
		var pack := [{ "type": _roll_elite_id(), "count": 1 }]
		for s in escorts:
			pack.push_back(s)
		return pack
	return _apply_chapter_count_scale(base)

func _apply_chapter_count_scale(entries: Array) -> Array:
	var ch: int = _get_chapter()
	var scale: float = _chapter_count_scale(ch)
	if ch <= 1:
		return entries
	for e in entries:
		if int(e.count) > 0:
			e.count = maxi(1, int(e.count * scale + 0.5))
	return entries

## 普通波按层号编队（GDD 7.3 普通波表）
func _normal_pack_for_floor(floor: int) -> Array:
	match floor:
		1:  return [{ "type": "basic", "count": 5 }]
		2:  return [{ "type": "basic", "count": 8 }, { "type": "swift", "count": 2 }]
		4:  return [{ "type": "basic", "count": 10 }, { "type": "swift", "count": 3 }, { "type": "heavy", "count": 1 }]
		6:  return [{ "type": "basic", "count": 12 }, { "type": "swift", "count": 4 }, { "type": "heavy", "count": 2 }, { "type": "split", "count": 1 }]
		8:  return [{ "type": "basic", "count": 14 }, { "type": "swift", "count": 5 }, { "type": "heavy", "count": 3 }, { "type": "split", "count": 2 }]
		10: return [{ "type": "basic", "count": 15 }, { "type": "swift", "count": 6 }, { "type": "heavy", "count": 3 }, { "type": "split", "count": 2 }, { "type": "decoy", "count": 1 }]
		_:  return _interp_pack(floor)

## 未列出的层（3/5/7/9/11/12 roll 成普通波时）按相邻插值
func _interp_pack(floor: int) -> Array:
	var known_basic := { 1: 5, 2: 8, 4: 10, 6: 12, 8: 14, 10: 15 }
	var lo := 1
	var hi := 2
	for f in known_basic.keys():
		if f <= floor:
			lo = f
		if f >= floor:
			hi = f
			break
	if lo == hi:
		return _normal_pack_for_floor(lo)
	var span := maxf(1.0, float(hi - lo))
	var t := float(floor - lo) / span
	var basic_count := int(known_basic[lo] + (known_basic[hi] - known_basic[lo]) * t)
	var pack := [{ "type": "basic", "count": basic_count }]
	if floor >= 2:
		pack.push_back({ "type": "swift", "count": maxi(2, (floor - 1) / 2) })
	if floor >= 4:
		pack.push_back({ "type": "heavy", "count": maxi(1, (floor - 3) / 2) })
	if floor >= 6:
		pack.push_back({ "type": "split", "count": maxi(1, (floor - 5) / 3) })
	return pack

## 精英 4 变体（GDD 7.3）roll 1 个
func _roll_elite_id() -> String:
	var ids := ["elite_tearer", "elite_toxin", "elite_mirror", "elite_fortress"]
	return ids[randi() % ids.size()]

## 营地 3 选 1（GDD 7.3）
func _roll_camp_options() -> Array:
	return _shuffle(["heal50", "evolve", "purify"])

## 商店库存（GDD 7.3，roll 3-5 项）
func _roll_shop_stock() -> Array:
	var stock := []
	stock.push_back("common_card")
	if randf() < 0.6:
		stock.push_back("rare_card")
	if randf() < 0.7:
		stock.push_back("heal30")
	if randf() < 0.5:
		stock.push_back("energy5")
	if randf() < 0.4:
		stock.push_back("sell")
	stock.shuffle()
	if stock.size() > 5:
		stock.resize(5)
	return stock

## 事件 6 预设（GDD 7.3）roll 1 个
func _roll_event_id() -> String:
	var ids := ["hungry_egg", "ruin", "mystery_merchant", "energy_vortex", "cursed_orb", "time_rift"]
	return ids[randi() % ids.size()]

## 当前层难度系数（floor × node，供 wave_spawner / 敌人缩放）
func get_difficulty(floor: int, node_type: int) -> float:
	var ff: float = FLOOR_FACTOR.get(floor, 1.0)
	var nf: float = NODE_FACTOR.get(node_type, 1.0)
	return ff * nf

## 当前运行时章节属性放大（速度/血量的章节部分）
func get_chapter_stat_scale() -> float:
	return _chapter_stat_scale(_get_chapter())

## 节点中文名（供 UI）
func node_name(node_type: int) -> String:
	return NODE_NAMES.get(node_type, "?")

## 从 GameManager 恢复本局路线（load_game 后调用）
func restore_from_gm() -> void:
	if _gm == null:
		return
	var data = _gm.get_meta("run_route", [])
	if data.is_empty() and "run_route" in _gm:
		data = _gm.run_route
	if not data.is_empty():
		_run_route = data
		print("[RouteGenerator] 已恢复 ", _run_route.size(), " 层路线")

## 打印路线（调试）
func _print_route(route: Array) -> void:
	print("[RouteGenerator] 本局路线:")
	for rec in route:
		var opts := []
		for t in rec.options:
			opts.push_back(node_name(t))
		print("  层 ", rec.floor, " → ", " / ".join(opts))
