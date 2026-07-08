extends Node
## MobileAdapter — 移动端适配层
## 负责竖屏锁定、分辨率适配、触控优化

const VIEWPORT_WIDTH := 720
const VIEWPORT_HEIGHT := 1280

func _ready() -> void:
	_setup_display()
	_setup_rendering()
	print("[MobileAdapter] 移动端适配完成 — ", VIEWPORT_WIDTH, "x", VIEWPORT_HEIGHT)

## 设置显示参数
func _setup_display() -> void:
	# 锁定竖屏
	if DisplayServer.has_feature(DisplayServer.FEATURE_SCREEN_PORTAIT):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	# 设置视口尺寸
	DisplayServer.window_set_size(Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
	
	# 启用全屏（移动端）
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

## 设置渲染参数
func _setup_rendering() -> void:
	# 使用 mobile 渲染器
	var rendering_device := RenderingServer.get_rendering_device()
	if rendering_device:
		var adapter_info := rendering_device.get_adapter_name()
		print("[MobileAdapter] GPU: ", adapter_info)

## 获取逻辑分辨率
func get_logical_size() -> Vector2:
	return Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)

## 屏幕坐标转逻辑坐标
func screen_to_logic(screen_pos: Vector2) -> Vector2:
	var view_rect = get_viewport_rect()
	var scale = view_rect.size.x / VIEWPORT_WIDTH
	return screen_pos / scale

## 获取摇杆区域 (底部居中)
func get_joystick_rect() -> Rect2:
	var size = get_logical_size()
	var joystick_radius = 60.0
	var center_x = size.x / 2.0
	var center_y = size.y - 100.0
	return Rect2(
		center_x - joystick_radius * 2,
		center_y - joystick_radius * 2,
		joystick_radius * 4,
		joystick_radius * 4
	)
