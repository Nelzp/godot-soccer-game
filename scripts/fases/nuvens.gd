
extends ParallaxBackground
## Nuvens passando devagar. A faixa de nuvens tem escala igual nos dois eixos
## (sem esticar) e vem acompanhada de uma cópia espelhada: a repetição
## "original + espelho" emenda sem costura.

@export var velocidade_nuvens: float = 45.0

@onready var camada: ParallaxLayer = $ParallaxLayer
@onready var nuvens: Sprite2D = $ParallaxLayer/Sprite2D
@onready var espelho: Sprite2D = $ParallaxLayer/Espelho


func _ready() -> void:

	var largura := nuvens.texture.get_width() * nuvens.scale.x

	# A cópia espelhada fica logo depois da original
	espelho.position = nuvens.position + Vector2(largura, 0.0)
	camada.motion_mirroring.x = largura * 2.0


func _process(delta: float) -> void:
	camada.motion_offset.x -= velocidade_nuvens * delta
