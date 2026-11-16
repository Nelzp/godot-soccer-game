extends "res://inimigo_base.gd"
## Juiz: fica parado, vira para o jogador e lança cartões quando o enxerga.
## Vida, dano e morte vêm de inimigo_base.gd.

## Distância (px) em que o Juiz enxerga o jogador, para cada lado.
@export var alcance_visao: float = 300.0

const CENA_CARTAO := preload("res://cena_cartao.tscn")

var direcao_inimigo = 1

@onready var raio_visao: RayCast2D = $RayCast2D


func _physics_process(_delta: float) -> void:

	if morrendo:
		return

	var personagem := buscar_jogador()

	if personagem == null:
		$AnimationPlayer.play("parado")
		return

	# Vira para o lado do jogador (o ponto de lançamento acompanha)
	if global_position.x < personagem.global_position.x:
		$Sprite2D.flip_h = false
		$Marker2D.position.x = abs($Marker2D.position.x)
		direcao_inimigo = 1
	else:
		$Sprite2D.flip_h = true
		$Marker2D.position.x = -abs($Marker2D.position.x)
		direcao_inimigo = -1

	if ve_jogador():
		$AnimationPlayer.play("atirando")
	else:
		$AnimationPlayer.play("parado")


## Aponta o raio de visão para o lado do jogador e confere se ele está à vista.
## Outros inimigos e projéteis não tapam a visão; paredes e obstáculos sólidos tapam.
func ve_jogador() -> bool:

	raio_visao.target_position = Vector2(alcance_visao * direcao_inimigo, 0.0)
	raio_visao.clear_exceptions()
	raio_visao.force_raycast_update()

	for _i in range(8):

		if not raio_visao.is_colliding():
			return false

		var alvo = raio_visao.get_collider()

		if alvo == null or not (alvo is Node):
			return false

		if alvo.is_in_group("jogador"):
			return true

		if alvo.is_in_group("inimigos") or alvo.is_in_group("projeteis"):
			raio_visao.add_exception(alvo)
			raio_visao.force_raycast_update()
			continue

		# Parede ou obstáculo sólido entre o Juiz e o jogador
		return false

	return false


## Chamado pela animação "atirando".
func atirar_cartao():

	if morrendo:
		return

	var obj_cartao = CENA_CARTAO.instantiate()

	# A direção vem antes de entrar na cena, para o cartão já nascer virado
	obj_cartao.get_node("CharacterBody2D").direcao = direcao_inimigo

	get_parent().add_child(obj_cartao)
	obj_cartao.global_position = $Marker2D.global_position
