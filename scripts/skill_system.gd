extends Node
## SkillSystem — 技能管理器
## 管理所有技能的生命周期：冷却、释放、效果执行

# ─── 技能定义数据库 ─────────────────────────────────────
# 格式: { id, name, category, cooldown, effects: {...} }
var _skill_definitions: Dictionary = {
    # ── 指向性技能 (划屏) ──
    "swallow_wave": {
        "name": "吞噬波",
        "category": 0,  # SWIPE
        "cooldown": 3.0,
        "description": "沿划动方向发射吞噬光束",
        "effects": {
            "type": "beam",
            "length": 300.0,
            "width": 40.0,
            "speed": 400.0,
            "damage": 1.0,
            "color": Color(0.3, 1.0, 0.5),
        },
    },
    "spiral_capture": {
        "name": "螺旋吞噬",
        "category": 0,
        "cooldown": 4.0,
        "description": "以自身为中心旋转吞噬",
        "effects": {
            "type": "spiral",
            "radius": 100.0,
            "duration": 1.5,
            "speed": 200.0,
            "color": Color(0.2, 0.8, 0.3),
        },
    },
    "tracking_capture": {
        "name": "追踪吞噬",
        "category": 0,
        "cooldown": 5.0,
        "description": "释放追踪弹吞噬敌人",
        "effects": {
            "type": "tracking",
            "count": 3,
            "speed": 300.0,
            "damage": 1.0,
            "color": Color(0.4, 1.0, 0.6),
        },
    },
    "black_hole_pull": {
        "name": "黑洞牵引",
        "category": 0,
        "cooldown": 6.0,
        "description": "在目标点生成黑洞吸入敌人",
        "effects": {
            "type": "blackhole",
            "radius": 80.0,
            "duration": 2.0,
            "pull_strength": 200.0,
            "damage": 0.5,
            "color": Color(0.5, 0.2, 1.0),
        },
    },
    "phase_cut": {
        "name": "相位切割",
        "category": 0,
        "cooldown": 4.0,
        "description": "沿划动方向产生切割线",
        "effects": {
            "type": "line",
            "length": 400.0,
            "width": 10.0,
            "speed": 600.0,
            "damage": 2.0,
            "color": Color(1.0, 0.3, 0.3),
        },
    },
    # ── 非指向性技能 (双击) ──
    "shadow_clone": {
        "name": "影分身之术",
        "category": 1,  # DOUBLE
        "cooldown": 8.0,
        "description": "生成分身自动吞噬敌人",
        "effects": {
            "type": "summon",
            "count": 3,
            "duration": 5.0,
            "clone_strength": 0.5,
            "color": Color(0.3, 0.5, 0.8, 0.6),
        },
    },
    "shadow_bind": {
        "name": "影子束缚术",
        "category": 1,
        "cooldown": 10.0,
        "description": "范围内敌人被束缚无法移动",
        "effects": {
            "type": "slow",
            "radius": 200.0,
            "duration": 3.0,
            "slow_factor": 0.0,  # 完全停止
            "color": Color(0.4, 0.2, 0.6, 0.4),
        },
    },
    "mirror_domain": {
        "name": "镜像领域",
        "category": 1,
        "cooldown": 12.0,
        "description": "复制范围内的敌人成为友方",
        "effects": {
            "type": "copy",
            "radius": 150.0,
            "duration": 8.0,
            "copy_count": 1,
            "color": Color(0.8, 0.6, 1.0, 0.3),
        },
    },
    "time_stop": {
        "name": "时空停滞",
        "category": 1,
        "cooldown": 15.0,
        "description": "全屏敌人冻结",
        "effects": {
            "type": "freeze",
            "duration": 2.0,
            "post_stun": 1.0,
            "color": Color(0.6, 0.8, 1.0, 0.5),
        },
    },
    "pull_to_center": {
        "name": "群体拉近",
        "category": 1,
        "cooldown": 6.0,
        "description": "范围内敌人强制拉向玩家",
        "effects": {
            "type": "pull",
            "radius": 250.0,
            "strength": 300.0,
            "duration": 1.0,
            "color": Color(0.9, 0.5, 0.2),
        },
    },
    "capture_aura": {
        "name": "吞噬光环",
        "category": 1,
        "cooldown": 10.0,
        "description": "周围持续造成吞噬伤害",
        "effects": {
            "type": "aura",
            "radius": 80.0,
            "duration": 8.0,
            "damage_per_second": 2.0,
            "color": Color(1.0, 0.8, 0.0, 0.3),
        },
    },
}

