extends CharacterBody2D

var direcao = 1
var velocidade = 650

@onready var animacao: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animacao.play("rolando")


func _physics_process(delta: float) -> void:

	velocity.x = velocidade * direcao
	velocity.y = 0

	move_and_slide()

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		print("Bola colidiu com: ", objeto.name)

		if objeto.has_method("morrer"):
			print("Juiz atingido!")
			objeto.morrer()
			get_parent().queue_free()
			return
