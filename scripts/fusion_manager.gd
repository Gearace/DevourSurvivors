extends Node
## fusion_manager.gd
## 融合进化系统 — 检测融合配方、触发融合、应用融合效果
## 与 GameManager 配合工作

signal fusion_triggered(fusion_name: String, result_card: Dictionary)
signal fusion_failed(reason: String)

var triggered_fusions: Array[String] = []

static func get_fusion_result(fusion_key: String) -> Dictionary:
	var results: Dictionary = {
		"shadow_clone_expert+shadow_resonance": {
			"name": "暗影军团", "desc": "分身数量+3，且分身可独立升级",
			"stats": {"clone_count_bonus": 3, "clone_can_upgrade": true},
			"replaces": ["shadow_clone_expert", "shadow_resonance"]
		},
		"black_hole_body+black_hole_resonance": {
			"name": "奇点", "desc": "引力范围翻倍，产生吞噬漩涡持续吸引远处敌人",
			"stats": {"gravity_radius_double": true, "continuous_pull": true},
			"replaces": ["black_hole_body", "black_hole_resonance"]
		},
		"split_gene+split_resonance": {
			"name": "增殖", "desc": "分裂出的小兵达到原体型的80%，且能再次分裂(限1次)",
			"stats": {"split_size_ratio": 0.8, "split_once_more": true},
			"replaces": ["split_gene", "split_resonance"]
		},
		"mirror_reflect+mirror_resonance": {
			"name": "绝对防御", "desc": "完全免疫伤害2s，每30s触发一次",
			"stats": {"full_invincible_duration": 2.0, "full_invincible_cooldown": 30.0},
			"replaces": ["mirror_reflect", "mirror_resonance"]
		},
		"capture_synergy+hunger_resonance": {
			"name": "饕餮", "desc": "每吞噬10个敌人获得永久攻击力+5%",
			"stats": {"permanent_attack_per_10": 0.05, "threshold": 10},
			"replaces": ["capture_synergy", "hunger_resonance"]
		},
		"swift_body+capture_instinct": {
			"name": "猎手", "desc": "基础移速+25%，吞噬后加速层数+5层",
			"stats": {"speed_bonus": 0.25, "extra_speed_stacks": 5},
			"replaces": ["swift_body", "capture_instinct"]
		},
		"ancient_egg+capture_heart": {
			"name": "不朽", "desc": "每波恢复50%生命，升级时牌组+1容量",
			"stats": {"hp_regen_per_wave": 0.50, "deck_capacity_bonus": 1},
			"replaces": ["ancient_egg", "capture_heart"]
		},
	}
	return results.get(fusion_key, {})

func check_and_trigger_fusion(new_card_id: String) -> Dictionary:
	var deck = GameManager.player_deck
	for card_id in deck:
		var result = _try_fuse(card_id, new_card_id)
		if not result.is_empty():
			return _execute_fusion(result)
	return {}

func _get_fusion_recipe(card_a: String, card_b: String) -> Dictionary:
	var fusions: Dictionary = {
		"shadow_clone_expert+shadow_resonance": {"name": "暗影军团", "cards": ["shadow_clone_expert", "shadow_resonance"], "result": "dark_legion"},
		"black_hole_body+black_hole_resonance": {"name": "奇点", "cards": ["black_hole_body", "black_hole_resonance"], "result": "singularity"},
		"split_gene+split_resonance": {"name": "增殖", "cards": ["split_gene", "split_resonance"], "result": "proliferation"},
		"mirror_reflect+mirror_resonance": {"name": "绝对防御", "cards": ["mirror_reflect", "mirror_resonance"], "result": "absolute_defense"},
		"capture_synergy+hunger_resonance": {"name": "饕餮", "cards": ["capture_synergy", "hunger_resonance"], "result": "taotie"},
		"swift_body+capture_instinct": {"name": "猎手", "cards": ["swift_body", "capture_instinct"], "result": "hunter"},
		"ancient_egg+capture_heart": {"name": "不朽", "cards": ["ancient_egg", "capture_heart"], "result": "immortality"},
	}
	var key1 = card_a + "+" + card_b
	var key2 = card_b + "+" + card_a
	if key1 in fusions:
		return fusions[key1]
	elif key2 in fusions:
		return fusions[key2]
	return {}

func _try_fuse(card_a: String, card_b: String) -> Dictionary:
	var fusion_data = _get_fusion_recipe(card_a, card_b)
	if fusion_data.is_empty():
		return {}
	
	var fusion_key = card_a + "+" + card_b
	var reverse_key = card_b + "+" + card_a
	if fusion_key in triggered_fusions or reverse_key in triggered_fusions:
		print("[FusionManager] 融合已触发过: ", fusion_data.get("name", ""))
		return {}
	
	if not GameManager.has_card(card_a) or not GameManager.has_card(card_b):
		return {}
	
	return fusion_data

func _execute_fusion(fusion_data: Dictionary) -> Dictionary:
	var fusion_name = fusion_data.get("name", "")
	var replaced_cards = fusion_data.get("cards", [])
	var result_card_id = fusion_data.get("result", "")
	
	print("[FusionManager] 触发融合: ", fusion_name)
	print("[FusionManager] 移除: ", replaced_cards)
	print("[FusionManager] 获得: ", result_card_id)
	
	for card_id in replaced_cards:
		GameManager.remove_card_from_deck(card_id)
	
	GameManager.add_card_to_deck(result_card_id)
	
	triggered_fusions.append(replaced_cards[0] + "+" + replaced_cards[1])
	
	var fusion_key = replaced_cards[0] + "+" + replaced_cards[1]
	var result = get_fusion_result(fusion_key)
	
	if not result.is_empty():
		_apply_fusion_effects(result)
	
	fusion_triggered.emit(fusion_name, result)
	EventBus.fusion_triggered.emit(fusion_name, replaced_cards)
	
	return result

func _apply_fusion_effects(result: Dictionary) -> void:
	var stats = result.get("stats", {})
	if stats.is_empty():
		return
	
	var s = GameManager.player_stats
	
	if "gravity_radius_double" in stats and stats["gravity_radius_double"]:
		if "enemy_slow_radius" in s:
			s["enemy_slow_radius"] = float(s["enemy_slow_radius"]) * 2.0
	if "full_invincible_duration" in stats:
		s["full_invincible_duration"] = stats["full_invincible_duration"]
		s["full_invincible_cooldown"] = stats["full_invincible_cooldown"]
	if "speed_bonus" in stats:
		s["speed"] = s.get("speed", 200.0) * (1.0 + stats["speed_bonus"])
	if "deck_capacity_bonus" in stats:
		GameManager.deck_capacity += stats["deck_capacity_bonus"]
	if "hp_regen_per_wave" in stats:
		s["hp_regen_per_wave"] = max(s.get("hp_regen_per_wave", 0.0), float(stats["hp_regen_per_wave"]))
	
	print("[FusionManager] 融合效果已应用: ", result.get("name", ""))

func reset_for_new_run() -> void:
	triggered_fusions.clear()
	print("[FusionManager] 融合系统已重置")

func debug_print_fusions() -> void:
	print("[FusionManager] 已触发融合: ", triggered_fusions)
	print("[FusionManager] 当前牌组: ", GameManager.player_deck)
