extends CharacterBody2D
## Base comum dos inimigos (Juiz, Goleiro, Zagueiro e o Chefão).
##
## Padroniza o que todo inimigo precisa fazer do mesmo jeito:
## - entrar no grupo "inimigos" (usado pela bola e pelo carrinho do jogador);
## - ter pontos de vida próprios (vida_maxima);
## - receber dano somente por receber_dano(quantidade);
## - morrer uma única vez: para de agir, desliga as colisões, cai e some.
##
## O desenho fica em Visual/Sprite2D: o nó Visual tem a origem nos pés e vira
## para os lados pela escala (assim os quadros ancorados não "pulam").
##
## Para usar, o script do inimigo começa com:
##     extends "res://scripts/personagens/inimigo_base.gd"
## e sai logo no início do _physics_process quando "morrendo" for true.

## Emitido uma única vez, quando o inimigo começa a morrer.
signal derrotado(inimigo: Node)
## Emitido a cada golpe que não matou.
signal atingido(inimigo: Node)

const VARIACOES := preload("res://scripts/personagens/variacoes_inimigos.gd")

## Pontos de vida (a bola tira 1 e o carrinho tira 2). Cada cena define o seu
## valor e cada instância pode mudar no Inspetor.
@export var vida_maxima: int = 1

var vida: int = 1
var morrendo: bool = false

var _jogador_em_cache: Node2D = null
var _tween_dano: Tween
var _tween_tranco: Tween


func _notification(what: int) -> void:
	# _notification é chamado em todos os scripts da hierarquia, então
	# isto roda mesmo quando o inimigo tem o próprio _ready().
	if what == NOTIFICATION_READY:
		vida = vida_maxima
		add_to_group("inimigos")


## Nó que vira e cai junto com o desenho (Visual, ou o próprio sprite).
func no_visual() -> Node2D:
	var visual := get_node_or_null("Visual") as Node2D
	return visual if visual != null else get_node_or_null("Sprite2D") as Node2D


## O desenho do inimigo (onde ficam a variação de uniforme e o piscar).
func sprite_visual() -> Sprite2D:
	var sprite := get_node_or_null("Visual/Sprite2D") as Sprite2D
	return sprite if sprite != null else get_node_or_null("Sprite2D") as Sprite2D


## Vira o desenho para `lado` (1 = direita, -1 = esquerda).
func virar_visual(lado: int) -> void:
	var visual := get_node_or_null("Visual") as Node2D
	if visual != null and lado != 0:
		visual.scale.x = float(lado)


## Lado para onde o desenho está virado.
func lado_visual() -> int:
	var visual := get_node_or_null("Visual") as Node2D
	return -1 if visual != null and visual.scale.x < 0.0 else 1


## Única forma de causar dano a um inimigo. Ignorada se ele já estiver morrendo.
func receber_dano(quantidade: int = 1) -> void:

	if morrendo or quantidade <= 0:
		return

	vida = maxi(vida - quantidade, 0)

	if vida == 0:
		morrer()
	else:
		_reagir_ao_dano(quantidade)
		atingido.emit(self)


## Reação a um golpe que não matou: por padrão, pisca em vermelho e dá um
## tranco para trás. Cada inimigo pode sobrescrever.
func _reagir_ao_dano(_quantidade: int) -> void:
	piscar_dano()


## Pisca o sprite em vermelho duas vezes e dá um tranco curto para trás
## (mostra que o golpe contou).
func piscar_dano() -> void:

	var sprite_dano := sprite_visual()

	if sprite_dano == null:
		return

	if _tween_dano != null:
		_tween_dano.kill()

	_tween_dano = create_tween()

	for _i in range(2):
		_tween_dano.tween_property(sprite_dano, "modulate", Color(1, 0.4, 0.4), 0.07)
		_tween_dano.tween_property(sprite_dano, "modulate", Color(1, 1, 1), 0.07)

	var visual := get_node_or_null("Visual") as Node2D

	if visual == null:
		return

	if _tween_tranco != null:
		_tween_tranco.kill()

	visual.position.x = 0.0
	_tween_tranco = create_tween()
	_tween_tranco.tween_property(visual, "position:x", -6.0 * lado_visual(), 0.05)
	_tween_tranco.tween_property(visual, "position:x", 0.0, 0.1)


## Aplica uma variação de uniforme (ver variacoes_inimigos.gd) no desenho.
func aplicar_variacao(tipo: String, indice: int) -> void:
	VARIACOES.aplicar(sprite_visual(), tipo, indice)


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

	if _tween_tranco != null:
		_tween_tranco.kill()

	var animacao := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animacao != null:
		animacao.pause()

	_animar_morte()


## Animação de morte: clarão, recua com um pulinho para longe do jogador, tomba
## para trás (o pivô do Visual fica nos pés) e apaga. Inimigos especiais (como
## o Chefão) podem sobrescrever, desde que chamem queue_free() no final.
func _animar_morte() -> void:

	var visual := no_visual()
	var sprite_morte := sprite_visual()
	var tween := create_tween()

	if visual == null:
		tween.tween_callback(queue_free)
		return

	# Cai para o lado oposto ao jogador
	var lado := -lado_visual()
	var jogador := buscar_jogador()
	if jogador != null and jogador.global_position.x != global_position.x:
		lado = 1 if global_position.x > jogador.global_position.x else -1

	if sprite_morte != null:
		sprite_morte.modulate = Color(1, 1, 1)
	visual.modulate = Color(2.2, 2.2, 2.2)

	var base := visual.position
	tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.12)
	tween.parallel().tween_property(visual, "position", base + Vector2(lado * 14.0, -16.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position", base + Vector2(lado * 26.0, 0.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual, "rotation", lado * deg_to_rad(84.0), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.18)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
