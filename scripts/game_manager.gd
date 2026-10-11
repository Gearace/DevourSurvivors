extends Node
## GameManager — 全局状态管理器 (autoload 单例)
## 负责游戏状态机、全局数据、事件分发

signal game_state_changed(new_state: String)
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal player_died
signal game_over(score: int)
signal level_up

# 游戏状态枚举
enum GameState {
	MENU,           # 主菜单
	PLAYING,        # 游戏中
	PAUSED,         # 暂停
	LEVEL_UP,       # 升级弹窗
	GAME_OVER,      # 游戏结束
	TUTORIAL        # 教程
}

var current_state: GameState = GameState.MENU

# 全局数据
var player_stats: Dictionary = {
	"level": 1,  # v1.2: 保留字段向后兼容，不再驱动体型（体型 = 20px + 变异卡数量×1px）
	"xp": 0,  # v1.1: 废弃, 经验系统已移除 (无职业无经验, 成长来自卡牌构筑)
	"max_hp": 100,
	"current_hp": 100,
	"speed": 200.0,
	"capture_range": 40.0,
	"capture_bonus": 1.0,
	"skill_cd_multiplier": 1.0,
	"total_captured": 0,
	"score": 0,
	# 能量系统 (啃食燃料，GDD 3.2.4)
	"energy": 10.0,
	"max_energy": 10.0,
}

# 波次数据
var current_wave: int = 1
var enemies_spawned_this_wave: int = 0
var enemies_remaining_this_wave: int = 0

# 牌组数据
var player_deck: Array[String] = []  # 已获得的卡牌ID列表
var deck_capacity: int = 10

# 路线数据 (GDD 7.2 / 5.7)
var run_route: Array = []      # 本局 13 层路线 [{floor, options, picked}]
var current_floor: int = 1     # 当前层号
var current_node_type: int = 0 # 当前节点类型 (RouteGenerator.NodeType)
var chapter: int = 1           # 当前章节号 (GDD 7.5)

# 技能数据
var active_skills: Array[String] = ["swallow_wave"]  # 初始自带吞噬波
var passive_skills: Array[String] = []  # 被动卡牌
var relics: Array[String] = []  # 遗物

# v1.2: 技能空间 + 三类卡构筑 (GDD 2.2/2.3)
## 技能空间: 未浸篆的已选技能 (4 选 1 后进入，可合成/浸篆)
var skill_space: Array[String] = []
## 已浸篆生效的三类卡: {"id":,"type":进化卡|变异卡|领域卡,"skill_id":,"material":,"material_tier":int,"duration":int(-1=永久),"elapsed":int}
var inscribed_cards: Array = []

# v1.2: 遗物 (道具类) — 已拾取遗物 id, 提供数值 buff (GDD 六)
var relic_buffs: Array[String] = []

# 融合检测
var fusion_results: Dictionary = {}  # 存储已触发的融合结果

# 难度系数 (随波次递增)
var difficulty_multiplier: float = 1.0

# 能量常量
const ENERGY_REGEN_PER_SEC := 0.5   # 自然能量回复
const ENERGY_REGEN_TICK := 0.5      # 回复计时间隔

var _energy_regen_timer: float = 0.0

func _ready() -> void:
	add_to_group("game_manager")
	print("[GameManager] 初始化完成 — 吞噬幸存者 v1.0")

func _process(delta: float) -> void:
	# 游戏中自然回能 (与卡牌能量回复叠加)
	if is_playing():
		_energy_regen_timer -= delta
		if _energy_regen_timer <= 0.0:
			_energy_regen_timer = ENERGY_REGEN_TICK
			regenerate_energy(ENERGY_REGEN_PER_SEC * ENERGY_REGEN_TICK)

## 能量 API

## 当前能量
func get_energy() -> float:
	return player_stats.get("energy", 0.0)

## 能量上限
func get_max_energy() -> float:
	return player_stats.get("max_energy", 10.0)

## 消耗能量；成功返回 true，能量不足返回 false
func spend_energy(amount: float) -> bool:
	if get_energy() < amount:
		return false
	player_stats["energy"] = max(0.0, get_energy() - amount)
	return true

## 回复能量 (含上限)
func regenerate_energy(amount: float) -> void:
	var cap := get_max_energy()
	player_stats["energy"] = min(cap, get_energy() + amount)

## 提升能量上限 (卡牌用)
func increase_max_energy(amount: float) -> void:
	player_stats["max_energy"] = get_max_energy() + amount

func set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(current_state)

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_level_up() -> bool:
	return current_state == GameState.LEVEL_UP

