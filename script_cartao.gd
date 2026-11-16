
extends CharacterBody2D
## Cartão lançado pelo Juiz.
## - Só causa dano ao jogador (grupo "jogador").
## - Atravessa outros inimigos e projéteis sem machucá-los.
## - Some ao acertar o jogador, uma parede ou um obstáculo.
## - Some sozinho depois de tempo_de_vida segundos.

var direcao = 1
var velocidade = 700

## Tempo máximo (s) até o cartão sumir, mesmo sem acertar nada.
@export var tempo_de_vida: float = 4.0

var removendo: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:

	add_to_group("projeteis")

	# O desenho do cartão voa para a direita
	sprite.flip_h = direcao < 0

	# O tempo de vida para quando o jogo está pausado
	get_tree().create_timer(tempo_de_vida, false).timeout.connect(remover)


func _physics_process(delta: float) -> void:

	if removendo:
		return

	sprite.flip_h = direcao < 0

	velocity.x = velocidade * direcao
	velocity.y = 0

	move_and_slide()

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto == null or not (objeto is Node):
			continue

		# Acertou o jogador
		if objeto.is_in_group("jogador"):

			if objeto.has_method("receber_dano"):
				objeto.receber_dano()

			remover()
			return

		# Outros inimigos e projéteis: atravessa, sem causar dano
		if objeto.is_in_group("inimigos") or objeto.is_in_group("projeteis"):
			add_collision_exception_with(objeto)
			continue

		# Qualquer outra coisa (parede, obstáculo): desaparece
		remover()
		return


func remover() -> void:

	if removendo:
		return

	removendo = true
	get_parent().queue_free()
