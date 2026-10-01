extends Node2D

## 격자 한 칸 크기 (debug_grid.gd의 CELL_SIZE와 동일)
const CELL_SIZE := 64

## 상호작용 가능 거리 (칸 수)
@export var interact_range_cells: int = 2

## 칸 상태
enum TileState { GRASS, TILLED, PLANTED }

## 날짜
var current_day: int = 1

## 갈린/심은 칸 저장. 키: Vector2i, 값: TileState
var _tiles: Dictionary = {}

## 씨앗을 심은 날짜 저장. 키: Vector2i, 값: int (심은 날짜)
var _planted_days: Dictionary = {}

# --- 색상 팔레트 (자연스러운 톤) ---------------------------------------------
const TILLED_BORDER_COLOR := Color(0.30, 0.18, 0.10, 1.0)   # 밭 테두리/도랑
const TILLED_MAIN_COLOR := Color(0.44, 0.28, 0.15, 1.0)     # 밭 흙 본체
const TILLED_FURROW_COLOR := Color(0.36, 0.22, 0.12, 1.0)   # 밭고랑 선

# 작물 단계별 색상
const SEED_HOLE_COLOR := Color(0.24, 0.14, 0.08, 1.0)       # 씨앗 홈
const SEED_COLOR_A := Color(0.72, 0.58, 0.35, 1.0)          # 씨앗 알갱이 1
const SEED_COLOR_B := Color(0.82, 0.68, 0.42, 1.0)          # 씨앗 알갱이 2

const STEM_COLOR := Color(0.30, 0.56, 0.20, 1.0)            # 새싹/작물 줄기
const SPROUT_LEAF_COLOR := Color(0.55, 0.85, 0.25, 1.0)     # Stage 1: 연두색 떡잎

const GROW_LEAF_DARK := Color(0.20, 0.62, 0.22, 1.0)        # Stage 2: 성장 중 잎
const GROW_LEAF_LIGHT := Color(0.30, 0.74, 0.28, 1.0)       # Stage 2: 새 잎

const MATURE_LEAF_COLOR := Color(0.16, 0.50, 0.18, 1.0)     # Stage 3: 풍성한 짙은 잎
const MATURE_FRUIT_COLOR := Color(0.98, 0.62, 0.12, 1.0)    # Stage 3: 익은 열매 (황금빛 주황)
const MATURE_FRUIT_HI := Color(1.0, 0.82, 0.38, 1.0)       # Stage 3: 열매 하이라이트

# 호버 하이라이트
const HOVER_IN_FILL := Color(1.0, 1.0, 1.0, 0.12)
const HOVER_IN_BORDER := Color(1.0, 1.0, 1.0, 0.55)
const HOVER_OUT_FILL := Color(0.9, 0.2, 0.2, 0.10)
const HOVER_OUT_BORDER := Color(0.9, 0.2, 0.2, 0.45)

## 현재 마우스가 올라가 있는 격자 칸
var _hover_cell := Vector2i.ZERO

## 노드 참조
@onready var _player: CharacterBody2D = get_parent().get_node("Player")
@onready var _inventory: Inventory = get_parent().get_node("Inventory")
@onready var _inventory_ui: InventoryUI = get_parent().get_node("HUD/InventoryUI")
@onready var _shop: Node2D = get_parent().get_node_or_null("Shop")
@onready var _shop_ui: ShopUI = get_parent().get_node_or_null("HUD/ShopUI")
@onready var _mode_label: Label = get_parent().get_node("HUD/ModeLabel")
@onready var _day_label: Label = get_parent().get_node("HUD/DayLabel")
@onready var _harvest_label: Label = get_parent().get_node("HUD/HarvestLabel")
@onready var _money_label: Label = get_parent().get_node_or_null("HUD/MoneyLabel")


func _ready() -> void:
	if _inventory_ui and _inventory:
		_inventory_ui.setup(_inventory)
		_inventory.inventory_changed.connect(func():
			_update_hud()
			queue_redraw()
		)
		_inventory.selected_slot_changed.connect(func(_idx):
			_update_hud()
			queue_redraw()
		)
		_inventory.money_changed.connect(func(_val):
			_update_hud()
		)

	if _shop_ui and _inventory and _player:
		_shop_ui.setup(_inventory, _player, _inventory_ui)

	if _shop and _shop_ui:
		_shop.set_shop_ui(_shop_ui)

	_update_hud()


# --- 헬퍼 함수 ----------------------------------------------------------------

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / CELL_SIZE), floori(world_pos.y / CELL_SIZE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5,
					cell.y * CELL_SIZE + CELL_SIZE * 0.5)


func _cell_dist(a: Vector2i, b: Vector2i) -> int:
	var diff := (a - b).abs()
	return maxi(diff.x, diff.y)


func _get_tile_state(cell: Vector2i) -> TileState:
	return _tiles.get(cell, TileState.GRASS) as TileState


