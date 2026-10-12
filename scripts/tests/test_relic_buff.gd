extends SceneTree
## test_relic_buff.gd — headless 测试: 遗物数值 buff 接入技能威力结算 (GDD 六)
## 验证 game_manager.get_relic_* 数据层 + relic_system 结算; skill_system 经主场景回归验证
## 运行: godot --headless -s res://scripts/tests/test_relic_buff.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	print("=== 遗物 buff → 技能威力 测试 ===")
	var all_pass: bool = true

	var db = load("res://scripts/card_database.gd")
	var rs = load("res://scripts/relic_system.gd")

	# 测试 1: 无遗物时, 威力倍数 = 1.0
	var no_buff: float = gm.get_relic_power_bonus()
	print("无遗物威力倍数: ", no_buff, " (期望 1.0)")
	if no_buff < 1.0 or no_buff > 1.0:
		all_pass = false
		push_error("无遗物威力应 = 1.0")

	# 测试 2: 拾取 雷引 (史诗, 雷/金系×1.5) → 威力倍数应 >= 1.5
	var thunder: Array[Dictionary] = db.get_relic_props_by_rarity("史诗")
	var pick: Dictionary = {}
	for p in thunder:
		if p.get("id", "") == "prop_thunder":
			pick = p
			break
	if pick.is_empty():
		all_pass = false
		push_error("找不到 雷引 遗物")
	else:
		rs.apply_buff(pick, gm)
		var buffed: float = gm.get_relic_power_bonus()
		print("拾取雷引后威力倍数: ", buffed, " (期望 >= 1.5)")
		if buffed < 1.5:
			all_pass = false
			push_error("雷引应提供 x1.5 威力")
		# 无冷却 buff 仍应为 false (雷引不是神器)
		if gm.get_relic_no_cooldown():
			all_pass = false
			push_error("雷引不应提供无冷却")

	# 测试 3: 神器 虚空之眼 → 无冷却判定 true
	var void_eye: Array[Dictionary] = db.get_relic_props_by_rarity("神器")
	var ve: Dictionary = {}
	for p in void_eye:
		if p.get("id", "") == "prop_void_eye":
			ve = p
			break
	if ve.is_empty():
		all_pass = false
		push_error("找不到 虚空之眼 遗物")
	else:
		rs.apply_buff(ve, gm)
		var no_cd: bool = gm.get_relic_no_cooldown()
		print("虚空之眼 无冷却判定: ", no_cd, " (期望 true)")
		if not no_cd:
			all_pass = false
			push_error("虚空之眼 应判定无冷却")

	# 测试 4: 能量回速 buff (能量狂澜 史诗 +50%)
	var ef: Array[Dictionary] = db.get_relic_props_by_rarity("史诗")
	for p in ef:
		if p.get("id", "") == "prop_energy_fever":
			rs.apply_buff(p, gm)
			break
	var regen: float = gm.get_relic_energy_regen_bonus()
	print("能量回速 buff: ", regen, " (期望 0.5)")
	if absf(regen - 0.5) > 0.001:
		all_pass = false
		push_error("能量狂澜应 +50% 能量回速")

	# 测试 5: 血量 buff (血誓 普通 +10% 开局回满)
	var blood: Array[Dictionary] = db.get_relic_props_by_rarity("普通")
	var bpick: Dictionary = {}
	for p in blood:
		if p.get("id", "") == "prop_blood_oom":
			bpick = p
			break
	if bpick.is_empty():
		all_pass = false
		push_error("找不到 血誓 遗物")
	else:
		var before_hp: int = int(gm.player_stats.get("max_hp", 100))
		rs.apply_buff(bpick, gm)
		var after_hp: int = int(gm.player_stats.get("max_hp", 0))
		print("血誓 max_hp ", before_hp, " → ", after_hp, " (期望 +10%)")
		var expect: int = int(before_hp * 1.1)
		if absi(after_hp - expect) > 1:
			all_pass = false
			push_error("血誓应 +10% 血量")
		if gm.player_stats.get("current_hp", 0) != gm.player_stats.get("max_hp", 0):
			all_pass = false
			push_error("血誓开局应回满血")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)