## 吞噬敌人后的处理
func on_enemy_captured(enemy_type: String, capture_value: float) -> void:
	player_stats["total_captured"] += 1
	player_stats["score"] += int(capture_value * 10)
	
	# v1.1: 经验系统已移除 (无职业无经验, 成长来自卡牌构筑)
## v1.2: 体型同步 — 浸篆生效 变异卡 后调用 (GDD 2.0)
## 体型 = 初始 20px + 变异卡数量×1px + 变异卡效果
## 保留 level 字段向后兼容，但不再用于体型计算
var mutation_card_count: int = 0  # 当前生效变异卡数量

func sync_body_on_mutation() -> void:
	var table = preload("res://scripts/devour_table.gd").new()
	var new_radius: float = table.body_radius_for_mutation(mutation_card_count)
	player_stats["capture_range"] = new_radius + 10.0
	level_up.emit()
	print("[GameManager] 体型同步 (v1.2 变异卡驱动)! 变异卡=", mutation_card_count, " 半径=", new_radius)

## v1.2: 每层结束结算 — 已浸篆三类卡有效期 -1，失效的卡技能放回技能空间，材质被消耗 (GDD 2.3)
func tick_inscribed_cards() -> void:
	for i in range(inscribed_cards.size() - 1, -1, -1):
		var card: Dictionary = inscribed_cards[i]
		if card.get("duration", 1) == -1:  # 永久有效
			continue
		card["elapsed"] = int(card.get("elapsed", 0)) + 1
		if int(card["elapsed"]) >= int(card["duration"]):
			_inscribe_expired(card)
			inscribed_cards.remove_at(i)
			if card.get("type", "") == "变异卡":
				mutation_card_count = max(0, mutation_card_count - 1)
				sync_body_on_mutation()

## 沉浸卡失效: 技能放回技能空间, 材质已消耗 (不返还, GDD 2.3)
func _inscribe_expired(card: Dictionary) -> void:
	var skill_id: String = card.get("skill_id", "")
	if skill_id != "" and skill_id not in skill_space and skill_id not in active_skills:
		skill_space.append(skill_id)
	print("[GameManager] 沉浸卡失效: ", card.get("name", card.get("id", "")), " → 技能放回技能空间，材质消耗")
func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	difficulty_multiplier = 1.0 + (wave_num - 1) * 0.15
	wave_started.emit(wave_num)
	print("[GameManager] 波次 ", wave_num, " 开始 — 难度系数: ", difficulty_multiplier)

func end_wave() -> void:
	wave_cleared.emit(current_wave)
	print("[GameManager] 波次 ", current_wave, " 清除")

## 牌组管理
func add_card_to_deck(card_id: String) -> bool:
	if player_deck.size() < deck_capacity:
		player_deck.append(card_id)
		print("[GameManager] 获得卡牌: ", card_id, " (", player_deck.size(), "/", deck_capacity, ")")
		
		# 应用被动效果
		var card = CardDatabase.find_card_by_id(card_id)
		if not card.is_empty():
			UpgradeSystem._apply_passive_effects(card)
		
		return true
	else:
		print("[GameManager] 牌组已满! (", deck_capacity, ")")
		return false

func remove_card_from_deck(card_id: String) -> void:
	if card_id in player_deck:
		player_deck.erase(card_id)
		print("[GameManager] 移除卡牌: ", card_id)

func has_card(card_id: String) -> bool:
	return card_id in player_deck

func get_deck_size() -> int:
	return player_deck.size()

func get_capacity() -> int:
	return deck_capacity

## 融合检测
func check_fusion(new_card_id: String) -> Dictionary:
	for card_id in player_deck:
		var result = _try_fuse(card_id, new_card_id)
		if not result.is_empty():
			return result
	return {}

func _try_fuse(card_a: String, card_b: String) -> Dictionary:
	# 融合配方表
	var fusions = {
		"shadow_clone+shadow_resonance": {
			"name": "暗影军团",
			"cards": ["shadow_clone", "shadow_resonance"],
			"result": "dark_legion"
		},
		"black_hole_body+black_hole_resonance": {
			"name": "奇点",
			"cards": ["black_hole_body", "black_hole_resonance"],
			"result": "singularity"
		},
		"split_gene+split_resonance": {
			"name": "增殖",
			"cards": ["split_gene", "split_resonance"],
			"result": "proliferation"
		},
		"mirror_reflect+mirror_resonance": {
			"name": "绝对防御",
			"cards": ["mirror_reflect", "mirror_resonance"],
			"result": "absolute_defense"
		},
		"capture_synergy+hunger_resonance": {
			"name": "饕餮",
			"cards": ["capture_synergy", "hunger_resonance"],
			"result": "taotie"
		},
		"swift_body+capture_instinct": {
			"name": "猎手",
			"cards": ["swift_body", "capture_instinct"],
			"result": "hunter"
		},
		"ancient_egg+capture_heart": {
			"name": "不朽",
			"cards": ["ancient_egg", "capture_heart"],
			"result": "immortality"
		},
	}
	
	var key1 = card_a + "+" + card_b
	var key2 = card_b + "+" + card_a
	
	if key1 in fusions:
		return fusions[key1]
	elif key2 in fusions:
		return fusions[key2]
	
	return {}

