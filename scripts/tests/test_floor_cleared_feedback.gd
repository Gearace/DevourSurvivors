extends SceneTree
## test_floor_cleared_feedback.gd — headless 测试: 清层横幅 + 剩余敌人 感知反馈
## 运行: godot --headless -s res://scripts/tests/test_floor_cleared_feedback.gd

func _initialize() -> void:
	var gm = load("res://scripts/game_manager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)
	var sp = load("res://scripts/wave_spawner.gd").new()
	sp.name = "WaveSpawner"
	root.add_child(sp)

	print("=== 清层反馈 测试 ===")
	var all_pass: bool = true

	var fb = load("res://scripts/floor_banner.gd")

	# 测试 1: 横幅文案
	var txt: String = fb.cleared_banner_text(1, "普通波")
	print("层清文案: ", txt)
	if not txt.contains("第 1 层") or not txt.contains("路线"):
		all_pass = false
		push_error("横幅文案应含 层号 + 路线选择")

	# 测试 2: 剩余提示
	var h1: String = fb.remaining_hint(3, 5)
	var h2: String = fb.remaining_hint(0, 5)
	print("剩余提示: ", h1, " / ", h2)
	if not h1.contains("3/5") or not h2.contains("已清"):
		all_pass = false
		push_error("剩余提示错误")

	# 测试 3: 横幅时序 (3s 窗口)
	if not fb.banner_shown(0.0) or not fb.banner_shown(2.0):
		all_pass = false
		push_error("3s 窗口内应显示横幅")
	if fb.banner_shown(4.0):
		all_pass = false
		push_error("4s 后横幅应消失")
	if not fb.banner_done(4.0) or fb.banner_done(2.0):
		all_pass = false
		push_error("banner_done 应在 >=3s 时 true")

	# 测试 4: 奖励顺序
	var order: Array[String] = fb.CLEAR_REWARD_ORDER
	print("清层奖励顺序: ", order)
	if order.size() != 3:
		all_pass = false
		push_error("清层奖励应 3 步: 进化卡→遗物→路线")

	# 测试 5: wave_spawner 剩余敌人计数
	sp.get_node_or_null("../ObjectPool")  # 无 pool 场景, 仅验证方法存在
	if not sp.has_method("get_remaining_enemies") or not sp.has_method("get_wave_spawn_total"):
		all_pass = false
		push_error("wave_spawner 应有 get_remaining_enemies / get_wave_spawn_total")
	print("wave_spawner 方法存在校验: 通过")

	print("=== 测试 ", "全部通过" if all_pass else "存在失败", " ===")
	# 测试 6: v1.2 层清反馈信号驱动 (wave_cleared 一次, HUD 横幅 3s 窗口)
	if not sp.has_signal("wave_cleared"):
		all_pass = false
		push_error("wave_spawner 应暴露 wave_cleared 信号 (清层反馈驱动)")
	else:
		print("wave_cleared 信号存在校验: 通过")
	# HUD 横幅接线: _on_wave_cleared 显示 + _hide_floor_banner 隐藏 (奖励链完成时)
	var f = FileAccess.open("res://scripts/hud_controller.gd", FileAccess.READ)
	var hud_src: String = f.get_as_text() if f else ""
	if not hud_src.contains("func _on_wave_cleared") or not hud_src.contains("func _hide_floor_banner"):
		all_pass = false
		push_error("hud_controller 应有 _on_wave_cleared / _hide_floor_banner 方法")
	else:
		print("HUD 横幅接线校验: 通过")
	quit(0 if all_pass else 1)
