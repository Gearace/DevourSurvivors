extends SceneTree
## test_material_drop.gd — headless 测试：材质掉落 + 品阶结构
## 运行: godot --headless -s res://scripts/tests/test_material_drop.gd

func _initialize() -> void:
	# 手动挂载 autoloads (与 project.godot [autoload] 一致)
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
	var am = load("res://scripts/audio_mgr.gd").new()
	am.name = "AudioMgr"
	root.add_child(am)

	print("=== 材质掉落测试 ===")

	# 测试 1: 掉落材质
	gm.drop_elemental_material("heavy")
	gm.drop_elemental_material("heavy")
	gm.drop_elemental_material("elite_tearer")
	gm.drop_elemental_material("boss_ch1")

	print("持有材质结构: ", gm.held_materials)

	# 验证 held_materials 是 { material: { tier: count } }
	var ok: bool = true
	for mat in gm.held_materials:
		var tier_map = gm.held_materials[mat]
		if typeof(tier_map) != TYPE_DICTIONARY:
			push_error("材质 ", mat, " 的 tier_map 不是 Dictionary")
			ok = false
		else:
			for tier in tier_map:
				if int(tier) < 0 or int(tier) > 5:
					push_error("材质 ", mat, " 的品阶 ", tier, " 越界")
					ok = false
	print("结构验证: ", "通过" if ok else "失败")

	# 测试 2: 品阶计数
	var total_mat_count = 0
	for mat in gm.held_materials:
		total_mat_count += gm.get_material_count(mat)
	print("材质总数: ", total_mat_count)

	# 测试 3: 品阶获取
	for mat in gm.held_materials:
		var max_t = gm.get_material_max_tier(mat)
		print("  ", mat, " 最高品阶: ", max_t, " (", gm.MATERIAL_TIER_NAMES.get(max_t, "?"), ")")

	# 测试 4: 消耗
	var any_mat: String = ""
	if not gm.held_materials.is_empty():
		any_mat = gm.held_materials.keys()[0]
	if any_mat != "":
		var before: int = gm.get_material_count(any_mat)
		var spent: bool = gm.spend_material(any_mat, 1)
		var after: int = gm.get_material_count(any_mat)
		print("消耗测试: ", any_mat, " 前=", before, " 后=", after, " 成功=", spent)

	# 测试 5: 技能元素 roll
	var sd = load("res://scripts/skill_data.gd")
	var rolled_el = sd.roll_element()
	print("技能元素 roll: ", rolled_el, " (应在 0-6)")

	print("=== 材质掉落测试完成 ===")
	quit(0)
