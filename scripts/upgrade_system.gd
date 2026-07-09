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

var rarity_rank := {
    "Common": 0,
    "Uncommon": 1,
    "Legendary": 2,
    "Relic": 3,
}

func draw_upgrade_cards() -> Array[Dictionary]:
    current_level = GameManager.player_stats.level
    current_wave = GameManager.current_wave
    var pool = _get_card_pool()
    var build_type = _detect_build_type()
    var drawn: Array[Dictionary] = []
    var available := pool.duplicate()
    for i in CARDS_TO_DRAW:
        if available.is_empty():
            break
        var weights = CardDatabase.get_rarity_weights(current_level)
        if pity_counter >= PITY_THRESHOLD:
            weights.Uncommon = 1.0
        weights = _apply_build_guidance(weights, build_type, available)
        var card = _weighted_draw(available, weights)
        if card != {}:
            drawn.append(card)
            available.erase(card)
            if rarity_rank.get(card.rarity, 0) >= 2:
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
        if not GameManager.has_card(card.id):
            if card.category == "Relic":
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
    var core_counts := {"Core": 0, "Component": 0, "Resonance": 0}
    for card_id in deck:
        var card = CardDatabase.find_card_by_id(card_id)
        if card.is_empty():
            continue
        var cat = card.category
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
        result.Uncommon = min(1.0, result.Uncommon * 1.3)
    elif build_type == "Component":
        result.Common = min(1.0, result.Common * 1.2)
    elif build_type == "Resonance":
        result.Uncommon = min(1.0, result.Uncommon * 1.4)
    var total = result.Common + result.Uncommon + result.Legendary + result.Relic
    if total > 0:
        result.Common /= total
        result.Uncommon /= total
        result.Legendary /= total
        result.Relic /= total
    return result

func _weighted_draw(pool: Array[Dictionary], weights: Dictionary) -> Dictionary:
    if pool.is_empty():
        return {}
    var total_weight := 0.0
    var card_weights: Array[float] = []
    for card in pool:
        var rarity = card.rarity
        var w = weights.get(rarity, 0.1)
        if card.category == "Resonance":
            var check_id = card.stats.get("resonance_check", "")
            if check_id != "":
                var has_prerequisite = false
                for pc in pool:
                    if pc.id == check_id:
                        has_prerequisite = true
                        break
                    # Also check name-based resonance checks
                    if check_id == "shadow_clone" and "shadow_clone" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "black_hole_body" and "black_hole" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "mirror_reflect" and "mirror" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "split_gene" and "split" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "energy_siphon" and "energy" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "phoenix-blood" and "phoenix" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "extreme_squeeze" and "extreme" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "perpetual_engine" and "perpetual" in pc.id:
                        has_prerequisite = true
                        break
                    if check_id == "greedy_mouth" and "greedy" in pc.id:
                        has_prerequisite = true
                        break
                if not has_prerequisite:
                    w *= 0.1
        card_weights.append(w)
        total_weight += w
    if total_weight <= 0:
        total_weight = 1.0
    var rand = randf() * total_weight
    var cumulative := 0.0
    for i in card_weights.size():
        cumulative += card_weights[i]
        if rand <= cumulative:
            return pool[i]
    return pool[-1]

func select_card(card: Dictionary) -> void:
    var card_id = card.id
    if GameManager.add_card_to_deck(card_id):
        print("[UpgradeSystem] 玩家选择了: ", card.name)
        var fusion_result = GameManager.check_fusion(card_id)
        if not fusion_result.is_empty():
            print("[UpgradeSystem] 触发融合: ", fusion_result.name)
        _apply_passive_effects(card)
        card_selected.emit(card_id)
    _close_upgrade_popup()

func _apply_passive_effects(card: Dictionary) -> void:
    var stats = card.get("stats", {})
    if stats.is_empty():
        return
    var s = GameManager.player_stats
    if "speed_bonus" in stats:
        s.speed *= (1.0 + stats.speed_bonus)
    if "capture_range_bonus" in stats:
        s.capture_range *= (1.0 + stats.capture_range_bonus)
    if "capture_radius_bonus" in stats:
        s.capture_range *= (1.0 + stats.capture_radius_bonus)
    if "max_hp_bonus" in stats:
        s.max_hp *= (1.0 + stats.max_hp_bonus)
        s.current_hp = s.max_hp
    if "cooldown_reduction" in stats:
        s.skill_cd_multiplier *= (1.0 - stats.cooldown_reduction)
    if "capture_value_bonus" in stats:
        s.capture_bonus *= (1.0 + stats.capture_value_bonus)
    if "hp_regen_per_capture" in stats:
        s.vampire_heal = stats.hp_regen_per_capture
    if "invincible_on_capture" in stats and stats.invincible_on_capture:
        s.invincible_on_capture = true
        s.invincible_duration = stats.invincible_duration
    if "energy_per_capture" in stats:
        s.energy_per_capture = stats.energy_per_capture
    if "energy_cap_bonus" in stats:
        s.energy_cap += stats.energy_cap_bonus
    if "initial_energy_bonus" in stats:
        s.current_energy += stats.initial_energy_bonus
    if "max_simultaneous_captures" in stats:
        s.max_simultaneous_captures = stats.max_simultaneous_captures
    if "low_hp_capture_bonus" in stats:
        s.low_hp_capture_bonus = stats.low_hp_capture_bonus
        s.low_hp_threshold = stats.low_hp_threshold
    print("[UpgradeSystem] 应用被动效果: ", card.name)
    print("[UpgradeSystem] 当前属性: LV=", s.level, " HP=", s.current_hp, " Speed=", s.speed, " Capture=", s.capture_range)

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
    var counts := {"Core": 0, "Component": 0, "Resonance": 0, "Relic": 0}
    for card in pool:
        if card.category in counts:
            counts[card.category] += 1
    print("[UpgradeSystem] 类别分布: ", counts)
    print("[UpgradeSystem] 当前保底计数: ", pity_counter)
    print("[UpgradeSystem] 当前等级权重: ", CardDatabase.get_rarity_weights(current_level))
