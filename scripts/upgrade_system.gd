extends Node
## upgrade_system.gd
## 升级抽卡系统 — 负责升级触发、卡牌抽取、保底机制、流派引导
## 与 GameManager 配合工作

signal cards_drawn(cards: Array)
signal card_selected(card_id: String)
signal level_up_triggered

const CARDS_TO_DRAW := 4
const PITY_THRESHOLD := 5
const BUILD_GUIDANCE_THRESHOLD := 3

var pity_counter: int = 0
var last_rarity: String = ""
var current_level: int = 1
var current_wave: int = 1

var rarity_rank: Dictionary = {
	"Common": 0,
	"Uncommon": 1,
	"Legendary": 2,
	"Relic": 3,
}

func draw_upgrade_cards() -> Array[Dictionary]:
	current_level = GameManager.player_stats.get("level", 1)
	current_wave = GameManager.current_wave
	var pool = _get_card_pool()
	var build_type = _detect_build_type()
	var drawn: Array[Dictionary] = []
	var available = pool.duplicate()
	for i in CARDS_TO_DRAW:
		if available.is_empty():
			break
		var weights = CardDatabase.get_rarity_weights(current_level)
		if pity_counter >= PITY_THRESHOLD:
			weights["Uncommon"] = 1.0
		weights = _apply_build_guidance(weights, build_type, available)
		var card = _weighted_draw(available, weights)
		if not card.is_empty():
			drawn.append(card)
			available.erase(card)
			if rarity_rank.get(card.get("rarity", "Common"), 0) >= 2:
				pity_counter = 0
			else:
				pity_counter += 1
	drawn.shuffle()
	cards_drawn.emit(drawn)
	level_up_triggered.emit()
	print("[UpgradeSystem] 抽取了 %d 张升级卡牌, 流派: %s" % [drawn.size(), build_type])
	return drawn

func _get_card_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var all_cards = CardDatabase.get_all_cards()
	for card in all_cards:
		var cid = card.get("id", "")
		if not GameManager.has_card(cid):
			if card.get("category", "") == "Relic":
				if _is_relic_unlocked(card):
					pool.append(card)
			else:
				pool.append(card)
	return pool

func _is_relic_unlocked(card: Dictionary) -> bool:
	var condition = card.get("unlock_condition", "")
	if condition == "":
		return true
	if "通关10波" in condition:
		return current_wave >= 10
	if "连续10波" in condition:
		return false
	return true

func _detect_build_type() -> String:
	var deck = GameManager.player_deck
	var core_counts: Dictionary = {"Core": 0, "Component": 0, "Resonance": 0}
	for card_id in deck:
		var card = CardDatabase.find_card_by_id(card_id)
		if card.is_empty():
			continue
		var cat = card.get("category", "")
		if cat in core_counts:
			core_counts[cat] += 1
	var max_cat = "Core"
	var max_count = 0
	for cat in core_counts:
		if core_counts[cat] > max_count:
			max_count = core_counts[cat]
			max_cat = cat
	if max_count >= BUILD_GUIDANCE_THRESHOLD:
		return max_cat
	return ""

func _apply_build_guidance(weights: Dictionary, build_type: String, pool: Array[Dictionary]) -> Dictionary:
	var result = weights.duplicate()
	if build_type == "Core":
		result["Uncommon"] = min(1.0, result.get("Uncommon", 0) * 1.3)
	elif build_type == "Component":
		result["Common"] = min(1.0, result.get("Common", 0) * 1.2)
	elif build_type == "Resonance":
		result["Uncommon"] = min(1.0, result.get("Uncommon", 0) * 1.4)
	var total: float = result.get("Common", 0) + result.get("Uncommon", 0) + result.get("Legendary", 0) + result.get("Relic", 0)
	if total > 0:
		result["Common"] = result.get("Common", 0) / total
		result["Uncommon"] = result.get("Uncommon", 0) / total
		result["Legendary"] = result.get("Legendary", 0) / total
		result["Relic"] = result.get("Relic", 0) / total
	return result

