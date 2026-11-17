extends CharacterBody2D
## Base comum dos inimigos (Juiz, Goleiro, Zagueiro e, a partir da P2, o Chefão).
##
## Padroniza o que todo inimigo precisa fazer do mesmo jeito:
## - entrar no grupo "inimigos" (usado pela bola e pelo carrinho do jogador);
## - ter pontos de vida próprios (vida_maxima);
## - receber dano somente por receber_dano(quantidade);
## - morrer uma única vez: para de agir, desliga as colisões, pisca e some.
##
## Para usar, o script do inimigo começa com:
##     extends "res://inimigo_base.gd"
## e sai logo no início do _physics_process quando "morrendo" for true.

## Emitido uma única vez, quando o inimigo começa a morrer.
signal derrotado(inimigo: Node)

const VARIACOES := preload("res://variacoes_inimigos.gd")

## Pontos de vida (a bola tira 1 e o carrinho tira 2). Cada cena define o seu
## valor e cada instância pode mudar no Inspetor.
@export var vida_maxima: int = 1

var vida: int = 1
var morrendo: bool = false

var _jogador_em_cache: Node2D = null
var _tween_dano: Tween


func _notification(what: int) -> void:
	# _notification é chamado em todos os scripts da hierarquia, então
	# isto roda mesmo quando o inimigo tem o próprio _ready().
	if what == NOTIFICATION_READY:
		vida = vida_maxima
		add_to_group("inimigos")


## Única forma de causar dano a um inimigo. Ignorada se ele já estiver morrendo.
func receber_dano(quantidade: int = 1) -> void:

	if morrendo or quantidade <= 0:
		return

	vida = maxi(vida - quantidade, 0)

	if vida == 0:
		morrer()
	else:
		_reagir_ao_dano(quantidade)


## Reação a um golpe que não matou: por padrão, pisca em vermelho.
## Cada inimigo pode sobrescrever.
func _reagir_ao_dano(_quantidade: int) -> void:
	piscar_dano()


## Pisca o sprite em vermelho duas vezes (mostra que o golpe contou).
func piscar_dano() -> void:

	var sprite_dano := get_node_or_null("Sprite2D") as CanvasItem

	if sprite_dano == null:
		return

	if _tween_dano != null:
		_tween_dano.kill()

	_tween_dano = create_tween()

	for _i in range(2):
		_tween_dano.tween_property(sprite_dano, "modulate", Color(1, 0.4, 0.4), 0.07)
		_tween_dano.tween_property(sprite_dano, "modulate", Color(1, 1, 1), 0.07)


## Aplica uma variação de uniforme (ver variacoes_inimigos.gd) no Sprite2D.
func aplicar_variacao(tipo: String, indice: int) -> void:
	VARIACOES.aplicar(get_node_or_null("Sprite2D") as CanvasItem, tipo, indice)


func esta_vivo() -> bool:
	return not morrendo


## Devolve o jogador (grupo "jogador") ou null, sem depender de caminhos na árvore.
func buscar_jogador() -> Node2D:

	if _jogador_em_cache == null or not is_instance_valid(_jogador_em_cache) or not _jogador_em_cache.is_inside_tree():
		_jogador_em_cache = get_tree().get_first_node_in_group("jogador") as Node2D

	return _jogador_em_cache


func morrer() -> void:

	if morrendo:
		return

	morrendo = true
	velocity = Vector2.ZERO

	# Morto não recebe nem causa dano e não bloqueia mais ninguém
	remove_from_group("inimigos")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	derrotado.emit(self)

	if _tween_dano != null:
		_tween_dano.kill()

	var animacao := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animacao != null:
		animacao.stop()

	_animar_morte()


## Animação de morte. A padrão é a mesma que o Juiz já usava: pisca duas
## vezes e some. Inimigos especiais (como o Chefão) podem sobrescrever,
## desde que chamem queue_free() no final.
func _animar_morte() -> void:

	var sprite_morte := get_node_or_null("Sprite2D") as CanvasItem
	var tween := create_tween()

	if sprite_morte != null:
		# Sem resto do vermelho de um golpe anterior
		sprite_morte.modulate = Color(1, 1, 1)
		for _i in range(2):
			tween.tween_property(sprite_morte, "modulate:a", 0.0, 0.12)
			tween.tween_property(sprite_morte, "modulate:a", 1.0, 0.12)

	tween.tween_callback(queue_free)
