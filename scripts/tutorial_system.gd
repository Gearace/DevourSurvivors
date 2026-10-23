extends RefCounted
## tutorial_system.gd
## M5.6 新手前 30 秒引导 (路线化后的引导文案)
## 前 30 秒 3 条引导: 摇杆移动 / 吞噬敌人 / 技能释放
## 纯数据层, 无节点; 由 main_game_controller / HUD 调用, 按游戏时间推进

## 前 30 秒引导文案 (3 条, 触发时机 + 持续秒数)
const HINTS: Array = [
	{
		"trigger": "floor_1_start",   # 第 1 层开局
		"text": "拖动摇杆移动你的吞噬体",
		"duration": 6.0,
	},
	{
		"trigger": "first_enemy",     # 屏幕出现第 1 只敌人
		"text": "靠近敌人自动吞噬，吃掉它们成长",
		"duration": 8.0,
	},
	{
		"trigger": "first_capture",   # 第一次成功吞噬
		"text": "划屏释放技能，双击切换 — 吞噬波已装备",
		"duration": 8.0,
	},
]

## 取前 30 秒引导 (供测试 / HUD 读取)
static func get_first_30s_hints() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in HINTS:
		out.append(h.duplicate(true))
	return out

## 按游戏时间取当前应显示的引导 (前 30 秒)
## game_time: 自开局秒数; 返回当前 text (无引导返 "")
static func current_hint(game_time: float) -> String:
	if game_time > 30.0:
		return ""
	var cumulative: float = 0.0
	for h in HINTS:
		cumulative += float(h.get("duration", 0.0))
		if game_time < cumulative:
			return str(h.get("text", ""))
	return ""

## 取某 trigger 的引导文案
static func hint_by_trigger(trigger: String) -> Dictionary:
	for h in HINTS:
		if h.get("trigger", "") == trigger:
			return h.duplicate(true)
	return {}
