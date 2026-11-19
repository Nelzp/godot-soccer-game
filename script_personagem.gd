
extends CharacterBody2D

var velocidade = 500
var gravidade = 30
var forca_pulo = 800
var direcao = 1

## Dano do carrinho em inimigos (a bola causa 1; o chefão terá mais vida).
@export var dano_carrinho: int = 2

## Quanto o empurrão horizontal (golpes do chefão) perde por segundo.
@export var atrito_empurrao: float = 1800.0

## Quanto (px) a câmera se adianta para o lado em que o jogador anda, para
## mostrar mais do que vem pela frente (ex.: o Juiz que lança de longe).
@export var antecipacao_camera: float = 100.0
## Rapidez com que a câmera chega à antecipação (maior = mais rápido).
@export var rapidez_camera: float = 2.2

var animando = false
var carrinho_atingiu_inimigo = false
var morto: bool = false
## Ligado na vitória: nada mais causa dano ao jogador.
var invencivel: bool = false
## Velocidade horizontal extra de um empurrão, que diminui com o tempo.
var empurrao_x: float = 0.0

@onready var hud = get_tree().current_scene.find_child("Hud", true, false)
@onready var camera: Camera2D = $Camera2D

## Lado para onde a câmera está adiantada (1 = direita, -1 = esquerda).
var _lado_camera: int = 1


func _ready() -> void:
	_lado_camera = direcao
	camera.position.x = antecipacao_camera * _lado_camera


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

	_atualizar_camera(delta, velocity.x != 0)

	# Pulo
	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = -forca_pulo

	# Empurrão recebido (soma com o movimento e vai perdendo força)
	if empurrao_x != 0.0:
		velocity.x += empurrao_x
		empurrao_x = move_toward(empurrao_x, 0.0, atrito_empurrao * delta)

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


## A câmera se adianta para o lado em que o jogador anda. Só segue o lado
## enquanto ele anda: virar parado (para chutar) não balança a câmera.
func _atualizar_camera(delta: float, andando: bool) -> void:

	if andando:
		_lado_camera = direcao

	var alvo := antecipacao_camera * _lado_camera
	camera.position.x = lerpf(camera.position.x, alvo, 1.0 - exp(-rapidez_camera * delta))


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


## Empurra o jogador (ex.: soco do chefão). x vira um impulso horizontal que
## diminui aos poucos; y negativo joga o jogador para cima.
func empurrar(impulso: Vector2) -> void:

	if morto:
		return

	empurrao_x = impulso.x

	if impulso.y < 0.0:
		velocity.y = impulso.y


func receber_dano() -> void:

	if morto or invencivel:
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
