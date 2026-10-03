extends CanvasLayer
## RunOver — 死亡结算 / 章节推进 UI (GDD 7.7 / 5.10)
## 职责：
##   · 监听 GameManager.player_died → 显示 run over 面板（得分/最高层/永恒之环保留 1 卡）
##   · 重试：清空本局、roll 新路线、从第 1 层重新开始
##   · 章节推进（通关 13 层 Boss 后）：保留 build，HP/能量回复至 70%，进下一章
## 依赖：GameManager（状态/分数/牌组）、RouteGenerator（roll 路线）、WaveSpawner（start_node）

var _gm: Node
var _spawner: Node
var _route_generator: Node

# UI
var panel: Panel
var overlay: ColorRect
var title_label: Label
var stat_label: Label
var ring_label: Label
var retry_btn: Button
var next_btn: Button

var is_run_over := false

func _ready() -> void:
	layer = 110  # 高于 RouteUI(90) 与 UpgradePopup(100)
	_gm = get_node_or_null("/root/GameManager")
	_build_ui()
	visible = false
	if _gm and _gm.has_signal("player_died"):
		_gm.player_died.connect(_on_player_died)
	if _gm and _gm.has_signal("game_over"):
		_gm.game_over.connect(_on_game_over)
	print("[RunOver] 初始化完成")

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2
	overlay.color = Color(0, 0, 0, 0.85)
	add_child(overlay)

	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = 2
	panel.grow_vertical = 2
	panel.custom_minimum_size = Vector2(600, 520)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -260
	panel.offset_bottom = 260
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.07, 0.12, 1.0)
	ps.corner_radius_top_left = 10
	ps.corner_radius_top_right = 10
	ps.corner_radius_bottom_left = 10
	ps.corner_radius_bottom_right = 10
	ps.border_width_left = 2
	ps.border_width_top = 2
	ps.border_width_right = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.9, 0.3, 0.3, 1.0)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(40, 40)
	vbox.size = Vector2(520, 440)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.text = "你被吞噬了"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.self_modulate = Color(1.0, 0.4, 0.4, 1.0)
	vbox.add_child(title_label)

	stat_label = Label.new()
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 18)
	stat_label.self_modulate = Color(0.9, 0.9, 0.95, 1.0)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(stat_label)

	ring_label = Label.new()
	ring_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_label.add_theme_font_size_override("font_size", 14)
	ring_label.self_modulate = Color(0.5, 0.85, 1.0, 1.0)
	ring_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ring_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	retry_btn = Button.new()
	retry_btn.text = "重新挑战"
	retry_btn.custom_minimum_size = Vector2(200, 56)
	retry_btn.add_theme_font_size_override("font_size", 18)
	btn_row.add_child(retry_btn)
	retry_btn.pressed.connect(_on_retry)

	next_btn = Button.new()
	next_btn.text = "进入下一章"
	next_btn.custom_minimum_size = Vector2(200, 56)
	next_btn.add_theme_font_size_override("font_size", 18)
	btn_row.add_child(next_btn)
	next_btn.pressed.connect(_on_next_chapter)

## 玩家死亡 → 显示 run over
func _on_player_died() -> void:
	is_run_over = true
	_populate_stats(false)
	visible = true
	if _gm:
		_gm.set_state(GameManager.GameState.GAME_OVER)
	print("[RunOver] 玩家阵亡，显示结算")

## game_over(score)（若走该信号）
func _on_game_over(score: int) -> void:
	if is_run_over:
		return
	is_run_over = true
	_gm.player_stats["score"] = score
	_populate_stats(false)
	visible = true
	if _gm:
		_gm.set_state(GameManager.GameState.GAME_OVER)

