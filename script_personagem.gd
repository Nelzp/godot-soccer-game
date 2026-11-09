extends CharacterBody2D

var velocidade = 500
var gravidade = 30
var forca_pulo = 800
var direcao = 1

var animando = false
var carrinho_atingiu_inimigo = false

@onready var hud = get_tree().current_scene.find_child("HUD", true, false)


func _process(delta: float) -> void:

	velocity.x = 0
	velocity.y += gravidade

	# Movimentação para esquerda
	if Input.is_action_pressed("ir_para_esquerda"):
		velocity.x = -velocidade
		direcao = -1
		$Sprite2D.flip_h = true

	# Movimentação para direita
	if Input.is_action_pressed("ir_para_direita"):
		velocity.x = velocidade
		direcao = 1
		$Sprite2D.flip_h = false

	# Pulo
	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = -forca_pulo

	# Verifica se uma animação de ação terminou
	if animando and not $AnimationPlayer.is_playing():
		animando = false

	if is_on_floor():

		if not animando:

			if velocity.x == 0:
				$AnimationPlayer.play("parado")
			else:
				$AnimationPlayer.play("correndo")

			# Chute
			if Input.is_action_just_pressed("chutar"):
				$AnimationPlayer.play("chutando")
				animando = true

			# Carrinho
			elif Input.is_action_just_pressed("carrinho"):
				$AnimationPlayer.play("carrinho")
				animando = true
				carrinho_atingiu_inimigo = false

	else:
		if not animando:
			$AnimationPlayer.play("pulando")

	move_and_slide()

	# Detecta colisões durante o carrinho
	if $AnimationPlayer.current_animation == "carrinho":
		verificar_colisao_carrinho()


func verificar_colisao_carrinho() -> void:

	if carrinho_atingiu_inimigo:
		return

	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto != null and objeto.has_method("morrer"):

			carrinho_atingiu_inimigo = true
			objeto.morrer()

			print("Inimigo derrotado pelo carrinho!")

			break


func spawnar_bolar():
	var cena_bola = preload("res://cena_bola.tscn")
	var obj_bola = cena_bola.instantiate()

	obj_bola.get_node("CharacterBody2D").direcao = direcao

	get_parent().add_child(obj_bola)

	var pos_x = abs($Marker2D.position.x)
	$Marker2D.position.x = pos_x * direcao

	obj_bola.global_position = $Marker2D.global_position


func receber_dano() -> void:

	print("O jogador recebeu dano!")

	if hud != null:
		print("HUD encontrado!")
		hud.receber_dano()
	else:
		print("ERRO: HUD não encontrado!")