# ─── 内部状态 ─────────────────────────────────────────
var _owned_skills: Dictionary = {}   # { skill_id: { level, cooldown_timer, max_cooldown } }
var _active_effects: Array[Node2D] = []  # 当前正在生效的技能效果节点
var _energy: float = 0.0
var _max_energy: float = 10.0
var _energy_regenerate_rate: float = 1.0  # 每秒恢复能量

# ─── 信号 ─────────────────────────────────────────
signal skill_cast_success(skill_id: String)
signal skill_failed(skill_id: String, reason: String)
signal effect_spawned(effect_node)
signal effect_removed(effect_node)

func _ready() -> void:
    # 初始技能: 吞噬波
    add_skill("swallow_wave")
    print("[SkillSystem] 初始化完成 — 拥有技能: ", _owned_skills.keys())

func _process(delta: float) -> void:
    # 更新冷却
    for skill_id in _owned_skills:
        var info = _owned_skills[skill_id]
        if info.get("cooldown_timer", 0.0) > 0:
            info["cooldown_timer"] = info.get("cooldown_timer", 0.0) - delta
    
    # 能量自然恢复
    _energy = min(_energy + _energy_regenerate_rate * delta, _max_energy)

## 添加技能到_owned
func add_skill(skill_id: String) -> void:
    if skill_id in _owned_skills:
        # 已有则升级
        upgrade_skill(skill_id)
        return
    
    if skill_id not in _skill_definitions:
        print("[SkillSystem] 警告: 未知技能ID ", skill_id)
        return
    
    var def = _skill_definitions[skill_id]
    _owned_skills[skill_id] = {
        "level": 1,
        "cooldown_timer": 0.0,
        "max_cooldown": def.cooldown,
    }
    print("[SkillSystem] 获得技能: ", def.name, " (", skill_id, ")")

## 升级已有技能
func upgrade_skill(skill_id: String) -> void:
    if skill_id not in _owned_skills:
        return
    _owned_skills[skill_id]["level"] = _owned_skills[skill_id]["level"] + 1
    print("[SkillSystem] 升级技能: ", skill_id, " Lv.", _owned_skills[skill_id]["level"])

## 检查技能是否就绪 (冷却结束)
func is_skill_ready(skill_id: String) -> bool:
    if skill_id not in _owned_skills:
        return false
    return _owned_skills[skill_id]["cooldown_timer"] <= 0

## 获取技能冷却剩余时间
func get_skill_cooldown_remaining(skill_id: String) -> float:
    if skill_id not in _owned_skills:
        return 0.0
    return max(_owned_skills[skill_id]["cooldown_timer"], 0.0)

## 获取技能信息
func get_skill_info(skill_id: String) -> Dictionary:
    if skill_id not in _owned_skills:
        return {}
    var info = _owned_skills[skill_id].duplicate()
    if skill_id in _skill_definitions:
        info.merge(_skill_definitions[skill_id])
    return info

## 获取所有已拥有技能ID
func get_owned_skill_ids() -> Array[String]:
    return _owned_skills.keys()

## 释放技能 (划屏)
func cast_swipe_skill(skill_id: String, direction: Vector2) -> bool:
    if not is_skill_ready(skill_id):
        var remaining = get_skill_cooldown_remaining(skill_id)
        skill_failed.emit(skill_id, "冷却中 (" + str(remaining) + "s)")
        return false
    
    var def = _skill_definitions.get(skill_id, {})
    if def.is_empty():
        print("[SkillSystem] 未知技能: ", skill_id)
        return false
    
    # 启动冷却
    _owned_skills[skill_id]["cooldown_timer"] = def.get("cooldown", 3.0)
    
    # 执行效果
    var effect = _create_effect(skill_id, def, direction)
    if effect:
        _active_effects.push_back(effect)
        skill_cast_success.emit(skill_id)
        return true
    
    return false