func _weighted_draw(pool: Array[Dictionary], weights: Dictionary) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_weight: float = 0.0
	var card_weights: Array[float] = []
	for card in pool:
		var rarity = card.get("rarity", "Common")
		var w = weights.get(rarity, 0.1)
		if card.get("category", "") == "Resonance":
			var check_id = card.get("stats", {}).get("resonance_check", "")
			if check_id != "":
				var has_prerequisite = false
				for pc in pool:
					var pc_id = pc.get("id", "")
					if pc_id == check_id:
						has_prerequisite = true
						break
					if check_id == "shadow_clone" and "shadow_clone" in pc_id:
						has_prerequisite = true
						break
					if check_id == "black_hole_body" and "black_hole" in pc_id:
						has_prerequisite = true
						break
					if check_id == "mirror_reflect" and "mirror" in pc_id:
						has_prerequisite = true
						break
					if check_id == "split_gene" and "split" in pc_id:
						has_prerequisite = true
						break
					if check_id == "energy_siphon" and "energy" in pc_id:
						has_prerequisite = true
						break
					if check_id == "phoenix-blood" and "phoenix" in pc_id:
						has_prerequisite = true
						break
					if check_id == "extreme_squeeze" and "extreme" in pc_id:
						has_prerequisite = true
						break
					if check_id == "perpetual_engine" and "perpetual" in pc_id:
						has_prerequisite = true
						break
					if check_id == "greedy_mouth" and "greedy" in pc_id:
						has_prerequisite = true
						break
				if not has_prerequisite:
					w *= 0.1
		card_weights.append(w)
		total_weight += w
	if total_weight <= 0:
		total_weight = 1.0
	var rand = randf() * total_weight
	var cumulative: float = 0.0
	for i in card_weights.size():
		cumulative += card_weights[i]
		if rand <= cumulative:
			return pool[i]
	return pool[-1]

func select_card(card: Dictionary) -> void:
	var card_id = card.get("id", "")
	if GameManager.add_card_to_deck(card_id):
		print("[UpgradeSystem] 玩家选择了: ", card.get("name", ""))
		var fusion_result = GameManager.check_fusion(card_id)
		if not fusion_result.is_empty():
			print("[UpgradeSystem] 触发融合: ", fusion_result.get("name", ""))
		_apply_passive_effects(card)
		card_selected.emit(card_id)
	_close_upgrade_popup()

func _apply_passive_effects(card: Dictionary) -> void:
	var stats = card.get("stats", {})
	if stats.is_empty():
		return
	var s = GameManager.player_stats
	if "speed_bonus" in stats:
		s["speed"] = s.get("speed", 200.0) * (1.0 + stats["speed_bonus"])
	if "capture_range_bonus" in stats:
		s["capture_range"] = s.get("capture_range", 40.0) * (1.0 + stats["capture_range_bonus"])
	if "capture_radius_bonus" in stats:
		s["capture_range"] = s.get("capture_range", 40.0) * (1.0 + stats["capture_radius_bonus"])
	if "max_hp_bonus" in stats:
		s["max_hp"] = s.get("max_hp", 100) * (1.0 + stats["max_hp_bonus"])
		s["current_hp"] = s["max_hp"]
	if "cooldown_reduction" in stats:
		s["skill_cd_multiplier"] = s.get("skill_cd_multiplier", 1.0) * (1.0 - stats["cooldown_reduction"])
	if "capture_value_bonus" in stats:
		s["capture_bonus"] = s.get("capture_bonus", 1.0) * (1.0 + stats["capture_value_bonus"])
	if "hp_regen_per_capture" in stats:
		s["vampire_heal"] = stats["hp_regen_per_capture"]
	if "invincible_on_capture" in stats and stats["invincible_on_capture"]:
		s["invincible_on_capture"] = true
		s["invincible_duration"] = stats.get("invincible_duration", 0.5)
	if "energy_per_capture" in stats:
		s["energy_per_capture"] = stats["energy_per_capture"]
	if "energy_cap_bonus" in stats:
		s["energy_cap"] = s.get("energy_cap", 0) + stats["energy_cap_bonus"]
	if "initial_energy_bonus" in stats:
		s["current_energy"] = s.get("current_energy", 0) + stats["initial_energy_bonus"]
	if "max_simultaneous_captures" in stats:
		s["max_simultaneous_captures"] = stats["max_simultaneous_captures"]
	if "low_hp_capture_bonus" in stats:
		s["low_hp_capture_bonus"] = stats["low_hp_capture_bonus"]
		s["low_hp_threshold"] = stats.get("low_hp_threshold", 0.2)
	print("[UpgradeSystem] 应用被动效果: ", card.get("name", ""))
	print("[UpgradeSystem] 当前属性: LV=", s.get("level", 1), " HP=", s.get("current_hp", 100), " Speed=", s.get("speed", 200.0), " Capture=", s.get("capture_range", 40.0))

func _close_upgrade_popup() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	print("[UpgradeSystem] 升级完成，恢复游戏")

func reset_for_new_run() -> void:
	pity_counter = 0
	last_rarity = ""
	current_level = 1
	current_wave = 1

func debug_print_pool() -> void:
	var pool = _get_card_pool()
	print("[UpgradeSystem] 可用卡牌数: ", pool.size())
	var counts: Dictionary = {"Core": 0, "Component": 0, "Resonance": 0, "Relic": 0}
	for card in pool:
		var cat = card.get("category", "")
		if cat in counts:
			counts[cat] += 1
	print("[UpgradeSystem] 类别分布: ", counts)
	print("[UpgradeSystem] 当前保底计数: ", pity_counter)
	print("[UpgradeSystem] 当前等级权重: ", CardDatabase.get_rarity_weights(current_level))
