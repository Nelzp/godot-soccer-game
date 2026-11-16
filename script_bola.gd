extends CharacterBody2D
## Bola chutada pelo jogador.
## - Causa dano a inimigos (grupo "inimigos") e some.
## - Some ao bater de frente em qualquer outra coisa (parede, obstáculo, chefão...).
## - Rola pelo chão sem sumir e nunca colide com quem a chutou.
## - Some sozinha depois de tempo_de_vida segundos.

var direcao = 1
var velocidade = 650

## Dano causado a um inimigo atingido.
@export var dano: int = 1
## Tempo máximo (s) até a bola sumir, mesmo sem acertar nada.
@export var tempo_de_vida: float = 2.5

var removendo: bool = false

@onready var animacao: AnimationPlayer = $AnimationPlayer


func _ready() -> void:

	add_to_group("projeteis")

	# Gira no sentido em que a bola está indo
	if direcao < 0:
		animacao.play_backwards("rolando")
	else:
		animacao.play("rolando")

	# O tempo de vida para quando o jogo está pausado
	get_tree().create_timer(tempo_de_vida, false).timeout.connect(remover)


func _physics_process(_delta: float) -> void:

	if removendo:
		return

	velocity.x = velocidade * direcao
	velocity.y = 0

	move_and_slide()

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto == null or not (objeto is Node):
			continue

		# Inimigo vivo: causa dano e some
		if objeto.is_in_group("inimigos") and objeto.has_method("receber_dano"):
			objeto.receber_dano(dano)
			remover()
			return

		# Batida de frente (parede, obstáculo, chefão...): some.
		# O contato com o chão (normal apontando para cima) é ignorado.
		if absf(colisao.get_normal().x) >= 0.5:
			remover()
			return


func remover() -> void:

	if removendo:
		return

	removendo = true
	get_parent().queue_free()
