extends Control
class_name InventoryUI

# --- 내부 슬롯 패널 클래스 (Drag & Drop 및 클릭 지원) ---------------------------
class InventorySlotPanel extends Panel:
	var slot_index: int = 0
	var is_hotbar: bool = false
	var ui: InventoryUI

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 핫바 슬롯 클릭 시 즉시 선택
			if is_hotbar and ui and ui.inventory:
				ui.inventory.select_slot(slot_index)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if not ui or not ui.inventory:
			return null
		var item = ui.inventory.get_slot(slot_index)
		if item == null:
			return null

		# 드래그 미리보기 (커서 따라다니는 반투명 아이콘)
		var preview := Control.new()
		var p_panel := Panel.new()
		p_panel.custom_minimum_size = Vector2(50, 50)
		p_panel.size = Vector2(50, 50)
		p_panel.position = Vector2(-25, -25)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.22, 0.9)
		style.border_color = Color(1.0, 0.84, 0.30, 0.95)
		style.set_border_width_all(2)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		p_panel.add_theme_stylebox_override("panel", style)

		var icon_box := Control.new()
		icon_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p_panel.add_child(icon_box)
		ui.render_item_icon(icon_box, item.get("id", ""))

		if not item.get("is_tool", false):
			var count_lbl := Label.new()
			count_lbl.text = "x%d" % item.get("count", 0)
			count_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			count_lbl.offset_left = -38
			count_lbl.offset_top = -18
			count_lbl.offset_right = -4
			count_lbl.offset_bottom = -2
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_lbl.add_theme_font_size_override("font_size", 10)
			count_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82))
			p_panel.add_child(count_lbl)

		preview.add_child(p_panel)
		set_drag_preview(preview)

		return { "slot_index": slot_index, "item": item }

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("slot_index")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is Dictionary and data.has("slot_index"):
			var from_idx: int = data["slot_index"]
			if ui and ui.inventory:
				ui.inventory.move_or_swap_slot(from_idx, slot_index)


## 인벤토리 데이터 참조
var inventory: Inventory

## 슬롯 UI 노드 배열
var _hotbar_slot_nodes: Array = []
var _inv_slot_nodes: Array = []

## UI 노드 참조
var _hotbar_container: HBoxContainer
var _selected_item_label: Label
var _inv_window: Panel
var _inv_grid: GridContainer

var _is_ui_built: bool = false


func _ready() -> void:
	_ensure_nodes()

	if inventory and not _is_ui_built:
		_init_ui()
	elif not inventory:
		var inv_node = get_tree().root.find_child("Inventory", true, false)
		if inv_node is Inventory:
			setup(inv_node)


func _ensure_nodes() -> void:
	if not _hotbar_container:
		_hotbar_container = get_node_or_null("Hotbar/HBox") as HBoxContainer
	if not _selected_item_label:
		_selected_item_label = get_node_or_null("Hotbar/SelectedItemLabel") as Label
	if not _inv_window:
		_inv_window = get_node_or_null("InventoryWindow") as Panel
	if not _inv_grid:
		_inv_grid = get_node_or_null("InventoryWindow/VBox/GridContainer") as GridContainer


func setup(inv: Inventory) -> void:
	inventory = inv
	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if not inventory.selected_slot_changed.is_connected(_on_selected_slot_changed):
		inventory.selected_slot_changed.connect(_on_selected_slot_changed)

	if is_node_ready():
		_init_ui()


func _init_ui() -> void:
	_ensure_nodes()
	if not _hotbar_container or not _inv_grid:
		return

	_build_hotbar_slots()
	_build_inventory_slots()
	_is_ui_built = true
	refresh_all()


func is_inventory_open() -> bool:
	return _inv_window != null and _inv_window.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# I키: 인벤토리 창 열기/닫기 토글
		if event.keycode == KEY_I:
			var shop_ui = get_node_or_null("../ShopUI") as ShopUI
			if shop_ui and shop_ui.is_shop_open():
				get_viewport().set_input_as_handled()
				return

			toggle_inventory_window()
			get_viewport().set_input_as_handled()
			return
		# 1 ~ 9 키: 핫바 슬롯 선택
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var slot_idx: int = event.keycode - KEY_1
			if inventory:
				inventory.select_slot(slot_idx)
			get_viewport().set_input_as_handled()
			return


