extends RefCounted
## interaction_matrix.gd
## v1.2: 五行材质 × 奇幻七元素 交互矩阵 (GDD 五行作用于元素.md)
## 结算: 最终威力 = 技能基础威力 × 材质加成 × 交互矩阵修正 × 遗物buff
## 8 种交互: 增幅×1.5 / 抵消×0.3 / 平衡×1.0 / 变异(×1.0+特殊) / 传导(范围+50%) / 庇护(减伤30%) / 同化(DOT) / 反噬(自损25%)

## 交互类型
const FUKU := "增幅"      # ×1.5
const DIUI := "抵消"      # ×0.3
const PINGHENG := "平衡"  # ×1.0
const BIAN_YI := "变异"   # ×1.0 + 特殊机制
const CHUAN_DAO := "传导" # 范围+50%
const BI_HU := "庇护"     # 减伤30%
const TONG_HUA := "同化"  # 每2s削20%
const FAN_SHI := "反噬"   # 释放时自损25%最大生命

## 威力倍率 (只影响数值, 传导/庇护/同化/反噬走特殊字段)
const MULTIPLIER: Dictionary = {
	"增幅": 1.5, "抵消": 0.3, "平衡": 1.0, "变异": 1.0,
	"传导": 1.0, "庇护": 1.0, "同化": 1.0, "反噬": 1.0,
}

## 完整矩阵 (五行5 × 奇幻7)。每格为交互类型数组 (可复合, 取首个为主威力修正)。
## 顺序: 五行 [金,木,水,火,土] × 奇幻 [风,火,水,土,雷,光,暗]
const MATRIX: Dictionary = {
	"金": ["平衡", "抵消", "平衡", "平衡", "传导", "变异", "变异"],
	"木": ["增幅", ["增幅", "同化"], "平衡", ["抵消", "同化"], "抵消", ["增幅", "庇护"], "变异"],
	"水": ["传导", ["抵消", "变异"], "增幅", ["抵消", "同化"], "传导", ["变异", "反噬"], ["增幅", "庇护"]],
	"火": ["传导", "增幅", ["抵消", "变异"], "增幅", ["变异", "传导"], "增幅", ["变异", "反噬"]],
	"土": [["抵消", "同化"], "平衡", ["抵消", "同化"], "增幅", "平衡", ["变异", "庇护"], ["变异", "庇护"]],
}
const ELEMENTS_FANTASY: Array[String] = ["风", "火", "水", "土", "雷", "光", "暗"]
const MATERIALS: Array[String] = ["金", "木", "水", "火", "土"]

## 取某 五行×奇幻 的交互 (可能多个)
static func get_interactions(material: String, fantasy_element: String) -> Array:
	var mat: Array = MATRIX.get(material, [])
	var idx: int = ELEMENTS_FANTASY.find(fantasy_element)
	if idx < 0 or idx >= mat.size():
		return ["平衡"]
	var cell: Variant = mat[idx]
	if typeof(cell) == TYPE_STRING:
		return [cell]
	return cell

## 主威力倍率 (取交互列表首个的倍率; 复合时首个为主)
static func get_power_multiplier(material: String, fantasy_element: String) -> float:
	var interactions: Array = get_interactions(material, fantasy_element)
	var primary: Variant = interactions[0]
	var primary_name: String = primary if typeof(primary) == TYPE_STRING else (primary[0] if primary.size() > 0 else "平衡")
	return MULTIPLIER.get(primary_name, 1.0)

## 范围修正 (传导 → 范围 +50%)
static func get_range_bonus(material: String, fantasy_element: String) -> float:
	for it in get_interactions(material, fantasy_element):
		var name: String = it if typeof(it) == TYPE_STRING else (it[0] if it.size() > 0 else "")
		if name == "传导":
			return 0.5
	return 0.0

## 是否带 庇护 (减伤30%)
static func has_shield(material: String, fantasy_element: String) -> bool:
	for it in get_interactions(material, fantasy_element):
		var name: String = it if typeof(it) == TYPE_STRING else (it[0] if it.size() > 0 else "")
		if name == "庇护":
			return true
	return false

## 是否带 同化 (DOT 每2s削20%目标属性)
static func has_corrosion(material: String, fantasy_element: String) -> bool:
	for it in get_interactions(material, fantasy_element):
		var name: String = it if typeof(it) == TYPE_STRING else (it[0] if it.size() > 0 else "")
		if name == "同化":
			return true
	return false

## 是否带 反噬 (释放自损25%最大生命)
static func has_backlash(material: String, fantasy_element: String) -> bool:
	for it in get_interactions(material, fantasy_element):
		var name: String = it if typeof(it) == TYPE_STRING else (it[0] if it.size() > 0 else "")
		if name == "反噬":
			return true
	return false

## 完整结算: 基础威力 → 最终威力 + 附加修正
## material_bonus: 材质自身五行加成 (简化默认 1.0, 由浸篆品阶决定, 见 inscription)
## relic_buff: 遗物数值 buff (默认 1.0)
static func resolve(base_power: float, material: String, fantasy_element: String,
		material_bonus: float = 1.0, relic_buff: float = 1.0) -> Dictionary:
	var interactions: Array = get_interactions(material, fantasy_element)
	var power_mult: float = get_power_multiplier(material, fantasy_element)
	var final: float = base_power * material_bonus * power_mult * relic_buff
	return {
		"final_power": final,
		"power_multiplier": power_mult,
		"range_bonus": get_range_bonus(material, fantasy_element),
		"shield_damage_reduction": 0.3 if has_shield(material, fantasy_element) else 0.0,
		"corrosion_dot": has_corrosion(material, fantasy_element),
		"backlash_self_damage": has_backlash(material, fantasy_element),
		"interactions": interactions,
	}
