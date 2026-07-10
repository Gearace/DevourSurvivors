extends Control
## upgrade_popup.gd
## 升级弹窗控制器 — 通过代码动态创建UI，无场景依赖

signal card_confirmed(card: Dictionary)

var panel: Control
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
    
    # Panel (主面板)
    panel = Panel.new()
    panel.name = "Panel"
    panel.layout_mode = 3  # LayoutMode.NONE
    panel.offset_top = 60.0
    panel.offset_bottom = -60.0
    panel.offset_left = 40.0
    panel.offset_right = -40.0
    add_child(panel)
    
    # VBox (垂直布局)
    var vbox = VBoxContainer.new()
    vbox.name = "VBox"
    vbox.spacing = 12
    vbox.alignment = 1  # HORIZONTAL_ALIGNMENT_CENTER
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
    
    # Use a simple spacer instead
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 5)
    vbox.add_child(spacer)
    
    # Card Grid
    card_grid = GridContainer.new()
    card_grid.name = "CardGrid"
    card_grid.custom_minimum_size = Vector2(0, 200)
    card_grid.columns = 2
    # Use theme override for separation
    var ui_theme = Theme.new()
    ui_theme.set_constant("h_separation", "GridContainer", 16)
    ui_theme.set_constant("v_separation", "GridContainer", 16)
    card_grid.theme = ui_theme
    vbox.add_child(card_grid)
    
    # Confirm Button
    confirm_btn = Button.new()
    confirm_btn.name = "ConfirmButton"
    confirm_btn.custom_minimum_size = Vector2(0, 50)
    confirm_btn.text = "确认选择"
    confirm_btn.disabled = true
    vbox.add_child(confirm_btn)
    
    confirm_btn.pressed.connect(_on_confirm_pressed)

func show_upgrade(cards: Array[Dictionary]) -> void:
    current_cards = cards
    selected_card_idx = -1
    confirm_btn.disabled = true
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
    var tween = create_tween()
    tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.3)
    print("[UpgradePopup] 显示 %d 张卡牌" % cards.size())

func _create_card_ui(card: Dictionary, idx: int) -> Control:
    var container = VBoxContainer.new()
    container.custom_minimum_size = Vector2(180, 220)
    container.set("theme_override_constants/separation", 8)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.border_width_left = 4
    var border_color = rarity_colors.get(card.get("rarity", "Common"), Color.WHITE)
    style.border_color = border_color
    style.expand_margins_left = 2
    style.expand_margins_right = 2
    style.expand_margins_top = 2
    style.expand_margins_bottom = 2
    container.add_theme_stylebox_override("panel", style)

    var name_label = Label.new()
    name_label.text = card.get("name", "Unknown")
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.autowrap_mode = TEXT_AUTOWRAP_WORD_SMART
    name_label.custom_minimum_size = Vector2(160, 40)
    name_label.add_theme_font_size_override("font_size", 18)
    name_label.self_modulate = border_color
    container.add_child(name_label)

    var cat_label = Label.new()
    cat_label.text = card.get("category", "") + " " + card.get("rarity", "")
    cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cat_label.add_theme_font_size_override("font_size", 12)
    cat_label.self_modulate = Color(0.7, 0.7, 0.7, 1.0)
    container.add_child(cat_label)

    var desc_label = Label.new()
    desc_label.text = card.get("description", "")
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc_label.autowrap_mode = TEXT_AUTOWRAP_WORD_SMART
    desc_label.custom_minimum_size = Vector2(160, 60)
    desc_label.add_theme_font_size_override("font_size", 13)
    desc_label.self_modulate = Color(0.9, 0.9, 0.9, 1.0)
    container.add_child(desc_label)

    var rarity_label = Label.new()
    rarity_label.text = _get_rarity_text(card.get("rarity", "Common"))
    rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rarity_label.add_theme_font_size_override("font_size", 11)
    rarity_label.self_modulate = border_color
    container.add_child(rarity_label)

    container.mouse_filter = Control.MOUSE_FILTER_STOP
    var border_copy = border_color
    container.gui_input.connect(func _on_card_input(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _select_card(idx, container, style, border_copy)
    )

    container.set_meta("card_index", idx)
    container.set_meta("card_data", card)
    return container

func _create_empty_card_slot() -> Control:
    var container = VBoxContainer.new()
    container.custom_minimum_size = Vector2(180, 220)
    container.set("theme_override_constants/separation", 8)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.border_width_left = 2
    style.border_color = Color(0.3, 0.3, 0.3, 0.5)
    container.add_theme_stylebox_override("panel", style)
    var label = Label.new()
    label.text = "牌组已满"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 14)
    label.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
    container.add_child(label)
    return container

func _select_card(idx: int, container: Control, _orig_style: StyleBoxFlat, orig_border: Color) -> void:
    for child in card_grid.get_children():
        if child.has_meta("highlighted") and child.get_meta("highlighted"):
            child.set_meta("highlighted", false)
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
    _animate_panel_out()
    card_confirmed.emit(card)

func _animate_panel_out() -> void:
    var tween = create_tween()
    tween.tween_property(panel, "modulate", Color.TRANSPARENT, 0.2)
    tween.tween_callback(_on_panel_anim_finished)

func _on_panel_anim_finished() -> void:
    visible = false

func _get_rarity_text(rarity: String) -> String:
    match rarity:
        "Common": return "普通"
        "Uncommon": return "稀有"
        "Legendary": return "传说"
        "Relic": return "遗物"
    return rarity

func hide_upgrade() -> void:
    visible = false










