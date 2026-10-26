extends CanvasLayer
## RouteUI — 路线「决策时刻」控制器 (GDD 7.6 / 5.3)
## 职责：层完成后暂停游戏，显示下一层 3 张候选节点卡（3 选 1），
## 玩家点选后把选择交给 RouteGenerator.pick_option → wave_spawner.start_node。
## 营地/商店/事件节点内的 2-3 选 1 复用同款卡片横排。

signal node_chosen(pack: Dictionary)

var _gm: Node
var _rg: Node          # RouteGenerator
var _spawner: Node    # WaveSpawner
# P1: 营地场景底图
var _camp_scene: TextureRect

# UI
var overlay: ColorRect
var panel: Panel
var title_label: Label
var card_row: HBoxContainer
var cards: Array = []   # 当前候选卡数据
var picking_floor: int = -1

# 节点卡面展示映射 (node_type → 名称/图标/难度系数/副标题)
# v1.2 P0: icon 由 emoji 替换为 64x64 节点图标贴图 (assets/ui/nodes/ui_node_*.png)
const NODE_DISPLAY: Dictionary = {
	0: {"name": "普通波", "icon": "ui_node_normal", "factor": "×1.0", "sub": "标准敌人编队"},
	1: {"name": "精英",   "icon": "ui_node_elite",  "factor": "×1.6", "sub": "必掉 遗物/传说"},
	2: {"name": "营地",   "icon": "ui_node_camp",   "factor": "×0.3", "sub": "三选一休整"},
	3: {"name": "商店",   "icon": "ui_node_shop",   "factor": "×0.5", "sub": "花分数买卡"},
	4: {"name": "事件",   "icon": "ui_node_event",  "factor": "×1.2", "sub": "随机剧情二选一"},
	5: {"name": "章节Boss", "icon": "ui_node_boss", "factor": "×2.0", "sub": "通关节点"},
}

func _ready() -> void:
	layer = 90  # 低于 UpgradePopup(100)，高于游戏层
	_gm = get_node_or_null("/root/GameManager")
	_build_ui()
	visible = false
	print("[RouteUI] 初始化完成")

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)

	# P1: 营地场景底图 — 进营地节点(2)时铺在 overlay 上, 给安全屋氛围
	_camp_scene = TextureRect.new()
	_camp_scene.name = "CampScene"
	if ResourceLoader.exists("res://assets/ui/camp/ui_camp_scene.png"):
		_camp_scene.texture = load("res://assets/ui/camp/ui_camp_scene.png")
	_camp_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camp_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_camp_scene.anchor_left = 0.5
	_camp_scene.anchor_right = 0.5
	_camp_scene.anchor_top = 0.5
	_camp_scene.anchor_bottom = 0.5
	_camp_scene.grow_horizontal = 2
	_camp_scene.grow_vertical = 2
	_camp_scene.custom_minimum_size = Vector2(720, 400)
	_camp_scene.position = Vector2(-360, -360)
	_camp_scene.modulate = Color(1, 1, 1, 0.35)
	_camp_scene.visible = false
	overlay.add_child(_camp_scene)

	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = 2
	panel.grow_vertical = 2
	panel.custom_minimum_size = Vector2(680, 560)
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -280
	panel.offset_bottom = 280
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.14, 1.0)
	ps.corner_radius_top_left = 8
	ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8
	ps.corner_radius_bottom_right = 8
	ps.border_width_left = 2
	ps.border_width_top = 2
	ps.border_width_right = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.35, 0.4, 0.6, 1.0)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.position = Vector2(0, 28)
	title_label.size = Vector2(680, 40)
	title_label.text = "选择路线"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.self_modulate = Color(1, 0.9, 0.5, 1.0)
	panel.add_child(title_label)

	var sub = Label.new()
	sub.name = "SubLabel"
	sub.position = Vector2(0, 74)
	sub.size = Vector2(680, 28)
	sub.text = ""
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.self_modulate = Color(0.75, 0.75, 0.8, 1.0)
	panel.add_child(sub)

	card_row = HBoxContainer.new()
	card_row.name = "CardRow"
	card_row.position = Vector2(60, 130)
	card_row.size = Vector2(560, 300)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 24)
	panel.add_child(card_row)

	var hint = Label.new()
	hint.name = "HintLabel"
	hint.position = Vector2(0, 470)
	hint.size = Vector2(680, 24)
	hint.text = "点选任意一张进入该节点"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.self_modulate = Color(0.6, 0.65, 0.75, 1.0)
	panel.add_child(hint)

## 显示「决策时刻」：下一层 3 选 1
## options: Array[int] 节点类型；floor: 下一层号
func show_decision(floor: int, options: Array) -> void:
	picking_floor = floor
	# P1: 营地场景底图 — 仅当候选里有营地节点(2)时显示
	_set_camp_scene_visible(options.has(2))
	var rg = _get_route_generator()
	# 副标题：预览后 1-2 层（路线 C）
	var sub = get_node_or_null("SubLabel")
	if sub:
		sub.text = _preview_next(rg, floor)
	title_label.text = "层 %d — 选择路线" % floor
	# v1.2: 路线 3选1 显示时隐藏残留层清横幅, 避免遮挡候选卡 (GDD 七)
	var hud = get_node_or_null("../HUD")
	if hud and hud.has_method("_hide_floor_banner"):
		hud._hide_floor_banner()
	_build_cards(options)
	visible = true
	# 暂停游戏
	if _gm:
		_gm.set_state(GameManager.GameState.PAUSED)
	print("[RouteUI] 显示层 %d 决策，候选 %d 项" % [floor, options.size()])

