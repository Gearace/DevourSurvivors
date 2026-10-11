extends RefCounted
## inscription_system.gd
## v1.2: 浸篆系统 (GDD 2.3) — 技能 + 五行材质 → 三类卡 (进化卡/变异卡/领域卡)
## 材质品阶+数量决定有效期 (1局 ~ 永久)；失效后技能放回技能空间, 材质被消耗
## 纯数据逻辑, 无节点, 便于单元测试

## 有效期 (局数) 规则: 品质越高/数量越多 → 越长, 最低 1 局, 最高永久
## 简化映射 (GDD 2.3: 1 个最低品质材质 = 1 局):
##   白(0): 1 局   绿(1): 2 局   蓝(2): 3 局   紫(3): 4 局   橙(4): 5 局   红(5): 永久
const TIER_DURATION: Dictionary = {
	0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: -1,  # -1 = 永久
}
const MATERIALS: Array[String] = ["金", "木", "水", "火", "土"]

## 技能基础元素 (七元素随机 roll, GDD 5: 元素由技能池随机 roll, 与技能本身无关)
## 若 skill 已带 element 则沿用, 否则随机
const SKILL_ELEMENTS: Array[String] = ["风", "火", "水", "土", "雷", "光", "暗"]

func _init() -> void:
	pass

## 计算有效期 (局数): 由材质品阶+数量决定
## qty >= 2 时 +1 局 (上限永久); 永久材质不受 qty 影响
static func calc_duration(material_tier: int, qty: int) -> int:
	var base: int = TIER_DURATION.get(material_tier, 1)
	if base == -1:
		return -1  # 已永久
	if qty >= 2:
		base += 1
	# 上限: 红=永久
	if base >= 5:
		return -1
	return base

## 由材质决定产出卡类型 (简化, 详见 CardDatabase.material_to_card_type)
static func card_type_for_material(material: String) -> String:
	var db = load("res://scripts/card_database.gd")
	if db and db.has_method("material_to_card_type"):
		return db.material_to_card_type(material)
	match material:
		"金", "水": return "进化卡"
		"木", "火": return "变异卡"
		"土": return "领域卡"
		_: return "进化卡"

## 执行浸篆: skill_id + 材质 → 三类卡
## 返回 {id, type, skill_id, skill_name, material, material_tier, duration, elapsed, name}
## 失败 (材质不足) 返回 {}
static func inscribe(skill_id: String, skill_name: String, material: String,
		material_tier: int, qty: int) -> Dictionary:
	if not (material in MATERIALS):
		return {}
	if material_tier < 0 or qty < 1:
		return {}
	var card_type: String = card_type_for_material(material)
	var duration: int = calc_duration(material_tier, qty)
	var type_label: String
	match card_type:
		"进化卡": type_label = "进化"
		"变异卡": type_label = "变异"
		"领域卡": type_label = "领域"
	return {
		"id": "%s_%s_%d" % [skill_id, material, material_tier],
		"type": card_type,
		"skill_id": skill_id,
		"skill_name": skill_name,
		"material": material,
		"material_tier": material_tier,
		"duration": duration,
		"elapsed": 0,
		"name": "%s·%s%s" % [type_label, material, skill_name],
	}

## 局间休整延长 1 局: 消耗同品质材质 1.5 倍每局数量 (GDD 2.3)
## 永久卡不可延长; 返回是否成功
static func can_extend(card: Dictionary) -> bool:
	if int(card.get("duration", 1)) == -1:
		return false
	return true

## 延长所需同品质材质数量 (ceil(1.5 * qty)), qty 来自卡本身
static func extend_cost(card: Dictionary) -> int:
	var tier: int = int(card.get("material_tier", 0))
	# 简化: 每局消耗 1 个该品质材质, 延长 1 局需 1.5 倍 → ceil
	var per_floor: int = max(1, tier + 1)
	return int(ceil(1.5 * per_floor))

## 合成 (GDD 2.2): 技能空间 2 张未浸篆技能 → 高阶/异化技能
## 产物元素 = 两元素交互; 简化: 拼接标签, 需浸篆后才生效
static func synthesize(skill_a: Dictionary, skill_b: Dictionary) -> Dictionary:
	var elem_a: String = str(skill_a.get("element", ""))
	var elem_b: String = str(skill_b.get("element", ""))
	return {
		"id": "synth_%s_%s" % [skill_a.get("id", ""), skill_b.get("id", "")],
		"name": "高阶·%s+%s" % [elem_a, elem_b],
		"element": "%s+%s" % [elem_a, elem_b],
		"from": [skill_a.get("id", ""), skill_b.get("id", "")],
		"needs_inscribe": true,
	}
