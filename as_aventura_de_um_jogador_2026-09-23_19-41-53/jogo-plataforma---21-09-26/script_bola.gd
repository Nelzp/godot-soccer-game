extends CharacterBody2D

var direcao    = 1 #  1 => Direita, -1 => Esquerda
var velocidade = 350

func _process(delta: float) -> void:
	velocity.x = velocidade * direcao
	velocity.y = 0
	move_and_slide()
	
