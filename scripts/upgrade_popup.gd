extends CanvasLayer
## upgrade_popup.gd
## 升级弹窗控制器 — 作为 CanvasLayer (Layer 100) 悬浮于视口顶端，不受相机缩放和位移影响

signal card_confirmed(card: Dictionary)

var panel: Control
var current_mode: String = "upgrade"  # v1.2: "upgrade"=进化卡 | "relic"=遗物
signal all_rewards_done  # v1.2: 4选1 + 遗物3选1 全部完成, 放行到路线 3选1
var card_grid: GridContainer
var confirm_btn: Button
var title_label: Label
var overlay: ColorRect

var current_cards: Array[Dictionary] = []
var selected_card_idx: int = -1

var rarity_colors: Dictionary = {
	"Common": Color(0.6, 0.8, 0.6, 1.0),
	"Uncommon": Color(0.4, 0.6, 1.0, 1.0),
	"Legendary": Color(1.0, 0.7, 0.2, 1.0),
	"Relic": Color(1.0, 0.3, 1.0, 1.0),
}

func _ready() -> void:
	layer = 100 # 确保处于 UI 最上层
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Overlay (全屏遮罩)
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2
	overlay.color = Color(0, 0, 0, 0.7)
	add_child(overlay)
	
	# Panel (主面板 - 居中显示 720x800)
	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = 2
	panel.grow_vertical = 2
	panel.custom_minimum_size = Vector2(720, 800)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -400
	panel.offset_bottom = 400
	
	var panel_style = StyleBoxTexture.new()
	var tex = load("res://assets/ui/panels/ui_upgrade_panel.png")
	if tex:
		panel_style.texture = tex
		panel_style.texture_margin_left = 20
		panel_style.texture_margin_right = 20
		panel_style.texture_margin_top = 20
		panel_style.texture_margin_bottom = 20
		panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(panel)
	
	# VBox (垂直布局，填满 panel 并预留内边距)
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 40
	vbox.offset_top = 40
	vbox.offset_right = -40
	vbox.offset_bottom = -40
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.custom_minimum_size = Vector2(0, 50)
	title_label.text = "升级！选择卡牌"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.self_modulate = Color(1, 0.85, 0.3, 1)
	vbox.add_child(title_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Card Grid (居中对齐)
	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var ui_theme = Theme.new()
	ui_theme.set_constant("h_separation", "GridContainer", 20)
	ui_theme.set_constant("v_separation", "GridContainer", 20)
	card_grid.theme = ui_theme
	vbox.add_child(card_grid)
	
	# Confirm Button
	confirm_btn = Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.custom_minimum_size = Vector2(240, 55)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.text = "确认选择"
	confirm_btn.disabled = true
	
	var btn_style = StyleBoxTexture.new()
	var btn_tex = load("res://assets/ui/buttons/ui_button_confirm.png")
	if btn_tex:
		btn_style.texture = btn_tex
		btn_style.texture_margin_left = 8
		btn_style.texture_margin_right = 8
		btn_style.texture_margin_top = 8
		btn_style.texture_margin_bottom = 8
		confirm_btn.add_theme_stylebox_override("normal", btn_style)
		confirm_btn.add_theme_stylebox_override("hover", btn_style)
		confirm_btn.add_theme_stylebox_override("pressed", btn_style)
		
	vbox.add_child(confirm_btn)
	
	confirm_btn.pressed.connect(_on_confirm_pressed)

func show_upgrade(cards: Array[Dictionary]) -> void:
	current_cards = cards
	selected_card_idx = -1
	confirm_btn.disabled = true
	# v1.2: 进化卡模式, 标题
	current_mode = "upgrade"
	if title_label:
		title_label.text = "技能 4 选 1 — 选 1 张浸篆"
	_show_skip_button(true)
	
	for child in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()
		
	for i in cards.size():
		var card = cards[i]
		var card_node = _create_card_ui(card, i)
		card_grid.add_child(card_node)
		
	for j in range(4 - cards.size()):
		var empty = _create_empty_card_slot()
		card_grid.add_child(empty)
		
	visible = true
	panel.modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.25)
	print("[UpgradePopup] 显示 %d 张卡牌" % cards.size())


