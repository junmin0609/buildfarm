extends CharacterBody2D

## 이동 속도 (픽셀/초). 인스펙터에서 변경 가능.
@export var speed: float = 200.0

## 이동 가능 여부 (상점 UI 열릴 때 false)
var can_move: bool = true


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return

	# 입력 벡터 구하기
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0

	# 대각선 이동 시 속도가 빨라지지 않도록 정규화
	if input.length() > 0.0:
		input = input.normalized()

	velocity = input * speed
	move_and_slide()
