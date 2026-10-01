extends Node
class_name Inventory

signal inventory_changed
signal money_changed(new_money: int)
signal selected_slot_changed(new_index: int)

const HOTBAR_SIZE := 9
const INVENTORY_SIZE := 27
const TOTAL_SLOTS := HOTBAR_SIZE + INVENTORY_SIZE # 9 + 27 = 36

## 플레이어 소지금 (시작 100 G)
var money: int = 100

## 현재 선택된 핫바 슬롯 (0 ~ 8)
var selected_slot: int = 0

## 슬롯 배열 (0~8은 핫바, 9~35는 3x9 인벤토리 보관함)
## 각 원소는 null 또는 Dictionary { "id", "name", "count", "is_tool", "description" }
var slots: Array = []


func _init() -> void:
	_init_slots()


func _init_slots() -> void:
	slots.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		slots[i] = null

	# 초기 배치 (핫바 1, 2, 3번 슬롯)
	# 1번 슬롯: 괭이 (도구)
	slots[0] = {
		"id": "hoe",
		"name": "괭이",
		"count": 1,
		"is_tool": true,
		"description": "땅을 갈아 밭을 만듭니다."
	}
	# 2번 슬롯: 씨앗 x5 (요구사항: 시작 5개)
	slots[1] = {
		"id": "seed",
		"name": "씨앗",
		"count": 5,
		"is_tool": false,
		"description": "갈린 땅에 심을 수 있습니다."
	}
	# 3번 슬롯: 작물 x0
	slots[2] = {
		"id": "crop",
		"name": "작물",
		"count": 0,
		"is_tool": false,
		"description": "수확한 작물입니다."
	}


# --- 돈 관리 ------------------------------------------------------------------

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)
	print("Money added: +%d G (Total: %d G)" % [amount, money])


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		print("돈이 부족합니다! (필요: %d G, 보유: %d G)" % [amount, money])
		return false
	money -= amount
	money_changed.emit(money)
	print("Money spent: -%d G (Remaining: %d G)" % [amount, money])
	return true


# --- 슬롯 선택 ----------------------------------------------------------------

func select_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	if selected_slot != index:
		selected_slot = index
		selected_slot_changed.emit(selected_slot)


func get_selected_item() -> Variant:
	if selected_slot >= 0 and selected_slot < slots.size():
		return slots[selected_slot]
	return null


func get_slot(index: int) -> Variant:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


# --- 슬롯 이동 / 교환 --------------------------------------------------------

func move_or_swap_slot(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= TOTAL_SLOTS or to_idx < 0 or to_idx >= TOTAL_SLOTS:
		return
	if from_idx == to_idx:
		return

	var from_item = slots[from_idx]
	if from_item == null:
		return

	var to_item = slots[to_idx]

	if to_item == null:
		# 1) 빈 슬롯으로 이동
		slots[to_idx] = from_item
		slots[from_idx] = null
	elif to_item.get("id") == from_item.get("id") and not from_item.get("is_tool", false):
		# 2) 같은 종류의 스택 가능 아이템이면 수량 합치기
		to_item["count"] = to_item.get("count", 0) + from_item.get("count", 0)
		slots[from_idx] = null
	else:
		# 3) 다른 종류이거나 도구이면 위치 교환 (Swap)
		slots[to_idx] = from_item
		slots[from_idx] = to_item

	inventory_changed.emit()


# --- 아이템 소모 및 추가 ------------------------------------------------------

func consume_selected(amount: int = 1) -> bool:
	var item = get_selected_item()
	if item == null:
		return false
	if item.get("is_tool", false):
		return true

	var current_count: int = item.get("count", 0)
	if current_count < amount:
		return false

	item["count"] = current_count - amount
	inventory_changed.emit()
	return true


func add_item(id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true

	# 1) 기존 동일 아이템 슬롯에 누적
	for i in range(slots.size()):
		var item = slots[i]
		if item != null and item.get("id") == id and not item.get("is_tool", false):
			item["count"] = item.get("count", 0) + amount
			inventory_changed.emit()
			return true

	# 2) 없으면 첫 빈 슬롯에 등록
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = {
				"id": id,
				"name": _get_default_name(id),
				"count": amount,
				"is_tool": false,
				"description": ""
			}
			inventory_changed.emit()
			return true

	return false


## 특정 아이템을 지정 수량만큼 제거 (판매 등)
func remove_item(id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if get_item_count(id) < amount:
		return false

	var remaining := amount
	# 뒤쪽 슬롯부터 차감하여 앞쪽 슬롯/핫바 보존
	for i in range(slots.size() - 1, -1, -1):
		var item = slots[i]
		if item != null and item.get("id") == id and not item.get("is_tool", false):
			var count: int = item.get("count", 0)
			if count <= 0:
				continue
			var take: int = mini(count, remaining)
			item["count"] = count - take
			remaining -= take
			if remaining <= 0:
				break

	inventory_changed.emit()
	return true


func get_item_count(id: String) -> int:
	var total := 0
	for item in slots:
		if item != null and item.get("id") == id:
			total += item.get("count", 0)
	return total


func _get_default_name(id: String) -> String:
	match id:
		"hoe": return "괭이"
		"seed": return "씨앗"
		"crop": return "작물"
		_: return id
