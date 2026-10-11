extends SceneTree
## test_inscription_material.gd — headless 测试：v1.2 浸篆/三类卡 + 材质升级/熔炼 + 变异体型
## 运行: godot --headless -s res://scripts/tests/test_inscription_material.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)
	var eb = load("res://scripts/event_bus.gd").new()
	eb.name = "EventBus"
	root.add_child(eb)

	print("=== v1.2 浸篆/材质/变异 测试 ===")
	var all_pass: bool = true

	# 测试 1: 材质升级成功率 (白→绿 90% ... 橙→红 50%)
	var ms = load("res://scripts/material_system.gd")
	var expected: Dictionary = { 1: 0.9, 2: 0.8, 3: 0.7, 4: 0.6, 5: 0.5 }
	for t in range(1, 6):
		var c: float = ms.upgrade_success_chance(t)
		if absf(c - expected[t]) > 0.001:
			all_pass = false
			push_error("升级成功率 target=", t, " 期望=", expected[t], " 实际=", c)
	print("升级成功率表: 通过" if all_pass else "失败")

	# 测试 2: 升级成功/失败/大成功/暴击
	var r_fail: Dictionary = ms.attempt_upgrade(1, func() -> float: return 0.999)
	print("升级失败(退回低档): success=", r_fail["success"], " new_tier=", r_fail["new_tier"])
	if r_fail["success"] or r_fail["new_tier"] != 0:
		all_pass = false
		push_error("失败应退回低一档(白=0)")
	var always_succ = func() -> float: return 0.0  # < 成功率 → 成功, 非大成功非暴击
	# 全部返回 0.0: roll=0.0<成功率→成功; great_roll=0.0<0.05→大成功跳一档 1→3
	var r_ok: Dictionary = ms.attempt_upgrade(1, func() -> float: return 0.0)
	print("升级成功: success=", r_ok["success"], " new_tier=", r_ok["new_tier"], " great=", r_ok["great"])
	if not r_ok["success"] or r_ok["new_tier"] != 3 or not r_ok["great"]:
		all_pass = false
		push_error("全 0.0 应成功+大成功跳档 1→3")

	# 测试 3: 熔炼双属性 + 背板占比 + 回归单一
	var sm: Dictionary = ms.smelt("金", "水", 3.0, 1.0)
	print("熔炼 金3:水1 →", sm)
	# 熔炼产物为双属性 (背板占比); 回归单一在「下一次升级」时判定, 非熔炼本身
	if sm["is_single"] != false or sm["dominant"] != "金":
		all_pass = false
		push_error("金3:水1 应双属性, 主属性=金, 占比 0.75")
	var sm2: Dictionary = ms.smelt("金", "水", 1.0, 1.0)
	print("熔炼 金:水 1:1 →", sm2)
	if sm2["is_single"] != false or absf(sm2["ratio"]["金"] - 0.5) > 0.001:
		all_pass = false
		push_error("1:1 应为双属性, 占比 0.5")

	# 测试 4: 浸篆 有效期 + 卡类型
	var ins = load("res://scripts/inscription_system.gd")
	var d1: int = ins.calc_duration(0, 1)   # 白 1 个 = 1 局
	var d2: int = ins.calc_duration(0, 2)   # 白 2 个 = 2 局
	var d3: int = ins.calc_duration(5, 1)   # 红 = 永久
	print("有效期: 白×1=", d1, " 白×2=", d2, " 红×1=", d3)
	if d1 != 1 or d2 != 2 or d3 != -1:
		all_pass = false
		push_error("有效期计算错误")
	var ct: String = ins.card_type_for_material("金")
	print("金材质 → 卡类型:", ct)
	if ct != "进化卡":
		all_pass = false
		push_error("金应→进化卡")

	# 测试 5: 浸篆生成三类卡
	var card: Dictionary = ins.inscribe("swallow_wave", "吞噬波", "木", 3, 1)
	print("浸篆产物:", card)
	if card.get("type", "") != "变异卡" or int(card.get("duration", 0)) != 4:
		all_pass = false
		push_error("木材质应→变异卡, 紫品阶=4局")

	# 测试 6: GameManager 变异体型驱动
	gm.inscribed_cards.append({"id": "t_mut", "type": "变异卡", "skill_id": "t_skill_x", "duration": 1, "elapsed": 0})
	gm.mutation_card_count += 1
	gm.sync_body_on_mutation()
	var table = load("res://scripts/devour_table.gd").new()
	var expect_r: float = table.body_radius_for_mutation(1)
	if absf(gm.player_stats["capture_range"] - (expect_r + 10.0)) > 0.001:
		all_pass = false
		push_error("变异卡应驱动 capture_range")
	print("变异体型: capture_range=", gm.player_stats["capture_range"], " (期望=", expect_r + 10.0, ")")

	# 测试 7: 浸篆卡到期 → 技能放回技能空间, 材质消耗, 变异卡-1
	gm.tick_inscribed_cards()
	print("到期后: inscribed=", gm.inscribed_cards.size(), " 变异卡=", gm.mutation_card_count, " 技能空间=", gm.skill_space)
	if gm.inscribed_cards.size() != 0 or gm.mutation_card_count != 0 or gm.skill_space.size() != 1:
		all_pass = false
		push_error("到期应清空浸篆/变异-1/技能放回空间")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)



