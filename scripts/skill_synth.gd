extends RefCounted
## skill_synth.gd
## v1.2: 技能合成系统 (GDD 2.2 + 技能合成系统和浸篆系统.md)
## 技能空间 2 张未浸篆技能 → 高阶/异化 (复合材)。产物元素 = 两元素交互 (共 21 种两两组合, 28 种物性见文档)
## 纯数据逻辑

## 七元素两两组合 → 复合材名 + 物性标签 (来自 技能合成系统和浸篆系统.md 互合成表)
const COMPOUNDS: Dictionary = {
	"风+火": {"name": "燎原", "tags": ["供氧助燃", "扇形扩散", "顺风延长", "逆风自熄"]},
	"风+水": {"name": "雾",   "tags": ["遮蔽视线", "降低锁定", "可导电"]},
	"风+土": {"name": "沙",   "tags": ["磨损护甲", "减速", "磨蚀机关", "可玻璃化"]},
	"风+雷": {"name": "岚",   "tags": ["大范围落雷", "持续电场", "风暴区滞留"]},
	"风+光": {"name": "极光", "tags": ["折射光束", "幻象分身", "纯干扰"]},
	"风+暗": {"name": "阴风", "tags": ["穿透掩体", "降温", "驱散增益", "无声潜行"]},
	"火+水": {"name": "蒸汽", "tags": ["推开", "烫伤", "模糊视野", "可冷凝回水"]},
	"火+土": {"name": "熔岩", "tags": ["燃烧地表", "缓慢流动", "遇水凝黑曜石"]},
	"火+雷": {"name": "等离子","tags": ["无视部分抗性", "高温+麻痹", "极不稳定"]},
	"火+光": {"name": "圣焰", "tags": ["对不死/暗特攻", "持续灼烧", "照明解谜"]},
	"火+暗": {"name": "黑炎", "tags": ["粘附难灭", "持续掉血", "治疗反转"]},
	"水+土": {"name": "泥",   "tags": ["陷足减速", "降低摩擦", "可干燥成土"]},
	"水+雷": {"name": "激流", "tags": ["全场传导", "范围扩大伤害摊薄"]},
	"水+光": {"name": "虹露", "tags": ["治疗", "解状态", "分光谱线多属性"]},
	"水+暗": {"name": "浊毒", "tags": ["持续腐蚀", "降抗", "污染水源"]},
	"土+雷": {"name": "磁石", "tags": ["吸附金属", "偏转弹道", "牵引机关"]},
	"土+光": {"name": "晶簇", "tags": ["反射光线", "棱镜解谜", "脆而硬"]},
	"土+暗": {"name": "腐壤", "tags": ["削弱脚下单位", "生菌孢", "可肥沃化"]},
	"雷+光": {"name": "裁决", "tags": ["单体贯穿", "破盾", "对暗额外判定"]},
	"雷+暗": {"name": "咒雷", "tags": ["倒转操作", "技能沉默", "内伤型"]},
	"光+暗": {"name": "黄昏", "tags": ["双向兼容", "效果减半", "万能钥匙"]},
}
const ELEMENTS: Array[String] = ["风", "火", "水", "土", "雷", "光", "暗"]

## 归一化元素组合键 (顺序无关: 风+火 == 火+风)
static func combo_key(e1: String, e2: String) -> String:
	# 按固定顺序排, 保证 "风+火" 而非 "火+风"
	var i1: int = ELEMENTS.find(e1)
	var i2: int = ELEMENTS.find(e2)
	var hi: String = ELEMENTS[mini(i1, i2)]
	var lo: String = ELEMENTS[maxi(i1, i2)]
	return hi + "+" + lo

## 两元素合成 → 复合材 (含物性标签)。相同元素 → {} (同名不叠加)
static func synthesize(e1: String, e2: String) -> Dictionary:
	if e1 == e2 or not (e1 in ELEMENTS) or not (e2 in ELEMENTS):
		return {}
	return COMPOUNDS.get(combo_key(e1, e2), {})

## 生成一个高阶/异化技能 (需浸篆后才生效, GDD 2.2)
## 返回 {id, name, element, compound, tags, from, needs_inscribe}
static func make_synth_skill(skill_a: Dictionary, skill_b: Dictionary) -> Dictionary:
	var e1: String = str(skill_a.get("element", ""))
	var e2: String = str(skill_b.get("element", ""))
	var compound: Dictionary = synthesize(e1, e2)
	if compound.is_empty():
		# 同名元素: 生成强化版 (威力+20%)
		return {
			"id": "synth_%s_%s" % [skill_a.get("id", ""), skill_b.get("id", "")],
			"name": "高阶·" + e1,
			"element": e1,
			"compound": "同名强化",
			"tags": ["威力+20%"],
			"from": [skill_a.get("id", ""), skill_b.get("id", "")],
			"power_bonus": 0.2,
			"needs_inscribe": true,
		}
	return {
		"id": "synth_%s_%s" % [skill_a.get("id", ""), skill_b.get("id", "")],
		"name": compound.get("name", "异化"),
		"element": combo_key(e1, e2),
		"compound": compound.get("name", ""),
		"tags": compound.get("tags", []),
		"from": [skill_a.get("id", ""), skill_b.get("id", "")],
		"needs_inscribe": true,
	}

## 回收成本 (GDD: 复合材溶印退回基础材有损耗, 防穷举)
static func recycle_loss() -> float:
	return 0.15
