extends Node2D
## SkillEffect — 技能效果可视化 + 吞噬判定
## 每种效果类型都有独立的绘制和逻辑实现

# ─── 公开属性 ─────────────────────────────────────────
@export var effect_duration: float = 2.0

# ─── 内部状态 ─────────────────────────────────────────
var _timer: float = 0.0
var _active: bool = true
var _effect_type: String = ""
var _center: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _visuals: Array[Node] = []
var _gm: Node
var _player: Node2D

func _ready() -> void:
    _timer = effect_duration
    _gm = get_node_or_null("/root/GameManager")
    _player = get_node_or_null("/root/MainGame/Player")
    add_to_group("skill_effects")

func _process(delta: float) -> void:
    if not _active:
        return
    
    _timer -= delta
    if _timer <= 0:
        _cleanup()
        return
    
    _update_logic(delta)

## 逻辑更新 (每帧调用)
func _update_logic(delta: float) -> void:
    match _effect_type:
        "beam":
            _update_beam(delta)
        "spiral":
            _update_spiral(delta)
        "tracking":
            _update_tracking(delta)
        "blackhole":
            _update_blackhole(delta)
        "line":
            _update_line(delta)
        "summon":
            _update_summon(delta)
        "slow":
            _update_slow(delta)
        "copy":
            _update_copy(delta)
        "freeze":
            _update_freeze(delta)
        "pull":
            _update_pull(delta)
        "aura":
            _update_aura(delta)

## 清理
func _cleanup() -> void:
    _active = false
    for v in _visuals:
        if is_instance_valid(v):
            v.queue_free()
    _visuals.clear()
    
    var skill_sys = get_node_or_null("/root/MainGame/SkillSystem")
    if skill_sys and skill_sys.has_method("remove_effect"):
        skill_sys.remove_effect(self)
    queue_free()

## ── 吞噬检测 ──

func _capture_in_radius(radius: float) -> void:
    if _player == null:
        return
    var pool = get_node_or_null("/root/MainGame/ObjectPool")
    if pool == null:
        return
    
    var player_radius: float = 20.0
    if _player.has_meta("body_radius"):
        player_radius = _player.get_meta("body_radius")
    var enemies = pool.get_active_enemies()
    
    for enemy in enemies:
        if enemy == null or not enemy.active:
            continue
        var dist = _center.distance_to(enemy.global_position)
        if dist <= radius:
            var e_radius: float = 15.0
            if enemy.has_meta("body_radius"):
                e_radius = enemy.get_meta("body_radius")
            if player_radius >= e_radius * 0.8:
                _capture_single(enemy)

func _capture_single(enemy) -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    var enemy_type: String = "basic"
    if enemy.has_meta("enemy_type"):
        enemy_type = enemy.get_meta("enemy_type")
    var enemy_size: float = 15.0
    if enemy.has_meta("body_radius"):
        enemy_size = enemy.get_meta("body_radius")
    var data: Dictionary = {
        "node": enemy,
        "type": enemy_type,
        "size": enemy_size,
    }
    if _player and _player.has_method("_execute_capture"):
        _player._execute_capture(data)

## ── 效果工厂方法 ──

func setup_beam(center: Vector2, direction: Vector2, effects: Dictionary) -> void:
    _effect_type = "beam"
    _center = center
    _direction = direction.normalized()
    effect_duration = 0.5
    _create_beam_visual(effects)

