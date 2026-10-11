extends RefCounted
## material_system.gd
## v1.2: 五行材质升级/熔炼/分解 (GDD 2.4 / 2.5)
## 升级: 同属性材质提档, 成功率 = 100% - 目标档阶*10%, 需 3 个同品质同属性辅助材质; 失败退回低一档
## 熔炼: 不同属性材质混合, 产物双属性 + 背板占比; 升级成功率低于同属性; 单一属性占比>75% 回归单一
## 纯数据逻辑, 无节点

const MATERIALS: Array[String] = ["金", "木", "水", "火", "土"]
const TIERS: Array[int] = [0, 1, 2, 3, 4, 5]  # 白绿蓝紫橙红
const TIER_NAMES: Dictionary = { 0: "白", 1: "绿", 2: "蓝", 3: "紫", 4: "橙", 5: "红" }

## 升级成功率: 目标档阶 * 10% 折损 (GDD 2.4)
## 白→绿=90%, 绿→蓝=80%, 蓝→紫=70%, 紫→橙=60%, 橙→红=50%
static func upgrade_success_chance(target_tier: int) -> float:
	return clamp(1.0 - target_tier * 0.10, 0.0, 1.0)

## 执行升级: 主材质从 tier 提至 tier+1
## 结果: {success: bool, great: bool, critical: bool, new_tier: int}
## great=大成功跳一档(5%), critical=暴击(2%), 只在成功时 roll
## 可选传入可控的随机源 (func()->float), 默认真随机
static func attempt_upgrade(current_tier: int, rand_check: Callable = Callable()) -> Dictionary:
	var target: int = current_tier + 1
	if target > 5:
		return {"success": false, "great": false, "critical": false, "new_tier": current_tier}
	var roll: float = rand_check.call() if rand_check.is_valid() else randf()
	if roll >= upgrade_success_chance(target):
		# 失败: 退回低一档 (不低于白)
		return {"success": false, "great": false, "critical": false, "new_tier": maxi(0, current_tier - 1)}
	var great_roll: float = rand_check.call() if rand_check.is_valid() else randf()
	var critical_roll: float = rand_check.call() if rand_check.is_valid() else randf()
	var new_tier: int = target
	var great: bool = false
	var critical: bool = false
	if great_roll < 0.05:
		new_tier = mini(5, target + 1)  # 大成功跳一档
		great = true
	elif critical_roll < 0.02:
		critical = true
	return {"success": true, "great": great, "critical": critical, "new_tier": new_tier}

## 升级需额外 3 个同品质同属性辅助材质 (GDD 2.4)
static func upgrade_aux_count() -> int:
	return 3

## 熔炼: 两种不同属性材质 → 双属性产物 + 背板占比
## a/b 为数量或权重, 返回 {attrs:[x,y], ratio: {x:0.0..1.0, y:...}, is_single: bool}
static func smelt(attr_a: String, attr_b: String, weight_a: float, weight_b: float) -> Dictionary:
	if attr_a == attr_b or not (attr_a in MATERIALS) or not (attr_b in MATERIALS):
		return {}
	var total: float = weight_a + weight_b
	if total <= 0.0:
		return {}
	var ratio_a: float = weight_a / total
	var ratio_b: float = weight_b / total
	# 单一属性占比超过 75% → 回归单一属性 (GDD 2.5)
	var is_single: bool = (ratio_a > 0.75 or ratio_b > 0.75)
	return {
		"attrs": [attr_a, attr_b],
		"ratio": {attr_a: ratio_a, attr_b: ratio_b},
		"is_single": is_single,
		"dominant": attr_a if ratio_a >= ratio_b else attr_b,
	}

## 熔炼产物升级成功率低于同属性 (GDD 2.5): 在基础成功率上额外 -10%
static func smelted_upgrade_chance(target_tier: int) -> float:
	return clamp(upgrade_success_chance(target_tier) - 0.10, 0.0, 1.0)