## 填充统计 + 永恒之环信息
func _populate_stats(cleared_chapter: bool) -> void:
	if _gm == null:
		return
	var score: int = int(_gm.player_stats.get("score", 0))
	var floor: int = _gm.current_floor
	var level: int = int(_gm.player_stats.get("level", 1))
	var captured: int = int(_gm.player_stats.get("total_captured", 0))
	var lines := []
	lines.append("分数  %d" % score)
	lines.append("到达  第 %d 层" % floor)
	lines.append("等级  Lv.%d   吞噬  %d" % [level, captured])
	stat_label.text = "\n".join(lines)
	# 永恒之环：死亡时若持有该遗物，保留 1 张卡进下一局
	var has_ring: bool = false
	if _gm.has("relics"):
		has_ring = _gm.relics.has("eternal_ring")
	var ring_txt := ""
	if has_ring:
		# 保留牌组最后一张（简化；正式随机 1 张）
		var deck = _gm.player_deck
		if deck.size() > 0:
			var keep = deck[deck.size() - 1]
			var card = CardDatabase.find_card_by_id(keep)
			ring_txt = "永恒之环 · 保留 [ %s ] 进入下一局" % card.get("name", keep)
		else:
			ring_txt = "永恒之环 · 保留 1 张卡进入下一局"
	else:
		ring_txt = "（未持有 永恒之环）"
	if cleared_chapter:
		ring_label.text = "章节通关！保留 build，HP/能量回复 70% 进入下一章\n" + ring_txt
	else:
		ring_label.text = ring_txt

## 重新挑战：清空本局、roll 新路线、从第 1 层开始
func _on_retry() -> void:
	_reset_for_new_run()
	visible = false
	is_run_over = false
	print("[RunOver] 重新开始")

## 进入下一章：保留 build，HP/能量回复 70%，章节号 +1
func _on_next_chapter() -> void:
	_advance_chapter()
	visible = false
	is_run_over = false
	print("[RunOver] 进入下一章")

## 重置本局（死亡重试）
func _reset_for_new_run() -> void:
	_clear_field()
	if _gm:
		_gm.reset_run()
	if _route_generator == null:
		_route_generator = get_node_or_null("/root/MainGame/RouteGenerator")
	if _spawner == null:
		_spawner = get_node_or_null("/root/MainGame/WaveSpawner")
	if _route_generator:
		_route_generator.generate_run()
	# 第 1 层固定普通波
	if _route_generator and _spawner:
		var p1 = _route_generator.pick_option(1, 0)
		_spawner.start_node(p1)
	# 升级系统重置
	var us = get_node_or_null("/root/UpgradeSystem")
	if us and us.has_method("reset_for_new_run"):
		us.reset_for_new_run()
	if _gm:
		_gm.set_state(GameManager.GameState.PLAYING)

## 章节推进（通关后）
func _advance_chapter() -> void:
	if _gm == null:
		return
	# 保留 build（卡牌不重置），HP/能量回复至 70%
	var max_hp: int = _gm.player_stats.get("max_hp", 100)
	_gm.player_stats["current_hp"] = int(max_hp * 0.7)
	_gm.player_stats["energy"] = float(_gm.player_stats.get("max_energy", 10.0)) * 0.7
	_clear_field()
	# roll 新章节路线（章节号由 route_generator / gm 递增；此处重置到第 1 层）
	if _gm.has_method("start_new_chapter"):
		_gm.start_new_chapter()
		# 重置楼层/波次/节点类型，保留章节号与 build
		_gm.current_floor = 1
		_gm.current_node_type = 0
		_gm.current_wave = 1
		_gm.enemies_spawned_this_wave = 0
		_gm.enemies_remaining_this_wave = 0
		# 章节间敌人速度/属性递增（GDD 7.5）：每章 +20%
		_gm.difficulty_multiplier = 1.0 + (int(_gm.chapter) - 1) * 0.2
	if _route_generator:
		_route_generator.generate_run()
	if _route_generator and _spawner:
		var p1 = _route_generator.pick_option(1, 0)
		_spawner.start_node(p1)
	if _gm:
		_gm.set_state(GameManager.GameState.PLAYING)

## 清场（清空敌人 + 重置生成器）
func _clear_field() -> void:
	var pool = get_node_or_null("/root/MainGame/ObjectPool")
	if pool and pool.has_method("despawn_all"):
		pool.despawn_all()
	if _spawner and _spawner.has_method("clear_all"):
		_spawner.clear_all()

## 外部绑定（main_game 注入）
func bind(spawner: Node, route_generator: Node) -> void:
	_spawner = spawner
	_route_generator = route_generator
