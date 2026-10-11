extends Resource
## SkillData — 技能数据资源
## 每个技能一个 Resource 实例，存储在技能数据库中

class_name SkillData

# ─── 技能枚举 ─────────────────────────────────────────
enum SkillCategory {
    SWIPE,       # 指向性技能 (划屏)
    DOUBLE,      # 非指向性技能 (双击)
    PASSIVE,     # 被动技能
}

# v1.2: 技能自带奇幻七元素 (风/火/水/土/雷/光/暗, 随机 roll)
enum SkillElement {
    WIND,        # 风
    FIRE,        # 火
    WATER,       # 水
    EARTH,       # 土
    THUNDER,     # 雷
    LIGHT,       # 光
    DARK,        # 暗
}


enum SkillTarget {
    SELF,        # 以自己为中心
    DIRECTION,   # 指定方向
    AREA,        # 指定区域
}

# ─── 公开属性 ─────────────────────────────────────────
@export var skill_id: String = ""            # 唯一标识
@export var skill_name: String = ""          # 显示名称
@export var category: int = 0                # SkillCategory
@export var target_type: int = 0             # SkillTarget
@export var description: String = ""         # 技能描述
@export var cooldown: float = 3.0            # 冷却时间 (秒)
@export var energy_cost: float = 0.0         # 能量消耗 (0=不用能量)
@export var element: int = -1               # v1.2: 奇幻元素 (SkillElement, -1=未 roll)
@export var material: String = ""           # v1.2: 五行材质 (金/木/水/火/土, 空=未浸篆)
@export var level: int = 1                   # 当前等级
@export var max_level: int = 3               # 最大等级

# ─── 效果参数 ─────────────────────────────────────────
@export_group("Effects")
@export var damage: float = 0.0              # 伤害值
@export var duration: float = 0.0            # 持续时长
@export var radius: float = 0.0              # 影响半径
@export var speed: float = 0.0               # 移动速度
@export var count: int = 1                   # 数量 (弹数/分身数)
@export var strength: float = 1.0            # 强度倍率

# ─── 视觉效果 ─────────────────────────────────────────
@export_group("Visuals")
@export var particle_scene: PackedScene       # 粒子特效预制体
@export var sound_cast: String = ""           # 释放音效
@export var sound_impact: String = ""         # 命中音效
@export var color: Color = Color.WHITE        # 技能颜色

# ─── 等级加成 ─────────────────────────────────────────
@export_group("Level Scaling")
@export var damage_per_level: float = 0.0
@export var cooldown_reduction_per_level: float = 0.0
@export var radius_increase_per_level: float = 0.0
@export var count_increase_per_level: int = 0

## 获取当前等级的实际冷却
func get_current_cooldown() -> float:
    var reduction = cooldown_reduction_per_level * (level - 1)
    return max(cooldown - reduction, 0.5)

## 获取当前等级的实际伤害
func get_current_damage() -> float:
    return damage + damage_per_level * (level - 1)

## 获取当前等级的实际半径
func get_current_radius() -> float:
    return radius + radius_increase_per_level * (level - 1)

## 获取当前等级的实际数量
func get_current_count() -> int:
    return count + count_increase_per_level * (level - 1)

## 升级技能
func upgrade() -> bool:
    if level < max_level:
        level += 1
        return true
    return false

## 从字典创建 SkillData
static func from_dict(data: Dictionary) -> SkillData:
    var skill = SkillData.new()
    skill.skill_id = data.get("id", "")
    skill.skill_name = data.get("name", "")
    skill.category = data.get("category", 0)
    skill.target_type = data.get("target_type", 0)
    skill.description = data.get("description", "")
    skill.cooldown = data.get("cooldown", 3.0)
    skill.energy_cost = data.get("energy_cost", 0.0)
    skill.element = data.get("element", -1)
    skill.material = data.get("material", "")
    skill.damage = data.get("damage", 0.0)
    skill.duration = data.get("duration", 0.0)
    skill.radius = data.get("radius", 0.0)
    skill.speed = data.get("speed", 0.0)
    skill.count = data.get("count", 1)
    skill.strength = data.get("strength", 1.0)
    skill.color = data.get("color", Color.WHITE)
    skill.damage_per_level = data.get("damage_per_level", 0.0)
    skill.cooldown_reduction_per_level = data.get("cooldown_reduction_per_level", 0.0)
    skill.radius_increase_per_level = data.get("radius_increase_per_level", 0.0)
    skill.count_increase_per_level = data.get("count_increase_per_level", 0)
    return skill

## v1.2: 随机 roll 一个奇幻元素 (风/火/水/土/雷/光/暗)
static func roll_element() -> int:
    var elts: Array[int] = [SkillElement.WIND, SkillElement.FIRE, SkillElement.WATER, SkillElement.EARTH, SkillElement.THUNDER, SkillElement.LIGHT, SkillElement.DARK]
    return elts[randi() % elts.size()]
