
extends CharacterBody2D
## Cartão lançado pelo Juiz (amarelo) e pelo Chefão (vermelho).
## - Só causa dano ao jogador (grupo "jogador").
## - Atravessa outros inimigos e projéteis sem machucá-los.
## - Some ao acertar o jogador, uma parede, um obstáculo ou o chão.
## - Some sozinho depois de tempo_de_vida segundos ou de percorrer
##   alcance_maximo px (se definido), apagando rapidamente.
## - Voo: em linha reta na direção `vetor` (mira do Juiz); sem `vetor`, voa na
##   horizontal para `direcao` e, se altura_alvo for definida, sobe ou desce
##   até essa altura (cartões do Chefão).

var direcao = 1
## Direção do voo (normalizada). Vector2.ZERO = horizontal, para `direcao`.
var vetor: Vector2 = Vector2.ZERO

## Velocidade (px/s).
@export var velocidade: float = 700.0
## Tempo máximo (s) até o cartão sumir, mesmo sem acertar nada.
@export var tempo_de_vida: float = 4.0
## Distância máxima (px) do voo. 0 = sem limite (vale só o tempo de vida).
@export var alcance_maximo: float = 0.0
## Velocidade máxima (px/s) para alcançar a altura_alvo.
@export var velocidade_vertical: float = 420.0

## Altura (y global) que o cartão procura durante o voo. NAN = voa reto.
var altura_alvo: float = NAN

var removendo: bool = false
var _percorrido: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:

	add_to_group("projeteis")
	add_to_group("projeteis_inimigos")

	if vetor != Vector2.ZERO:
		vetor = vetor.normalized()
		direcao = 1 if vetor.x >= 0.0 else -1

	# O desenho do cartão voa para a direita
	sprite.flip_h = direcao < 0

	# O tempo de vida para quando o jogo está pausado
	get_tree().create_timer(tempo_de_vida, false).timeout.connect(_apagar)


func _physics_process(delta: float) -> void:

	if removendo:
		return

	sprite.flip_h = direcao < 0

	if vetor != Vector2.ZERO:
		velocity = vetor * velocidade
	else:
		velocity.x = velocidade * direcao
		velocity.y = 0.0

		if not is_nan(altura_alvo) and delta > 0.0:
			velocity.y = clampf((altura_alvo - global_position.y) / delta, -velocidade_vertical, velocidade_vertical)

	var antes := global_position

	move_and_slide()

	_percorrido += global_position.distance_to(antes)

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto == null or not (objeto is Node):
			continue

		# Acertou o jogador
		if objeto.is_in_group("jogador"):

			if objeto.has_method("receber_dano"):
				# De onde veio o golpe: o jogador recua para o outro lado
				var sentido := vetor if vetor != Vector2.ZERO else Vector2(direcao, 0.0)
				objeto.receber_dano(global_position - sentido * 40.0)

			remover()
			return

		# Outros inimigos e projéteis: atravessa, sem causar dano
		if objeto.is_in_group("inimigos") or objeto.is_in_group("projeteis"):
			add_collision_exception_with(objeto)
			continue

		# Qualquer outra coisa (parede, obstáculo, chão): desaparece
		remover()
		return

	if alcance_maximo > 0.0 and _percorrido >= alcance_maximo:
		_apagar()


## Some na hora (acertou algo).
func remover() -> void:

	if removendo:
		return

	removendo = true
	get_parent().queue_free()


## Fim do alcance ou do tempo: apaga rápido em vez de sumir de repente.
func _apagar() -> void:

	if removendo:
		return

	removendo = true
	collision_layer = 0
	collision_mask = 0

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(get_parent().queue_free)
