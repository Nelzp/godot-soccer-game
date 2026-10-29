extends CharacterBody2D

var direcao    = 1 #  1 => Direita, -1 => Esquerda
var velocidade = 550

func _physics_process(delta: float) -> void:
	velocity.x = velocidade * direcao
	velocity.y = 0
	
	move_and_slide()
	
	for i in range(get_slide_collision_count()):
		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto.name == "Personagem":
			queue_free()
			return
