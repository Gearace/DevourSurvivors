extends RefCounted
## floor_banner.gd
## 层清 → 决策 UI 之间补「清层横幅」感知 (GDD 七 层清反馈)
## 纯数据/时序逻辑, 无节点依赖, 便于 headless 测试

## 清层横幅文案 (GDD 七: 清层后弹 3s, 再弹进化卡 4 选 1)
static func cleared_banner_text(floor: int, node_name: String) -> String:
	var node_cn: String
	match node_name:
		"普通波", "": node_cn = "层清"
		"精英": node_cn = "精英讨伐完成"
		"事件": node_cn = "事件结束"
		_: node_cn = "层清"
	return "第 %d 层 %s — 进入路线选择" % [floor, node_cn]

## 横幅停留秒数 (GDD 七: 清层反馈 3s 再弹下一层选择)
const BANNER_DURATION_SEC: float = 3.0

## 层清奖励顺序 (GDD 七)
const CLEAR_REWARD_ORDER: Array[String] = ["进化卡 4 选 1", "遗物 3 选 1 (精英/Boss)", "路线 3 选 1"]

## 当前层剩余怪物数 → 提示文案 (吃怪反馈: 还差几只)
static func remaining_hint(remaining: int, total: int) -> String:
	if remaining <= 0:
		return "本层已清 — 等 4 选 1"
	if total <= 0:
		return ""
	return "剩余 %d/%d 敌人 — 清层触发 4 选 1" % [remaining, total]

## 横幅应显示 (层清后 3s 窗口内)
static func banner_shown(elapsed: float) -> bool:
	return elapsed <= BANNER_DURATION_SEC

## 横幅到期 → 放行到决策 UI
static func banner_done(elapsed: float) -> bool:
	return elapsed >= BANNER_DURATION_SEC
