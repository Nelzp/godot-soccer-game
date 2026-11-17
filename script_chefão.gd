extends "res://inimigo_base.gd"
## Chefão "Cartão Vermelho".
##
## - 12 pontos de vida: a bola tira 1 e o carrinho tira 2.
## - Fica parado até a arena chamar ativar(); depois disso, apresenta-se
##   (barra de vida enchendo) e começa a luta.
## - Fase 1: persegue o jogador, dá socos de perto e, quando o jogador se
##   afasta, lança um cartão vermelho rasteiro (é preciso pular).
## - Fase 2 (metade da vida): fica mais rápido, golpeia mais depressa e lança
##   dois cartões: um rasteiro e, logo depois, um alto (passa por cima de
##   quem fica no chão e acerta quem pula na hora errada).
## - Não recebe dano parado, na apresentação nem na troca de fase.
## - Se o jogador subir na cabeça dele, é empurrado para fora.
## - Ao morrer, emite "derrotado" (inimigo_base.gd); a arena cuida da vitória.

## Emitido quando a luta começa (fim da espera).
signal ativado
## Emitido quando o chefão entra na fase 2.
signal fase_2_iniciada

enum Estado {
	INATIVO,
	APRESENTACAO,
	PERSEGUINDO,
	SOCANDO,
	ATIRANDO,
	RECUPERANDO,
	TRANSICAO,
}

const CENA_CARTAO_VERMELHO := preload("res://cena_cartao_vermelho.tscn")

@export_group("Movimento")
@export var gravidade: float = 980.0
@export var velocidade_fase_1: float = 120.0
@export var velocidade_fase_2: float = 185.0

@export_group("Soco")
## Alcance do soco além da borda do corpo (px).
@export var alcance_soco: float = 55.0
## Pausa (s) depois do soco, em que o chefão fica vulnerável.
@export var pausa_apos_soco_fase_1: float = 0.9
@export var pausa_apos_soco_fase_2: float = 0.5
## Empurrão aplicado ao jogador atingido (x para longe do chefão).
@export var empurrao_soco: Vector2 = Vector2(430.0, -320.0)

@export_group("Cartões")
## Distância horizontal mínima até o jogador para lançar cartões.
@export var distancia_para_lancar: float = 280.0
## Tempo (s) entre um lançamento e outro.
@export var recarga_cartao_fase_1: float = 3.0
@export var recarga_cartao_fase_2: float = 2.0
## Altura (px acima dos pés do chefão) do cartão rasteiro e do cartão alto.
@export var altura_cartao_baixo: float = 48.0
@export var altura_cartao_alto: float = 150.0
## Pausa (s) entre os dois cartões da fase 2.
@export var intervalo_rajada: float = 0.3

@export_group("Fases")
@export var duracao_apresentacao: float = 1.4
@export var duracao_transicao: float = 1.5
## Velocidade das animações na fase 2.
@export var velocidade_animacao_fase_2: float = 1.3

var fase: int = 1
var estado: Estado = Estado.INATIVO
var tempo_no_estado: float = 0.0
var pausa_atual: float = 0.0
var recarga_cartao: float = 1.0
## 1 = olhando para a direita; -1 = para a esquerda.
var olhando: int = -1
var golpe_aplicado: bool = false
var cartoes_na_rajada: int = 0
var tempo_jogador_em_cima: float = 0.0

var _tween_flash: Tween
var _tween_furia: Tween

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var ponto_lancamento: Marker2D = $Visual/PontoLancamento
@onready var animacao: AnimationPlayer = $AnimationPlayer
@onready var forma: CollisionShape2D = $CollisionShape2D
@onready var barra = $BarraVida


func _ready() -> void:

	animacao.animation_finished.connect(_on_animacao_terminou)
	_virar_para(olhando)
	_tocar("parado")


## Chamado pela arena quando o jogador entra. Começa a apresentação.
func ativar() -> void:

	if estado != Estado.INATIVO or morrendo:
		return

	var jogador := buscar_jogador()

	if jogador != null:
		_virar_para(1 if jogador.global_position.x > global_position.x else -1)

	_mudar_estado(Estado.APRESENTACAO)
	_tocar("parado")
	barra.mostrar(vida, vida_maxima)
	ativado.emit()


func esta_ativo() -> bool:
	return estado != Estado.INATIVO and not morrendo


func pode_receber_dano() -> bool:
	return not morrendo and estado != Estado.INATIVO and estado != Estado.APRESENTACAO and estado != Estado.TRANSICAO


