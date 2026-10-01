extends Node2D

## 격자 간격 (픽셀)
const CELL_SIZE := 64
## 격자 범위 (Ground ColorRect를 넉넉히 덮도록)
const EXTENT := 2000
## 격자선 색상 (은은하고 자연스러운 반투명 녹색)
const LINE_COLOR := Color(0.18, 0.34, 0.60, 0.22)
## 격자선 두께
const LINE_WIDTH := 1.0

## EXTENT 이상을 덮는, CELL_SIZE의 배수인 시작 좌표
## -2000 → floori(-2000.0 / 64) * 64 = -32 * 64 = -2048
var _grid_start: int = floori(float(-EXTENT) / CELL_SIZE) * CELL_SIZE
var _grid_end: int = ceili(float(EXTENT) / CELL_SIZE) * CELL_SIZE


func _draw() -> void:
	# 세로선
	var x := _grid_start
	while x <= _grid_end:
		draw_line(Vector2(x, _grid_start), Vector2(x, _grid_end), LINE_COLOR, LINE_WIDTH)
		x += CELL_SIZE
	# 가로선
	var y := _grid_start
	while y <= _grid_end:
		draw_line(Vector2(_grid_start, y), Vector2(_grid_end, y), LINE_COLOR, LINE_WIDTH)
		y += CELL_SIZE