## 重置本局（死亡重试，GDD 7.7 / 5.10）

## v1.1: 材质掉落系统 (无经验, 成长来自吞怪掉材质 + 卡牌构筑)
## v1.2: 材质品阶 6 档 (白/绿/蓝/紫/橙/红, 对应 GDD 2.4)
## 品阶越高→浸篆有效期越长 (见 2.3)；升级需额外 3 个同品质同属性辅助材质 (2.4)
const MATERIAL_TIERS: Array[int] = [0, 1, 2, 3, 4, 5]  # 0=白 1=绿 2=蓝 3=紫 4=橙 5=红
const MATERIAL_TIER_NAMES: Dictionary = { 0: "白", 1: "绿", 2: "蓝", 3: "紫", 4: "橙", 5: "红" }

## 按敌人类型 roll 材质:
##   basic / swift / decoy: 不掉
##   heavy:  30% 掉 1 个, 品质白/绿, 5 种材质均等
##   split:  40% 掉 1 个, 品质白/绿, 5 种材质均等
##   精英:   100% 掉 1~2 个, 品质蓝/紫, 50% 偏向精英属性 + 50% 随机
##   Boss:   100% 掉 2~3 个, 品质紫/橙, 偏向 Boss 属性
const ELEMENTAL_MATERIALS: Array[String] = ["金", "木", "水", "火", "土"]

# 当前持有的材质 (按类型计数)
# 当前持有的材质 (v1.2 按类型+品阶: { "金": {tier: count}})
var held_materials: Dictionary = {}  # { "金": {0: 1, 1: 2}, "木": {0: 1} }

## 获取某材质持有数量
func get_material_count(material: String) -> int:
	var tier_map: Dictionary = held_materials.get(material, {})
	var total: int = 0
	for tier in tier_map:
		total += int(tier_map.get(tier, 0))
	return total

## v1.2: 获取某材质某品阶持有数量
func get_material_count_tier(material: String, tier: int) -> int:
	var tier_map: Dictionary = held_materials.get(material, {})
	return int(tier_map.get(tier, 0))

## v1.2: 获取某材质最高品阶 (浸篆有效期判断用)
func get_material_max_tier(material: String) -> int:
	var tier_map: Dictionary = held_materials.get(material, {})
	if tier_map.is_empty(): return -1
	var max_t: int = -1
	for tier in tier_map:
		if int(tier) > max_t:
			max_t = int(tier)
	return max_t

## 消耗材质 (用于融合/镶嵌)
## 消耗材质 (v1.2: 浸篆/合成/升级/熔炼; tier=-1 跨品阶高优先)
func spend_material(material: String, amount: int = 1, tier: int = -1) -> bool:
	var tier_map: Dictionary = held_materials.get(material, {})
	if tier >= 0:
		if int(tier_map.get(tier, 0)) < amount:
			return false
		tier_map[tier] = int(tier_map.get(tier, 0)) - amount
		if tier_map[tier] <= 0:
			tier_map.erase(tier)
	else:
		var remaining: int = amount
		var tiers: Array = tier_map.keys().duplicate()
		tiers.sort_custom(func(a, b): return int(b) > int(a))
		for t in tiers:
			if remaining <= 0:
				break
			var avail: int = int(tier_map.get(t, 0))
			var take: int = mini(avail, remaining)
			tier_map[t] = avail - take
			if tier_map[t] <= 0:
				tier_map.erase(t)
			remaining -= take
		if remaining > 0:
			return false
	if tier_map.is_empty():
		held_materials.erase(material)
	else:
		held_materials[material] = tier_map
	return true

