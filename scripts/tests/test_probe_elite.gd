extends SceneTree
## 探针: 精英层逻辑 — 精英不能一口吞、要啃食、碰撞反噬掉血、吞下后 +5 收益 + 掉材质
## 运行: godot --headless -s res://scripts/tests/test_probe_elite.gd

func _inject_autoloads() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)
	var eb = load("res://scripts/event_bus.gd").new()
	eb.name = "EventBus"
	root.add_child(eb)
	var us = load("res://scripts/upgrade_system.gd").new()
	us.name = "UpgradeSystem"
	root.add_child(us)

func _initialize() -> void:
	_inject_autoloads()
	var main = Node2D.new()
	main.name = "MainGame"
	root.add_child(main)
	var pool = load("res://scripts/object_pool.gd").new()
	pool.name = "ObjectPool"
	main.add_child(pool)
	var sp = load("res://scripts/wave_spawner.gd").new()
	sp.name = "WaveSpawner"
	main.add_child(sp)

	# 不挂玩家节点 — 精英判定走 devour_table 纯数据校验, 无需实机 player
	for _i in range(5):
		await process_frame

	var gm = root.get_node("GameManager")
	var table = preload("res://scripts/devour_table.gd").new()
	var all_pass: bool = true

	# 断言 1: 精英体型 > 玩家(20px), 不能一口吞
	print("[ELITE] 精英 tearer 体型=45 vs 玩家 20 — 一口吞判定:", table.is_one_bite("elite_tearer"), "(期望 false)")
	if table.is_one_bite("elite_tearer"):
		all_pass = false
		print("[ELITE] FAIL: 精英应不能一口吞")

	# 断言 2: 精英需要啃食 N 秒
	var gnaw_sec: float = table.gnaw_seconds("elite_tearer")
	print("[ELITE] 精英啃食时长=", gnaw_sec, "秒 (期望 > 0)")
	if gnaw_sec <= 0.0:
		all_pass = false
		print("[ELITE] FAIL: 精英应有啃食时长")

	# 断言 3: 撞到比自己大的精英 → 反噬掉血
	var collision_dmg: float = table.get_collision_damage("elite_tearer", 20.0, 45.0)
	print("[ELITE] 碰撞反噬伤害=", collision_dmg, " (期望 > 0, 玩家 20 < 精英 45)")
	if collision_dmg <= 0.0:
		all_pass = false
		print("[ELITE] FAIL: 撞到更大精英应反噬掉血")

	# 断言 4: 吞下精英 → +5 收益
	var cap_val: float = table.get_energy_gain("elite_tearer")
	print("[ELITE] 精英能量收益=", cap_val, " (期望 5.0)")
	if cap_val != 5.0:
		all_pass = false
		print("[ELITE] FAIL: 精英收益应为 5")

	# 断言 5: 吞下精英 → 掉材质 (GameManager.drop_elemental_material)
	var mat_before: int = gm.get_material_count("水")
	gm.drop_elemental_material("elite_tearer")
	var mat_after_total: int = 0
	for m in ["金","木","水","火","土"]:
		mat_after_total += gm.get_material_count(m)
	print("[ELITE] 吞精英后材质总量=", mat_after_total, " (期望 >= 1, 精英 100% 掉 1~2)")
	if mat_after_total < 1:
		all_pass = false
		print("[ELITE] FAIL: 精英应 100% 掉材质")

	# 断言 6: 堡垒啃食无反噬 (GDD 5.8 铁壁堡垒: 啃食进度减半但无反噬)
	var fort_dmg: float = table.get_collision_damage("elite_fortress", 20.0, 50.0)
	print("[ELITE] 堡垒碰撞反噬=", fort_dmg, " (期望 0, 堡垒无反噬)")
	if fort_dmg != 0.0:
		all_pass = false
		print("[ELITE] FAIL: 堡垒应无反噬")

	print("=== 精英逻辑 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)
