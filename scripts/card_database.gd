extends Resource

## card_database.gd
## 卡牌数据库 — 全部43张被动卡牌的定义
## 类别: Core(核心)/Component(组件)/Resonance(共鸣)/Relic(遗物)
## 稀有度: Common(普通)/Uncommon(稀有)/Legendary(传说)/Relic(遗物)

class_name CardDatabase

# ========== 核心卡 (10张) ==========
static func get_core_cards() -> Array[Dictionary]:
	return [
		{"id": "shadow_clone_expert", "name": "影分身专家", "category": "Core", "rarity": "Uncommon", "description": "影分身数量+2，分身拥有本体50%吞噬力", "stats": {"clone_count_bonus": 2, "clone_capture_power": 0.5}, "special": "影分身之术技能的分身数量+2，分身吞噬敌人计入玩家"},
		{"id": "black_hole_body", "name": "黑洞体质", "category": "Core", "rarity": "Uncommon", "description": "周围100px内敌人移速-30%", "stats": {"enemy_slow_radius": 100, "enemy_slow_factor": 0.7}, "special": "被动光环: 100px范围内所有敌人减速30%"},
		{"id": "capture_instinct", "name": "吞噬本能", "category": "Core", "rarity": "Common", "description": "每次吞噬后移速+5%，持续3s，最多叠10层", "stats": {"capture_speed_bonus": 0.05, "capture_speed_max_stacks": 10, "capture_speed_duration": 3}, "special": "吞噬后获得加速层数，最高10层，每层+5%移速"},
		{"id": "split_gene", "name": "分裂基因", "category": "Core", "rarity": "Uncommon", "description": "被吞噬的分裂怪额外分裂出1个小兵", "stats": {"split_extra_count": 1}, "special": "吞噬分裂怪时，分裂出的小兵数量+1"},
		{"id": "mirror_reflect", "name": "镜像反射", "category": "Core", "rarity": "Legendary", "description": "受到伤害时50%概率反弹给攻击者", "stats": {"reflect_chance": 0.5}, "special": "受到敌人攻击时，50%概率将伤害反弹"},
		{"id": "capture_core", "name": "吞噬核心", "category": "Core", "rarity": "Common", "description": "吞噬判定范围永久+20%", "stats": {"capture_range_bonus": 0.2}, "special": "吞噬判定半径增加20%"},
		{"id": "energy_siphon", "name": "能量虹吸", "category": "Core", "rarity": "Uncommon", "description": "吞噬敌人时恢复1点能量", "stats": {"energy_per_capture": 1}, "special": "每次吞噬敌人恢复1点能量"},
		{"id": "rapid_evolution", "name": "极速进化", "category": "Core", "rarity": "Common", "description": "每吞噬5个敌人，体型+1%", "stats": {"size_per_n_captures": 5, "size_bonus_per_stack": 0.01}, "special": "每吞噬5个敌人，体型永久+1%"},
		{"id": "void_capture", "name": "虚空吞噬", "category": "Core", "rarity": "Legendary", "description": "可吞噬体型大你2倍的敌人(每波1次)", "stats": {"oversize_capture_ratio": 2, "oversize_charges_per_wave": 1}, "special": "每波可吞噬体型大于自己2倍的敌人1次"},
		{"id": "phoenix-blood", "name": "不死鸟之血", "category": "Core", "rarity": "Relic", "description": "生命值归零时保留1点生命(每波1次)", "stats": {"revive_hp": 1, "revive_per_wave": true}, "special": "濒死时自动复活，保留1HP，每波只能触发一次"}
	]