func toggle_inventory_window() -> void:
	_ensure_nodes()
	if _inv_window:
		_inv_window.visible = not _inv_window.visible
		if _inv_window.visible:
			refresh_inventory_window()


# --- 핫바 슬롯 UI 생성 (슬롯 0 ~ 8) -------------------------------------------

func _build_hotbar_slots() -> void:
	if not _hotbar_container:
		return

	for child in _hotbar_container.get_children():
		child.queue_free()
	_hotbar_slot_nodes.clear()

	for i in range(Inventory.HOTBAR_SIZE):
		var slot_panel := _create_slot_panel(i, true)
		_hotbar_container.add_child(slot_panel)
		_hotbar_slot_nodes.append(slot_panel)


# --- 인벤토리 창 슬롯 UI 생성 (3x9 = 27칸, 슬롯 9 ~ 35) -----------------------

func _build_inventory_slots() -> void:
	if not _inv_grid:
		return

	for child in _inv_grid.get_children():
		child.queue_free()
	_inv_slot_nodes.clear()

	for i in range(Inventory.INVENTORY_SIZE):
		var actual_idx := Inventory.HOTBAR_SIZE + i # 9 ~ 35
		var slot_panel := _create_slot_panel(actual_idx, false)
		_inv_grid.add_child(slot_panel)
		_inv_slot_nodes.append(slot_panel)


# --- 슬롯 패널 생성 헬퍼 ------------------------------------------------------

func _create_slot_panel(index: int, is_hotbar: bool) -> InventorySlotPanel:
	var panel := InventorySlotPanel.new()
	panel.slot_index = index
	panel.is_hotbar = is_hotbar
	panel.ui = self
	panel.custom_minimum_size = Vector2(52, 52)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# 1) 슬롯 번호 라벨 (핫바 슬롯에만 1~9 표시)
	if is_hotbar:
		var num_lbl := Label.new()
		num_lbl.name = "NumLabel"
		num_lbl.text = str(index + 1)
		num_lbl.offset_left = 4
		num_lbl.offset_top = 2
		num_lbl.add_theme_font_size_override("font_size", 10)
		num_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.78, 0.85))
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(num_lbl)

	# 2) 아이콘 컨테이너
	var icon_box := Control.new()
	icon_box.name = "IconBox"
	icon_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_box)

	# 3) 수량 라벨 (우하단)
	var count_lbl := Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count_lbl.offset_left = -40
	count_lbl.offset_top = -18
	count_lbl.offset_right = -4
	count_lbl.offset_bottom = -2
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82))
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(count_lbl)

	# 4) 아이템 이름 라벨 (인벤토리 창 슬롯 상단 표시)
	if not is_hotbar:
		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		name_lbl.offset_left = 2
		name_lbl.offset_top = 2
		name_lbl.offset_right = -2
		name_lbl.offset_bottom = 16
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.9))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(name_lbl)

	return panel


# --- 슬롯 시각 업데이트 -------------------------------------------------------

func _update_slot_view(panel: InventorySlotPanel, item: Variant, is_selected: bool, is_hotbar: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6

	if is_selected and is_hotbar:
		# 선택된 슬롯: 황금빛 강조 테두리 + 밝은 배경
		style.bg_color = Color(0.14, 0.18, 0.23, 0.95)
		style.border_color = Color(1.0, 0.84, 0.30, 1.0)
		style.set_border_width_all(2)
	else:
		# 기본 슬롯
		style.bg_color = Color(0.08, 0.11, 0.14, 0.85)
		style.border_color = Color(0.24, 0.32, 0.38, 0.6)
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)

	# 아이콘 업데이트
	var icon_box: Control = panel.get_node_or_null("IconBox")
	if icon_box:
		for child in icon_box.get_children():
			child.queue_free()

		if item != null:
			render_item_icon(icon_box, item.get("id", ""))

	# 수량 업데이트
	var count_lbl: Label = panel.get_node_or_null("CountLabel")
	if count_lbl:
		if item != null and not item.get("is_tool", false):
			count_lbl.text = "x%d" % item.get("count", 0)
			count_lbl.visible = true
		else:
			count_lbl.visible = false

	# 인벤토리 창의 이름 라벨 업데이트
	var name_lbl: Label = panel.get_node_or_null("NameLabel")
	if name_lbl:
		if item != null:
			name_lbl.text = item.get("name", "")
			name_lbl.visible = true
		else:
			name_lbl.visible = false