func receber_dano(quantidade: int = 1) -> void:

	if morrendo:
		return

	# Golpe que não conta: só um brilho fraco para mostrar que bateu
	# (na troca de fase o chefão já está piscando em vermelho)
	if not pode_receber_dano():
		if estado != Estado.TRANSICAO:
			_piscar(0.3, 0.12)
		return

	super.receber_dano(quantidade)
	barra.atualizar(vida, vida_maxima)


func _reagir_ao_dano(_quantidade: int) -> void:

	_piscar(0.85, 0.2)

	# Metade da vida (ou menos): vira fase 2
	if fase == 1 and vida * 2 <= vida_maxima:
		_iniciar_transicao()


func _physics_process(delta: float) -> void:

	if morrendo:
		return

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravidade * delta

	tempo_no_estado += delta
	recarga_cartao = maxf(recarga_cartao - delta, 0.0)

	var jogador := buscar_jogador()

	match estado:

		Estado.INATIVO:
			velocity.x = 0.0

		Estado.APRESENTACAO:
			velocity.x = 0.0
			if tempo_no_estado >= duracao_apresentacao:
				_mudar_estado(Estado.PERSEGUINDO)

		Estado.PERSEGUINDO:
			_perseguir(jogador)

		Estado.SOCANDO, Estado.ATIRANDO:
			velocity.x = 0.0

		Estado.RECUPERANDO:
			velocity.x = 0.0
			_tocar("parado")
			if tempo_no_estado >= pausa_atual:
				if cartoes_na_rajada > 0:
					_lancar_proximo_da_rajada()
				else:
					_mudar_estado(Estado.PERSEGUINDO)

		Estado.TRANSICAO:
			velocity.x = 0.0
			if tempo_no_estado >= duracao_transicao:
				_entrar_fase_2()

	move_and_slide()

	_empurrar_jogador_de_cima(jogador, delta)


# ---------------------------------------------------------------------------
# Perseguição
# ---------------------------------------------------------------------------

func _perseguir(jogador: Node2D) -> void:

	if jogador == null:
		velocity.x = 0.0
		_tocar("parado")
		return

	var dx := jogador.global_position.x - global_position.x

	if absf(dx) > 4.0:
		_virar_para(1 if dx > 0.0 else -1)

	if _jogador_no_alcance_do_soco(jogador, 0.0):
		_iniciar_soco()
		return

	if absf(dx) >= distancia_para_lancar and recarga_cartao <= 0.0:
		_iniciar_lancamento()
		return

	# Colado no jogador (por exemplo, com ele em cima): espera em vez de empurrar
	if absf(dx) <= _meia_largura() + 14.0:
		velocity.x = 0.0
		_tocar("parado")
		return

	velocity.x = olhando * (velocidade_fase_1 if fase == 1 else velocidade_fase_2)
	_tocar("correndo")


# ---------------------------------------------------------------------------
# Soco
# ---------------------------------------------------------------------------

func _iniciar_soco() -> void:

	golpe_aplicado = false
	velocity.x = 0.0
	_mudar_estado(Estado.SOCANDO)
	_tocar("socando", true)


## Chamado pela animação "socando" nos quadros de impacto (jab, gancho e
## soco vermelho). Acerta no máximo uma vez por ataque.
func aplicar_soco() -> void:

	if morrendo or estado != Estado.SOCANDO or golpe_aplicado:
		return

	var jogador := buscar_jogador()

	if jogador == null or not _jogador_no_alcance_do_soco(jogador, 20.0):
		return

	golpe_aplicado = true
	_ferir_jogador(jogador, Vector2(empurrao_soco.x * olhando, empurrao_soco.y))


func _jogador_no_alcance_do_soco(jogador: Node2D, folga: float) -> bool:

	var dx := jogador.global_position.x - global_position.x

	# Jogador às costas não leva soco (dá para escapar pulando por cima)
	if dx * olhando < -4.0:
		return false

	if absf(dx) > _meia_largura() + alcance_soco + folga + 20.0:
		return false

	# Precisa estar na altura do corpo, não em cima da cabeça
	return _pes_do_jogador(jogador) > _topo() + 20.0


# ---------------------------------------------------------------------------
# Cartões
# ---------------------------------------------------------------------------

func _iniciar_lancamento() -> void:

	cartoes_na_rajada = 2 if fase == 2 else 1
	velocity.x = 0.0
	_mudar_estado(Estado.ATIRANDO)
	_tocar("atirando", true)


func _lancar_proximo_da_rajada() -> void:

	var jogador := buscar_jogador()

	if jogador != null:
		_virar_para(1 if jogador.global_position.x > global_position.x else -1)

	_mudar_estado(Estado.ATIRANDO)
	_tocar("atirando", true)


