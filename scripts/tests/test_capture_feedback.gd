extends SceneTree
## test_capture_feedback.gd — headless 测试: 吃怪 → 掉材质 → HUD 计数 反馈闭环
## 运行: godot --headless -s res://scripts/tests/test_capture_feedback.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	print("=== 吃怪反馈闭环 测试 ===")
	var all_pass: bool = true

	# 1. 普通怪 (basic) 不掉材质 (GDD: 0%)
	gm.drop_elemental_material("basic")
	gm.drop_elemental_material("swift")
	gm.drop_elemental_material("decoy")
	var normal_total: int = 0
	for m in gm.held_materials:
		normal_total += gm.get_material_count(m)
	print("普通怪掉落材质数: ", normal_total, " (期望 0)")
	if normal_total != 0:
		all_pass = false
		push_error("普通怪不应掉材质")

	# 2. 重装怪 30% 掉 (强制多试几次确保至少掉到 1)
	var dropped_heavy: int = 0
	for i in range(200):
		gm.held_materials.clear()
		gm.drop_elemental_material("heavy")
		for m in gm.held_materials:
			dropped_heavy += gm.get_material_count(m)
	print("200 次 heavy 掉落总次数: ", dropped_heavy, " (期望 ~60, 即 30%)")
	# 30% 容差: 落在 [30, 90] 区间视为正常
	if dropped_heavy < 30 or dropped_heavy > 90:
		all_pass = false
		push_error("heavy 掉落率偏离 30% 过多")

	# 3. 分裂怪 40% 掉
	gm.held_materials.clear()
	var dropped_split: int = 0
	for i in range(200):
		gm.held_materials.clear()
		gm.drop_elemental_material("split")
		for m in gm.held_materials:
			dropped_split += gm.get_material_count(m)
	print("200 次 split 掉落总次数: ", dropped_split, " (期望 ~80, 即 40%)")
	if dropped_split < 50 or dropped_split > 110:
		all_pass = false
		push_error("split 掉落率偏离 40% 过多")

	# 4. 精英/Boss 100% 掉 (必掉)
	gm.held_materials.clear()
	gm.drop_elemental_material("elite_tearer")
	var elite_total: int = 0
	for m in gm.held_materials:
		elite_total += gm.get_material_count(m)
	print("精英掉落材质数: ", elite_total, " (期望 1~2)")
	if elite_total < 1:
		all_pass = false
		push_error("精英应必掉材质")

	# 5. HUD 计数路径: get_material_count 读到刚掉的精英材质
	gm.held_materials.clear()
	gm.drop_elemental_material("boss_ch1")
	var boss_total: int = 0
	for m in gm.held_materials:
		boss_total += gm.get_material_count(m)
	print("Boss 掉落材质数: ", boss_total, " (期望 2~3)")
	if boss_total < 2:
		all_pass = false
		push_error("Boss 应掉 2~3 材质")

	# 6. 精英材质品质应为 蓝/紫 (tier 2/3)
	gm.held_materials.clear()
	gm.drop_elemental_material("elite_mirror")
	for m in gm.held_materials:
		var tiers: Array = []
		for t in gm.held_materials[m]:
			tiers.append(int(t))
		for t in tiers:
			if t < 2 or t > 3:
				all_pass = false
				push_error("精英材质应 蓝(2)/紫(3), 实际 ", t)
	print("精英材质品质: 蓝/紫 校验完成")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)
