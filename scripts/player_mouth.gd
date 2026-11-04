extends Node2D
## M8-A: 玩家程序化大嘴 — 挂在 Player 节点下, 在史莱姆本体下方画一个可开合的嘴部
## 平时微张 (0.15), 吞噬瞬间张到 1.0, 然后缓动回弹
## 颜色: 深绿 + 黑内壁 + 小尖牙

## 0=闭合, 1=全开
var open_amount: float = 0.0
var target: float = 0.15        # 默认微张
var snap_speed := 14.0
var close_speed := 6.0

var _radius: float = 20.0       # 史莱姆 body_radius (由 Player 同步)

const MOUTH_OFFSET_Y := 0.18    # 嘴部中心相对史莱姆中心的垂直偏移 (body_radius 倍数)

func _process(delta: float) -> void:
	if open_amount < target:
		open_amount = min(target, open_amount + snap_speed * delta)
	elif open_amount > target:
		open_amount = max(target, open_amount - close_speed * delta)
	queue_redraw()

## 由 Player._execute_capture 调用
func trigger_munch(duration := 0.18) -> void:
	target = 1.0
	await get_tree().create_timer(duration).timeout
	target = 0.15

func set_radius(r: float) -> void:
	_radius = r

func _draw() -> void:
	# 嘴部画在史莱姆中心偏下方
	var cx := 0.0
	var cy := _radius * MOUTH_OFFSET_Y
	# 嘴部宽度 = 史莱姆半径的 0.8, 高度随 open_amount 变化
	var w := _radius * 0.8
	var h_outer := _radius * 0.05      # 闭合时的最小厚度
	var h_inner := _radius * 0.75 * open_amount  # 张开时内壁深度
	var h_total := h_outer + h_inner

	# 外嘴形: 一个扁椭圆 (黑色)
	var rect_outer := Rect2(cx - w/2, cy - h_total/2, w, h_total)
	draw_rect(rect_outer, Color(0.05, 0.15, 0.05, 0.9), true)

	# 内壁 (深绿, 比外嘴小一圈)
	var shrink := 0.85
	var rect_inner := Rect2(
		cx - w/2*shrink,
		cy - h_total/2*shrink + h_outer*0.3,
		w*shrink,
		h_total*shrink - h_outer*0.3
	)
	if open_amount > 0.05:
		draw_rect(rect_inner, Color(0.15, 0.45, 0.12, 0.85), true)

	# 上排小尖牙 (4 个白色三角, 随开合上下微移)
	var teeth_y := cy - h_total/2 + h_outer*0.3
	var tooth_w := w / 6.0
	var tooth_h := _radius * 0.08 * open_amount
	for i in range(4):
		var tx := cx - w/2*0.7 + i * tooth_w * 1.2
		var pts := PackedVector2Array([
			Vector2(tx, teeth_y),
			Vector2(tx + tooth_w, teeth_y),
			Vector2(tx + tooth_w/2, teeth_y + tooth_h),
		])
		draw_colored_polygon(pts, Color(0.95, 0.95, 0.9, 0.9))

	# 下排小尖牙 (朝上, 3 个)
	var teeth_y2 := cy + h_total/2 - h_outer*0.3
	for i in range(3):
		var tx := cx - w/2*0.6 + i * tooth_w * 1.1
		var pts := PackedVector2Array([
			Vector2(tx, teeth_y2),
			Vector2(tx + tooth_w, teeth_y2),
			Vector2(tx + tooth_w/2, teeth_y2 - tooth_h),
		])
		draw_colored_polygon(pts, Color(0.95, 0.95, 0.9, 0.85))
