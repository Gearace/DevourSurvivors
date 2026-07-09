extends Node
## fusion_manager.gd
## 融合进化系统 — 检测融合配方、触发融合、应用融合效果
## 与 GameManager 配合工作

signal fusion_triggered(fusion_name: String, result_card: Dictionary)
signal fusion_failed(reason: String)

# 融合产物效果映射
# 融合产物取代两张原料牌，产生更强的新效果

var triggered_fusions: Array[String] = []  # 本局已触发的融合

# ========== 融合产物数据库 ==========
static func get_fusion_result(fusion_key: String) -> Dictionary:
	var results = {
		"shadow_clone_expert+shadow_resonance": {
			"name": "暗影军团",
			"desc": "分身数量+3，且分身可独立升级",
			"stats": {"clone_count_bonus": 3, "clone_can_upgrade": true},
			"replaces": ["shadow_clone_expert", "shadow_resonance"]
		},
		"black_hole_body+black_hole_resonance": {
			"name": "奇点",
			"desc": "引力范围翻倍，产生吞噬漩涡持续吸引远处敌人",
			"stats": {"gravity_radius_double": true, "continuous_pull": true},
			"replaces": ["black_hole_body", "black_hole_resonance"]
		},
		"split_gene+split_resonance": {
			"name": "增殖",
			"desc": "分裂出的小兵达到原体型的80%，且能再次分裂(限1次)",
			"stats": {"split_size_ratio": 0.8, "split_once_more": true},
			"replaces": ["split_gene", "split_resonance"]
		},
		"mirror_reflect+mirror_resonance": {
			"name": "绝对防御",
			"desc": "完全免疫伤害2s，每30s触发一次",
			"stats": {"full_invincible_duration": 2.0, "full_invincible_cooldown": 30.0},
			"replaces": ["mirror_reflect", "mirror_resonance"]
		},
		"capture_synergy+hunger_resonance": {
			"name": "饕餮",
			"desc": "每吞噬10个敌人获得永久攻击力+5%",
			"stats": {"permanent_attack_per_10": 0.05, "threshold": 10},
			"replaces": ["capture_synergy", "hunger_resonance"]
		},
		"swift_body+capture_instinct": {
			"name": "猎手",
			"desc": "基础移速+25%，吞噬后加速层数+5层",
			"stats": {"speed_bonus": 0.25, "extra_speed_stacks": 5},
			"replaces": ["swift_body", "capture_instinct"]
		},
		"ancient_egg+capture_heart": {
			"name": "不朽",
			"desc": "每波恢复50%生命，升级时牌组+1容量",
			"stats": {"hp_regen_per_wave": 0.50, "deck_capacity_bonus": 1},
			"replaces": ["ancient_egg", "capture_heart"]
		},
	}
	return results.get(fusion_key, {})

# ========== 检测并触发融合 ==========
func check_and_trigger_fusion(new_card_id: String) -> Dictionary:
	var deck = GameManager.player_deck
	for card_id in deck:
		var result = _try_fuse(card_id, new_card_id)
		if not result.is_empty():
			return _execute_fusion(result)
	return {}

# ========== 尝试融合匹配 ==========
func _try_fuse(card_a: String, card_b: String) -> Dictionary:
	# 复用 GameManager 的融合配方
	var fusion_data = GameManager._try_fuse(card_a, card_b)
	if fusion_data.is_empty():
		return {}
	
	# 检查是否已经触发过这个融合
	var fusion_key = card_a + "+" + card_b
	var reverse_key = card_b + "+" + card_a
	if fusion_key in triggered_fusions or reverse_key in triggered_fusions:
		print("[FusionManager] 融合已触发过: ", fusion_data.name)
		return {}
	
	# 检查两张原料卡是否都在牌组中
	if not GameManager.has_card(card_a) or not GameManager.has_card(card_b):
		return {}
	
	return fusion_data

# ========== 执行融合 ==========
func _execute_fusion(fusion_data: Dictionary) -> Dictionary:
	var fusion_name = fusion_data.name
	var replaced_cards = fusion_data.cards
	var result_card_id = fusion_data.result
	
	print("[FusionManager] 触发融合: ", fusion_name)
	print("[FusionManager] 移除: ", replaced_cards)
	print("[FusionManager] 获得: ", result_card_id)
	
	# 1. 从牌组中移除原料卡
	for card_id in replaced_cards:
		GameManager.remove_card_from_deck(card_id)
	
	# 2. 添加融合产物到牌组
	GameManager.add_card_to_deck(result_card_id)
	
	# 3. 记录已触发的融合
	triggered_fusions.append(replaced_cards[0] + "+" + replaced_cards[1])
	
	# 4. 获取融合产物数据
	var fusion_key = replaced_cards[0] + "+" + replaced_cards[1]
	var result = get_fusion_result(fusion_key)
	
	# 5. 应用融合效果
	if not result.is_empty():
		_apply_fusion_effects(result)
	
	# 6. 发送信号
	fusion_triggered.emit(fusion_name, result)
	EventBus.fusion_triggered.emit(fusion_name, replaced_cards)
	
	return result

# ========== 应用融合效果 ==========
func _apply_fusion_effects(result: Dictionary) -> void:
	var stats = result.get("stats", {})
	if stats.is_empty():
		return
	
	var s = GameManager.player_stats
	
	if "clone_count_bonus" in stats:
		# 暗影军团: 分身相关
		pass
	if "gravity_radius_double" in stats and stats.gravity_radius_double:
		# 奇点: 黑洞半径翻倍
		if "enemy_slow_radius" in s:
			s.enemy_slow_radius *= 2.0
	if "full_invincible_duration" in stats:
		# 绝对防御
		s.full_invincible_duration = stats.full_invincible_duration
		s.full_invincible_cooldown = stats.full_invincible_cooldown
	if "speed_bonus" in stats:
		s.speed *= (1.0 + stats.speed_bonus)
	if "deck_capacity_bonus" in stats:
		GameManager.deck_capacity += stats.deck_capacity_bonus
	if "hp_regen_per_wave" in stats:
		# 不朽: 每波恢复50%生命
		s.hp_regen_per_wave = max(s.get("hp_regen_per_wave", 0), stats.hp_regen_per_wave)
	
	print("[FusionManager] 融合效果已应用: ", result.name)

# ========== 重置 ==========
func reset_for_new_run() -> void:
	triggered_fusions.clear()
	print("[FusionManager] 融合系统已重置")

# ========== 调试 ==========
func debug_print_fusions() -> void:
	print("[FusionManager] 已触发融合: ", triggered_fusions)
	print("[FusionManager] 当前牌组: ", GameManager.player_deck)
