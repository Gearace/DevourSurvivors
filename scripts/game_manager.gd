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
	"level": 1,
	"xp": 0,
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

# 技能数据
var active_skills: Array[String] = ["swallow_wave"]  # 初始自带吞噬波
var passive_skills: Array[String] = []  # 被动卡牌
var relics: Array[String] = []  # 遗物

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
	
	# 检查升级 (吞噬数作为经验阈值)
	if player_stats.get("total_captured", 0) >= get_xp_threshold():
		trigger_level_up()
## 计算升级所需XP (吞噬数)
func get_xp_threshold() -> int:
	return int(5 * pow(1.1, player_stats.get("level", 1) - 1))

## 触发升级
func trigger_level_up() -> void:
	player_stats["level"] += 1
	# 升级体型阶梯增长 (GDD 3.2.1)
	var table = preload("res://scripts/devour_table.gd").new()
	var new_radius: float = table.body_radius_for_level(player_stats["level"])
	player_stats["capture_range"] = new_radius + 10.0
	level_up.emit()
	set_state(GameState.LEVEL_UP)
	print("[GameManager] 升级! Lv.", player_stats.get("level", 1))
	
	# 通知 UpgradeSystem 抽卡
	var cards = UpgradeSystem.draw_upgrade_cards()
	
	# 通知 UpgradePopup 显示
	UpgradePopup.show_upgrade(cards)
	
	# 暂停游戏逻辑
	EventBus.game_paused.emit(true)
## 波次管理
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
