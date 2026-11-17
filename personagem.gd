
extends "res://inimigo_base.gd"
## Zagueiro rival (cena_inimigo2.tscn).
## Vida, dano e morte vêm de inimigo_base.gd.
##
## - Patrulha correndo; vira nas paredes, nos obstáculos e nos limites de
##   patrulha (se definidos).
## - Quando o jogador está no chão, à frente e perto, para, se prepara (aviso)
##   e dá um carrinho: avança rápido e, se encostar no jogador, tira 1 vida e
##   o empurra. Dá para escapar pulando por cima.
## - Depois do carrinho fica parado um instante (hora de atacar) e só repete
##   depois da recarga.
## - Tem 2 de vida: a bola tira 1 (ele cambaleia) e o carrinho do jogador tira 2.

enum Estado {
	PATRULHANDO,
	PREPARANDO,
	DESLIZANDO,
	RECUPERANDO,
	ATORDOADO,
}

@export var velocidade: float = 200.0
@export var gravidade: float = 980.0

@export_group("Patrulha")
## Até quantos px para cada lado do ponto de partida o zagueiro patrulha
## (0 = sem limite, vira só em paredes e obstáculos).
@export var raio_patrulha: float = 260.0

@export_group("Carrinho")
## Distância (px, de centro a centro) em que o zagueiro parte para o carrinho.
@export var distancia_carrinho: float = 250.0
## Tempo (s) de aviso antes do carrinho.
@export var tempo_preparo: float = 0.4
@export var velocidade_carrinho: float = 480.0
## Duração (s) do avanço do carrinho (cobre os quadros de deslize da animação).
@export var duracao_carrinho: float = 1.0
## Pausa (s) depois do carrinho, em que fica vulnerável.
@export var tempo_recuperacao: float = 0.8
## Tempo (s) mínimo entre um carrinho e outro.
@export var recarga_carrinho: float = 1.6
@export var empurrao_carrinho: Vector2 = Vector2(380.0, -300.0)

# Direção do movimento: 1 = Direita, -1 = Esquerda
var direcao: int = 1
var estado: Estado = Estado.PATRULHANDO
var tempo_no_estado: float = 0.0
var recarga: float = 0.0
var acertou_no_carrinho: bool = false
var estava_na_parede: bool = false
## Quanto tempo (s) dura a pausa atual (recuperação ou atordoamento).
var _duracao_pausa: float = 0.0
var _x_inicial: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_x_inicial = global_position.x
	atualizar_animacao()


func _physics_process(delta: float) -> void:

	if morrendo:
		return

	# Aplica gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0

	tempo_no_estado += delta
	recarga = maxf(recarga - delta, 0.0)

	match estado:

		Estado.PATRULHANDO:
			velocity.x = direcao * velocidade
			_procurar_jogador()

		Estado.PREPARANDO:
			velocity.x = 0.0
			if tempo_no_estado >= tempo_preparo:
				_iniciar_carrinho()

		Estado.DESLIZANDO:
			# Avança rápido e perde força no fim do carrinho
			var progresso := clampf(tempo_no_estado / duracao_carrinho, 0.0, 1.0)
			velocity.x = direcao * velocidade_carrinho * (1.0 - progresso * progresso * 0.6)
			if tempo_no_estado >= duracao_carrinho:
				_iniciar_recuperacao(tempo_recuperacao)

		Estado.RECUPERANDO, Estado.ATORDOADO:
			velocity.x = 0.0
			if tempo_no_estado >= _duracao_pausa:
				_mudar_estado(Estado.PATRULHANDO)

	move_and_slide()

	if estado == Estado.DESLIZANDO:
		_verificar_acerto_do_carrinho()

	# Inverte a direção ao encontrar uma parede (uma vez por batida)
	var parede_agora := is_on_wall()

	if parede_agora and not estava_na_parede:
		if estado == Estado.PATRULHANDO:
			inverter_direcao()
		elif estado == Estado.DESLIZANDO:
			# Bateu numa parede ou obstáculo: o carrinho acaba ali
			_iniciar_recuperacao(tempo_recuperacao)

	estava_na_parede = parede_agora

	# Limites de patrulha em volta do ponto de partida
	if estado == Estado.PATRULHANDO and raio_patrulha > 0.0:
		if global_position.x <= _x_inicial - raio_patrulha and direcao < 0:
			inverter_direcao()
		elif global_position.x >= _x_inicial + raio_patrulha and direcao > 0:
			inverter_direcao()

	atualizar_animacao()


