extends RefCounted
## relic_system.gd
## v1.2: 遗物 (道具类, GDD 六) — 数值 buff, 独立于卡牌体系, 拾取即局内生效
## 不参与浸篆/合成/升级/熔炼。稀有度 5 档: 普通/罕见/史诗/传说/神器
## 掉落: 精英层 3选1 (普通60/罕见30/史诗9/传说1); Boss 层保底1史诗以上 + 2 高稀有; 普通层无遗物

const RARITY_CN: Array[String] = ["普通", "罕见", "史诗", "传说", "神器"]
const RARITY_RANK: Dictionary = { "普通": 0, "罕见": 1, "史诗": 2, "传说": 3, "神器": 4 }

## roll 3 个遗物道具 (node_type: 1=精英, 5=Boss; 其它层无遗物返回空)
static func roll_relics(node_type: int, _seed: float = -1.0) -> Array[Dictionary]:
	if node_type != 1 and node_type != 5:
		return []
	var db = load("res://scripts/card_database.gd")
	var is_boss: bool = (node_type == 5)
	var drawn: Array[Dictionary] = []
	if is_boss:
		# 保底 1 史诗以上 (index 0), 其余 2 个偏高稀有度
		var hi_rarity: String
		var r: float = randf()
		if r < 0.5: hi_rarity = "史诗"
		elif r < 0.8: hi_rarity = "传说"
		else: hi_rarity = "神器"
		var p0: Variant = _pick_rarity(db, hi_rarity)
		if p0 != null: drawn.append(p0)
		for i in range(2):
			var r2: float = randf()
			var rar: String
			if r2 < 0.5: rar = "罕见"
			elif r2 < 0.85: rar = "史诗"
			else: rar = "传说"
			var p: Variant = _pick_rarity(db, rar)
			if p != null: drawn.append(p)
	else:
		# 精英层: 普通60 / 罕见30 / 史诗9 / 传说1
		for i in range(3):
			var p: Variant = _pick_rarity(db, _roll_elite_rarity())
			if p != null: drawn.append(p)
	return drawn

## 精英层稀有度分布
static func _roll_elite_rarity() -> String:
	var r: float = randf()
	if r < 0.60: return "普通"
	elif r < 0.90: return "罕见"
	elif r < 0.99: return "史诗"
	else: return "传说"

## 从该稀有度遗物池取 1 个; 池空则降级到普通
static func _pick_rarity(db, rarity_cn: String) -> Variant:
	var pool: Array[Dictionary] = db.get_relic_props_by_rarity(rarity_cn)
	if pool.is_empty():
		pool = db.get_relic_props_by_rarity("普通")
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

## 应用遗物 buff 到 GameManager (纯数值, GDD 六: 最终威力 × 遗物buff)
static func apply_buff(relic: Dictionary, gm) -> void:
	if gm == null or relic.is_empty():
		return
	var buff: Dictionary = relic.get("buff", {})
	var s: Dictionary = gm.player_stats
	if "max_hp_bonus" in buff:
		var bonus: float = buff["max_hp_bonus"]
		s["max_hp"] = int(s.get("max_hp", 100) * (1.0 + bonus))
		if buff.get("start_full_hp", false):
			s["current_hp"] = s["max_hp"]
	if "gnaw_speed_bonus" in buff:
		s["gnaw_speed_multiplier"] = s.get("gnaw_speed_multiplier", 1.0) + buff["gnaw_speed_bonus"]
	if "energy_regen_bonus" in buff:
		s["energy_regen_bonus"] = s.get("energy_regen_bonus", 0.0) + buff["energy_regen_bonus"]
	if "material_resist_bonus" in buff:
		s["material_resist_bonus"] = s.get("material_resist_bonus", 0.0) + buff["material_resist_bonus"]
	if "control_duration_bonus" in buff:
		s["control_duration_bonus"] = buff["control_duration_bonus"]
	# 元素增幅 / 无冷却 / 开局无敌 等存 buff 供 skill_system 结算
	gm.relic_buffs.append(relic.get("id", ""))
	var gm_relics = gm.relic_buffs  # 记录已拾取遗物 id
	print("[RelicSystem] 应用遗物 buff: ", relic.get("name", ""), " -> ", buff)

## 汇总遗物数值 buff (用于最终威力公式的 遗物buff 项)
static func total_power_buff(relic_ids: Array) -> float:
	var db = load("res://scripts/card_database.gd")
	var props: Array[Dictionary] = db.get_relic_props()
	var multi: float = 1.0
	for p in props:
		if p.get("id", "") in relic_ids:
			var buff: Dictionary = p.get("buff", {})
			# 元素增幅累加到该元素 (简化: 取最大 ×1.5 作为整体系数)
			if "element_power" in buff:
				var ep: Dictionary = buff["element_power"]
				for k in ep:
					multi = maxf(multi, float(ep[k]))
	if multi <= 0.0:
		return 1.0
	return multi
