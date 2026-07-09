const fs = require('fs');

// ===== 1. Fix game_manager.gd =====
var gm = fs.readFileSync('D:/Documents/小小幸存者/scripts/game_manager.gd', 'utf-8');
gm = gm.replace(
    'var error = FileAccess.store_json(save_data, "user://save_data.json")',
    'var json_str = JSON.stringify(save_data)\n\tvar file = FileAccess.open("user://save_data.json", FileAccess.WRITE)\n\tif file:\n\t\tfile.store_string(json_str)\n\t\tfile.close()\n\t\tprint("[GameManager] 游戏已保存")\n\t\treturn\n\tprint("[GameManager] 保存失败")'
);
gm = gm.replace(
    'var data = FileAccess.get_json_as_text("user://save_data.json")\n\tvar save_data: Dictionary = JSON.parse_string(data)',
    'var file = FileAccess.open("user://save_data.json", FileAccess.READ)\n\tif not file:\n\t\treturn false\n\tvar json_str = file.get_as_text()\n\tfile.close()\n\tvar parse_result = JSON.parse_string(json_str)\n\tif typeof(parse_result) != TYPE_DICTIONARY:\n\t\treturn false\n\tvar save_data = parse_result'
);
gm = gm.replace(
    '\tprint("[GameManager] 游戏已保存")\n\telse:\n\t\tprint("[GameManager] 保存失败: ", error)',
    ''
);
fs.writeFileSync('D:/Documents/小小幸存者/scripts/game_manager.gd', gm, 'utf-8');
console.log('game_manager.gd fixed');

// ===== 2. Fix card_database.gd =====
var cd = fs.readFileSync('D:/Documents/小小幸存者/scripts/card_database.gd', 'utf-8');
cd = cd.replace(
    'var counts := {"Core": 0, "Component": 0, "Resonance": 0, "Relic": 0}',
    'var counts: Dictionary = {"Core": 0, "Component": 0, "Resonance": 0, "Relic": 0}'
);
cd = cd.replace(
    'counts.total = get_all_cards().size()',
    'counts["total"] = get_all_cards().size()'
);
fs.writeFileSync('D:/Documents/小小幸存者/scripts/card_database.gd', cd, 'utf-8');
console.log('card_database.gd fixed');

// ===== 3. Fix upgrade_popup.gd =====
var up = fs.readFileSync('D:/Documents/小小幸存者/scripts/upgrade_popup.gd', 'utf-8');
// Fix: style is a local var, need to use it properly
// The issue is "style.border_color = ..." but style is not accessible in the _select_card function
// Need to store original border color in meta
up = up.replace(
    `func _select_card(idx: int, container: Control, orig_style: StyleBoxFlat, orig_border: Color) -> void:
    for child in card_grid.get_children():
        if child.has_meta("highlighted") and child.get_meta("highlighted"):
            if child.get_theme_stylebox("panel") is StyleBoxFlat:
                child.get_theme_stylebox("panel").border_color = orig_border
            child.set_meta("highlighted", false)
    container.set_meta("highlighted", true)
    var s = container.get_theme_stylebox("panel")
    if s is StyleBoxFlat:
        s.border_color = Color(1.0, 1.0, 1.0, 1.0)
    selected_card_idx = idx
    confirm_btn.disabled = false`,
    `func _select_card(idx: int, container: Control, orig_style: StyleBoxFlat, orig_border: Color) -> void:
    for child in card_grid.get_children():
        if child.has_meta("highlighted") and child.get_meta("highlighted"):
            var old_style = child.get_theme_stylebox("panel")
            if old_style is StyleBoxFlat:
                old_style.border_color = container.get_meta("orig_border")
            child.set_meta("highlighted", false)
    container.set_meta("highlighted", true)
    container.set_meta("orig_border", orig_border)
    var s = container.get_theme_stylebox("panel")
    if s is StyleBoxFlat:
        s.border_color = Color(1.0, 1.0, 1.0, 1.0)
    selected_card_idx = idx
    confirm_btn.disabled = false`
);
// Also fix: orig_style is unused parameter warning, remove it
up = up.replace(
    'func _select_card(idx: int, container: Control, orig_style: StyleBoxFlat, orig_border: Color) -> void:',
    'func _select_card(idx: int, container: Control, _orig_style: StyleBoxFlat, orig_border: Color) -> void:'
);
// Fix: the _create_card_ui passes style to _select_card but style is a local variable
// Need to capture orig_border properly
up = up.replace(
    `    var sel_style = style
    var sel_border = border_color
    container.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _select_card(sel_idx, container, sel_style, sel_border)
    )`,
    `    var border_copy = border_color
    container.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _select_card(idx, container, style, border_copy)
    )`
);
fs.writeFileSync('D:/Documents/小小幸存者/scripts/upgrade_popup.gd', up, 'utf-8');
console.log('upgrade_popup.gd fixed');

// ===== 4. Fix main_game.tscn =====
var mg = fs.readFileSync('D:/Documents/小小幸存者/scenes/main_game.tscn', 'utf-8');
mg = mg.replace('[gdscene load_steps=11 format=3', '[gdscene format=3 load_steps=11');
fs.writeFileSync('D:/Documents/小小幸存者/scenes/main_game.tscn', mg, 'utf-8');
console.log('main_game.tscn fixed');

console.log('ALL FIXES APPLIED');