## Chamado pela animação "atirando" no quadro em que o cartão sai da mão.
func lancar_cartao() -> void:

	if morrendo or estado != Estado.ATIRANDO or cartoes_na_rajada <= 0:
		return

	# Na fase 2, o segundo cartão da rajada vem alto
	var alto := fase == 2 and cartoes_na_rajada == 1
	cartoes_na_rajada -= 1

	var cartao := CENA_CARTAO_VERMELHO.instantiate()
	var corpo := cartao.get_node("CharacterBody2D")

	# Direção e altura antes de entrar na cena, para o cartão já nascer certo
	corpo.direcao = olhando
	corpo.altura_alvo = global_position.y - (altura_cartao_alto if alto else altura_cartao_baixo)

	get_parent().add_child(cartao)
	cartao.global_position = ponto_lancamento.global_position

	# O cartão nunca bate no próprio chefão
	corpo.add_collision_exception_with(self)


# ---------------------------------------------------------------------------
# Estados e animações
# ---------------------------------------------------------------------------

func _on_animacao_terminou(nome: StringName) -> void:

	if morrendo:
		return

	if nome == &"socando" and estado == Estado.SOCANDO:
		_iniciar_recuperacao(pausa_apos_soco_fase_1 if fase == 1 else pausa_apos_soco_fase_2)

	elif nome == &"atirando" and estado == Estado.ATIRANDO:

		if cartoes_na_rajada > 0:
			_iniciar_recuperacao(intervalo_rajada)
		else:
			recarga_cartao = recarga_cartao_fase_1 if fase == 1 else recarga_cartao_fase_2
			_iniciar_recuperacao(0.35)


func _iniciar_recuperacao(duracao: float) -> void:

	pausa_atual = duracao
	_mudar_estado(Estado.RECUPERANDO)
	_tocar("parado")


func _iniciar_transicao() -> void:

	cartoes_na_rajada = 0
	golpe_aplicado = true
	velocity.x = 0.0

	_mudar_estado(Estado.TRANSICAO)
	_tocar("parado", true)
	animacao.speed_scale = 2.2

	barra.marcar_furia()
	_tremer_camera(7.0, 0.45)

	# Pisca em vermelho três vezes enquanto "se enfurece"
	if _tween_flash != null:
		_tween_flash.kill()

	_tween_flash = create_tween()

	for _i in range(3):
		_tween_flash.tween_callback(_definir_cor_flash.bind(Color(1.0, 0.25, 0.2)))
		_tween_flash.tween_method(_definir_flash, 0.9, 0.0, duracao_transicao / 3.0)

	_tween_flash.tween_callback(_definir_cor_flash.bind(Color(1, 1, 1)))


func _entrar_fase_2() -> void:

	fase = 2
	animacao.speed_scale = velocidade_animacao_fase_2
	recarga_cartao = 0.8

	# Brilho vermelho pulsante durante toda a fase 2
	_tween_furia = create_tween().set_loops()
	_tween_furia.tween_property(visual, "modulate", Color(1.0, 0.72, 0.72), 0.45)
	_tween_furia.tween_property(visual, "modulate", Color(1, 1, 1), 0.45)

	_mudar_estado(Estado.PERSEGUINDO)
	fase_2_iniciada.emit()


func _mudar_estado(novo: Estado) -> void:

	estado = novo
	tempo_no_estado = 0.0


func _tocar(nome: StringName, reiniciar: bool = false) -> void:

	if reiniciar or animacao.current_animation != nome:
		animacao.play(nome)
		if reiniciar:
			animacao.seek(0.0, true)


func _virar_para(lado: int) -> void:

	olhando = lado
	visual.scale.x = float(lado)


# ---------------------------------------------------------------------------
# Jogador em cima da cabeça
# ---------------------------------------------------------------------------

func _empurrar_jogador_de_cima(jogador: Node2D, delta: float) -> void:

	if jogador == null or not esta_ativo() or not _jogador_esta_em_cima(jogador):
		tempo_jogador_em_cima = 0.0
		return

	tempo_jogador_em_cima += delta

	if tempo_jogador_em_cima < 0.3:
		return

	tempo_jogador_em_cima = 0.0

	# Só empurra (sem dano): joga o jogador para o lado em que ele está,
	# longe o bastante para cair fora do alcance do soco
	var lado := 1.0 if jogador.global_position.x >= global_position.x else -1.0

	if jogador.has_method("empurrar"):
		jogador.empurrar(Vector2(lado * 720.0, -420.0))

	_piscar(0.4, 0.15)

	# Respira um instante antes de voltar a perseguir (dá tempo de reagir)
	if estado == Estado.PERSEGUINDO:
		_iniciar_recuperacao(0.45)