## 释放技能 (双击)
func cast_double_skill(skill_id: String) -> bool:
    if not is_skill_ready(skill_id):
        var remaining = get_skill_cooldown_remaining(skill_id)
        skill_failed.emit(skill_id, "冷却中 (" + str(remaining) + "s)")
        return false
    
    var def = _skill_definitions.get(skill_id, {})
    if def.is_empty():
        print("[SkillSystem] 未知技能: ", skill_id)
        return false
    
    # 启动冷却
    _owned_skills[skill_id]["cooldown_timer"] = def.get("cooldown", 3.0)
    
    # 执行效果
    var effect = _create_effect(skill_id, def, Vector2.ZERO)
    if effect:
        _active_effects.push_back(effect)
        skill_cast_success.emit(skill_id)
        return true
    
    return false

## 创建技能效果节点
func _create_effect(skill_id: String, definition: Dictionary, direction: Vector2) -> Node2D:
    var effects = definition.get("effects", {})
    var effect_type = effects.get("type", "")
    var player = get_node_or_null("/root/MainGame/Player")
    
    if player == null:
        print("[SkillSystem] 警告: 找不到玩家节点")
        return null
    
    var effect_node: Node2D
    
    match effect_type:
        "beam":  # 吞噬波
            effect_node = _create_beam_effect(effects, player, direction)
        "spiral":  # 螺旋吞噬
            effect_node = _create_spiral_effect(effects, player)
        "tracking":  # 追踪吞噬
            effect_node = _create_tracking_effect(effects, player, direction)
        "blackhole":  # 黑洞牵引
            effect_node = _create_blackhole_effect(effects, player, direction)
        "line":  # 相位切割
            effect_node = _create_line_effect(effects, player, direction)
        "summon":  # 影分身
            effect_node = _create_summon_effect(effects, player)
        "slow":  # 影子束缚
            effect_node = _create_slow_effect(effects, player)
        "copy":  # 镜像复制
            effect_node = _create_copy_effect(effects, player)
        "freeze":  # 时空停滞
            effect_node = _create_freeze_effect(effects, player)
        "pull":  # 群体拉近
            effect_node = _create_pull_effect(effects, player)
        "aura":  # 吞噬光环
            effect_node = _create_aura_effect(effects, player)
        _:
            print("[SkillSystem] 未知效果类型: ", effect_type)
            return null
    
    if effect_node:
        get_tree().root.add_child(effect_node)
        effect_spawned.emit(effect_node)
        return effect_node
    
    return null

## ── 效果工厂方法 ──

func _create_beam_effect(effects: Dictionary, player: Node2D, direction: Vector2) -> Node2D:
    var BeamEffect: GDScript = preload("res://scripts/skill_effect.gd")
    var effect = BeamEffect.new()
    effect.setup_beam(player.global_position, direction, effects)
    return effect

func _create_spiral_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_spiral(player.global_position, effects)
    return effect

func _create_tracking_effect(effects: Dictionary, player: Node2D, direction: Vector2) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_tracking(player.global_position, effects)
    return effect

func _create_blackhole_effect(effects: Dictionary, player: Node2D, direction: Vector2) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    var target_pos = player.global_position + direction * 200.0
    effect.setup_blackhole(target_pos, effects)
    return effect

func _create_line_effect(effects: Dictionary, player: Node2D, direction: Vector2) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_line(player.global_position, direction, effects)
    return effect

func _create_summon_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_summon(player.global_position, effects)
    return effect

func _create_slow_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_slow(player.global_position, effects)
    return effect

func _create_copy_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_copy(player.global_position, effects)
    return effect

func _create_freeze_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_freeze(Vector2(720, 1280), effects)
    return effect

func _create_pull_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_pull(player.global_position, effects)
    return effect

func _create_aura_effect(effects: Dictionary, player: Node2D) -> Node2D:
    var effect = preload("res://scripts/skill_effect.gd").new()
    effect.setup_aura(player.global_position, effects)
    return effect

## 移除已完成的技能效果
func remove_effect(effect_node: Node2D) -> void:
    if effect_node in _active_effects:
        _active_effects.erase(effect_node)
    effect_removed.emit(effect_node)


