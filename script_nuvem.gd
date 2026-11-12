
extends ParallaxBackground

@export var velocidade_nuvens: float = 45.0

@onready var camada: ParallaxLayer = $ParallaxLayer
@onready var nuvens: Sprite2D = $ParallaxLayer/Sprite2D


func _ready() -> void:
	camada.motion_mirroring.x = nuvens.texture.get_width() * nuvens.scale.x


func _process(delta: float) -> void:
	camada.motion_offset.x -= velocidade_nuvens * delta
