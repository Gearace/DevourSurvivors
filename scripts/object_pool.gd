extends Node
## ObjectPool — 通用对象池
## 用于敌人节点的复用，避免频繁实例化/销毁产生的 GC 压力

# ─── 公开属性 ─────────────────────────────────────────
@export var scene_path: String = "res://scenes/enemy_base.tscn"
@export var initial_size: int = 50          # 预分配数量
@export var max_size: int = 200             # 最大容量

# ─── 内部状态 ─────────────────────────────────────────
var _pool: Array[Node2D] = []
var _scene: PackedScene
var _active_enemies: Array[Node2D] = []

func _ready() -> void:
    _scene = load(scene_path) as PackedScene
    _preallocate(initial_size)
    print("[ObjectPool] 预分配 ", _pool.size(), " 个敌人节点")

## 预分配对象
func _preallocate(count: int) -> void:
    for i in range(count):
        var instance = _scene.instantiate() as Node2D
        if instance:
            instance.visible = false
            instance.active = false
            _pool.push_back(instance)
            add_child(instance)

## 从池中获取一个敌人
func spawn(position: Vector2, type_data: Dictionary = {}) -> Node2D:
    var enemy: Node2D = null
    
    if _pool.is_empty():
        # 池空了，动态扩容
        if _active_enemies.size() < max_size:
            enemy = _scene.instantiate() as Node2D
            if enemy:
                add_child(enemy)
        else:
            return null  # 达到上限
    
    if enemy == null:
        enemy = _pool.pop_back()
    
    enemy.visible = true
    enemy.active = true
    enemy.global_position = position
    
    # 重置敌人状态
    if enemy.has_method("reset"):
        enemy.reset(position, type_data)
    
    # 设置玩家引用
    var player = get_node_or_null("/root/MainGame/Player")
    if player and enemy.has_method("set_player_reference"):
        enemy.set_player_reference(player)
    
    _active_enemies.push_back(enemy)
    return enemy

## 回收敌人到池中
func despawn(enemy: Node2D) -> void:
    if not is_instance_valid(enemy):
        return
    
    enemy.visible = false
    enemy.active = false
    
    # 从活跃列表中移除
    if enemy in _active_enemies:
        _active_enemies.erase(enemy)
    
    # 放回池中
    _pool.push_back(enemy)

## 回收所有活跃敌人
func despawn_all() -> void:
    for enemy in _active_enemies:
        if is_instance_valid(enemy):
            enemy.visible = false
            enemy.active = false
            _pool.push_back(enemy)
    _active_enemies.clear()

## 获取活跃敌人数量
func get_active_count() -> int:
    return _active_enemies.size()

## 获取池中剩余数量
func get_available_count() -> int:
    return _pool.size()

## 获取所有活跃敌人 (供吞噬判定遍历)
func get_active_enemies() -> Array[Node2D]:
    return _active_enemies.duplicate()
