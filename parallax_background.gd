extends ParallaxBackground

# Velocidade de deslocamento (ajusta conforme necessário)
@export var velocidade : float = 150.0

func _process(delta):
	# Move o fundo para a esquerda continuamente
	scroll_offset.x -= velocidade * delta
