extends StaticBody2D

var _is_player_near: bool = false
var _shop_ui: ShopUI

@onready var _prompt_label: Label = $PromptLabel
@onready var _interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	if _prompt_label:
		_prompt_label.visible = false

	if _interaction_area:
		_interaction_area.body_entered.connect(_on_body_entered)
		_interaction_area.body_exited.connect(_on_body_exited)


func set_shop_ui(ui: ShopUI) -> void:
	_shop_ui = ui


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D: # 플레이어
		_is_player_near = true
		if _prompt_label:
			_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_is_player_near = false
		if _prompt_label:
			_prompt_label.visible = false
		# 범위 밖으로 나가면 상점 닫기
		if _shop_ui and _shop_ui.is_shop_open():
			_shop_ui.close_shop()


func _unhandled_input(event: InputEvent) -> void:
	if _is_player_near and _shop_ui and not _shop_ui.is_shop_open():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_E:
				_shop_ui.open_shop()
				get_viewport().set_input_as_handled()
