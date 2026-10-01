extends Control
class_name ShopUI

const SEED_BUY_PRICE_1 := 10
const SEED_BUY_PRICE_5 := 50
const CROP_SELL_PRICE := 20

var inventory: Inventory
var player: CharacterBody2D
var inventory_ui: InventoryUI

# UI 노드 참조
@onready var _panel: Panel = $Window
@onready var _money_label: Label = $Window/VBox/MoneyLabel
@onready var _seed_info_label: Label = $Window/VBox/SeedSection/SeedInfoLabel
@onready var _crop_info_label: Label = $Window/VBox/CropSection/CropInfoLabel

@onready var _btn_buy_1: Button = $Window/VBox/SeedSection/BtnHBox/Buy1Btn
@onready var _btn_buy_5: Button = $Window/VBox/SeedSection/BtnHBox/Buy5Btn
@onready var _btn_sell_1: Button = $Window/VBox/CropSection/BtnHBox/Sell1Btn
@onready var _btn_sell_all: Button = $Window/VBox/CropSection/BtnHBox/SellAllBtn
@onready var _btn_close: Button = $Window/VBox/CloseBtn


func _ready() -> void:
	visible = false
	_connect_buttons()


func setup(inv: Inventory, ply: CharacterBody2D, inv_ui: InventoryUI) -> void:
	inventory = inv
	player = ply
	inventory_ui = inv_ui

	if inventory:
		inventory.money_changed.connect(func(_val): refresh())
		inventory.inventory_changed.connect(func(): refresh())


func _connect_buttons() -> void:
	if _btn_buy_1:
		_btn_buy_1.pressed.connect(_on_buy_1_pressed)
	if _btn_buy_5:
		_btn_buy_5.pressed.connect(_on_buy_5_pressed)
	if _btn_sell_1:
		_btn_sell_1.pressed.connect(_on_sell_1_pressed)
	if _btn_sell_all:
		_btn_sell_all.pressed.connect(_on_sell_all_pressed)
	if _btn_close:
		_btn_close.pressed.connect(close_shop)


func is_shop_open() -> bool:
	return visible


func open_shop() -> void:
	# 인벤토리 창이 열려 있다면 닫기
	if inventory_ui and inventory_ui.is_inventory_open():
		inventory_ui.toggle_inventory_window()

	visible = true
	if player:
		player.can_move = false

	refresh()


func close_shop() -> void:
	visible = false
	if player:
		player.can_move = true


func refresh() -> void:
	if not inventory or not visible:
		return

	var current_money := inventory.money
	var seed_count := inventory.get_item_count("seed")
	var crop_count := inventory.get_item_count("crop")

	if _money_label:
		_money_label.text = "보유 금액: %d G" % current_money

	if _seed_info_label:
		_seed_info_label.text = "씨앗 (구매: 10 G)  |  보유 수량: %d 개" % seed_count

	if _crop_info_label:
		_crop_info_label.text = "작물 (판매: 20 G)  |  보유 수량: %d 개" % crop_count

	if _btn_sell_all:
		var total_sell_val := crop_count * CROP_SELL_PRICE
		_btn_sell_all.text = "전부 판매 (+%d G)" % total_sell_val


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# E키 또는 Esc키로 상점 닫기
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			close_shop()
			get_viewport().set_input_as_handled()
			return
		# 상점 열려 있을 때 I키(인벤토리) 차단
		elif event.keycode == KEY_I:
			get_viewport().set_input_as_handled()
			return


# --- 버튼 콜백 ---------------------------------------------------------------

func _on_buy_1_pressed() -> void:
	if not inventory:
		return
	if inventory.spend_money(SEED_BUY_PRICE_1):
		inventory.add_item("seed", 1)
		refresh()


func _on_buy_5_pressed() -> void:
	if not inventory:
		return
	if inventory.spend_money(SEED_BUY_PRICE_5):
		inventory.add_item("seed", 5)
		refresh()


func _on_sell_1_pressed() -> void:
	if not inventory:
		return
	if inventory.get_item_count("crop") >= 1:
		if inventory.remove_item("crop", 1):
			inventory.add_money(CROP_SELL_PRICE)
			refresh()


func _on_sell_all_pressed() -> void:
	if not inventory:
		return
	var total_crop := inventory.get_item_count("crop")
	if total_crop > 0:
		if inventory.remove_item("crop", total_crop):
			inventory.add_money(total_crop * CROP_SELL_PRICE)
			refresh()