func _get_crop_stage(cell: Vector2i) -> int:
	if not _planted_days.has(cell):
		return 0
	var planted_day: int = _planted_days[cell]
	var elapsed := current_day - planted_day
	return clampi(elapsed, 0, 3)


func _update_hud() -> void:
	if _day_label:
		_day_label.text = "Day %d (다음 날: N)" % current_day

	if _mode_label and _inventory:
		var item = _inventory.get_selected_item()
		var slot_num := _inventory.selected_slot + 1
		if item != null:
			if item.get("is_tool", false):
				_mode_label.text = "선택: %s [%d]" % [item.get("name", ""), slot_num]
			else:
				_mode_label.text = "선택: %s x%d [%d]" % [item.get("name", ""), item.get("count", 0), slot_num]
		else:
			_mode_label.text = "선택: 빈 슬롯 [%d]" % slot_num

	if _harvest_label and _inventory:
		_harvest_label.text = "작물 보유량: %d" % _inventory.get_item_count("crop")

	if _money_label and _inventory:
		_money_label.text = "소지금: %d G" % _inventory.money


# --- 개발용: 다음 날 넘기기 (N키) ----------------------------------------------

func _next_day() -> void:
	current_day += 1
	print("--- Day %d ---" % current_day)
	_update_hud()
	queue_redraw()


# --- 매 프레임: 호버 칸 갱신 ---------------------------------------------------

func _process(_delta: float) -> void:
	var new_hover := _world_to_cell(get_global_mouse_position())
	if new_hover != _hover_cell:
		_hover_cell = new_hover
		queue_redraw()


# --- 입력 처리 ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# N키: 다음 날 진행
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			_next_day()
			return

	# 마우스 좌클릭: 농사 상호작용
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_handle_world_click()


# --- 마우스 클릭 처리 (아이템 선택 기반) ---------------------------------------

func _handle_world_click() -> void:
	# 0) 인벤토리나 상점 UI가 열려 있는 상태에서는 월드 클릭 무시
	if _inventory_ui and _inventory_ui.is_inventory_open():
		return
	if _shop_ui and _shop_ui.is_shop_open():
		return

	var clicked_cell := _world_to_cell(get_global_mouse_position())
	var player_cell := _world_to_cell(_player.global_position)
	var dist := _cell_dist(clicked_cell, player_cell)

	# 1) 작업 거리 체크
	if dist > interact_range_cells:
		print("Click — cell (%d, %d) dist %d — Out of range" % [clicked_cell.x, clicked_cell.y, dist])
		return

	var tile_state := _get_tile_state(clicked_cell)

	# 2) 성숙한 작물(Stage 3) 클릭 시 도구에 상관없이 수확 실행
	if tile_state == TileState.PLANTED and _get_crop_stage(clicked_cell) >= 3:
		_harvest_crop(clicked_cell)
		return

	# 3) 현재 선택된 아이템에 따른 농사 행동
	var item = _inventory.get_selected_item() if _inventory else null
	if item == null:
		# 빈 슬롯 선택 시 아무 행동도 하지 않음
		return

	var item_id: String = item.get("id", "")
	match item_id:
		"hoe":
			# 괭이: 잔디를 갈아 밭으로 만듦
			_try_till(clicked_cell, tile_state)
		"seed":
			# 씨앗: 갈린 땅에 씨앗을 심음 (수량 차감)
			_try_plant(clicked_cell, tile_state, item)
		_:
			# 그 외 아이템 (crop 등): 현재는 특별한 농사 행동 없음
			pass


# --- 땅 갈기 (괭이 선택 시) ---------------------------------------------------

func _try_till(cell: Vector2i, state: TileState) -> void:
	if state != TileState.GRASS:
		print("Till — cell (%d, %d) — Already %s" % [cell.x, cell.y, TileState.keys()[state]])
		return

	_tiles[cell] = TileState.TILLED
	print("Till — cell (%d, %d) — Tilled with hoe!" % [cell.x, cell.y])
	queue_redraw()


# --- 씨앗 심기 (씨앗 선택 시) --------------------------------------------------

func _try_plant(cell: Vector2i, state: TileState, item: Dictionary) -> void:
	if state == TileState.GRASS:
		print("Plant — cell (%d, %d) — Must till first" % [cell.x, cell.y])
		return
	if state == TileState.PLANTED:
		print("Plant — cell (%d, %d) — Already planted" % [cell.x, cell.y])
		return

	# 씨앗 수량 확인 및 소모
	var current_count: int = item.get("count", 0)
	if current_count <= 0:
		print("Plant — 씨앗이 부족합니다! (현재: 0개)")
		return

	if not _inventory.consume_selected(1):
		return

	_tiles[cell] = TileState.PLANTED
	_planted_days[cell] = current_day
	print("Plant — cell (%d, %d) — Planted on Day %d! (남은 씨앗: %d)" % [
		cell.x, cell.y, current_day, item.get("count", 0)
	])
	queue_redraw()


# --- 수확 처리 ---------------------------------------------------------------