# ========== 组件卡 (15张) ==========
static func get_component_cards() -> Array[Dictionary]:
	return [
		{"id": "greedy_mouth", "name": "贪婪之口", "category": "Component", "rarity": "Common", "description": "吞噬收益+20%", "stats": {"capture_value_bonus": 0.2}},
		{"id": "swift_body", "name": "迅捷之躯", "category": "Component", "rarity": "Common", "description": "基础移速+15%", "stats": {"speed_bonus": 0.15}},
		{"id": "iron_wall", "name": "铁壁", "category": "Component", "rarity": "Common", "description": "最大生命+50%", "stats": {"max_hp_bonus": 0.5}},
		{"id": "cooldown_reduction", "name": "冷却缩减", "category": "Component", "rarity": "Uncommon", "description": "技能CD-15%", "stats": {"cooldown_reduction": 0.15}},
		{"id": "capture_range", "name": "吞噬范围", "category": "Component", "rarity": "Common", "description": "吞噬判定半径+25%", "stats": {"capture_radius_bonus": 0.25}},
		{"id": "size_amplify", "name": "体型增幅", "category": "Component", "rarity": "Common", "description": "每次升级体型额外+5%", "stats": {"level_size_bonus": 0.05}},
		{"id": "energy_fulfill", "name": "能量充盈", "category": "Component", "rarity": "Uncommon", "description": "初始能量+3，上限+5", "stats": {"initial_energy_bonus": 3, "energy_cap_bonus": 5}},
		{"id": "vampire_fang", "name": "吸血之牙", "category": "Component", "rarity": "Uncommon", "description": "每次吞噬回复1HP", "stats": {"hp_regen_per_capture": 1}},
		{"id": "crushing_force", "name": "粉碎之力", "category": "Component", "rarity": "Common", "description": "吞噬重装怪额外+50%体型", "stats": {"heavy_capture_bonus": 0.5}},
		{"id": "ghost_step", "name": "幽灵步", "category": "Component", "rarity": "Uncommon", "description": "吞噬后0.5s无敌帧", "stats": {"invincible_duration": 0.5, "invincible_on_capture": true}},
		{"id": "multi_capture", "name": "多重吞噬", "category": "Component", "rarity": "Uncommon", "description": "可同时吞噬最多3个敌人", "stats": {"max_simultaneous_captures": 3}},
		{"id": "capture_accelerate", "name": "吞噬加速", "category": "Component", "rarity": "Common", "description": "低血量时吞噬收益+30%", "stats": {"low_hp_capture_bonus": 0.3, "low_hp_threshold": 0.2}},
		{"id": "energy_flow_back", "name": "能量回流", "category": "Component", "rarity": "Uncommon", "description": "技能未命中时返还50%能量", "stats": {"energy_refund_on_miss": 0.5}},
		{"id": "extreme_squeeze", "name": "极限压榨", "category": "Component", "rarity": "Common", "description": "血量低于20%时攻击+50%", "stats": {"low_hp_attack_bonus": 0.5, "low_hp_threshold": 0.2}},
		{"id": "perpetual_engine", "name": "永动引擎", "category": "Component", "rarity": "Uncommon", "description": "每秒自动恢复1点能量", "stats": {"energy_regen_per_second": 1}},
		{"id": "gnaw_steady", "name": "坚韧下颚", "category": "Component", "rarity": "Uncommon", "description": "啃食大怪时挣脱概率-40%（更稳）", "stats": {"escape_chance_reduction": 0.4}, "special": "啃食进度更稳定，大怪更难挣脱"}
	]

# ========== 共鸣卡 (12张) ==========
static func get_resonance_cards() -> Array[Dictionary]:
	return [
		{"id": "shadow_resonance", "name": "暗影共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有影分身专家时，分身持续时间+50%", "stats": {"resonance_check": "shadow_clone_expert", "clone_duration_bonus": 0.5}, "special": "当持有影分身专家时，分身持续时间延长50%"},
		{"id": "black_hole_resonance", "name": "黑洞共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有黑洞体质时，减速效果提升至-50%", "stats": {"resonance_check": "black_hole_body", "enhanced_slow_factor": 0.5}, "special": "当持有黑洞体质时，减速效果从30%提升至50%"},
		{"id": "capture_synergy", "name": "吞噬协同", "category": "Resonance", "rarity": "Uncommon", "description": "吞噬范围每增加10px，吞噬收益+5%", "stats": {"range_capture_synergy": 0.05, "range_interval": 10}, "special": "吞噬范围每10px转化为5%吞噬收益加成"},
		{"id": "mirror_resonance", "name": "镜像共鸣", "category": "Resonance", "rarity": "Legendary", "description": "有镜像反射时，反弹伤害翻倍", "stats": {"resonance_check": "mirror_reflect", "doubled_reflect_damage": true}, "special": "当持有镜像反射时，反弹伤害变为200%"},
		{"id": "split_resonance", "name": "分裂共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有分裂基因时，分裂体继承本体30%属性", "stats": {"resonance_check": "split_gene", "split_inherit_percentage": 0.3}, "special": "当持有分裂基因时，分裂出的小兵继承本体30%属性"},
		{"id": "hunger_resonance", "name": "饥饿共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有贪婪之口时，吞噬收益额外+15%", "stats": {"resonance_check": "greedy_mouth", "extra_bonus": 0.15}, "special": "当持有贪婪之口时，吞噬收益额外增加15%"},
		{"id": "evolution_resonance", "name": "进化共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有极速进化时，进化间隔减少至3个", "stats": {"resonance_check": "rapid_evolution", "reduced_interval": 3}, "special": "当持有极速进化时，体型增长间隔从5减少到3"},
		{"id": "energy_resonance", "name": "能量共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有能量虹吸时，能量恢复速度+50%", "stats": {"resonance_check": "energy_siphon", "energy_regen_bonus": 0.5}, "special": "当持有能量虹吸时，能量自然恢复速度+50%"},
		{"id": "undying_resonance", "name": "不死共鸣", "category": "Resonance", "rarity": "Legendary", "description": "有不死鸟之血时，复活后体型+20%", "stats": {"resonance_check": "phoenix-blood", "post_revive_size_bonus": 0.2}, "special": "当持有不死鸟之血且触发复活时，复活后体型+20%"},
		{"id": "extreme_resonance", "name": "极限共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有极限压榨时，濒血阈值提升至30%", "stats": {"resonance_check": "extreme_squeeze", "new_low_hp_threshold": 0.3}, "special": "当持有极限压榨时，濒血阈值从20%提升到30%"},
		{"id": "perpetual_resonance", "name": "永动共鸣", "category": "Resonance", "rarity": "Uncommon", "description": "有永动引擎时，能量上限+10", "stats": {"resonance_check": "perpetual_engine", "energy_cap_bonus": 10}, "special": "当持有永动引擎时，能量上限+10"},
		{"id": "greed_resonance", "name": "贪婪共鸣", "category": "Resonance", "rarity": "Common", "description": "有贪婪之口时，吞噬收益额外+10%", "stats": {"resonance_check": "greedy_mouth", "extra_capture_bonus": 0.1}, "special": "当持有贪婪之口时，吞噬收益额外+10%"}
	]

