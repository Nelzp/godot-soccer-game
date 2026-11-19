extends CharacterBody2D
## Jogador principal.
##
## - Corre, pula (o quadro do pulo acompanha a subida e a descida) e
##   aterrissa com um agachamento curto.
## - Chute: apoio (preparação) -> contato, quando a bola sai do pé -> perna no
##   alto -> volta. Durante o chute anda devagar e não vira (a bola sai sempre
##   para o lado do chute).
## - Carrinho: desliza para a frente perdendo velocidade, com o corpo baixo
##   (passa por baixo dos cartões); acerta no máximo um inimigo e só enquanto
##   desliza; depois se levanta.
## - Dano: pisca durante a invulnerabilidade e recua um pouco, sem interromper
##   o que estava fazendo. Na última vida, cai e a tela de game over abre.
##
## Os quadros ficam ancorados no nó Visual (tronco no x = 0, pés no y = 0), que
## vira para os lados pela escala; assim o desenho não "pula" entre quadros.

## Emitido quando o jogador perde uma vida (não quando está invulnerável).
signal dano_recebido
## Emitido quando o jogador morre (antes da animação de queda).
signal morreu

enum Estado {
	LIVRE,
	CHUTANDO,
	DESLIZANDO,
	LEVANTANDO,
	MORTO,
}

const CENA_BOLA := preload("res://cena_bola.tscn")
const CENA_GAME_OVER := "res://cena_game_over.tscn"

@export_group("Movimento")
@export var velocidade: float = 500.0
## Gravidade (px/s²).
@export var gravidade: float = 1800.0
@export var forca_pulo: float = 800.0
## Quanto o empurrão horizontal (golpes) perde por segundo.
@export var atrito_empurrao: float = 1800.0

@export_group("Chute")
## Fração da velocidade enquanto chuta (o pé de apoio segura o corpo).
@export_range(0.0, 1.0, 0.05) var velocidade_no_chute: float = 0.35

@export_group("Carrinho")
## Dano do carrinho em inimigos (a bola causa 1).
@export var dano_carrinho: int = 2
## Velocidade inicial (px/s) do deslize; cai até zero no fim.
@export var velocidade_carrinho: float = 900.0
## Duração (s) do deslize (quadros de entrada e de deslize da animação).
@export var duracao_deslize: float = 0.4
## Altura (px) do corpo durante o deslize (em pé: 105).
@export var altura_deslizando: float = 56.0

@export_group("Dano")
## Tempo (s) sem levar dano depois de um golpe.
@export var tempo_invulneravel: float = 1.0
## Recuo (px/s) e pulinho (px/s) ao levar um golpe que não empurra.
@export var recuo_dano: float = 260.0
@export var salto_dano: float = 180.0

@export_group("Câmera")
## Quanto (px) a câmera se adianta para o lado em que o jogador anda, para
## mostrar mais do que vem pela frente (ex.: o Juiz que lança de longe).
@export var antecipacao_camera: float = 100.0
## Rapidez com que a câmera chega à antecipação (maior = mais rápido).
@export var rapidez_camera: float = 2.2

var direcao: int = 1
var estado: Estado = Estado.LIVRE
var carrinho_atingiu_inimigo: bool = false
var morto: bool = false
## Ligado na vitória e na troca de fase: nada mais causa dano ao jogador.
var invencivel: bool = false
## Velocidade horizontal extra de um empurrão, que diminui com o tempo.
var empurrao_x: float = 0.0

## Ocupado com um ataque (chute ou carrinho)?
var animando: bool:
	get:
		return estado == Estado.CHUTANDO or estado == Estado.DESLIZANDO or estado == Estado.LEVANTANDO

var _tempo_no_estado: float = 0.0
var _invulneravel: float = 0.0
var _estava_no_chao: bool = true
var _lado_camera: int = 1
var _tween_dano: Tween
var _altura_em_pe: float = 105.0
var _y_forma_em_pe: float = -5.5

## HUD da fase (vidas); procurado ao entrar na cena.
var hud: Node = null

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var marcador: Marker2D = $Visual/Marker2D
@onready var forma: CollisionShape2D = $CollisionShape2D
@onready var animacao: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:

	var cena := get_tree().current_scene
	if cena != null:
		hud = cena.find_child("Hud", true, false)

	# A forma muda de altura no carrinho: cada jogador tem a sua
	forma.shape = forma.shape.duplicate()
	_altura_em_pe = (forma.shape as RectangleShape2D).size.y
	_y_forma_em_pe = forma.position.y

	animacao.animation_finished.connect(_on_animacao_terminou)
	virar(direcao)
	_lado_camera = direcao
	camera.position.x = antecipacao_camera * _lado_camera
	animacao.play("parado")