func _harvest_crop(cell: Vector2i) -> void:
	# 수확 성공: 작물 제거하고 갈린 땅(tilled) 상태 유지
	_tiles[cell] = TileState.TILLED
	_planted_days.erase(cell)

	# 인벤토리에 작물 +1 추가
	_inventory.add_item("crop", 1)

	print("Harvest — cell (%d, %d) — Harvested! 작물 총량: %d" % [
		cell.x, cell.y, _inventory.get_item_count("crop")
	])
	_update_hud()
	queue_redraw()


# --- 그리기 ------------------------------------------------------------------

func _draw() -> void:
	# 1) 칸 상태 표시 (갈린 흙 및 작물)
	for cell: Vector2i in _tiles:
		var state: TileState = _tiles[cell] as TileState
		var rect := Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)

		# 갈린 흙 배경 (도랑 테두리 + 두둑 본체 + 고랑선)
		if state == TileState.TILLED or state == TileState.PLANTED:
			draw_rect(rect, TILLED_BORDER_COLOR)
			var inner_rect := Rect2(rect.position.x + 2, rect.position.y + 2, CELL_SIZE - 4, CELL_SIZE - 4)
			draw_rect(inner_rect, TILLED_MAIN_COLOR)
			draw_line(Vector2(rect.position.x + 4, rect.position.y + 22),
					Vector2(rect.end.x - 4, rect.position.y + 22), TILLED_FURROW_COLOR, 1.5)
			draw_line(Vector2(rect.position.x + 4, rect.position.y + 42),
					Vector2(rect.end.x - 4, rect.position.y + 42), TILLED_FURROW_COLOR, 1.5)

		# 작물 표시
		if state == TileState.PLANTED:
			var center := _cell_center(cell)
			var stage := _get_crop_stage(cell)

			match stage:
				0:
					# Stage 0 (심은 날): 씨앗 홈 + 알갱이
					draw_circle(center + Vector2(0, 2), 6.5, SEED_HOLE_COLOR)
					draw_circle(center + Vector2(-3, 1), 3.5, SEED_COLOR_A)
					draw_circle(center + Vector2(2, 0), 3.0, SEED_COLOR_B)
				1:
					# Stage 1 (1일 경과): 귀여운 연두색 새싹
					draw_circle(center + Vector2(0, 8), 3.0, SEED_HOLE_COLOR)
					draw_line(center + Vector2(0, 8), center + Vector2(0, 0), STEM_COLOR, 2.5)
					draw_circle(center + Vector2(-5, -2), 4.5, SPROUT_LEAF_COLOR)
					draw_circle(center + Vector2(5, -2), 4.5, SPROUT_LEAF_COLOR)
					draw_circle(center + Vector2(0, -7), 7.5, GROW_LEAF_LIGHT)
				2:
					# Stage 2 (2일 경과): 성장 중인 녹색 잎사귀들
					draw_line(center + Vector2(0, 12), center + Vector2(0, -4), STEM_COLOR, 3.5)
					draw_circle(center + Vector2(-9, 2), 6.5, GROW_LEAF_DARK)
					draw_circle(center + Vector2(9, 2), 6.5, GROW_LEAF_DARK)
					draw_circle(center + Vector2(0, -7), 7.5, GROW_LEAF_LIGHT)
				3:
					# Stage 3 (3일 이상 경과): 다 자란 작물 (풍성한 잎 + 큼직한 황금빛 열매)
					draw_circle(center + Vector2(-12, 4), 8.0, MATURE_LEAF_COLOR)
					draw_circle(center + Vector2(12, 4), 8.0, MATURE_LEAF_COLOR)
					draw_circle(center + Vector2(0, -10), 9.0, MATURE_LEAF_COLOR)
					draw_circle(center + Vector2(0, 10), 8.0, MATURE_LEAF_COLOR)
					draw_circle(center, 12.0, MATURE_FRUIT_COLOR)
					draw_circle(center + Vector2(-3, -3), 3.0, MATURE_FRUIT_HI)

	# 2) 호버 하이라이트 (농사 작업이 가능한 아이템을 들고 있고 상점이 닫혀 있을 때만 표시)
	var can_farm := false
	if _shop_ui and _shop_ui.is_shop_open():
		can_farm = false
	elif _inventory:
		var cur_item = _inventory.get_selected_item()
		if cur_item != null:
			var item_id: String = cur_item.get("id", "")
			if item_id == "hoe":
				can_farm = true
			elif item_id == "seed" and cur_item.get("count", 0) > 0:
				can_farm = true

	if can_farm:
		var player_cell := _world_to_cell(_player.global_position)
		var dist := _cell_dist(_hover_cell, player_cell)
		var in_range := dist <= interact_range_cells

		var fill_color: Color = HOVER_IN_FILL if in_range else HOVER_OUT_FILL
		var border_color: Color = HOVER_IN_BORDER if in_range else HOVER_OUT_BORDER

		var hover_rect := Rect2(_hover_cell.x * CELL_SIZE, _hover_cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(hover_rect, fill_color)
		draw_rect(hover_rect, border_color, false, 2.0)
