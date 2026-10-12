extends SceneTree
## 探针: 清层判定根因 — 验证 start_node(战斗节点) → 5 只怪 → 全吞 → _check_wave_complete 触发
## 修复后: 清层不再要求生成队列排空 (队列+活跃 归零即清层)
## 运行: godot --headless -s res://scripts/tests/test_probe_clear_check.gd

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
	var up = load("res://scripts/upgrade_popup.gd").new()
	up.name = "UpgradePopup"
	root.add_child(up)

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

	for _i in range(5):
		await process_frame
	print("[PROBE] sp._pool=", sp._pool != null, " sp._gm=", sp._gm != null, " _is_generating=", sp._is_generating)

	# 模拟 start_node (战斗节点, 5 basic)
	var pack = {
		"floor": 1, "node_type": 0,
		"enemies": [ {"type": "basic", "count": 5} ]
	}
	sp.start_node(pack)
	print("[PROBE] start_node 后 _is_generating=", sp._is_generating, " spawn_total=", sp.get_wave_spawn_total())

	# 模拟 玩家 连续吞噬: 每 12 帧吞一只 已生成 的敌人, 直到本层全清
	var f3: int = 0
	while f3 < 360:
		for e in pool.get_active_enemies():
			pool.despawn(e)
		f3 += 12
		await process_frame
		if sp.get_remaining_enemies() <= 0:
			break

	# 清层后再等 20 帧让 _check_wave_complete 处理
	for _i in range(20):
		await process_frame

	# 断言: 清层判定链路通 — _is_generating 复位 + 4选1 弹窗弹出
	var up_probe: Node = main.get_node_or_null("UpgradePopup")
	if up_probe == null:
		up_probe = root.get_node_or_null("UpgradePopup")
	var popup_visible: bool = up_probe.visible if up_probe != null else false
	var gen_done: bool = (sp._is_generating == false)
	var passed: bool = popup_visible and gen_done
	print("[PROBE] 清层后 _is_generating=", sp._is_generating, " 4选1 弹窗 visible=", popup_visible)
	if passed:
		print("[PROBE] 结果: PASS — 清层判定链路通 (_check_wave_complete 触发 → 4选1 弹出)")
	else:
		print("[PROBE] 结果: FAIL — 清层判定断 (_is_generating=", sp._is_generating, " popup=", popup_visible, ")")
	quit(0 if passed else 1)
