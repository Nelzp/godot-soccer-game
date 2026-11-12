
extends CharacterBody2D

enum Estado {
	PATRULHANDO,
	ATACANDO
}

@export var velocidade: float = 200.0
@export var gravidade: float = 980.0
@export var distancia_para_liberar: float = 100.0

var direcao: int = 1
var estado: Estado = Estado.PATRULHANDO

var jogador_alvo: CharacterBody2D = null
var aguardando_afastamento: bool = false
var estava_na_parede: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:

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

	# Movimentar o goleiro
	move_and_slide()

	# Inverter direção ao encontrar uma parede
	if estado == Estado.PATRULHANDO:

		var parede_agora = is_on_wall()

		if parede_agora and not estava_na_parede:
			direcao *= -1
			atualizar_direcao()

		estava_na_parede = parede_agora

	# Liberar novo ataque quando o jogador se afastar
	if aguardando_afastamento and jogador_alvo != null:

		var distancia = global_position.distance_to(
			jogador_alvo.global_position
		)

		if distancia > distancia_para_liberar:
			aguardando_afastamento = false
			jogador_alvo = null

	# Detectar jogador pela colisão
	if estado == Estado.PATRULHANDO and not aguardando_afastamento:

		var jogador = detectar_jogador()

		if jogador != null:

			# Não atacar se o jogador estiver em cima do goleiro
			if jogador.global_position.y < global_position.y:
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

	velocity.x = 0.0

	# Atualizar a direção conforme a posição do jogador
	atualizar_direcao_ataque(jogador)

	# Executar animação de ataque
	animation_player.play("ataque")

	print("GOLEIRO: ATAQUE INICIADO!")


func _on_animation_finished(nome_animacao: StringName) -> void:

	if nome_animacao != "ataque":
		return

	if estado != Estado.ATACANDO:
		return

	# Aplicar dano quando o ataque terminar
	if jogador_alvo != null and is_instance_valid(jogador_alvo):

		if jogador_alvo.has_method("receber_dano"):
			jogador_alvo.receber_dano()
			print("GOLEIRO: Jogador atingido!")

	# Impedir ataques repetidos enquanto o jogador estiver próximo
	aguardando_afastamento = true

	# Voltar à patrulha
	estado = Estado.PATRULHANDO

	print("GOLEIRO: Ataque finalizado!")


func detectar_jogador() -> CharacterBody2D:

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto is CharacterBody2D and objeto.name == "Personagem":
			return objeto

	return null


func atualizar_direcao() -> void:

	# Orientação da animação de corrida
	sprite.flip_h = direcao < 0


func atualizar_direcao_ataque(jogador: CharacterBody2D) -> void:

	# Jogador à direita
	if jogador.global_position.x > global_position.x:
		sprite.flip_h = true

	# Jogador à esquerda
	else:
		sprite.flip_h = false
		
	if jogador.global_position.x > global_position.x:
		sprite.flip_h = false

	# Jogador à esquerda
	else:
		sprite.flip_h = true