func _physics_process(delta: float) -> void:

	if morto:
		# Caído: só a gravidade
		velocity.x = 0.0
		velocity.y += gravidade * delta
		move_and_slide()
		return

	_tempo_no_estado += delta
	_invulneravel = maxf(_invulneravel - delta, 0.0)

	var entrada := 0
	if Input.is_action_pressed("ir_para_esquerda"):
		entrada = -1
	if Input.is_action_pressed("ir_para_direita"):
		entrada = 1

	velocity.y += gravidade * delta

	match estado:

		Estado.LIVRE:
			velocity.x = entrada * velocidade
			if entrada != 0:
				virar(entrada)
			if Input.is_action_just_pressed("pular") and is_on_floor():
				velocity.y = -forca_pulo
			if is_on_floor():
				if Input.is_action_just_pressed("chutar"):
					_iniciar_chute()
				elif Input.is_action_just_pressed("carrinho"):
					_iniciar_carrinho()

		Estado.CHUTANDO:
			# Pé de apoio: anda devagar e não vira até o chute acabar
			velocity.x = entrada * velocidade * velocidade_no_chute
			if Input.is_action_just_pressed("pular") and is_on_floor():
				velocity.y = -forca_pulo

		Estado.DESLIZANDO:
			var progresso := clampf(_tempo_no_estado / duracao_deslize, 0.0, 1.0)
			velocity.x = direcao * velocidade_carrinho * pow(1.0 - progresso, 1.3)
			if _tempo_no_estado >= duracao_deslize:
				_levantar_do_carrinho()

		Estado.LEVANTANDO:
			velocity.x = 0.0

	# Empurrão recebido (soma com o movimento e vai perdendo força)
	if empurrao_x != 0.0:
		velocity.x += empurrao_x
		empurrao_x = move_toward(empurrao_x, 0.0, atrito_empurrao * delta)

	move_and_slide()

	if estado == Estado.DESLIZANDO:
		verificar_colisao_carrinho()
		# Bateu de frente numa parede ou obstáculo: o deslize acaba ali
		if is_on_wall():
			_levantar_do_carrinho()

	_atualizar_animacao()
	_atualizar_camera(delta, entrada != 0 and estado == Estado.LIVRE)
	_estava_no_chao = is_on_floor()


# ---------------------------------------------------------------------------
# Chute
# ---------------------------------------------------------------------------

func _iniciar_chute() -> void:
	_mudar_estado(Estado.CHUTANDO)
	animacao.play("chutando")
	animacao.seek(0.0, true)


## Chamado pela animação "chutando" no quadro do contato com a bola.
func spawnar_bolar() -> void:

	if morto:
		return

	virar(direcao)

	var obj_bola := CENA_BOLA.instantiate()
	var corpo_bola = obj_bola.get_node("CharacterBody2D")

	corpo_bola.direcao = direcao

	get_parent().add_child(obj_bola)

	# A bola nunca colide com quem a chutou
	corpo_bola.add_collision_exception_with(self)

	obj_bola.global_position = marcador.global_position


# ---------------------------------------------------------------------------
# Carrinho
# ---------------------------------------------------------------------------

func _iniciar_carrinho() -> void:
	carrinho_atingiu_inimigo = false
	_mudar_estado(Estado.DESLIZANDO)
	_abaixar_forma(true)
	animacao.play("carrinho")
	animacao.seek(0.0, true)


## Fim do deslize (pelo tempo, por bater em algo ou pela animação): o corpo
## volta à altura normal e o jogador se levanta, parado.
func _levantar_do_carrinho() -> void:

	if estado != Estado.DESLIZANDO:
		return

	_mudar_estado(Estado.LEVANTANDO)
	_abaixar_forma(false)

	# Se o deslize acabou antes do tempo, pula para o quadro de levantar
	if animacao.current_animation == "carrinho" and animacao.current_animation_position < 0.4:
		animacao.seek(0.4, true)


func _abaixar_forma(abaixar: bool) -> void:

	var retangulo := forma.shape as RectangleShape2D
	var base := _y_forma_em_pe + _altura_em_pe * 0.5
	var altura := altura_deslizando if abaixar else _altura_em_pe

	retangulo.size.y = altura
	forma.position.y = base - altura * 0.5


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


## Inimigo vivo = está no grupo "inimigos" (quem morre sai do grupo).
func e_inimigo_vivo(objeto) -> bool:
	return objeto != null and is_instance_valid(objeto) and objeto is Node and objeto.is_in_group("inimigos") and objeto.has_method("receber_dano")


# ---------------------------------------------------------------------------
# Estados e animação
# ---------------------------------------------------------------------------

func _mudar_estado(novo: Estado) -> void:
	estado = novo
	_tempo_no_estado = 0.0


