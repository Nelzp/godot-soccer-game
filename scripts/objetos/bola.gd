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
var _conferiu_saida: bool = false

@onready var animacao: AnimationPlayer = $AnimationPlayer
@onready var forma: CollisionShape2D = $CollisionShape2D


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

	# Chute colado no inimigo: a bola já nasce dentro dele e o movimento não
	# registraria a batida. Confere uma vez, logo na saída.
	if not _conferiu_saida:
		_conferiu_saida = true
		if _acertar_inimigo_sobreposto():
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


func _acertar_inimigo_sobreposto() -> bool:

	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.collision_mask = collision_mask

	var ignorar: Array[RID] = [get_rid()]
	for corpo in get_collision_exceptions():
		ignorar.append(corpo.get_rid())
	consulta.exclude = ignorar

	for resultado in get_world_2d().direct_space_state.intersect_shape(consulta, 8):
		var objeto = resultado.get("collider")
		if objeto is Node and objeto.is_in_group("inimigos") and objeto.has_method("receber_dano"):
			objeto.receber_dano(dano)
			remover()
			return true

	return false


func remover() -> void:

	if removendo:
		return

	removendo = true
	get_parent().queue_free()