## 玩家点选第 idx 张候选卡
func on_card_selected(idx: int) -> void:
	var options = _get_current_options()
	if idx < 0 or idx >= options.size():
		return
	var rg = _get_route_generator()
	if rg == null:
		return
	var pack = rg.pick_option(picking_floor, idx)
	if pack.is_empty():
		return
	# 隐藏 UI，恢复游戏
	_animate_out()
	node_chosen.emit(pack)
	# 交给 spawner 启动该节点
	var sp = _get_spawner()
	if sp and sp.has_method("start_node"):
		sp.start_node(pack)

## 构建 3 张候选卡
func _build_cards(options: Array) -> void:
	for c in card_row.get_children():
		card_row.remove_child(c)
		c.queue_free()
	cards.clear()
	for i in options.size():
		var nt: int = options[i]
		var disp = NODE_DISPLAY.get(nt, {"name": "?", "icon": "?", "factor": "", "sub": ""})
		var card_panel = PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(160, 260)
		var style = StyleBoxFlat.new()
		style.bg_color = _node_bg(nt)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = _node_border(nt)
		card_panel.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 10)
		card_panel.add_child(vbox)

		var icon_name: String = disp.get("icon", "")
		var icon_path := "res://assets/ui/nodes/" + icon_name + ".png"
		var icon_rect = TextureRect.new()
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
			icon_rect.custom_minimum_size = Vector2(64, 64)
		else:
			var fallback := Image.new()
			fallback.create_empty(1, 1, false, Image.FORMAT_RGBA8)
			fallback.fill(Color(0.5, 0.5, 0.5, 1.0))
			icon_rect.texture = ImageTexture.create_from_image(fallback)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon_rect)

		var nm = Label.new()
		nm.text = disp.get("name", "?")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 20)
		nm.self_modulate = Color(1, 1, 1, 1.0)
		vbox.add_child(nm)

		var fac = Label.new()
		fac.text = disp.get("factor", "")
		fac.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fac.add_theme_font_size_override("font_size", 14)
		fac.self_modulate = _node_border(nt)
		vbox.add_child(fac)

		var s2 = Label.new()
		s2.text = disp.get("sub", "")
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.add_theme_font_size_override("font_size", 12)
		s2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s2.self_modulate = Color(0.75, 0.75, 0.8, 1.0)
		vbox.add_child(s2)

		# 点击
		card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		card_panel.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == 1:
				on_card_selected(i)
		)
		card_row.add_child(card_panel)
		cards.push_back(nt)

## 预览后 1-2 层（路线 C）
## P1: 营地场景底图显隐 (候选含营地节点时铺 35% 透明度底图)
func _set_camp_scene_visible(show: bool) -> void:
	if _camp_scene and is_instance_valid(_camp_scene):
		_camp_scene.visible = show

func _preview_next(rg, cur_floor: int) -> String:
	if rg == null or not rg.has_method("get_run_route"):
		return ""
	var route = rg.get_run_route()
	var txt := ""
	var shown := 0
	for rec in route:
		if rec.floor > cur_floor and shown < 2:
			var t = rec.options[0] if rec.options.size() > 0 else 0
			var nm = NODE_DISPLAY.get(t, {}).get("name", "?")
			txt += ("  层%d:%s" % [rec.floor, nm])
			shown += 1
			if txt.length() > 0 and shown < 2:
				txt += "   "
	return ("后续预览 →" + txt) if txt != "" else ""

func _get_current_options() -> Array:
	var rg = _get_route_generator()
	if rg and rg.has_method("get_run_route"):
		for rec in rg.get_run_route():
			if rec.floor == picking_floor:
				return rec.options
	return []

func _get_route_generator() -> Node:
	if _rg != null and is_instance_valid(_rg):
		return _rg
	_rg = get_node_or_null("/root/MainGame/RouteGenerator")
	if _rg == null:
		_rg = get_node_or_null("RouteGenerator")
	return _rg

func _get_spawner() -> Node:
	if _spawner != null and is_instance_valid(_spawner):
		return _spawner
	_spawner = get_node_or_null("/root/MainGame/WaveSpawner")
	if _spawner == null:
		_spawner = get_node_or_null("../WaveSpawner")
	return _spawner

func _node_bg(nt: int) -> Color:
	match nt:
		0: return Color(0.16, 0.24, 0.18, 1.0)
		1: return Color(0.30, 0.12, 0.12, 1.0)
		2: return Color(0.12, 0.22, 0.30, 1.0)
		3: return Color(0.28, 0.22, 0.10, 1.0)
		4: return Color(0.22, 0.16, 0.30, 1.0)
		5: return Color(0.32, 0.26, 0.06, 1.0)
	return Color(0.15, 0.15, 0.2, 1.0)

func _node_border(nt: int) -> Color:
	match nt:
		0: return Color(0.4, 0.8, 0.4, 1.0)
		1: return Color(0.95, 0.35, 0.35, 1.0)
		2: return Color(0.4, 0.7, 0.95, 1.0)
		3: return Color(0.95, 0.75, 0.35, 1.0)
		4: return Color(0.75, 0.5, 0.95, 1.0)
		5: return Color(1.0, 0.85, 0.2, 1.0)
	return Color(0.6, 0.6, 0.6, 1.0)

func _animate_out() -> void:
	visible = false
	if _gm:
		_gm.set_state(GameManager.GameState.PLAYING)

## 外部绑定（main_game 注入）
func bind(spawner: Node, route_generator: Node) -> void:
	_spawner = spawner
	_rg = route_generator