# --- 임시 아이콘 렌더링 (도형 기반) -------------------------------------------

func render_item_icon(parent: Control, item_id: String) -> void:
	match item_id:
		"hoe":
			# 괭이: 갈색 손잡이 + 은색 날
			var handle := ColorRect.new()
			handle.color = Color(0.55, 0.35, 0.18)
			handle.size = Vector2(4, 22)
			handle.position = Vector2(24, 18)
			handle.rotation_degrees = -30
			handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(handle)

			var blade := ColorRect.new()
			blade.color = Color(0.80, 0.85, 0.90)
			blade.size = Vector2(14, 5)
			blade.position = Vector2(23, 15)
			blade.rotation_degrees = 15
			blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(blade)

		"seed":
			# 씨앗: 황갈색 씨앗 알갱이들
			var seed1 := ColorRect.new()
			seed1.color = Color(0.72, 0.58, 0.35)
			seed1.size = Vector2(7, 7)
			seed1.position = Vector2(19, 21)
			seed1.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(seed1)

			var seed2 := ColorRect.new()
			seed2.color = Color(0.85, 0.70, 0.42)
			seed2.size = Vector2(6, 6)
			seed2.position = Vector2(27, 24)
			seed2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(seed2)

		"crop":
			# 작물: 녹색 잎 + 황금빛 둥근 열매
			var leaf := ColorRect.new()
			leaf.color = Color(0.22, 0.65, 0.22)
			leaf.size = Vector2(8, 8)
			leaf.position = Vector2(22, 16)
			leaf.rotation_degrees = 45
			leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(leaf)

			var fruit := ColorRect.new()
			fruit.color = Color(0.98, 0.65, 0.15)
			fruit.size = Vector2(16, 16)
			fruit.position = Vector2(18, 20)
			fruit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(fruit)


# --- 전체 갱신 ---------------------------------------------------------------

func refresh_all() -> void:
	refresh_hotbar()
	refresh_inventory_window()


func refresh_hotbar() -> void:
	if not inventory:
		return

	for i in range(_hotbar_slot_nodes.size()):
		var panel: InventorySlotPanel = _hotbar_slot_nodes[i]
		var item = inventory.get_slot(i)
		var is_selected := (i == inventory.selected_slot)
		_update_slot_view(panel, item, is_selected, true)

	# 핫바 상단 선택 아이템 이름 표시
	if _selected_item_label:
		var cur_item = inventory.get_selected_item()
		if cur_item != null:
			if cur_item.get("is_tool", false):
				_selected_item_label.text = "[ %s ]" % cur_item.get("name", "")
			else:
				_selected_item_label.text = "[ %s ] x%d" % [cur_item.get("name", ""), cur_item.get("count", 0)]
		else:
			_selected_item_label.text = "[ 빈 슬롯 ]"


func refresh_inventory_window() -> void:
	if not inventory or not _inv_window or not _inv_window.visible:
		return

	for i in range(_inv_slot_nodes.size()):
		var panel: InventorySlotPanel = _inv_slot_nodes[i]
		var actual_idx := Inventory.HOTBAR_SIZE + i
		var item = inventory.get_slot(actual_idx)
		_update_slot_view(panel, item, false, false)


func _on_inventory_changed() -> void:
	refresh_all()


func _on_selected_slot_changed(_new_idx: int) -> void:
	refresh_all()
