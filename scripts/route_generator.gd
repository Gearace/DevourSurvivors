extends Node
## RouteGenerator — 路线生成器 (GDD 7.2 / 5.7)
## 负责：每局 roll 出 13 层完整路线 + 各层候选卡片，
## 带模板约束（精英≤2、商店≥1、事件≤2），结果写入 GameManager.run_route。
## v1.2 多大关: 按大关风格 (chapter_style.gd) roll 节点 — 每大关独立怪物风格 + Boss + 专属遗物
## (docs/关卡设计_灵感归纳_v1.md §3.0, 派生自 杀戮尖塔/黑神话/原神)
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
	# v1.2 多大关 §3.1 节奏曲线: 张力峰(3/6/9/12) + 战斗强度递增(4/5/8/10/12)
	1: 1.0,  2: 1.0,
	3: 0.3,  # 营地 — 张力峰(非战斗, 低系数)
	4: 1.15, # 三敌围猎+精英预演
	5: 1.4,  # 精英(首次) — 战斗强度峰
	6: 0.5,  # 事件(元素谜题) — 张力峰
	7: 0.3,  # 营地
	8: 0.5,  # 商店
	9: 1.6,  # 精英(精英×2) — 战斗强度峰
	10: 1.35, # 普通(高压层: 3×基础+1分裂)
	11: 1.2,  # 事件(路线分支) — 张力峰
	12: 1.8,  # 精英(高难度) — 战斗强度峰
	13: 2.0,  # Boss
}

