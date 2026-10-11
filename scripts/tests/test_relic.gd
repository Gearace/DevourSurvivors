extends SceneTree
## test_relic.gd — headless 测试: v1.2 遗物 (道具类) 掉落 + buff 应用
## 运行: godot --headless -s res://scripts/tests/test_relic.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)
	var us = load("res://scripts/upgrade_system.gd").new()
	us.name = "UpgradeSystem"
	root.add_child(us)

	print("=== v1.2 遗物道具 测试 ===")
	var all_pass: bool = true

	var db = load("res://scripts/card_database.gd")
	var rs = load("res://scripts/relic_system.gd")

	# 测试 1: 遗物道具池 (5 档稀有度)
	var props: Array[Dictionary] = db.get_relic_props()
	print("遗物道具总数: ", props.size())
	if props.size() < 5:
		all_pass = false
		push_error("遗物道具池应 >=5")
	var rarity_common: Array[Dictionary] = db.get_relic_props_by_rarity("普通")
	print("普通档遗物: ", rarity_common.size())
	if rarity_common.size() < 1:
		all_pass = false
		push_error("普通档应有遗物")

	# 测试 2: 普通层无遗物 (node_type 非 1/5 返回空)
	var normal: Array[Dictionary] = rs.roll_relics(0)
	print("普通层遗物: ", normal.size(), " (期望 0)")
	if normal.size() != 0:
		all_pass = false
		push_error("普通层不应掉遗物")

	# 测试 3: 精英层 3 选 1
	var elite: Array[Dictionary] = rs.roll_relics(1)
	print("精英层遗物: ", elite.size(), " (期望 3)")
	if elite.size() != 3:
		all_pass = false
		push_error("精英层应 3 选 1")

	# 测试 4: Boss 层 3 个且第 1 个保底史诗以上
	var boss: Array[Dictionary] = rs.roll_relics(5)
	print("Boss层遗物: ", boss.size(), " (期望 3)")
	if boss.size() != 3:
		all_pass = false
		push_error("Boss 层应 3 选 1")
	else:
		var rank: Dictionary = rs.RARITY_RANK
		var first_rank: int = int(rank.get(boss[0].get("rarity", "普通"), 0))
		print("Boss 首个遗物稀有度: ", boss[0].get("rarity", "?"))
		if first_rank < 2:
			all_pass = false
			push_error("Boss 首个遗物应保底史诗(2)以上")

	# 测试 5: 应用 buff (血量+10% 开局回满)
	var before_hp: int = int(gm.player_stats.get("max_hp", 100))
	var blood: Dictionary = db.get_relic_props_by_rarity("普通")[0]
	rs.apply_buff(blood, gm)
	print("应用血誓: max_hp ", before_hp, " → ", gm.player_stats.get("max_hp", 0))
	var expect_hp: int = int(before_hp * 1.1)
	if absi(int(gm.player_stats.get("max_hp", 0)) - expect_hp) > 1:
		all_pass = false
		push_error("血量+10% 未生效")
	if gm.relic_buffs.size() != 1:
		all_pass = false
		push_error("遗物应记入 relic_buffs")

	# 测试 6: 威力 buff 汇总
	var buffed: float = rs.total_power_buff(gm.relic_buffs)
	print("遗物威力 buff 系数: ", buffed)
	if buffed < 1.0:
		all_pass = false
		push_error("威力 buff 系数应 >= 1.0")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)
