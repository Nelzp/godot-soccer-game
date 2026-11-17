
extends "res://inimigo_base.gd"
## Goleiro: patrulha e, ao encostar no jogador, dá um soco.
## Vida, dano e morte vêm de inimigo_base.gd.

enum Estado {
	PATRULHANDO,
	ATACANDO
}

@export var velocidade: float = 200.0
@export var gravidade: float = 980.0
## Distância horizontal (px, de centro a centro) que o jogador precisa abrir
## depois de um ataque para o Goleiro poder atacar de novo.
@export var distancia_para_liberar: float = 200.0
## Até quantos pixels além da borda do corpo o soco alcança.
@export var alcance_golpe: float = 60.0
## Até quantos px para cada lado do ponto de partida o goleiro patrulha
## (0 = sem limite, vira só em paredes e obstáculos).
@export var raio_patrulha: float = 200.0
## Cores do uniforme e das luvas (ver variacoes_inimigos.gd).
@export_enum("Vermelho e amarelo (original)", "Verde e branco", "Azul e amarelo", "Roxo e rosa", "Laranja e preto") var variacao: int = 0

var direcao: int = 1
var estado: Estado = Estado.PATRULHANDO
var _x_inicial: float = 0.0

var jogador_alvo: CharacterBody2D = null
var aguardando_afastamento: bool = false
var estava_na_parede: bool = false
var golpe_aplicado: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var forma: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_x_inicial = global_position.x
	animation_player.animation_finished.connect(_on_animation_finished)
	aplicar_variacao("goleiro", variacao)


func _physics_process(delta: float) -> void:

	if morrendo:
		return

	# Aplicar gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0

	# Verificar se o jogador ainda existe
	if jogador_alvo != null and not is_instance_valid(jogador_alvo):
		jogador_alvo = null
		aguardando_afastamento = false
		estado = Estado.PATRULHANDO

	# Comportamento conforme o estado
	match estado:

		Estado.PATRULHANDO:
			patrulhar()

		Estado.ATACANDO:
			velocity.x = 0.0

			# Manter o goleiro olhando para o jogador durante o ataque
			if jogador_alvo != null and is_instance_valid(jogador_alvo):
				atualizar_direcao_ataque(jogador_alvo)

	# Movimentar o goleiro
	move_and_slide()

	# Inverter direção ao encontrar uma parede
	if estado == Estado.PATRULHANDO:

		var parede_agora = is_on_wall()

		if parede_agora and not estava_na_parede:
			direcao *= -1
			atualizar_direcao()

		estava_na_parede = parede_agora

		# Limites de patrulha em volta do ponto de partida
		if raio_patrulha > 0.0:
			if global_position.x <= _x_inicial - raio_patrulha and direcao < 0:
				direcao = 1
				atualizar_direcao()
			elif global_position.x >= _x_inicial + raio_patrulha and direcao > 0:
				direcao = -1
				atualizar_direcao()

	# Liberar novo ataque quando o jogador se afastar
	if aguardando_afastamento and jogador_alvo != null:

		var distancia = absf(jogador_alvo.global_position.x - global_position.x)

		if distancia > distancia_para_liberar:
			aguardando_afastamento = false
			jogador_alvo = null

	# Detectar jogador pela colisão
	if estado == Estado.PATRULHANDO and not aguardando_afastamento:

		var jogador = detectar_jogador()

		if jogador != null:

			# Não atacar se o jogador estiver em cima do goleiro
			if jogador_esta_em_cima(jogador):
				return

			iniciar_ataque(jogador)


func patrulhar() -> void:

	velocity.x = direcao * velocidade

	atualizar_direcao()

	if animation_player.current_animation != "correndo":
		animation_player.play("correndo")


func iniciar_ataque(jogador: CharacterBody2D) -> void:

	if estado == Estado.ATACANDO:
		return

	jogador_alvo = jogador
	estado = Estado.ATACANDO
	golpe_aplicado = false

	velocity.x = 0.0

	# Virar para o lado correto antes de atacar
	atualizar_direcao_ataque(jogador)

	animation_player.play("ataque")

	print("GOLEIRO: ATAQUE INICIADO!")


## Chamado pela animação "ataque" no quadro do soco (0,6 s).
## Só causa dano se o jogador ainda estiver ao alcance, e no máximo uma vez por ataque.
func aplicar_golpe() -> void:

	if morrendo or estado != Estado.ATACANDO or golpe_aplicado:
		return

	golpe_aplicado = true

	if not is_instance_valid(jogador_alvo):
		return

	if jogador_no_alcance(jogador_alvo) and jogador_alvo.has_method("receber_dano"):
		jogador_alvo.receber_dano()
		print("GOLEIRO: Jogador atingido!")


func _on_animation_finished(nome_animacao: StringName) -> void:

	if morrendo or nome_animacao != "ataque":
		return

	if estado != Estado.ATACANDO:
		return

	# Impedir ataques repetidos enquanto o jogador estiver próximo
	aguardando_afastamento = true

	estado = Estado.PATRULHANDO

	print("GOLEIRO: Ataque finalizado!")


func detectar_jogador() -> CharacterBody2D:

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto is CharacterBody2D and objeto.is_in_group("jogador"):
			return objeto

	return null


## O jogador está "em cima" quando o centro dele fica acima do topo do Goleiro.
func jogador_esta_em_cima(jogador: Node2D) -> bool:
	return jogador.global_position.y < global_position.y - meia_altura()


## Confere, no momento do soco, se o jogador ainda está ao alcance.
func jogador_no_alcance(jogador: Node2D) -> bool:

	if jogador == null or not is_instance_valid(jogador):
		return false

	if jogador_esta_em_cima(jogador):
		return false

	var dx := jogador.global_position.x - global_position.x
	var dy := jogador.global_position.y - global_position.y

	# Precisa estar do lado para onde o Goleiro está virado
	var lado := -1.0 if sprite.flip_h else 1.0

	if dx * lado < 0.0:
		return false

	if absf(dx) > meia_largura() + alcance_golpe:
		return false

	return absf(dy) <= meia_altura() + 40.0


func meia_largura() -> float:

	var retangulo := forma.shape as RectangleShape2D

	if retangulo == null:
		return 90.0

	return retangulo.size.x * 0.5 * absf(forma.scale.x)


func meia_altura() -> float:

	var retangulo := forma.shape as RectangleShape2D

	if retangulo == null:
		return 72.0

	return retangulo.size.y * 0.5 * absf(forma.scale.y)


func atualizar_direcao() -> void:

	# Sprite original olhando para a direita
	sprite.flip_h = direcao < 0


func atualizar_direcao_ataque(jogador: CharacterBody2D) -> void:

	# Jogador à esquerda: inverter o sprite
	# Jogador à direita: manter o sprite original
	sprite.flip_h = jogador.global_position.x < global_position.x
