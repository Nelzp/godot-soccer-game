
extends "res://inimigo_base.gd"
## Inimigo que patrulha (base do Zagueiro rival, concluído na P4).
## Vida, dano e morte vêm de inimigo_base.gd.

@export var velocidade: float = 200.0
@export var gravidade: float = 980.0

# Direção do movimento: 1 = Direita, -1 = Esquerda
var direcao: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _physics_process(delta: float) -> void:

	if morrendo:
		return

	# Aplica gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0

	# Movimento horizontal automático
	velocity.x = direcao * velocidade

	move_and_slide()

	# Inverte a direção ao encontrar uma parede
	if is_on_wall():
		inverter_direcao()

	atualizar_animacao()


func inverter_direcao() -> void:
	direcao *= -1


func atualizar_animacao() -> void:

	if direcao > 0:
		sprite.flip_h = false
	else:
		sprite.flip_h = true

	if abs(velocity.x) > 0:
		if animation_player.has_animation("correndo"):
			animation_player.play("correndo")
		elif animation_player.has_animation("walk"):
			animation_player.play("walk")

# A morte (piscar e sumir) agora fica em inimigo_base.gd
