@tool
extends Node2D
## Cenário da Fase 1 montado com trechos de cenario_principal.png, sem distorção.
##
## - Cada trecho é um recorte horizontal da imagem: (x inicial, x final, espelhado)
##   em pixels da imagem. A escala é a mesma nos dois eixos (antes a imagem era
##   esticada 23% na horizontal).
## - Os cortes usam colunas quase idênticas da imagem (415, 1017, 1235 e 1246) ou
##   eixos de espelho, então os trechos emendam sem costura visível.
## - A fase tem três quadras (início, meio e final). Entre duas quadras, o fundo
##   (gol + prédio) aparece espelhado e vira uma divisória natural.
## - Também monta o chão, as paredes das pontas e as plataformas de mão única em
##   cima dos caixotes e barreiras desenhados (grupo "plataformas").
## - @tool: o editor mostra o cenário montado; os nós gerados não são salvos na cena.

const TEXTURA := preload("res://cenario_principal.png")

## Mesma escala vertical de antes (a linha do chão continua em y = 529,5).
const ESCALA := 1.21576
const ALTURA_IMAGEM := 533.0
const Y_CENTRO := 324.0
const Y_CHAO := 529.5

## Camada de colisão 4 (valor 8): plataformas do cenário. O jogador a inclui
## na máscara; projéteis e inimigos não.
const CAMADA_PLATAFORMAS := 8

## Objetos desenhados que viram plataforma: (x inicial, x final, y do topo) em
## pixels da imagem. Só os que ficam inteiros dentro de um trecho são usados.
const PLATAFORMAS: Array[Vector3] = [
	# caixotes à esquerda do centro (pirâmide: topo e dois degraus)
	Vector3(445.0, 468.0, 355.0),
	Vector3(429.5, 445.0, 378.75),
	Vector3(468.0, 480.5, 378.75),
	# barreira listrada da frente
	Vector3(538.0, 599.0, 386.0),
	# caixotes à direita do centro
	Vector3(968.75, 994.5, 355.75),
	Vector3(954.5, 968.75, 382.5),
	Vector3(994.5, 1008.0, 382.5),
	# barreira listrada do trecho lateral
	Vector3(1141.7, 1226.7, 391.7),
	# dois caixotes perto do gol direito
	Vector3(1288.0, 1330.0, 379.0),
]

## Trechos da fase: (x inicial, x final, 1 = espelhado) em pixels da imagem.
@export var trechos: Array[Vector3i] = [
	# Quadra 1 — início (placar e gol da esquerda)
	Vector3i(0, 415, 0), Vector3i(415, 1017, 0), Vector3i(1017, 1235, 0), Vector3i(1017, 1235, 1), Vector3i(1246, 1600, 0),
	# Quadra 2 — meio
	Vector3i(1246, 1600, 1), Vector3i(1017, 1235, 0), Vector3i(1017, 1235, 1), Vector3i(415, 1017, 1), Vector3i(1017, 1235, 0), Vector3i(1017, 1235, 1), Vector3i(1246, 1600, 0),
	# Quadra 3 — final
	Vector3i(1246, 1600, 1), Vector3i(1017, 1235, 1), Vector3i(1017, 1235, 0), Vector3i(415, 1017, 0), Vector3i(1017, 1235, 0), Vector3i(1017, 1235, 1), Vector3i(1246, 1600, 0),
]:
	set(valor):
		trechos = valor
		_montar()

## Largura total montada (px do mundo); a fase usa para os limites da câmera.
var largura: float = 0.0


func _ready() -> void:
	_montar()


static func y_mundo(y_imagem: float) -> float:
	return Y_CENTRO + (y_imagem - ALTURA_IMAGEM * 0.5) * ESCALA


func _montar() -> void:

	if not is_inside_tree():
		return

	for filho in get_children():
		if filho.has_meta("gerado"):
			remove_child(filho)
			filho.queue_free()

	var x := 0.0
	var topo := Y_CENTRO - ALTURA_IMAGEM * ESCALA * 0.5

	for indice in range(trechos.size()):

		var trecho := trechos[indice]
		var x0 := float(trecho.x)
		var x1 := float(trecho.y)
		var espelhado := trecho.z != 0
		var largura_trecho := (x1 - x0) * ESCALA

		var sprite := Sprite2D.new()
		sprite.name = "Trecho%02d" % indice
		sprite.texture = TEXTURA
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(x0, 0.0, x1 - x0, ALTURA_IMAGEM)
		sprite.region_filter_clip_enabled = true
		sprite.flip_h = espelhado
		sprite.scale = Vector2(ESCALA, ESCALA)
		sprite.position = Vector2(x, topo)
		_adicionar(sprite)

		_montar_plataformas(indice, x, x0, x1, espelhado)

		x += largura_trecho

	largura = x
	_montar_limites()


func _montar_plataformas(indice: int, x: float, x0: float, x1: float, espelhado: bool) -> void:

	var corpo: StaticBody2D = null

	for plataforma in PLATAFORMAS:

		if plataforma.x < x0 or plataforma.y > x1:
			continue

		if corpo == null:
			corpo = StaticBody2D.new()
			corpo.name = "Plataformas%02d" % indice
			corpo.add_to_group("plataformas")
			# Camada própria: só o jogador pisa nelas; bola, cartões, inimigos e
			# a visão do Juiz passam direto
			corpo.collision_layer = CAMADA_PLATAFORMAS
			corpo.collision_mask = 0
			_adicionar(corpo)

		# Posição dentro do trecho (espelhada se o trecho estiver espelhado)
		var inicio := (plataforma.x - x0) if not espelhado else (x1 - plataforma.y)
		var fim := (plataforma.y - x0) if not espelhado else (x1 - plataforma.x)

		var retangulo := RectangleShape2D.new()
		retangulo.size = Vector2((fim - inicio) * ESCALA, 8.0)

		var forma := CollisionShape2D.new()
		forma.shape = retangulo
		forma.one_way_collision = true
		forma.position = Vector2(x + (inicio + fim) * 0.5 * ESCALA, y_mundo(plataforma.z) + 4.0)
		corpo.add_child(forma)


func _montar_limites() -> void:

	var limites := StaticBody2D.new()
	limites.name = "Limites"
	_adicionar(limites)

	# Chão em toda a extensão
	var chao := RectangleShape2D.new()
	chao.size = Vector2(largura + 400.0, 200.0)
	var forma_chao := CollisionShape2D.new()
	forma_chao.name = "Chao"
	forma_chao.shape = chao
	forma_chao.position = Vector2(largura * 0.5, Y_CHAO + 100.0)
	limites.add_child(forma_chao)

	# Paredes nas duas pontas (bem altas: não dá para pular por cima)
	for lado in [0, 1]:
		var parede := RectangleShape2D.new()
		parede.size = Vector2(60.0, 1400.0)
		var forma := CollisionShape2D.new()
		forma.name = "ParedeEsquerda" if lado == 0 else "ParedeDireita"
		forma.shape = parede
		forma.position = Vector2(-30.0 if lado == 0 else largura + 30.0, Y_CHAO - 600.0)
		limites.add_child(forma)


func _adicionar(no: Node) -> void:
	no.set_meta("gerado", true)
	add_child(no)
