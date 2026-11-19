@tool
extends StaticBody2D
## Obstáculo sólido no gramado, com arte da folha
## "recursos/imagens/objetos/obstaculos.png".
##
## - A origem fica no meio da base: posicione com y na linha do chão.
## - A colisão acompanha o tamanho do desenho (escolha o tipo e a escala no
##   inspetor; o editor já mostra o resultado).
## - Bloqueia jogador, inimigos, bola e cartões (camada 1). Inimigos que
##   patrulham dão meia-volta nele; o jogador precisa pular.

enum Tipo {
	BARREIRA_DE_SALTO,
	BARREIRA_DE_BONECOS,
	CONE,
	CAIXA_DE_SALTO,
	BARREIRA_LISTRADA,
}

## Recortes da folha de obstáculos (sem bordas transparentes).
const RECORTES := {
	Tipo.BARREIRA_DE_SALTO: Rect2(88, 491, 126, 81),
	Tipo.BARREIRA_DE_BONECOS: Rect2(579, 239, 147, 135),
	Tipo.CONE: Rect2(72, 163, 68, 85),
	Tipo.CAIXA_DE_SALTO: Rect2(24, 889, 127, 99),
	Tipo.BARREIRA_LISTRADA: Rect2(111, 321, 111, 88),
}

## Quanto da largura do desenho vira colisão (o desenho tem contorno e
## "pés" que não precisam bloquear).
const LARGURA_UTIL := {
	Tipo.BARREIRA_DE_SALTO: 0.94,
	Tipo.BARREIRA_DE_BONECOS: 0.9,
	Tipo.CONE: 0.7,
	Tipo.CAIXA_DE_SALTO: 0.96,
	Tipo.BARREIRA_LISTRADA: 0.94,
}

@export var tipo: Tipo = Tipo.BARREIRA_DE_SALTO:
	set(valor):
		tipo = valor
		_montar()

@export_range(0.2, 2.0, 0.01) var escala: float = 0.6:
	set(valor):
		escala = valor
		_montar()

@export var espelhado: bool = false:
	set(valor):
		espelhado = valor
		_montar()


func _ready() -> void:

	if not Engine.is_editor_hint():
		add_to_group("obstaculos")

	_montar()


func _montar() -> void:

	if not is_inside_tree():
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var forma := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if sprite == null or forma == null:
		return

	var recorte: Rect2 = RECORTES[tipo]
	var tamanho := recorte.size * escala

	sprite.region_enabled = true
	sprite.region_rect = recorte
	sprite.scale = Vector2(escala, escala)
	sprite.flip_h = espelhado
	sprite.centered = true
	sprite.position = Vector2(0.0, -tamanho.y * 0.5)

	var retangulo := forma.shape as RectangleShape2D

	# Cada obstáculo tem a própria forma (não compartilha com outras cópias)
	if retangulo == null or not retangulo.resource_local_to_scene:
		retangulo = RectangleShape2D.new()
		retangulo.resource_local_to_scene = true
		forma.shape = retangulo

	retangulo.size = Vector2(tamanho.x * LARGURA_UTIL[tipo], tamanho.y)
	forma.position = Vector2(0.0, -tamanho.y * 0.5)
