
extends "res://scripts/personagens/inimigo_base.gd"
## Goleiro: patrulha e, com o jogador perto e à frente (ou encostando), soca.
## Vida, dano e morte vêm de inimigo_base.gd.
##
## Soco: guarda agachado e guarda (aviso, ~0,36 s, ainda vira para o jogador),
## soco com um passo à frente, impacto (o golpe conta aqui, se o jogador ainda
## estiver ao alcance) e volta. Dá para escapar recuando ou pulando por cima.

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
## O soco começa quando o jogador chega a esta distância (px) da borda do corpo.
@export var distancia_para_atacar: float = 50.0
## Velocidade (px/s) do passo à frente durante o soco.
@export var velocidade_investida: float = 150.0
## Até quantos px para cada lado do ponto de partida o goleiro patrulha
## (0 = sem limite, vira só em paredes e obstáculos).
@export var raio_patrulha: float = 200.0
## Cores do uniforme e das luvas (ver variacoes_inimigos.gd).
@export_enum("Vermelho e amarelo (original)", "Verde e branco", "Azul e amarelo", "Roxo e rosa", "Laranja e preto") var variacao: int = 0

## Tempo (s) da animação "ataque" em que o soco sai (fim do aviso) e em que o
## passo à frente acaba.
const INICIO_SOCO := 0.36
const FIM_INVESTIDA := 0.5

var direcao: int = 1
var estado: Estado = Estado.PATRULHANDO
var _x_inicial: float = 0.0

var jogador_alvo: CharacterBody2D = null
var aguardando_afastamento: bool = false
var estava_na_parede: bool = false
var golpe_aplicado: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var forma: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_x_inicial = global_position.x
	animation_player.animation_finished.connect(_on_animation_finished)
	aplicar_variacao("goleiro", variacao)
	atualizar_direcao()


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

	match estado:

		Estado.PATRULHANDO:
			patrulhar()

		Estado.ATACANDO:
			var tempo := animation_player.current_animation_position
			if tempo < INICIO_SOCO:
				# Aviso: parado, ainda acompanhando o jogador
				velocity.x = 0.0
				if jogador_alvo != null and is_instance_valid(jogador_alvo):
					atualizar_direcao_ataque(jogador_alvo)
			elif tempo < FIM_INVESTIDA:
				# O soco sai com um passo à frente (direção já decidida)
				velocity.x = lado_visual() * velocidade_investida
			else:
				velocity.x = 0.0

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

	# Jogador perto e à frente, ou encostando: soca
	if estado == Estado.PATRULHANDO and not aguardando_afastamento:

		var jogador = detectar_jogador()

		if jogador != null and not jogador_esta_em_cima(jogador):
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
	animation_player.seek(0.0, true)


## Chamado pela animação "ataque" no quadro do impacto.
## Só causa dano se o jogador ainda estiver ao alcance, e no máximo uma vez por ataque.
func aplicar_golpe() -> void:

	if morrendo or estado != Estado.ATACANDO or golpe_aplicado:
		return

	golpe_aplicado = true

	if not is_instance_valid(jogador_alvo):
		return

	if jogador_no_alcance(jogador_alvo) and jogador_alvo.has_method("receber_dano"):
		jogador_alvo.receber_dano(global_position)


func _on_animation_finished(nome_animacao: StringName) -> void:

	if morrendo or nome_animacao != "ataque":
		return

	if estado != Estado.ATACANDO:
		return

	# Impedir ataques repetidos enquanto o jogador estiver próximo
	aguardando_afastamento = true

	direcao = lado_visual()
	estado = Estado.PATRULHANDO


## Jogador encostado (colisão) ou perto, à frente e na mesma altura.
func detectar_jogador() -> CharacterBody2D:

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto is CharacterBody2D and objeto.is_in_group("jogador"):
			return objeto

	var jogador := buscar_jogador() as CharacterBody2D

	if jogador == null:
		return null

	var dx := jogador.global_position.x - global_position.x

	if dx * lado_visual() <= 0.0:
		return null

	if absf(dx) > meia_largura() + distancia_para_atacar + 20.0:
		return null

	if absf(jogador.global_position.y - global_position.y) > meia_altura() + 30.0:
		return null

	return jogador


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
	if dx * lado_visual() < 0.0:
		return false

	if absf(dx) > meia_largura() + alcance_golpe:
		return false

	return absf(dy) <= meia_altura() + 40.0


func meia_largura() -> float:

	var retangulo := forma.shape as RectangleShape2D

	if retangulo == null:
		return 52.0

	return retangulo.size.x * 0.5 * absf(forma.scale.x)


func meia_altura() -> float:

	var retangulo := forma.shape as RectangleShape2D

	if retangulo == null:
		return 70.0

	return retangulo.size.y * 0.5 * absf(forma.scale.y)


func atualizar_direcao() -> void:
	# Desenho original olhando para a direita
	virar_visual(direcao)


func atualizar_direcao_ataque(jogador: CharacterBody2D) -> void:
	virar_visual(-1 if jogador.global_position.x < global_position.x else 1)
