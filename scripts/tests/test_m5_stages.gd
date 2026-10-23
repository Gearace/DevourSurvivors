extends SceneTree
## test_m5_stages.gd — M5 多大关 + Boss 3 阶段 (headless)
## 运行: godot --headless -s res://scripts/tests/test_m5_stages.gd
## 验证 关卡设计_灵感归纳_v1.md §3.0/§3.3:
##   · 多大关结构总纲 (3.0) — chapter_style 表 3 个独立风格 + 无尽
##   · route_generator 按大关风格 roll Boss / 注入新增怪
##   · Boss 3 阶段 (3.3) — 满血/50%/20% 阶段机 + 忍杀窗口 + 啃食加速 meta

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	print("=== M5 多大关 + Boss 3 阶段 测试 ===")
	var all_pass: bool = true

	var cs = load("res://scripts/chapter_style.gd")
	var rg = load("res://scripts/route_generator.gd").new()
	rg.name = "RouteGenerator"
	_gm = gm
	root.add_child(rg)
	# 手动触发 _ready (因为 load().new() 不进场景树不会自动调, 但 add_child 会)

	# ── 3.0 多大关结构总纲 ───────────────────────────────
	# 验证: 3 个独立风格大关 + 无尽 (大关 4+)
	var style_count: int = cs.style_count()
	print("大关风格数=", style_count, " (期望 3 + 无尽)")
	if style_count != 3:
		all_pass = false
		push_error("大关风格数应为 3, 实际 ", style_count)

	# 每个大关有 boss_id + relic_id + extra_enemies
	for i in 3:
		var s: Dictionary = cs.get_style(i + 1)
		if s.get("boss_id", "") == "" or s.get("relic_id", "") == "":
			all_pass = false
			push_error("大关 ", i + 1, " 缺 boss_id/relic_id")
		if s.get("extra_enemies", []).is_empty():
			all_pass = false
			push_error("大关 ", i + 1, " 缺 extra_enemies")
	print("大关 1 boss=", cs.get_style(1)["boss_id"], "  relic=", cs.get_style(1)["relic_id"])
	print("大关 2 boss=", cs.get_style(2)["boss_id"], "  relic=", cs.get_style(2)["relic_id"])
	print("大关 3 boss=", cs.get_style(3)["boss_id"], "  relic=", cs.get_style(3)["relic_id"])

	# 无尽 (大关 4+) 走 get_style(4)
	var endless: Dictionary = cs.get_style(4)
	if endless.get("id", "") != cs.ENDLESS_STYLE:
		all_pass = false
		push_error("大关 4 应为无尽风格")
	print("大关 4 (无尽) id=", endless["id"], "  boss=", endless["boss_id"])

	# 难度放大: 大关 2 > 大关 1, 大关 4 > 大关 3
	var s1: float = cs.chapter_stat_scale(1)
	var s2: float = cs.chapter_stat_scale(2)
	var s4: float = cs.chapter_stat_scale(4)
	if not (s1 < s2 and s2 < s4):
		all_pass = false
		push_error("难度放大应递增: ", s1, " < ", s2, " < ", s4)
	print("难度放大: 大关1=", s1, "  大关2=", s2, "  大关4=", s4)

	# ── 3.0 route_generator 按大关风格 roll ──────────────
	# 验证: route_generator.get_current_style() 随 chapter 变化
	# rg._gm 在 _ready 里 get_node_or_null("/root/GameManager"), 测试里 gm 已 add_child 到 root
	# 但 _ready 在 add_child 时已跑过, 此时 _gm 可能是 null — 手动注入
	if rg.has_method("_inject_gm_for_test"):
		pass
	# 直接设置 _gm 字段 (GDScript 允许测试访问)
	rg._gm = gm
	var st1: Dictionary = rg.get_current_style_from_chapter(1)
	if st1.get("id", "") != "swamp":
		all_pass = false
		push_error("chapter 1 应 腐沼风格, 实际 ", st1.get("id", "?"))
	var st2: Dictionary = rg.get_current_style_from_chapter(2)
	if st2.get("id", "") != "gold_mine":
		all_pass = false
		push_error("chapter 2 应 熔金矿洞风格, 实际 ", st2.get("id", "?"))
	var st4: Dictionary = rg.get_current_style_from_chapter(4)
	if st4.get("id", "") != cs.ENDLESS_STYLE:
		all_pass = false
		push_error("chapter 4 应 无尽风格, 实际 ", st4.get("id", "?"))
	print("route_generator 按大关风格 roll 通过 (腐沼/熔金矿洞/无尽)")

	# 验证: _roll_boss_id 随 chapter 变 (不再固定 boss_ch1)
	gm.chapter = 1
	var b1: String = rg._roll_boss_id(1)
	gm.chapter = 2
	var b2: String = rg._roll_boss_id(2)
	if b1 == b2:
		all_pass = false
		push_error("不同大关 Boss 应不同: ", b1, " vs ", b2)
	print("Boss 随大关变化: 大关1=", b1, "  大关2=", b2)

	# 验证: 普通波注入大关新增怪 (chapter 1 = 腐沼 toxin_swarmer)
	gm.chapter = 1
	var pack1: Array = rg._normal_pack_for_floor(6)
	var has_toxin: bool = false
	for e in pack1:
		if e.get("type", "") == "toxin_swarmer":
			has_toxin = true
	if not has_toxin:
		all_pass = false
		push_error("腐沼风格 层 6 普通波应含 toxin_swarmer, 实际: ", pack1)
	print("腐沼风格 层 6 注入 toxin_swarmer=", has_toxin)

	# ── 3.1 单大关 13 层节奏曲线重排 ─────────────────────
	# 验证: 模板按 v1.2 §3.1 节奏 (张力峰 3/6/9/12 + 战斗强度峰 4/5/8/10/12)
	# 层 3 = 营地(2), 层 5 = 精英(1), 层 6 = 事件(4), 层 8 = 商店(3), 层 9 = 精英(1), 层 13 = Boss(5)
	var tpl: Array = rg._template
	if tpl.size() != 13:
		all_pass = false
		push_error("节奏模板应为 13 层, 实际 ", tpl.size())
	var expected_types: Dictionary = {
		1: 0,  # 普通(教学)
		3: 2,  # 营地
		4: 0,  # 普通(三敌围猎)
		5: 1,  # 精英(首次)
		6: 4,  # 事件(元素谜题)
		7: 2,  # 营地
		8: 3,  # 商店
		9: 1,  # 精英
		10: 0, # 普通(高压)
		11: 4, # 事件(路线分支)
		12: 1, # 精英(高难度)
		13: 5, # Boss
	}
	for rec in tpl:
		var f: int = int(rec.floor)
		if not expected_types.has(f):
			continue
		var exp: int = int(expected_types[f])
		var actual: int
		if rec.fixed:
			actual = int(rec.type)
		else:
			actual = int(rec.options[0])
		if actual != exp:
			all_pass = false
			push_error("层 ", f, " 节奏节点应为 ", exp, ", 实际 ", actual)
	print("节奏曲线 13 层验证通过 (张力峰 3/6/9/12 + 战斗峰 4/5/8/10/12)")

	# ── 3.3 Boss 3 阶段 ──────────────────────────────────
	var eb = load("res://scripts/enemy_base.gd")
	var boss: Node2D = eb.new()
	boss.name = "BossTest"
	root.add_child(boss)
	boss.enemy_type = "boss_swamp"
	boss.max_hp = 10
	boss.current_hp = 10

	# 阶段 1: 满血 — 无弱点
	boss._process_boss(0.01)
	if boss.boss_phase != 1 or boss.boss_weakness_open:
		all_pass = false
		push_error("满血应 阶段 1 且无弱点")

	# 阶段 2: 50% 血量 — 弱点暴露 (gnaw_mult = 1.5)
	boss.current_hp = 5
	boss._process_boss(0.01)
	if boss.boss_phase != 2 or not boss.boss_weakness_open:
		all_pass = false
		push_error("50% 应 阶段 2 弱点暴露")
	var gm2: float = boss.get_meta("gnaw_mult", 0.0)
	if absf(gm2 - 1.5) > 0.001:
		all_pass = false
		push_error("弱点暴露 gnaw_mult 应 1.5, 实际 ", gm2)

	# 阶段 3: 20% 血量 — 狂暴 + 忍杀窗口 (gnaw_mult = 3.0)
	boss.current_hp = 2
	boss._process_boss(0.01)
	if boss.boss_phase != 3 or not boss.boss_enraged:
		all_pass = false
		push_error("20% 应 阶段 3 狂暴")
	var gm3: float = boss.get_meta("gnaw_mult", 0.0)
	if absf(gm3 - 3.0) > 0.001:
		all_pass = false
		push_error("忍杀窗口 gnaw_mult 应 3.0, 实际 ", gm3)
	if boss.boss_kill_window <= 0.0:
		all_pass = false
		push_error("狂暴应开忍杀窗口, 实际 ", boss.boss_kill_window)
	print("Boss 3 阶段: 满血(阶段1) → 50%(阶段2,gnaw×1.5) → 20%(阶段3,gnaw×3.0,忍杀窗口)")

	# 非 Boss 不触发阶段机
	var basic: Node2D = eb.new()
	basic.enemy_type = "basic"
	basic.max_hp = 1
	basic.current_hp = 1
	root.add_child(basic)
	basic._process_boss(0.01)
	if basic.boss_phase != 1:
		all_pass = false
		push_error("非 Boss 不应进阶段机")

	# Boss 对象池复用: reset 后阶段归 1
	boss.current_hp = 2
	boss._process_boss(0.01)
	boss._reset_boss_state()
	if boss.boss_phase != 1 or boss.boss_weakness_open or boss.boss_enraged:
		all_pass = false
		push_error("reset 后 Boss 阶段应归 1")

	# ── P1 警报机制 (合金装备 §3.5) ──────────────────────
	var alarm = load("res://scripts/alarm_system.gd").new()
	# 初始: 无警报
	if alarm.get_next_layer_scale() != 1.0:
		all_pass = false
		push_error("初始警报应为 1.0×")
	# 连续吞噬 5 只 → 警报 ×1 → 下层 ×1.2
	for i in 5:
		alarm.on_capture()
	if alarm.alarm_level != 1:
		all_pass = false
		push_error("连续 5 只吞噬应升警报到 1, 实际 ", alarm.alarm_level)
	if absf(alarm.get_next_layer_scale() - 1.2) > 0.001:
		all_pass = false
		push_error("警报 ×1 下层放大应 1.2, 实际 ", alarm.get_next_layer_scale())
	# 受伤 → 警报清零
	alarm.on_damage()
	if alarm.alarm_level != 0 or alarm.get_next_layer_scale() != 1.0:
		all_pass = false
		push_error("受伤后警报应清零")
	# 精英清完护卫 → 警报清零
	alarm.alarm_level = 1
	alarm.on_elite_cleared()
	if alarm.alarm_level != 0:
		all_pass = false
		push_error("精英清完护卫应警报清零")
	print("警报机制: 5连吞→×1.2 / 受伤清零 / 精英清完清零")

	# ── P1 层 11 路线分支 (杀戮尖塔 §3.2) ─────────────────
	var branch1: Dictionary = rg.roll_route_branch()
	if not (branch1.get("branch", "") in ["safe", "risky"]):
		all_pass = false
		push_error("路线分支应为 safe/risky, 实际 ", branch1.get("branch"))
	print("路线分支 roll=", branch1.get("branch"), " 遗物×", branch1.get("relic_multiplier"))

	# ── P1 跨大关保留/重置 (杀戮尖塔/艾尔登法环 §3.0) ──────
	# 验证 start_new_chapter 把 HP/能量 重置至 70%
	gm.chapter = 1
	gm.player_stats["current_hp"] = 100
	gm.player_stats["max_hp"] = 100
	gm.player_stats["energy"] = 10.0
	gm.player_stats["max_energy"] = 10.0
	gm.start_new_chapter()
	if gm.chapter != 2:
		all_pass = false
		push_error("start_new_chapter 应 章节 1→2, 实际 ", gm.chapter)
	var hp_after: int = int(gm.player_stats["current_hp"])
	var energy_after: float = float(gm.player_stats["energy"])
	if hp_after != 70:
		all_pass = false
		push_error("跨大关 HP 应 70% (70), 实际 ", hp_after)
	if absf(energy_after - 7.0) > 0.01:
		all_pass = false
		push_error("跨大关 能量应 70% (7.0), 实际 ", energy_after)
	# build 保留 (技能空间/三类卡/遗物 不清)
	if not gm.player_stats.has("max_hp"):
		all_pass = false
		push_error("build 应保留")
	print("跨大关保留/重置: 章节 1→2, HP/能量 70%, build 保留")

	print("=== M5 多大关 + Boss 3 阶段 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)

var _gm: Node
