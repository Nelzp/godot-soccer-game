extends CharacterBody2D

@export var velocidade: float = 200.0
@export var gravidade: float = 980.0

# Direção do movimento: 1 = Direita, -1 = Esquerda
var direcao: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _physics_process(delta: float) -> void:
	# Aplica a gravidade se o inimigo não estiver no chão
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0

	# Movimento horizontal automático
	velocity.x = direcao * velocidade

	# Move o personagem lidando com colisões
	move_and_slide()

	# Se colidir com uma parede, inverte a direção
	if is_on_wall():
		inverter_direcao()

	# Atualiza o visual e as animações
	atualizar_animacao()

func inverter_direcao() -> void:
	direcao *= -1

func atualizar_animacao() -> void:
	# Ajusta o espelhamento do Sprite
	if direcao > 0:
		sprite.flip_h = false
	elif direcao < 0:
		sprite.flip_h = true

	# Toca a animação correspondente
	if abs(velocity.x) > 0:
		if animation_player.has_animation("correndo"):
			animation_player.play("correndo")
		elif animation_player.has_animation("walk"):
			animation_player.play("walk")
	else:
		if animation_player.has_animation("parado"):
			animation_player.play("parado")
		elif animation_player.has_animation("idle"):
			animation_player.play("idle")
