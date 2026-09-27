extends RefCounted
## GnawEscapeTable — 大怪挣脱率数值 (GDD 3.2.2 挣脱率)
## 不同大怪挣脱概率/反馈不同，越大越难啃
##
## 用法: preload().get_table().escape_params(type_id)
## 返回 Dictionary:
##   chance        : 每次挣脱检查的脱缰概率
##   interval      : 挣脱检查间隔 (秒)
##   feedback      : 挣脱时把玩家推开距离
##   energy_refund : 挣脱返还能量比例 (0~1, 占 max_energy)
##   steadiness    : 啃食稳固度倍率 (越大啃越快)

const BASE_CHANCE := 0.12
const BASE_INTERVAL := 1.5
const BASE_FEEDBACK := 0.0
const BASE_REFUND := 0.3
const BASE_STEADINESS := 1.0

static var _table: RefCounted = null

@static func get_table() -> RefCounted:
	if _table == null:
		_table = _GnawTable.new()
	return _table

class _GnawTable:
	## 挣脱参数表 (按敌人类型)
	var params: Dictionary = {
		# 大怪：短啃 → 较快挣脱
		"heavy": { "chance": 0.18, "interval": 1.2, "feedback": 60.0, "energy_refund": 0.4, "steadiness": 1.0 },
		# 分裂怪：中啃 → 中等
		"split": { "chance": 0.15, "interval": 1.5, "feedback": 50.0, "energy_refund": 0.35, "steadiness": 1.0 },
		# 诱饵：中啃 → 高频挣脱（陷阱性质）
		"decoy": { "chance": 0.30, "interval": 1.0, "feedback": 110.0, "energy_refund": 0.2, "steadiness": 0.85 },
		# Boss：长啃 → 低挣脱但反噬强
		"boss": { "chance": 0.08, "interval": 2.0, "feedback": 160.0, "energy_refund": 0.15, "steadiness": 0.8 },
	}

	## 取某类型的挣脱参数 (小怪没有啃食，返回空)
	func escape_params(type_id: String) -> Dictionary:
		if params.has(type_id):
			return params[type_id]
		# 默认 (未知大怪)
		return {
			"chance": BASE_CHANCE,
			"interval": BASE_INTERVAL,
			"feedback": BASE_FEEDBACK,
			"energy_refund": BASE_REFUND,
			"steadiness": BASE_STEADINESS,
		}