# ─── 13 层节奏曲线模板（v1.2 多大关 §3.1, 派生自 FC 关卡门 + 忍者龙剑传限时）───
# 节奏点: 3/6/9/12 层为「张力峰」(非战斗节点), 战斗层 4/5/8/10/12 强度递增
# 每层: { floor, fixed, type(固定层) 或 options(roll层) }
# 节点类型: 0=普通波 1=精英 2=营地 3=商店 4=事件 5=Boss
var _template: Array = [
	{ "floor": 1,  "fixed": true,  "type": 0 },  # 普通(教学) — 本大关风格首现
	{ "floor": 2,  "fixed": true,  "type": 0 },  # 普通(双敌变体)
	{ "floor": 3,  "fixed": false, "options": [2] },  # 营地(1选1) — 张力峰
	{ "floor": 4,  "fixed": true,  "type": 0 },  # 普通(三敌围猎+精英预演)
	{ "floor": 5,  "fixed": false, "options": [1] },  # 精英(首次) — 战斗强度峰
	{ "floor": 6,  "fixed": false, "options": [4] },  # 事件(元素谜题) — 张力峰
	{ "floor": 7,  "fixed": false, "options": [2] },  # 营地(1选1)
	{ "floor": 8,  "fixed": false, "options": [3] },  # 商店(2遗物)
	{ "floor": 9,  "fixed": false, "options": [1] },  # 精英(精英×2, 护卫×3) — 战斗强度峰
	{ "floor": 10, "fixed": true,  "type": 0 },  # 普通(高压层: 3×基础+1分裂)
	{ "floor": 11, "fixed": false, "options": [4] },  # 事件(路线分支) — 张力峰
	{ "floor": 12, "fixed": false, "options": [1] },  # 精英(精英×2+护卫×3, 高难度) — 战斗强度峰
	{ "floor": 13, "fixed": true,  "type": 5 },  # Boss(3阶段, 法宝遗物)
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
## v1.2 P1 警报机制 (合金装备 §3.5): 玩家行为触发难度
var alarm: RefCounted

func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	var _cs = load("res://scripts/chapter_style.gd")
	set_meta("chapter_style", _cs)
	# v1.2 P1 警报机制 (合金装备 §3.5): 玩家行为触发难度
	alarm = load("res://scripts/alarm_system.gd").new()
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
	# v1.2 多大关: 节奏曲线模板 (3.1) 已固定 精英/事件/营地/商店 在各层, 无需约束校验
	# 保留兼容: 仅校验 Boss 在层 13, 且每层 options 非空
	for rec in route:
		if rec.options.is_empty():
			return false
		if rec.floor == 13:
			for t in rec.options:
				if t != 5:
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
	# v1.2 多大关: 统一走 chapter_style 表 (敌人数 ×1.1/大关)
	var cs: Variant = load("res://scripts/chapter_style.gd")
	return cs.chapter_count_scale(chapter)
func _chapter_stat_scale(chapter: int) -> float:
	# v1.2 多大关: 统一走 chapter_style 表 (难度 ×1.25/大关)
	var cs: Variant = null
	if has_meta("chapter_style"):
		cs = get_meta("chapter_style")
	if cs == null:
		cs = load("res://scripts/chapter_style.gd")
		set_meta("chapter_style", cs)
	return cs.chapter_stat_scale(chapter)

## 运行中当前章节难度（供 UI/外部读取）
func get_runtime_difficulty() -> float:
	return _runtime_difficulty

## 章节 Boss：每章换形态 + 数值随章节放大
func _roll_boss_id(chapter: int) -> String:
	# v1.2 多大关: 按大关风格表取 Boss (杀戮尖塔式每关不同 Boss)
	var cs: Variant = null
	if has_meta("chapter_style"):
		cs = get_meta("chapter_style")
	if cs == null:
		cs = load("res://scripts/chapter_style.gd")
		set_meta("chapter_style", cs)
	var style: Dictionary = cs.get_style(chapter)
	return style.get("boss_id", "boss_ch%d" % chapter)

## 取当前大关风格 (供 wave_spawner / 环境 / UI 读取)
func get_current_style() -> Dictionary:
	var cs: Variant = null
	if has_meta("chapter_style"):
		cs = get_meta("chapter_style")
	if cs == null:
		cs = load("res://scripts/chapter_style.gd")
		set_meta("chapter_style", cs)
	return cs.get_style(_get_chapter())

## 取指定大关风格 (测试用, 不依赖 gm.chapter)
func get_current_style_from_chapter(chapter: int) -> Dictionary:
	var cs: Variant = null
	if has_meta("chapter_style"):
		cs = get_meta("chapter_style")
	if cs == null:
		cs = load("res://scripts/chapter_style.gd")
		set_meta("chapter_style", cs)
	return cs.get_style(chapter)

## 大关中文名 (供 HUD 显示)
func get_style_name() -> String:
	return get_current_style().get("name", "")

## 大关专属遗物 (Boss 通关必掉, 黑神话法宝)
func get_style_relic_id() -> String:
	return get_current_style().get("relic_id", "")

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
		# v1.2 P1 警报: 精英层也受警报放大 (护卫视野被压缩)
		return _apply_alarm_scale(_apply_chapter_count_scale(pack))
	return _apply_chapter_count_scale(base)

## v1.2 P1 警报机制: 按当前警报等级放大下一层敌人数 (§3.5: ×1.2/×1.4)
func _apply_alarm_scale(entries: Array) -> Array:
	if alarm == null:
		return entries
	var scale: float = alarm.get_next_layer_scale()
	if scale <= 1.0:
		return entries
	for e in entries:
		if int(e.count) > 0:
			e.count = maxi(1, int(e.count * scale + 0.5))
	return entries

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
	var pack: Array
	match floor:
		1:  pack = [{ "type": "basic", "count": 5 }]
		2:  pack = [{ "type": "basic", "count": 8 }, { "type": "swift", "count": 2 }]
		4:  pack = [{ "type": "basic", "count": 10 }, { "type": "swift", "count": 3 }, { "type": "heavy", "count": 1 }]
		6:  pack = [{ "type": "basic", "count": 12 }, { "type": "swift", "count": 4 }, { "type": "heavy", "count": 2 }, { "type": "split", "count": 1 }]
		8:  pack = [{ "type": "basic", "count": 14 }, { "type": "swift", "count": 5 }, { "type": "heavy", "count": 3 }, { "type": "split", "count": 2 }]
		10: pack = [{ "type": "basic", "count": 15 }, { "type": "swift", "count": 6 }, { "type": "heavy", "count": 3 }, { "type": "split", "count": 2 }, { "type": "decoy", "count": 1 }]
		_:  pack = _interp_pack(floor)
	# v1.2 多大关: 注入本大关风格的新增怪 (杀戮尖塔式 每关不同怪物)
	# 层 2 起刷本风格 extra_enemies, 层 4 起额外 +1 只
	var style: Dictionary = get_current_style()
	var extra: Array = style.get("extra_enemies", [])
	if not extra.is_empty() and floor >= 2:
		var type_id: String = str(extra[0])
		var inject_count: int = 1 if floor < 4 else 2
		pack.push_back({ "type": type_id, "count": inject_count })
	return pack

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

## v1.2 P1 层 11 路线分支 (杀戮尖塔 §3.2): 2 条路线, 选「安全线」或「风险线」
## 安全线: 后续层 12 降为 普通波(低难度), 遗物 ×1
## 风险线: 后续层 12 保持 精英(高难度), 遗物 ×2 (超额回报)
## 返回: { branch: "safe"|"risky", next_floor_type: int, relic_multiplier: int }
func roll_route_branch() -> Dictionary:
	var is_risky: bool = randf() < 0.5
	if is_risky:
		return { "branch": "risky", "next_floor_type": 1, "relic_multiplier": 2, "label": "风险线 · 精英 ×2 遗物" }
	return { "branch": "safe", "next_floor_type": 0, "relic_multiplier": 1, "label": "安全线 · 普通波 + 营地" }

## 应用路线分支到层 12 (玩家选了安全线 → 层 12 降为普通波; 风险线 → 保持精英)
func apply_route_branch(branch: Dictionary) -> void:
	if _run_route.is_empty():
		return
	for rec in _run_route:
		if rec.floor == 12:
			var new_type: int = int(branch.get("next_floor_type", 0))
			rec.options = [new_type]
			# 风险线遗物 ×2 → 标记本层 elite 掉落遗物数 ×2 (wave_spawner 读)
			if int(branch.get("relic_multiplier", 1)) > 1:
				set_meta("relic_multiplier", 2)
			_store_to_gm()
			print("[RouteGenerator] 路线分支应用: ", branch.get("label", ""), " → 层 12 变 ", node_name(new_type))
			return

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
