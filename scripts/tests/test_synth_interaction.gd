extends SceneTree
## test_synth_interaction.gd — headless 测试: v1.2 交互矩阵 + 技能合成
## 运行: godot --headless -s res://scripts/tests/test_synth_interaction.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	print("=== v1.2 交互矩阵/技能合成 测试 ===")
	var all_pass: bool = true

	var im = load("res://scripts/interaction_matrix.gd")

	# 测试 1: 矩阵取值 (金×风=平衡, 木×风=增幅, 火×火=增幅)
	var i1: Array = im.get_interactions("金", "风")
	var i2: Array = im.get_interactions("木", "风")
	print("金×风=", i1, " 木×风=", i2)
	if i1[0] != "平衡" or i2[0] != "增幅":
		all_pass = false
		push_error("矩阵取值错误")

	# 测试 2: 威力倍率
	var p_amp: float = im.get_power_multiplier("木", "风")     # 增幅 → 1.5
	var p_off: float = im.get_power_multiplier("金", "火")     # 抵消 → 0.3
	var p_bal: float = im.get_power_multiplier("金", "风")     # 平衡 → 1.0
	print("倍率: 增幅=", p_amp, " 抵消=", p_off, " 平衡=", p_bal)
	if absf(p_amp - 1.5) > 0.001 or absf(p_off - 0.3) > 0.001 or absf(p_bal - 1.0) > 0.001:
		all_pass = false
		push_error("威力倍率错误")

	# 测试 3: 特殊修正 (传导/庇护/同化/反噬)
	var r_conduct: float = im.get_range_bonus("金", "雷")     # 金×雷=传导 → 0.5
	var shield: bool = im.has_shield("木", "光")               # 木×光=增幅,庇护 → true
	var corro: bool = im.has_corrosion("木", "火")             # 木×火=增幅,同化 → true
	var backlash: bool = im.has_backlash("水", "光")           # 水×光=变异,反噬 → true
	print("传导=", r_conduct, " 庇护=", shield, " 同化=", corro, " 反噬=", backlash)
	if absf(r_conduct - 0.5) > 0.001 or not shield or not corro or not backlash:
		all_pass = false
		push_error("特殊修正错误")

	# 测试 4: 完整结算 (吞噬波=火元素 浸篆在 木 → 木×火=增幅1.5, 同化)
	var res: Dictionary = im.resolve(100.0, "木", "火", 1.0, 1.0)
	print("结算 木×火:", res)
	if absf(res["final_power"] - 150.0) > 0.001 or not res["corrosion_dot"]:
		all_pass = false
		push_error("结算威力/同化错误 (期望 100×1.5=150, 含同化)")

	# 测试 5: 技能合成 (21 种两两组合全在)
	var ss = load("res://scripts/skill_synth.gd")
	var count: int = 0
	for a in ss.ELEMENTS:
		for b in ss.ELEMENTS:
			if a == b:
				continue
			var ai: int = ss.ELEMENTS.find(a)
			var bi: int = ss.ELEMENTS.find(b)
			if ai > bi:  # 只计 i<j 的唯一无序对, 避免风+火/火+风重复
				continue
			var key: String = ss.combo_key(a, b)
			if not ss.COMPOUNDS.has(key):
				push_error("缺少复合材: ", key)
				all_pass = false
			else:
				count += 1
	print("复合材数量(唯一组合): ", count, " (期望 21)")
	if count != 21:
		all_pass = false
		push_error("唯一组合数应为 21")

	# 测试 6: 同名元素合成 → 高阶强化
	var a: Dictionary = {"id": "s1", "element": "火"}
	var b: Dictionary = {"id": "s2", "element": "火"}
	var out: Dictionary = ss.make_synth_skill(a, b)
	print("同名 火+火 →", out)
	if out.get("compound", "") != "同名强化" or absf(float(out.get("power_bonus", 0.0)) - 0.2) > 0.001:
		all_pass = false
		push_error("同名合成错误")

	# 测试 7: 异元素合成 → 复合材
	var c: Dictionary = {"id": "s3", "element": "风"}
	var d: Dictionary = {"id": "s4", "element": "火"}
	var out2: Dictionary = ss.make_synth_skill(c, d)
	print("风+火 →", out2)
	if out2.get("compound", "") != "燎原":
		all_pass = false
		push_error("风+火 应为 燎原")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	quit(0 if all_pass else 1)
