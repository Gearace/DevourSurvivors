extends RefCounted
## alarm_system.gd
## v1.2 P1: 警报机制 (合金装备警报等级, docs/关卡设计_灵感归纳_v1.md §3.5)
## 玩家行为触发难度: 同一层连续吞噬 N 只不受伤 → 警报 ×1 → 下一层敌人数 +20%
## 精英层清完护卫瞬间警报清零 (奖励干净清场)
## 纯数据逻辑, 无节点, 便于单元测试

## 连续吞噬阈值 (不受伤即累加)
const CAPTURE_THRESHOLD := 5
## 警报等级 → 下一层敌人数放大
const ALARM_SCALE: Dictionary = { 0: 1.0, 1: 1.2, 2: 1.4 }
## 受伤后连续吞噬计数重置

## 状态: 当前警报等级 (0/1/2) + 本层连续吞噬计数
var alarm_level: int = 0
var capture_streak: int = 0

## 玩家吞噬 1 只 (不受伤时由 player 调用) → 累加 streak, 达阈值升警报
func on_capture() -> void:
	capture_streak += 1
	if capture_streak >= CAPTURE_THRESHOLD:
		# 每满 5 只 +1 警报 (上限 2)
		var new_level: int = mini(2, capture_streak / CAPTURE_THRESHOLD)
		if new_level > alarm_level:
			alarm_level = new_level
			capture_streak = 0  # 升级后重新计数

## 玩家受伤 (碰撞反噬/精英撕裂波/Boss 反噬) → 警报清零 + streak 清零
func on_damage() -> void:
	if alarm_level > 0:
		alarm_level = 0
	capture_streak = 0

## 精英层清完护卫 → 警报清零 (奖励干净清场, §3.5)
func on_elite_cleared() -> void:
	alarm_level = 0
	capture_streak = 0

## 取下一层敌人数放大 (供 wave_spawner / route_generator 读)
func get_next_layer_scale() -> float:
	return ALARM_SCALE.get(alarm_level, 1.0)

## 跨大关重置 (杀戮尖塔 build 延续, §3.0: 警报归零)
func reset() -> void:
	alarm_level = 0
	capture_streak = 0