func setup_spiral(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "spiral"
    _center = center
    effect_duration = effects.get("duration", 1.5)
    _create_spiral_visual(effects)

func setup_tracking(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "tracking"
    _center = center
    effect_duration = 3.0
    _create_tracking_visual(effects)

func setup_blackhole(position: Vector2, effects: Dictionary) -> void:
    _effect_type = "blackhole"
    _center = position
    effect_duration = effects.get("duration", 2.0)
    _create_blackhole_visual(effects)

func setup_line(center: Vector2, direction: Vector2, effects: Dictionary) -> void:
    _effect_type = "line"
    _center = center
    _direction = direction.normalized()
    effect_duration = 0.4
    _create_line_visual(effects)

func setup_summon(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "summon"
    _center = center
    effect_duration = effects.get("duration", 5.0)
    _create_summon_visual(effects)

func setup_slow(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "slow"
    _center = center
    effect_duration = effects.get("duration", 3.0)
    _create_slow_visual(effects)

func setup_copy(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "copy"
    _center = center
    effect_duration = effects.get("duration", 8.0)
    _create_copy_visual(effects)

func setup_freeze(screen_size: Vector2, effects: Dictionary) -> void:
    _effect_type = "freeze"
    effect_duration = effects.get("duration", 2.0)
    _create_freeze_visual(screen_size)

func setup_pull(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "pull"
    _center = center
    effect_duration = effects.get("duration", 1.0)
    _create_pull_visual(effects)

func setup_aura(center: Vector2, effects: Dictionary) -> void:
    _effect_type = "aura"
    _center = center
    effect_duration = effects.get("duration", 8.0)
    _create_aura_visual(effects)

## ── 视觉效果创建 ──

func _create_beam_visual(effects: Dictionary) -> void:
    var length = effects.get("length", 300.0)
    var width = effects.get("width", 40.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_beam.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2(length / size.x, width / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_spiral_visual(effects: Dictionary) -> void:
    var radius = effects.get("radius", 100.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_spiral.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2((radius * 2) / size.x, (radius * 2) / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_tracking_visual(effects: Dictionary) -> void:
    var count = effects.get("count", 3)
    
    for i in range(count):
        var sprite = Sprite2D.new()
        sprite.texture = load("res://assets/sprites/skills/fx_tracking_orb.png")
        var angle = (TAU / count) * i
        sprite.position = Vector2(cos(angle) * 30.0, sin(angle) * 30.0)
        add_child(sprite)
        _visuals.push_back(sprite)

func _create_blackhole_visual(effects: Dictionary) -> void:
    var radius = effects.get("radius", 80.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_blackhole.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2((radius * 2) / size.x, (radius * 2) / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_line_visual(effects: Dictionary) -> void:
    var length = effects.get("length", 400.0)
    var width = effects.get("width", 10.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_line_cut.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2(length / size.x, width / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_summon_visual(effects: Dictionary) -> void:
    var count = effects.get("count", 3)
    
    for i in range(count):
        var sprite = Sprite2D.new()
        sprite.texture = load("res://assets/sprites/skills/fx_shadow_clone.png")
        var angle = (TAU / count) * i
        sprite.position = Vector2(cos(angle) * 50.0, sin(angle) * 50.0)
        add_child(sprite)
        _visuals.push_back(sprite)

func _create_slow_visual(effects: Dictionary) -> void:
    var radius = effects.get("radius", 200.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_shadow_bind.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2((radius * 2) / size.x, (radius * 2) / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_copy_visual(effects: Dictionary) -> void:
    var radius = effects.get("radius", 150.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_mirror_domain.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2((radius * 2) / size.x, (radius * 2) / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_freeze_visual(screen_size: Vector2) -> void:
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_freeze.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2(screen_size.x / size.x, screen_size.y / size.y)
        # Center in screen coordinates
        sprite.position = screen_size / 2
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_pull_visual(effects: Dictionary) -> void:
    var radius = effects.get("radius", 250.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_pull.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2((radius * 2) / size.x, (radius * 2) / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

func _create_aura_visual(effects: Dictionary) -> void:
    var radius = effects.get("radius", 80.0)
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/sprites/skills/fx_aura.png")
    if sprite.texture:
        var size = sprite.texture.get_size()
        sprite.scale = Vector2((radius * 2) / size.x, (radius * 2) / size.y)
    add_child(sprite)
    _visuals.push_back(sprite)

## ── 效果逻辑更新 ──

func _update_beam(delta: float) -> void:
    _capture_in_radius(300.0)

func _update_spiral(delta: float) -> void:
    _capture_in_radius(100.0)

func _update_tracking(delta: float) -> void:
    # 追踪弹每帧检测
    if _timer > 2.0:  # 前1秒是飞行时间
        pass

func _update_blackhole(delta: float) -> void:
    _capture_in_radius(80.0)

func _update_line(delta: float) -> void:
    _capture_in_radius(400.0)

func _update_summon(delta: float) -> void:
    # 分身自动吞噬 — 每0.5秒检测一次
    if fmod(Time.get_ticks_msec(), 500) < int(delta * 1000):
        _capture_in_radius(60.0)

func _update_slow(delta: float) -> void:
    # 减速效果 — 标记范围内敌人
    _capture_in_radius(200.0)

func _update_copy(delta: float) -> void:
    _capture_in_radius(150.0)

func _update_freeze(delta: float) -> void:
    # 冻结效果 — 不做吞噬，只是视觉
    pass

func _update_pull(delta: float) -> void:
    _capture_in_radius(250.0)

func _update_aura(delta: float) -> void:
    # 光环持续吞噬
    if fmod(Time.get_ticks_msec(), 1000) < int(delta * 1000):
        _capture_in_radius(80.0)