func inverter_direcao() -> void:
	direcao *= -1


# ---------------------------------------------------------------------------
# Carrinho
# ---------------------------------------------------------------------------

func _procurar_jogador() -> void:

	if recarga > 0.0:
		return

	var jogador := buscar_jogador() as CharacterBody2D

	if jogador == null or not jogador.is_on_floor():
		return

	var dx := jogador.global_position.x - global_position.x

	if absf(dx) > distancia_carrinho:
		return

	# Precisa estar mais ou menos na mesma altura (no mesmo chão)
	if absf(jogador.global_position.y - global_position.y) > 70.0:
		return

	# Jogador às costas: o zagueiro vira e se prepara do mesmo jeito
	direcao = 1 if dx > 0.0 else -1
	_mudar_estado(Estado.PREPARANDO)


func _iniciar_carrinho() -> void:

	acertou_no_carrinho = false
	_mudar_estado(Estado.DESLIZANDO)
	animation_player.play("carrinho")
	animation_player.seek(0.0, true)


func _verificar_acerto_do_carrinho() -> void:

	if acertou_no_carrinho:
		return

	var alvo: Node = null

	for i in range(get_slide_collision_count()):
		var objeto = get_slide_collision(i).get_collider()
		if objeto is Node and objeto.is_in_group("jogador"):
			alvo = objeto
			break

	# Encostado no jogador mesmo sem ter se movido neste quadro
	if alvo == null:
		var contato := KinematicCollision2D.new()
		if test_move(global_transform, Vector2(direcao * 6.0, 0.0), contato):
			var objeto = contato.get_collider()
			if objeto is Node and objeto.is_in_group("jogador"):
				alvo = objeto

	if alvo == null:
		return

	acertou_no_carrinho = true

	if alvo.has_method("receber_dano"):
		alvo.receber_dano()

	if alvo.has_method("empurrar"):
		alvo.empurrar(Vector2(empurrao_carrinho.x * direcao, empurrao_carrinho.y))

	# O carrinho para no jogador
	_iniciar_recuperacao(tempo_recuperacao)


func _iniciar_recuperacao(duracao: float) -> void:

	recarga = recarga_carrinho
	_duracao_pausa = duracao
	_mudar_estado(Estado.RECUPERANDO)


func _mudar_estado(novo: Estado) -> void:

	estado = novo
	tempo_no_estado = 0.0


# ---------------------------------------------------------------------------
# Dano
# ---------------------------------------------------------------------------

## Golpe que não matou: pisca, recua um pouco e fica atordoado.
func _reagir_ao_dano(_quantidade: int) -> void:

	_duracao_pausa = 0.45
	_mudar_estado(Estado.ATORDOADO)
	piscar_dano()


# ---------------------------------------------------------------------------
# Animação
# ---------------------------------------------------------------------------

func atualizar_animacao() -> void:

	# O desenho original olha para a direita
	sprite.flip_h = direcao < 0

	match estado:

		Estado.PATRULHANDO:
			_tocar("correndo")

		Estado.PREPARANDO, Estado.RECUPERANDO, Estado.ATORDOADO:
			_tocar("parado")

		Estado.DESLIZANDO:
			pass  # "carrinho" já foi iniciado


func _tocar(nome: StringName) -> void:

	if animation_player.current_animation != nome and animation_player.has_animation(nome):
		animation_player.play(nome)

# A morte (piscar e sumir) fica em inimigo_base.gd