## 吞噬敌人时 roll 材质掉落
func drop_elemental_material(enemy_type: String) -> void:
	# 普通小怪不掉材质
	if enemy_type == "basic" or enemy_type == "swift" or enemy_type == "decoy":
		return
	# 精英 / Boss
	if enemy_type in ["elite_tearer", "elite_toxin", "elite_mirror", "elite_fortress", "boss_ch1", "boss_v2_void", "boss_v3_abyss"]:
		var is_boss: bool = enemy_type in ["boss_ch1", "boss_v2_void", "boss_v3_abyss"]
		_grant_elemental_drop(enemy_type, true, is_boss)
		return
	# heavy / split 按概率掉
	var chance: float = 0.0
	match enemy_type:
		"heavy": chance = 0.30
		"split": chance = 0.40
		_: chance = 0.0
	if chance <= 0.0 or randf() > chance:
		return
	_grant_elemental_drop(enemy_type, false)

## 实际发放 1 个材质
## 实际发放 1 个材质 (v1.2: 带品阶)
func _grant_elemental_drop(enemy_type: String, is_elite_or_boss: bool, is_boss: bool = false) -> void:
	# 决定材质类型: 精英/Boss 50% 偏向自身属性, 否则 5 种均等
	var material: String
	if is_elite_or_boss and randf() < 0.5:
		material = _get_biased_material(enemy_type)
	else:
		material = ELEMENTAL_MATERIALS[randi() % ELEMENTAL_MATERIALS.size()]
	# v1.2 品阶 (GDD 四: heavy/split 白绿, 精英 蓝紫, Boss 紫橙)
	var tier: int
	if is_boss:
		tier = [3, 4][randi() % 2]
	elif is_elite_or_boss:
		tier = [2, 3][randi() % 2]
	else:
		tier = [0, 1][randi() % 2]
	if not held_materials.has(material):
		held_materials[material] = {}
	var tier_map: Dictionary = held_materials[material]
	tier_map[tier] = int(tier_map.get(tier, 0)) + 1
	print("[GameManager] 掉落材质: ", material, " 品阶", MATERIAL_TIER_NAMES.get(tier, "?"), " (来源: ", enemy_type, ")")

## 精英/Boss 属性偏向 (撕裂者=火, 毒囊=木, 镜影=水, 堡垒=土, Boss 按章节)
func _get_biased_material(enemy_type: String) -> String:
	match enemy_type:
		"elite_tearer": return "火"
		"elite_toxin":  return "木"
		"elite_mirror": return "水"
		"elite_fortress": return "土"
		_: return ELEMENTAL_MATERIALS[randi() % ELEMENTAL_MATERIALS.size()]

## 重置材质 (重新挑战时)
func reset_materials() -> void:
	held_materials.clear()


func reset_run() -> void:
	# 保留牌组（构筑延续），重置 HP/能量/分数/层号
	player_stats["current_hp"] = player_stats.get("max_hp", 100)
	player_stats["energy"] = player_stats.get("max_energy", 10.0)
	player_stats["score"] = 0
	player_stats["total_captured"] = 0
	current_wave = 1
	current_floor = 1
	current_node_type = 0
	run_route = []
	relics = []  # 重试清空遗物（永恒之环保留的卡由 RunOver 在 reset 前处理）
	# v1.1: 重置材质掉落 (重新挑战)
	reset_materials()
	set_state(GameState.PLAYING)
	print("[GameManager] 本局已重置 — 重新开始")

## 章节推进（通关 13 层后，GDD 7.5 / 5.10）
## 保留 build，章节号 +1；HP/能量由 RunOver 回复至 70%
func start_new_chapter() -> void:
	chapter += 1
	current_floor = 1
	current_node_type = 0
	run_route = []
	# 章节间敌人速度递增（GDD 7.5：章节2 +20% 等）
	# 简化：记录章节，route_generator 可据此加难度
	print("[GameManager] 进入第 ", chapter, " 章")
## 保存/加载
func save_game() -> void:
	var save_data = {
		"stats": player_stats,
		"deck": player_deck,
		"wave": current_wave,
		"score": player_stats.get("score", 0),
	}
	var json_str = JSON.stringify(save_data)
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("[GameManager] 游戏已保存")
	else:
		print("[GameManager] 保存失败")

func load_game() -> bool:
	if not FileAccess.file_exists("user://save_data.json"):
		return false
	
	var file = FileAccess.open("user://save_data.json", FileAccess.READ)
	if not file:
		return false
	var json_str = file.get_as_text()
	file.close()
	var parse_result = JSON.parse_string(json_str)
	if typeof(parse_result) != TYPE_DICTIONARY:
		return false
	var save_data = parse_result
	if save_data.is_empty():
		return false
	
	player_stats = save_data.get("stats", player_stats)
	player_deck = save_data.get("deck", [])
	current_wave = save_data.get("wave", 1)
	print("[GameManager] 游戏已加载 — Lv.", player_stats.get("level", 1), " 波次", current_wave)
	return true
