
extends CharacterBody2D

var velocidade = 500
var gravidade = 30
var forca_pulo = 800
var direcao = 1

## Dano do carrinho em inimigos (a bola causa 1; o chefão terá mais vida).
@export var dano_carrinho: int = 2

var animando = false
var carrinho_atingiu_inimigo = false
var morto: bool = false

@onready var hud = get_tree().current_scene.find_child("Hud", true, false)


func _physics_process(delta: float) -> void:

	# Impedir ações quando o jogador morrer
	if morto:
		return

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

	# Cada carrinho atinge no máximo um inimigo
	if carrinho_atingiu_inimigo:
		return

	var alvo = null

	# Inimigo em que o jogador bateu durante o movimento deste quadro
	for i in range(get_slide_collision_count()):

		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if e_inimigo_vivo(objeto):
			alvo = objeto
			break

	# Inimigo encostado à frente, mesmo com o jogador parado
	if alvo == null:

		var contato := KinematicCollision2D.new()

		if test_move(global_transform, Vector2(direcao * 20.0, 0.0), contato):
			if e_inimigo_vivo(contato.get_collider()):
				alvo = contato.get_collider()

	if alvo != null:

		carrinho_atingiu_inimigo = true
		alvo.receber_dano(dano_carrinho)

		print("Inimigo atingido pelo carrinho!")


## Inimigo vivo = está no grupo "inimigos" (quem morre sai do grupo).
func e_inimigo_vivo(objeto) -> bool:
	return objeto != null and is_instance_valid(objeto) and objeto is Node and objeto.is_in_group("inimigos") and objeto.has_method("receber_dano")


func spawnar_bolar():
	var cena_bola = preload("res://cena_bola.tscn")
	var obj_bola = cena_bola.instantiate()
	var corpo_bola = obj_bola.get_node("CharacterBody2D")

	corpo_bola.direcao = direcao

	get_parent().add_child(obj_bola)

	# A bola nunca colide com quem a chutou
	corpo_bola.add_collision_exception_with(self)

	var pos_x = abs($Marker2D.position.x)
	$Marker2D.position.x = pos_x * direcao

	obj_bola.global_position = $Marker2D.global_position


func receber_dano() -> void:

	if morto:
		return

	print("O jogador recebeu dano!")

	if hud != null:
		print("HUD encontrado!")
		hud.receber_dano()
	else:
		print("ERRO: HUD não encontrado!")


func morrer() -> void:

	if morto:
		return

	morto = true

	velocity = Vector2.ZERO

	# Impedir movimentação e novas ações
	set_process(false)
	set_physics_process(false)

	print("JOGADOR MORREU!")

	if hud != null:
		hud.receber_dano()
	else:
		print("ERRO: HUD não encontrado!")
