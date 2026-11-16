
extends CharacterBody2D

@export var velocidade: float = 150.0
@export var distancia: float = 200.0

var direcao: int = 1
var posicao_inicial: float

@onready var sprite = $Sprite2D
@onready var animacao = $AnimationPlayer

func _ready() -> void:
	posicao_inicial = global_position.x

	# Inicia a animação de corrida
	animacao.play("correndo")

func _physics_process(_delta: float) -> void:
	velocity.x = velocidade * direcao
	move_and_slide()

	if global_position.x >= posicao_inicial + distancia:
		direcao = -1
		sprite.flip_h = true

	elif global_position.x <= posicao_inicial - distancia:
		direcao = 1
		sprite.flip_h = false

	# Mantém a animação de corrida ativa
	if animacao.current_animation != "correndo":
		animacao.play("correndo")
