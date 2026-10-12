extends RefCounted
## DevourTable — 吞噬机制数值表 (GDD 3.2.5 敌人类型 → 机制映射)
## 用法: var table = preload(""res://scripts/devour_table.gd"").new()
##
## 四层机制:
##   门槛  能否一口吞 (体型比对)
##   进度  大怪需持续啃 N 秒才吞下 (环形进度条)
##   反噬  啃比自己大的怪时被扣血/推开
##   资源  啃大怪持续消耗能量 (小怪一口吞免费)

const GROWTH_PER_LEVEL := 1.0          # 每级体型增量
const START_BODY_RADIUS := 20.0       # 初始玩家体型
# v1.2: 体型成长 = 初始 20px + 变异卡数量×1px + 变异卡效果 (GDD 2.0)
const MUTATION_BODY_BONUS := 1.0     # 每张变异卡 +1px 体型

# ─── 数据表 ─────────────────────────────────────────────
var one_bite: Dictionary = { "basic": true, "swift": true }
var gnaw: Dictionary = { "basic": 0.0, "swift": 0.0, "heavy": 2.0, "split": 3.0, "decoy": 3.0, "boss": 8.0,
	"boss_ch1": 12.0, "boss_v2_void": 12.0, "boss_v3_abyss": 12.0,
	"elite_tearer": 5.0, "elite_toxin": 4.0, "elite_mirror": 3.0, "elite_fortress": 10.0 }
var gnaw_energy_per_sec: Dictionary = { "basic": 0.0, "swift": 0.0, "heavy": 1.0, "split": 0.8, "decoy": 1.2, "boss": 2.0,
	"boss_ch1": 2.0, "boss_v2_void": 2.0, "boss_v3_abyss": 2.0,
	"elite_tearer": 1.0, "elite_toxin": 0.8, "elite_mirror": 0.8, "elite_fortress": 0.0 }
var gnaw_hp_dmg: Dictionary = { "basic": 0.0, "swift": 0.0, "heavy": 3.0, "split": 0.0, "decoy": 5.0, "boss": 6.0,
	"boss_ch1": 3.0, "boss_v2_void": 3.0, "boss_v3_abyss": 3.0,
	"elite_tearer": 2.0, "elite_toxin": 3.0, "elite_mirror": 2.0, "elite_fortress": 0.0 }
var collision_dmg: Dictionary = { "basic": 0.0, "swift": 0.0, "heavy": 4.0, "split": 3.0, "decoy": 5.0, "boss": 8.0,
	"boss_ch1": 15.0, "boss_v2_void": 15.0, "boss_v3_abyss": 15.0,
	"elite_tearer": 6.0, "elite_toxin": 5.0, "elite_mirror": 4.0, "elite_fortress": 0.0 }
var collision_pushback: Dictionary = { "basic": 0.0, "swift": 0.0, "heavy": 90.0, "split": 70.0, "decoy": 110.0, "boss": 160.0,
	"boss_ch1": 160.0, "boss_v2_void": 160.0, "boss_v3_abyss": 160.0,
	"elite_tearer": 120.0, "elite_toxin": 110.0, "elite_mirror": 90.0, "elite_fortress": 130.0 }
var energy_gain: Dictionary = { "basic": 2.0, "swift": 1.0, "heavy": 3.0, "split": 2.0, "decoy": 0.0, "boss": 10.0,
	"boss_ch1": 10.0, "boss_v2_void": 10.0, "boss_v3_abyss": 10.0,
	"elite_tearer": 5.0, "elite_toxin": 5.0, "elite_mirror": 5.0, "elite_fortress": 5.0 }

# ─── 查询 API ─────────────────────────────────────────────

## 能否一口吞
func is_one_bite(type_id: String) -> bool:
	return one_bite.get(type_id, false)

## 啃食需要多少秒 (0 = 一口吞)
func gnaw_seconds(type_id: String) -> float:
	return gnaw.get(type_id, 0.0)

## 啃食每秒耗能
func energy_cost_per_sec(type_id: String) -> float:
	return gnaw_energy_per_sec.get(type_id, 0.0)

## 啃食反噬每秒扣血
func gnaw_damage_per_sec(type_id: String) -> float:
	return gnaw_hp_dmg.get(type_id, 0.0)

## 撞到该类型受伤 (敌人比玩家大才造成)
func get_collision_damage(type_id: String, player_radius: float, enemy_radius: float) -> float:
	if enemy_radius > player_radius:
		return collision_dmg.get(type_id, 0.0)
	return 0.0

## 撞到该类型推开距离
func get_collision_pushback(type_id: String) -> float:
	return collision_pushback.get(type_id, 0.0)

## 吞下后能量收益
func get_energy_gain(type_id: String) -> float:
	return energy_gain.get(type_id, 0.0)

## 等级 → 体型半径 (阶梯式成长，GDD 3.2.1)
func body_radius_for_level(level: int) -> float:
	return START_BODY_RADIUS + max(0, level - 1) * GROWTH_PER_LEVEL

## v1.2: 体型 = 初始 20px + 变异卡数量×1px (GDD 2.0)；不再由 level 驱动
func body_radius_for_mutation(mutation_count: int) -> float:
	return START_BODY_RADIUS + max(0, mutation_count) * MUTATION_BODY_BONUS
