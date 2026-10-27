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

# v1.2: 五行材质计数 (吃怪反馈, GDD 四)
var _material_label: Label
var _material_hint: Label
var _remaining_label: Label
var _banner: Label
var _banner_timer: float = 0.0
# v1.2 P1c: 警报指示器 (合金装备式 0/1/2 级, 读 RouteGenerator.alarm)
var _alarm_icon: TextureRect
var _alarm_label: Label
var _last_alarm_level: int = -1
# P1: 章节横幅 (ui_chapter_banner 900x200 + 大关中文名, 进新章节闪现 2.5s)
var _chapter_banner_bg: TextureRect
var _chapter_banner_label: Label
var _banner_timer_chapter: float = 0.0
var _last_chapter: int = -1

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

	# v1.2: 五行材质计数条 (吃怪实时刷新)
	_material_label = Label.new()
	_material_label.name = "MaterialLabel"
	_material_label.position = Vector2(10, 95)
	_material_label.add_theme_font_size_override("font_size", 12)
	_material_label.text = "材质 金0 木0 水0 火0 土0"
	if ga:
		ga.add_child(_material_label)

	# v1.2 P1c: 警报指示器 (右上角, 图标 + 等级文字; 0 级隐藏)
	_alarm_icon = TextureRect.new()
	_alarm_icon.name = "AlarmIcon"
	if ResourceLoader.exists("res://assets/ui/ui_alarm.png"):
		_alarm_icon.texture = load("res://assets/ui/ui_alarm.png")
		_alarm_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_alarm_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_alarm_icon.custom_minimum_size = Vector2(32, 32)
		_alarm_icon.position = Vector2(660, 20)
		_alarm_icon.visible = false
		if ga:
			ga.add_child(_alarm_icon)

	_alarm_label = Label.new()
	_alarm_label.name = "AlarmLabel"
	_alarm_label.position = Vector2(640, 54)
	_alarm_label.add_theme_font_size_override("font_size", 12)
	_alarm_label.text = ""
	_alarm_label.self_modulate = Color(1.0, 0.35, 0.35, 1.0)
	_alarm_label.visible = false
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_alarm_label.size = Vector2(44, 20)
	if ga:
		ga.add_child(_alarm_label)

	# v1.2: 本层通关 4 选 1 提示 (提示成长线)
	_material_hint = Label.new()
	_material_hint.name = "MaterialHint"
	_material_hint.position = Vector2(10, 112)
	_material_hint.add_theme_font_size_override("font_size", 11)
	_material_hint.text = "清层: 技能4选1 + 精英/Boss遗物3选1"
	_material_hint.modulate = Color(1.0, 0.9, 0.5, 0.85)
	if ga:
		ga.add_child(_material_hint)

	# v1.2: 本层剩余敌人 (吃怪反馈: 还差几只才触发 4 选 1)
	_remaining_label = Label.new()
	_remaining_label.name = "RemainingLabel"
	_remaining_label.position = Vector2(10, 129)
	_remaining_label.add_theme_font_size_override("font_size", 12)
	_remaining_label.text = "剩余敌人 —"
	if ga:
		ga.add_child(_remaining_label)

	# v1.2: 层清横幅 (清层后 3s 再弹 4 选 1, 补感知)
	_banner = Label.new()
	_banner.name = "FloorBanner"
	_banner.position = Vector2(0, 120)
	_banner.size = Vector2(720, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.self_modulate = Color(1.0, 0.9, 0.3, 1.0)
	_banner.visible = false
	if ga:
		ga.add_child(_banner)

	# P1: 章节横幅 — ui_chapter_banner 底图 + 大关名, 进新章节闪现
	_chapter_banner_bg = TextureRect.new()
	_chapter_banner_bg.name = "ChapterBannerBG"
	if ResourceLoader.exists("res://assets/ui/ui_chapter_banner.png"):
		_chapter_banner_bg.texture = load("res://assets/ui/ui_chapter_banner.png")
	_chapter_banner_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chapter_banner_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chapter_banner_bg.position = Vector2(110, 180)
	_chapter_banner_bg.custom_minimum_size = Vector2(500, 110)
	_chapter_banner_bg.modulate = Color(1, 1, 1, 0.95)
	_chapter_banner_bg.visible = false
	if ga:
		ga.add_child(_chapter_banner_bg)

	_chapter_banner_label = Label.new()
	_chapter_banner_label.name = "ChapterBannerLabel"
	_chapter_banner_label.position = Vector2(110, 210)
	_chapter_banner_label.size = Vector2(500, 50)
	_chapter_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_banner_label.add_theme_font_size_override("font_size", 34)
	_chapter_banner_label.self_modulate = Color(1.0, 0.92, 0.5, 1.0)
	_chapter_banner_label.visible = false
	if ga:
		ga.add_child(_chapter_banner_label)

func _process(_delta: float) -> void:
	_update_alarm_display()
	_update_chapter_banner(_delta)
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
	# v1.2: 刷新五行材质计数
	_refresh_materials()
	# v1.2: 刷新本层剩余敌人
	_refresh_remaining()


## v1.2: 本层剩余敌人 (吃怪反馈: 还差几只才触发 4 选 1)
func _refresh_remaining() -> void:
	if _remaining_label == null:
		return
	var sp = get_node_or_null("../WaveSpawner")
	if sp == null or not sp.has_method("get_remaining_enemies"):
		_remaining_label.text = "剩余敌人 —"
		return
	var remaining: int = sp.get_remaining_enemies()
	var total: int = sp.get_wave_spawn_total() if sp.has_method("get_wave_spawn_total") else 0
	var fb = load("res://scripts/floor_banner.gd")
	_remaining_label.text = fb.remaining_hint(remaining, total)

## 隐藏层清横幅 (奖励链完成 → 进路线 3选1 时调用, GDD 七)
func _hide_floor_banner() -> void:
	if _banner:
		_banner.visible = false
	_banner_timer = 0.0

## v1.2: 层清横幅 — 由 WaveSpawner.wave_cleared 信号驱动 (GDD 七 清层反馈 3s 窗口)
func _on_wave_cleared(_floor: int) -> void:
	if _banner == null:
		return
	var rb = load("res://scripts/floor_banner.gd")
	if _gm:
		_banner.text = rb.cleared_banner_text(_gm.current_wave, "")
	_banner.visible = true
	_banner_timer = 0.0

## v1.2: 五行材质计数条 (金/木/水/火/土 + 品阶)
func _refresh_materials() -> void:
	if _gm == null or _material_label == null:
		return
	if not _gm.has_method("get_material_count"):
		return
	var parts: Array[String] = []
	for mat in ["金", "木", "水", "火", "土"]:
		var cnt: int = _gm.get_material_count(mat)
		if cnt > 0:
			var top: int = _gm.get_material_max_tier(mat)
			var tier_name: String = _gm.MATERIAL_TIER_NAMES.get(maxi(0, top), "白")
			parts.append("%s%d(%s)" % [mat, cnt, tier_name])
	var text: String = "材质 " + (" ".join(parts) if parts.size() > 0 else "无")
	_material_label.text = text
## v1.2 P1c: 警报等级显示 (读 RouteGenerator.alarm.alarm_level, 0 级隐藏)
func _update_alarm_display() -> void:
	if _alarm_icon == null or not is_instance_valid(_alarm_icon):
		return
	var rg = get_node_or_null("/root/MainGame/RouteGenerator")
	if rg == null:
		rg = get_node_or_null("RouteGenerator")
	if rg == null or rg.get("alarm") == null:
		_alarm_icon.visible = false
		_alarm_label.visible = false
		_last_alarm_level = 0
		return
	var alarm_obj = rg.alarm
	# alarm 是 RefCounted 实例 (alarm_system), 没有 Object.get 的默认值重载 — 直接读字段
	var level: int = int(alarm_obj.alarm_level) if "alarm_level" in alarm_obj else 0
	if level != _last_alarm_level:
		_last_alarm_level = level
		if level <= 0:
			_alarm_icon.visible = false
			_alarm_label.visible = false
		else:
			_alarm_icon.visible = true
			_alarm_label.visible = true
			var lvl_colors: Array = [Color.WHITE, Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.4, 0.3, 1.0), Color(1.0, 0.15, 0.15, 1.0)]
			_alarm_icon.modulate = lvl_colors[mini(level, lvl_colors.size() - 1)]
			_alarm_label.text = "警报 ×" + str(level)

## P1: 章节横幅 — GameManager.chapter 变化时闪现 2.5s (ui_chapter_banner 底图)
func _update_chapter_banner(delta: float) -> void:
	if _gm == null:
		return
	if _chapter_banner_label == null or not is_instance_valid(_chapter_banner_label):
		return
	var ch: int = int(_gm.chapter) if "chapter" in _gm else 1
	if ch != _last_chapter:
		_last_chapter = ch
		var rg = get_node_or_null("/root/MainGame/RouteGenerator")
		var ch_name := ""
		if rg and rg.has_method("get_style_name"):
			ch_name = rg.get_style_name()
		if ch_name == "":
			ch_name = "第 " + str(ch) + " 大关"
		_chapter_banner_label.text = ch_name
		_chapter_banner_bg.visible = true
		_chapter_banner_label.visible = true
		_chapter_banner_bg.modulate = Color(1, 1, 1, 1.0)
		_banner_timer_chapter = 2.5
	if _banner_timer_chapter > 0.0:
		_banner_timer_chapter -= delta
		if _banner_timer_chapter <= 0.0:
			_chapter_banner_bg.visible = false
			_chapter_banner_label.visible = false