## v1.1: 遗物卡 3 选 1 (复用 card_grid, 传 mode="relic")
## 与进化卡 4 选 1 共用同一弹窗, 仅标题/稀有度显示不同
func show_relic_choices(cards: Array[Dictionary]) -> void:
	# 修改标题为"遗物卡 3 选 1"
	if title_label:
		title_label.text = "遗物卡！选择一项被动"
	current_cards = cards
	selected_card_idx = -1
	confirm_btn.disabled = true
	# v1.2: 遗物模式
	current_mode = "relic"
	_show_skip_button(false)
	
	for child in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()
	
	for i in cards.size():
		var card = cards[i]
		var card_node = _create_card_ui(card, i)
		card_grid.add_child(card_node)
	
	visible = true
	panel.modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.25)
	print("[UpgradePopup] 遗物卡 3 选 1 显示: ", cards.size(), " 张")
func _create_card_ui(card: Dictionary, idx: int) -> Control:
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(180, 220)
	
	var card_style = StyleBoxTexture.new()
	var rarity = card.get("rarity", "Common")
	var tex_path = "res://assets/ui/cards/ui_card_common.png"
	match rarity:
		"Uncommon": tex_path = "res://assets/ui/cards/ui_card_uncommon.png"
		"Legendary": tex_path = "res://assets/ui/cards/ui_card_legendary.png"
		"Relic": tex_path = "res://assets/ui/cards/ui_card_relic.png"
		
	var card_tex = load(tex_path)
	if card_tex:
		card_style.texture = card_tex
		card_style.texture_margin_left = 12
		card_style.texture_margin_right = 12
		card_style.texture_margin_top = 12
		card_style.texture_margin_bottom = 12
	else:
		# Fallback to flat style
		var fallback = StyleBoxFlat.new()
		fallback.bg_color = Color(0.15, 0.15, 0.2, 1.0)
		fallback.corner_radius_top_left = 6
		fallback.corner_radius_top_right = 6
		fallback.corner_radius_bottom_left = 6
		fallback.corner_radius_bottom_right = 6
		fallback.border_width_left = 4
		fallback.border_color = rarity_colors.get(rarity, Color.WHITE)
		card_style = fallback
		
	card_panel.add_theme_stylebox_override("panel", card_style.duplicate())
	
	# MarginContainer for internal padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card_panel.add_child(margin)

	var container = VBoxContainer.new()
	container.set("theme_override_constants/separation", 8)
	margin.add_child(container)

	var border_color = rarity_colors.get(rarity, Color.WHITE)

	# v1.2 P1c: 技能 motif 图标 + 材质 badge (程序化组合: 卡牌渲染叠加 badge)
	var icon_area = HBoxContainer.new()
	icon_area.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_area.add_theme_constant_override("separation", 4)
	container.add_child(icon_area)

	var skill_icon_path := _find_skill_icon_path(card)
	if skill_icon_path != "" and ResourceLoader.exists(skill_icon_path):
		var skill_icon_rect = TextureRect.new()
		skill_icon_rect.texture = load(skill_icon_path)
		skill_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skill_icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_area.add_child(skill_icon_rect)

	var material: String = card.get("material", "")
	if material != "":
		var mat_name := _material_to_badge_name(material)
		var badge_path := "res://assets/ui/cards/badges/icon_mat_" + mat_name + ".png"
		if ResourceLoader.exists(badge_path):
			var badge_rect = TextureRect.new()
			badge_rect.texture = load(badge_path)
			badge_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge_rect.custom_minimum_size = Vector2(28, 28)
			icon_area.add_child(badge_rect)

	var name_label = Label.new()
	name_label.text = card.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(152, 40)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.self_modulate = border_color
	container.add_child(name_label)

	var cat_label = Label.new()
	cat_label.text = card.get("category", "") + " " + card.get("rarity", "")
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.self_modulate = Color(0.7, 0.7, 0.7, 1.0)
	container.add_child(cat_label)

	var desc_label = Label.new()
	desc_label.text = card.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(152, 50)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.self_modulate = Color(0.9, 0.9, 0.9, 1.0)
	container.add_child(desc_label)

	var rarity_label = Label.new()
	rarity_label.text = _get_rarity_text(rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.self_modulate = border_color
	container.add_child(rarity_label)

	# Click mechanics
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.mouse_filter = Control.MOUSE_FILTER_PASS

	var border_copy = border_color
	card_panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			_select_card(idx, card_panel, card_style, border_copy)
	)

	card_panel.set_meta("card_index", idx)
	card_panel.set_meta("card_data", card)
	return card_panel