func _jogador_esta_em_cima(jogador: Node2D) -> bool:

	var corpo_jogador := jogador as CharacterBody2D

	if corpo_jogador == null or not corpo_jogador.is_on_floor():
		return false

	if absf(jogador.global_position.x - global_position.x) > _meia_largura() + 24.0:
		return false

	return _pes_do_jogador(jogador) <= _topo() + 8.0


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------

func _ferir_jogador(jogador: Node, empurrao: Vector2) -> void:

	if jogador.has_method("receber_dano"):
		jogador.receber_dano()

	if jogador.has_method("empurrar"):
		jogador.empurrar(empurrao)


## Altura (y global) dos pés do jogador, pela forma de colisão dele.
func _pes_do_jogador(jogador: Node2D) -> float:

	var forma_jogador := jogador.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if forma_jogador != null and forma_jogador.shape is RectangleShape2D:
		var retangulo := forma_jogador.shape as RectangleShape2D
		return forma_jogador.global_position.y + retangulo.size.y * 0.5 * absf(forma_jogador.global_scale.y)

	return jogador.global_position.y + 50.0


func _topo() -> float:
	return forma.global_position.y - _meia_altura()


func _meia_largura() -> float:

	var retangulo := forma.shape as RectangleShape2D

	if retangulo == null:
		return 36.0

	return retangulo.size.x * 0.5 * absf(forma.scale.x)


func _meia_altura() -> float:

	var retangulo := forma.shape as RectangleShape2D

	if retangulo == null:
		return 76.0

	return retangulo.size.y * 0.5 * absf(forma.scale.y)


func _piscar(intensidade: float, duracao: float) -> void:

	if _tween_flash != null and _tween_flash.is_running():
		_tween_flash.kill()

	_definir_cor_flash(Color(1, 1, 1))

	_tween_flash = create_tween()
	_tween_flash.tween_method(_definir_flash, intensidade, 0.0, duracao)


func _definir_flash(valor: float) -> void:

	var material_flash := sprite.material as ShaderMaterial

	if material_flash != null:
		material_flash.set_shader_parameter("intensidade_flash", valor)


func _definir_cor_flash(cor: Color) -> void:

	var material_flash := sprite.material as ShaderMaterial

	if material_flash != null:
		material_flash.set_shader_parameter("cor_flash", cor)


## Treme a câmera atual (a do jogador) por alguns instantes, sem deixar
## aparecer o que fica fora dos limites da fase.
func _tremer_camera(intensidade: float, duracao: float) -> void:

	var camera := get_viewport().get_camera_2d()

	if camera == null:
		return

	# O deslocamento (offset) da câmera ignora os limites, então ele é
	# limitado aqui ao espaço que sobra entre a tela e as bordas da fase
	var centro := camera.get_screen_center_position() - camera.offset
	var meia_tela := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
	var minimo := Vector2(camera.limit_left + meia_tela.x - centro.x, camera.limit_top + meia_tela.y - centro.y)
	var maximo := Vector2(camera.limit_right - meia_tela.x - centro.x, camera.limit_bottom - meia_tela.y - centro.y)

	var tween := camera.create_tween()

	for _i in range(maxi(int(duracao / 0.05), 1)):
		var deslocamento := Vector2(
			clampf(randf_range(-intensidade, intensidade), minf(minimo.x, 0.0), maxf(maximo.x, 0.0)),
			clampf(randf_range(-intensidade, intensidade), minf(minimo.y, 0.0), maxf(maximo.y, 0.0))
		)
		tween.tween_property(camera, "offset", deslocamento, 0.05)

	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


# ---------------------------------------------------------------------------
# Morte
# ---------------------------------------------------------------------------

## Morte do chefão: clarão, tremor, pisca, tomba e some.
func _animar_morte() -> void:

	if _tween_furia != null:
		_tween_furia.kill()

	if _tween_flash != null:
		_tween_flash.kill()

	barra.atualizar(0, vida_maxima)
	barra.esconder(1.4)
	_tremer_camera(10.0, 0.7)

	_definir_cor_flash(Color(1, 1, 1))
	visual.modulate = Color(1, 1, 1)

	var tween := create_tween()
	tween.tween_method(_definir_flash, 1.0, 0.0, 0.35)

	for _i in range(5):
		tween.tween_property(sprite, "modulate:a", 0.25, 0.08)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)

	# Tomba para trás (o pivô do Visual fica nos pés)
	tween.tween_property(visual, "rotation", -olhando * PI * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
