extends CanvasLayer
## HUD — 顶部状态栏 (GDD 2.1 屏幕布局)
## 职责：实时显示 HP / 能量 / 等级 / 波次
## 依赖 GameManager 读取全局数据，每帧刷新

var _gm: Node
var _energy_bar: ProgressBar
var _hp_bar: ProgressBar
var _level_label: Label
var _energy_label: Label
var _wave_label: Label

func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	
	# 动态创建能量条
	_energy_bar = ProgressBar.new()
	_energy_bar.name = "EnergyBar"
	_energy_bar.custom_minimum_size = Vector2(120, 14)
	_energy_bar.max_value = 10.0
	_energy_bar.show_percentage = false
	_energy_bar.modulate = Color(0.5, 0.2, 0.9, 1.0)
	# 简单样式
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.6, 0.3, 1.0, 1.0)
	_energy_bar.add_theme_stylebox_override("background", sb)
	_energy_bar.add_theme_stylebox_override("fill", fill)
	# 放在 GameArea 左上
	var ga = get_node_or_null("GameArea")
	if ga:
		_energy_bar.position = Vector2(10, 60)

		ga.add_child(_energy_bar)
	
	# 能量文字
	_energy_label = Label.new()
	_energy_label.name = "EnergyLabel"
	_energy_label.position = Vector2(10, 76)
	_energy_label.add_theme_font_size_override("font_size", 12)
	_energy_label.text = "EN 10/10"
	if ga:
		ga.add_child(_energy_label)
	
	# 等级
	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.position = Vector2(150, 60)
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.text = "Lv.1"
	if ga:
		ga.add_child(_level_label)
	
	# 波次
	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.position = Vector2(200, 60)
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.text = "Wave 1"
	if ga:
		ga.add_child(_wave_label)

func _process(_delta: float) -> void:
	if _gm == null:
		return
	var stats: Dictionary = _gm.player_stats
	var energy: float = stats.get("energy", 0.0)
	var max_energy: float = stats.get("max_energy", 10.0)
	var level: int = stats.get("level", 1)
	var wave: int = _gm.current_wave
	var hp: int = stats.get("current_hp", 0)
	var max_hp: int = stats.get("max_hp", 100)
	
	if _energy_bar:
		_energy_bar.max_value = max_energy
		_energy_bar.value = energy
	if _energy_label:
		_energy_label.text = "EN %d/%d" % [int(energy), int(max_energy)]
	if _level_label:
		_level_label.text = "Lv.%d" % level
	if _wave_label:
		_wave_label.text = "Wave %d" % wave
	# HP (若 HUD 容器有 HP_Label 则同步)
	var hp_label = get_node_or_null("HUD_Container/HP_Label")
	if hp_label and hp_label is Label:
		hp_label.text = "HP: %d/%d" % [hp, max_hp]
