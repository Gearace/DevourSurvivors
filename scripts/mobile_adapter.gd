extends Node
## MobileAdapter — 移动端适配层
## 负责竖屏锁定、分辨率适配、触控优化

const VIEWPORT_WIDTH := 720
const VIEWPORT_HEIGHT := 1280

## Godot 4.7 DisplayServer.WindowMode 兼容值

func _ready() -> void:
    _setup_display()
    _setup_rendering()
    print("[MobileAdapter] 移动端适配完成 — ", VIEWPORT_WIDTH, "x", VIEWPORT_HEIGHT)

## 设置显示参数
func _setup_display() -> void:
    # 竖屏锁定由 project.godot 配置，此处不再运行时检查
    
    # 设置视口尺寸
    DisplayServer.window_set_size(Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
    
    # 启用全屏（移动端）
    if OS.has_feature("android") or OS.has_feature("ios"):
        DisplayServer.window_set_mode(4)

## 设置渲染参数
func _setup_rendering() -> void:
    # 使用 mobile 渲染器
    var rendering_device = RenderingServer.get_rendering_device()
    if rendering_device:
        var adapter_name: String = rendering_device.get_adapter_name()
        print("[MobileAdapter] GPU: ", adapter_name)

## 获取逻辑分辨率
func get_logical_size() -> Vector2:
    return Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)

## 屏幕坐标转逻辑坐标
func screen_to_logic(screen_pos: Vector2) -> Vector2:
    var vp = get_viewport()
    var view_rect: Rect2
    if vp:
        var vp_size: Vector2 = vp.get_visible_rect().size
        view_rect = Rect2(Vector2.ZERO, vp_size)
    else:
        view_rect = Rect2(Vector2.ZERO, Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
    var scale: float = view_rect.size.x / VIEWPORT_WIDTH
    return screen_pos / scale

## 获取摇杆区域 (底部居中)
func get_joystick_rect() -> Rect2:
    var size = get_logical_size()
    var joystick_radius: float = 60.0
    var center_x: float = size.x / 2.0
    var center_y: float = size.y - 100.0
    return Rect2(
        center_x - joystick_radius * 2,
        center_y - joystick_radius * 2,
        joystick_radius * 4,
        joystick_radius * 4
    )