## v1.2 P1c: 卡牌 -> 技能 motif 图标路径
func _find_skill_icon_path(card: Dictionary) -> String:
	# 优先: card 自身 id 匹配技能 id
	var id: String = card.get("id", "")
	if id != "":
		var direct := "res://assets/ui/cards/icons/icon_skill_" + id + ".png"
		if ResourceLoader.exists(direct):
			return direct
	# 兼容: skill_id 字段
	var sid: String = card.get("skill_id", "")
	if sid != "":
		var via_skill := "res://assets/ui/cards/icons/icon_skill_" + sid + ".png"
		if ResourceLoader.exists(via_skill):
			return via_skill
	return ""

## 材质中文名 -> badge 文件名
func _material_to_badge_name(material: String) -> String:
	match material:
		"金": return "metal"
		"木": return "wood"
		"水": return "water"
		"火": return "fire"
		"土": return "earth"
		_: return ""

func _create_empty_card_slot() -> Control:
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(180, 220)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	card_panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "槽位已空"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
	card_panel.add_child(label)
	return card_panel

func _select_card(idx: int, container: Control, orig_style: StyleBox, orig_border: Color) -> void:
	for child in card_grid.get_children():
		if child.has_meta("highlighted") and child.get_meta("highlighted"):
			child.set_meta("highlighted", false)
			var old_style = child.get_theme_stylebox("panel")
			if old_style is StyleBoxFlat:
				old_style.border_color = child.get_meta("orig_border")
	container.set_meta("highlighted", true)
	container.set_meta("orig_border", orig_border)
	
	var s = container.get_theme_stylebox("panel")
	if s is StyleBoxFlat:
		s.border_color = Color(1.0, 1.0, 1.0, 1.0)
	selected_card_idx = idx
	confirm_btn.disabled = false

func _on_confirm_pressed() -> void:
	if selected_card_idx < 0 or selected_card_idx >= current_cards.size():
		return
	var card = current_cards[selected_card_idx]
	print("[UpgradePopup] 确认选择: ", card.get("name", ""))
	UpgradeSystem.select_card(card)
	card_confirmed.emit(card)
	# v1.2: 清层奖励链 — 4选1(进化卡) 完成后, 弹 遗物 3选1 (仅精英/Boss)
	# 进化卡 4选1 完成 → 放行 (普通层: 直接路线; 精英/Boss: 弹遗物, 遗物完成再 all_rewards_done)
	# 遗物 3选1 完成 → 放行到路线 3选1
	_animate_panel_out()
	all_rewards_done.emit()

func _animate_panel_out() -> void:
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.TRANSPARENT, 0.2)
	tween.tween_callback(_on_panel_anim_finished)

func _on_panel_anim_finished() -> void:
	visible = false

## v1.2: 跳过按钮 (不选遗物直接进路线)
var _skip_btn: Button

func _show_skip_button(show: bool) -> void:
	if _skip_btn == null:
		_skip_btn = Button.new()
		_skip_btn.name = "SkipButton"
		_skip_btn.text = "跳过"
		_skip_btn.custom_minimum_size = Vector2(120, 44)
		_skip_btn.pressed.connect(_on_skip_pressed)
		# 加到 panel 的 vbox
		var vbox = panel.get_node_or_null("VBox")
		if vbox:
			vbox.add_child(_skip_btn)
	if _skip_btn:
		_skip_btn.visible = show

func _on_skip_pressed() -> void:
	# 跳过遗物 3选1, 直接放行到路线 3选1
	if current_mode == "relic":
		_animate_panel_out()
		all_rewards_done.emit()

func _get_rarity_text(rarity: String) -> String:
	# 英文稀有度 → 中文
	match rarity:
		"Common": return "普通"
		"Uncommon": return "罕见"
		"Epic": return "史诗"
		"Legendary": return "传说"
		"Relic": return "神器"
	# 已是中文稀有度直接返回
	match rarity:
		"普通": return "普通"
		"罕见": return "罕见"
		"史诗": return "史诗"
		"传说": return "传说"
		"神器": return "神器"
	return rarity

func hide_upgrade() -> void:
	visible = false
