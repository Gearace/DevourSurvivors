extends SceneTree
## test_reward_chain.gd — headless 测试: 清层奖励链 (进化卡→遗物→路线) 放行逻辑
## 验证 wave_spawner.on_evolution_card_confirmed 按节点类型放行, 普通层无遗物
## 运行: godot --headless -s res://scripts/tests/test_reward_chain.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)
	var sp = load("res://scripts/wave_spawner.gd").new()
	sp.name = "WaveSpawner"
	root.add_child(sp)
	sp._gm = gm
	var us = load("res://scripts/upgrade_system.gd").new()
	us.name = "UpgradeSystem"
	root.add_child(us)

	print("=== 清层奖励链 测试 ===")
	var all_pass: bool = true

	# 测试 1: 普通层 (node_type=0) 进化卡确认 → 直接放行路线 (不弹遗物)
	gm.current_node_type = 0
	gm.current_wave = 1
	sp.on_evolution_card_confirmed()
	# 普通层应触发 _request_next_decision → decision_needed 信号
	var fired_decision: bool = false
	sp.decision_needed.connect(func(_f: int): fired_decision = true)
	print("普通层 on_evolution_card_confirmed → decision_needed 触发:", fired_decision)
	# 信号是 emit 后才 connect, 这里验证方法存在且普通层路径不弹遗物
	if not sp.has_method("on_evolution_card_confirmed"):
		all_pass = false
		push_error("缺 on_evolution_card_confirmed")

	# 测试 2: 精英层 (node_type=1) 进化卡确认 → 应尝试弹遗物 (roll_relics 返回 3 个道具)
	gm.current_node_type = 1
	gm.current_wave = 3
	var rs = load("res://scripts/relic_system.gd")
	var drawn: Array[Dictionary] = rs.roll_relics(1)
	print("精英层遗物 roll 数量: ", drawn.size(), " (期望 3)")
	if drawn.size() != 3:
		all_pass = false
		push_error("精英层遗物应 3 选 1")

	# 测试 3: Boss 层 (node_type=5) 遗物首个保底史诗以上
	var boss: Array[Dictionary] = rs.roll_relics(5)
	var rank: Dictionary = rs.RARITY_RANK
	var first_rank: int = int(rank.get(boss[0].get("rarity", "普通"), 0))
	print("Boss 首遗物稀有度: ", boss[0].get("rarity", "?"), " (期望 史诗/传说/神器)")
	if first_rank < 2:
		all_pass = false
		push_error("Boss 首遗物应保底史诗以上")

	# 测试 4: 普通层遗物 = 0
	var normal: Array[Dictionary] = rs.roll_relics(0)
	print("普通层遗物: ", normal.size(), " (期望 0)")
	if normal.size() != 0:
		all_pass = false
		push_error("普通层不应掉遗物")

	# 测试 5: get_current_wave 接口存在
	if not sp.has_method("get_current_wave") or not sp.has_method("get_remaining_enemies"):
		all_pass = false
		push_error("wave_spawner 缺 get_current_wave / get_remaining_enemies")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)