# ========== 遗物卡 (6张) ==========
static func get_relic_cards() -> Array[Dictionary]:
	return [
		{"id": "ancient_egg", "name": "远古之卵", "category": "Relic", "rarity": "Relic", "description": "每波结束后恢复20%生命", "stats": {"hp_regen_per_wave": 0.2}, "drop_source": "随机掉落"},
		{"id": "capture_heart", "name": "吞噬之心", "category": "Relic", "rarity": "Relic", "description": "每次升级额外获得1张随机卡牌", "stats": {"extra_card_per_level": 1}, "drop_source": "Boss掉落"},
		{"id": "fortune_compass", "name": "命运罗盘", "category": "Relic", "rarity": "Relic", "description": "Boss房出现率+50%", "stats": {"boss_room_rate_bonus": 0.5}, "drop_source": "随机掉落"},
		{"id": "void_eye", "name": "虚空之眼", "category": "Relic", "rarity": "Relic", "description": "技能改为消耗能量(每5s恢复1)", "stats": {"skill_consumes_energy": true, "energy_regen_interval": 5}, "drop_source": "传说掉落"},
		{"id": "eternal_ring", "name": "永恒之环", "category": "Relic", "rarity": "Relic", "description": "死亡后保留1张随机卡牌到下一局", "stats": {"keep_card_on_death": true}, "drop_source": "隐藏条件", "unlock_condition": "通关10波后解锁"},
		{"id": "perpetual_engine_relic", "name": "永动引擎", "category": "Relic", "rarity": "Relic", "description": "被动获得能量恢复(每10s+1)", "stats": {"passive_energy_interval": 10, "passive_energy_amount": 1}, "drop_source": "隐藏条件", "unlock_condition": "连续10波无死亡"}
	]

# ========== 获取全部卡牌 ==========
static func get_all_cards() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(get_core_cards())
	all.append_array(get_component_cards())
	all.append_array(get_resonance_cards())
	all.append_array(get_relic_cards())
	return all

# ========== 按类别获取 ==========
static func get_cards_by_category(category: String) -> Array[Dictionary]:
	match category:
		"Core": return get_core_cards()
		"Component": return get_component_cards()
		"Resonance": return get_resonance_cards()
		"Relic": return get_relic_cards()
		_: return []

# ========== 按稀有度获取 ==========
static func get_cards_by_rarity(rarity: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in get_all_cards():
		if card.get("rarity", "") == rarity:
			result.append(card)
	return result

# ========== 稀有度权重 (用于抽卡) ==========
# 随着等级提升，高稀有度概率增加
static func get_rarity_weights(level: int) -> Dictionary:
	var common_weight: float = max(0.30, 0.70 - level * 0.02)
	var uncommon_weight: float = 0.25 + level * 0.01
	var legendary_weight: float = clamp(0.02 + level * 0.005, 0.02, 0.10)
	var relic_weight: float = clamp(0.01 + level * 0.003, 0.01, 0.05)
	var weights: Dictionary = {
		"Common": common_weight,
		"Uncommon": uncommon_weight,
		"Legendary": legendary_weight,
		"Relic": relic_weight,
	}
	return weights

# ========== 通过ID查找卡牌 ==========
static func find_card_by_id(card_id: String) -> Dictionary:
	for card in get_all_cards():
		if card.get("id", "") == card_id:
			return card
	return {}

# ========== 获取卡牌数量统计 ==========
static func get_card_counts() -> Dictionary:
	var counts: Dictionary = {"Core": 0, "Component": 0, "Resonance": 0, "Relic": 0, "total": 0}
	for card in get_all_cards():
		var cat: String = card.get("category", "")
		if cat in counts:
			counts[cat] = counts[cat] + 1
	var total: int = get_all_cards().size()
	counts["total"] = total as int
	return counts
