extends RefCounted
## chapter_style.gd
## v1.2: 多大关结构总纲 (docs/关卡设计_灵感归纳_v1.md §3.0, 派生自 杀戮尖塔/黑神话/原神)
## 核心思路: 13 层不是上限, 而是一个大关. 多个大关串成一局游戏, 每大关独立怪物风格 + Boss + 专属遗物.
## 纯数据层, 无节点, 便于单元测试.
## 参考作品: 杀戮尖塔(多章扩展+build延续+路线分支) / 黑神话(Boss法宝=大关专属遗物) / 原神(圣遗物构筑+元素反应)

# ─── 大关风格表 (每大关: 风格名 + 新机制 + 环境 + Boss + 专属遗物) ───
# 敌人风格: 决定本关内 普通/精英 层刷哪种基础敌 + 新机制怪
# 专属遗物: Boss 通关必掉 (黑神话法宝), 是构筑「放大器」层
const STYLES: Array = [
	{
		"id": "swamp",
		"name": "腐沼",
		"style": "慢速/群体/分裂",
		"new_mechanic": "toxin",            # 毒囊 (吞噬后 8s -3HP/s)
		"extra_enemies": ["toxin_swarmer"], # 本关新增怪 (slow + 群体)
		"environment": "toxic_fog",        # 毒雾 (每 30s 1 片 -5HP)
		"boss_id": "boss_swamp",
		"boss_name": "腐沼吞噬者",
		"relic_id": "relic_swamp_core",     # 毒囊之核
	},
	{
		"id": "gold_mine",
		"name": "熔金矿洞",
		"style": "快速/切割/金元素",
		"new_mechanic": "tear",             # 撕裂者 (4s 撕裂波)
		"extra_enemies": ["phase_cutter"],  # 本关新增怪 (fast + 切割)
		"environment": "lava_ground",       # 熔岩 (地面残留灼烧)
		"boss_id": "boss_gold_beast",
		"boss_name": "金甲兽",
		"relic_id": "relic_gold_shard",    # 金甲残片
	},
	{
		"id": "void_corridor",
		"name": "虚空回廊",
		"style": "镜像/分身/佯攻",
		"new_mechanic": "mirror",           # 镜影 (召唤 2 分身)
		"extra_enemies": ["decoy_wraith"],  # 本关新增怪 (mirror + 佯攻)
		"environment": "void_fog",          # 虚空 (视野-30%)
		"boss_id": "boss_void_devourer",
		"boss_name": "虚空吞噬者",
		"relic_id": "relic_void_fragment",  # 虚空碎片
	},
]

# 无尽深渊 (大关 4+): 全怪物混合 + 强化, 每大关 roll 2 种风格
const ENDLESS_STYLE := "endless"

## 取大关 1..3 风格; 4+ 返回无尽风格 (全混合)
static func get_style(chapter: int) -> Dictionary:
	if chapter < 1:
		chapter = 1
	if chapter <= STYLES.size():
		return STYLES[chapter - 1]
	# 大关 4+: 无尽深渊 — 全怪物混合, roll 2 种风格混合 (简化: 返 1 个标记)
	return {
		"id": ENDLESS_STYLE,
		"name": "无尽深渊",
		"style": "全怪物混合+强化",
		"new_mechanic": "all",
		"extra_enemies": ["basic", "swift", "heavy", "split", "decoy"],
		"environment": "random",
		"boss_id": "boss_abyss_echo",
		"boss_name": "深渊回响体",
		"relic_id": "relic_abyss_echo",
	}

## 取指定 id 的风格 (无尽用)
static func get_style_by_id(id: String) -> Dictionary:
	for s in STYLES:
		if s.get("id", "") == id:
			return s
	if id == ENDLESS_STYLE:
		return get_style(4)
	return {}

## 大关数量 (1..3 有独立风格, 4+ 无尽循环)
static func style_count() -> int:
	return STYLES.size()  # 3 个独立风格大关 + 无尽

## 大关难度放大 (跨大关保留/重置规则: 敌人数×1.1, 难度×1.25)
static func chapter_stat_scale(chapter: int) -> float:
	match chapter:
		1: return 1.0
		2: return 1.2
		3: return 1.4
		_: return 1.4 * pow(1.25, maxi(0, chapter - 3))

## 大关敌人数放大
static func chapter_count_scale(chapter: int) -> float:
	match chapter:
		1: return 1.0
		_: return pow(1.1, maxi(0, chapter - 1))
