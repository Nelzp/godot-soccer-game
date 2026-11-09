
extends CharacterBody2D

var direcao = 1
var velocidade = 700


func _physics_process(delta: float) -> void:

	velocity.x = velocidade * direcao
	velocity.y = 0

	move_and_slide()

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto == null:
			continue

		# Se atingir um objeto que recebe dano
		if objeto.name == "Personagem" and objeto.has_method("receber_dano"):

			objeto.receber_dano()

			get_parent().queue_free()
			return

		# Se atingir qualquer outro objeto, desaparece
		get_parent().queue_free()
		return