func _on_animacao_terminou(nome: StringName) -> void:

	if morto:
		return

	if nome == &"chutando" and estado == Estado.CHUTANDO:
		_mudar_estado(Estado.LIVRE)
	elif nome == &"carrinho" and (estado == Estado.LEVANTANDO or estado == Estado.DESLIZANDO):
		_abaixar_forma(false)
		_mudar_estado(Estado.LIVRE)


func _atualizar_animacao() -> void:

	if estado != Estado.LIVRE:
		return

	if not is_on_floor():
		# No ar: o quadro acompanha a velocidade vertical
		if animacao.current_animation != "pulando" or animacao.is_playing():
			animacao.play("pulando")
			animacao.pause()
		var quadro := 0.0
		if velocity.y >= 180.0:
			quadro = 0.3
		elif velocity.y >= -120.0:
			quadro = 0.2
		elif velocity.y >= -420.0:
			quadro = 0.1
		animacao.seek(quadro, true)
		return

	var andando := velocity.x != 0.0 and empurrao_x == 0.0

	# Acabou de cair: agacha um instante (se não estiver correndo)
	if not _estava_no_chao and not andando:
		animacao.play("aterrissando")
		return

	if animacao.current_animation == "aterrissando" and animacao.is_playing() and not andando:
		return

	_tocar("correndo" if andando else "parado")


func _tocar(nome: StringName) -> void:
	if animacao.current_animation != nome or not animacao.is_playing():
		animacao.play(nome)


## Vira o jogador (o desenho, o ponto de onde sai a bola) para `lado`.
func virar(lado: int) -> void:
	if lado == 0:
		return
	direcao = lado
	visual.scale.x = float(lado)


## A câmera se adianta para o lado em que o jogador anda. Só segue o lado
## enquanto ele anda: virar parado (para chutar) não balança a câmera.
func _atualizar_camera(delta: float, andando: bool) -> void:

	if andando:
		_lado_camera = direcao

	var alvo := antecipacao_camera * _lado_camera
	camera.position.x = lerpf(camera.position.x, alvo, 1.0 - exp(-rapidez_camera * delta))


# ---------------------------------------------------------------------------
# Dano e morte
# ---------------------------------------------------------------------------

## Empurra o jogador (ex.: carrinho do Zagueiro, soco do chefão). x vira um
## impulso horizontal que diminui aos poucos; y negativo joga para cima.
func empurrar(impulso: Vector2) -> void:

	if morto:
		return

	empurrao_x = impulso.x

	if impulso.y < 0.0:
		velocity.y = impulso.y


## Golpe recebido. `origem` (opcional) é de onde veio o golpe, para o recuo ir
## para o lado certo; sem ela, o jogador recua para trás.
func receber_dano(origem: Vector2 = Vector2.INF) -> void:

	if morto or invencivel or _invulneravel > 0.0:
		return

	_invulneravel = tempo_invulneravel
	dano_recebido.emit()
	_piscar_dano()

	# Recuo pequeno (golpes que empurram mais chamam empurrar() em seguida)
	var lado := -direcao
	if origem != Vector2.INF and origem.x != global_position.x:
		lado = 1 if global_position.x > origem.x else -1
	empurrao_x = lado * recuo_dano
	if is_on_floor():
		velocity.y = -salto_dano

	if hud != null:
		hud.receber_dano()


## Pisca durante a invulnerabilidade, começando com um vermelho rápido.
func _piscar_dano() -> void:

	if _tween_dano != null:
		_tween_dano.kill()

	visual.modulate = Color(1.0, 0.45, 0.45)
	_tween_dano = create_tween()
	_tween_dano.tween_property(visual, "modulate", Color(1, 1, 1, 0.35), 0.1)

	var vezes := maxi(int((tempo_invulneravel - 0.1) / 0.16), 1)
	for _i in range(vezes):
		_tween_dano.tween_property(visual, "modulate:a", 1.0, 0.08)
		_tween_dano.tween_property(visual, "modulate:a", 0.35, 0.08)

	_tween_dano.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.06)


## Última vida: o jogador para, tomba para trás e a tela de game over abre.
func morrer() -> void:

	if morto:
		return

	morto = true
	_mudar_estado(Estado.MORTO)
	_abaixar_forma(false)
	velocity = Vector2.ZERO
	empurrao_x = 0.0
	animacao.pause()

	if _tween_dano != null:
		_tween_dano.kill()

	morreu.emit()

	# Pulinho, tomba para trás (o pivô do Visual fica nos pés), apaga
	var base := visual.position
	visual.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.2)
	tween.parallel().tween_property(visual, "position:y", base.y - 26.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", base.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual, "rotation", -direcao * deg_to_rad(82.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.35)
	tween.tween_property(visual, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_ir_para_game_over)


func _ir_para_game_over() -> void:
	Transicao.ir_para(CENA_GAME_OVER, 0.35)
