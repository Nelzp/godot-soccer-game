extends Control
## Barra de volume no estilo da tela de configurações: 12 segmentos
## (verdes e depois amarelos), botão branco, clique/arraste com o mouse e
## setas esquerda/direita quando tem o foco.

## Emitido quando o jogador muda o valor (não quando o código muda).
signal valor_alterado(valor: float)

const COR_VERDE := Color8(118, 247, 54)
const COR_LIMA := Color8(187, 238, 43)
const COR_AMARELO := Color8(253, 217, 35)
const COR_VAZIO := Color8(68, 54, 96)
const COR_CONTORNO := Color8(18, 10, 34)
const COR_FOCO := Color8(232, 99, 235)

@export var segmentos: int = 12
## Quanto cada toque nas setas muda (0,05 = 5%).
@export var passo_teclado: float = 0.05
## Retângulo da barra dentro do controle (o resto é área de clique).
@export var area_barra: Rect2 = Rect2(7, 13, 299, 18)

var valor: float = 1.0

var _arrastando: bool = false


func _ready() -> void:

	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Muda o valor sem emitir sinal (usado ao abrir a tela).
func definir_valor(novo: float) -> void:

	valor = clampf(novo, 0.0, 1.0)
	queue_redraw()


func _mudar_valor(novo: float) -> void:

	novo = clampf(snappedf(novo, 0.01), 0.0, 1.0)

	if is_equal_approx(novo, valor):
		return

	valor = novo
	queue_redraw()
	valor_alterado.emit(valor)


func _gui_input(evento: InputEvent) -> void:

	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:

		_arrastando = evento.pressed

		if evento.pressed:
			grab_focus()
			_mudar_valor(_valor_na_posicao(evento.position.x))

		accept_event()

	elif evento is InputEventMouseMotion and _arrastando:
		_mudar_valor(_valor_na_posicao(evento.position.x))
		accept_event()

	elif evento.is_action_pressed("ui_left", true):
		_mudar_valor(valor - passo_teclado)
		accept_event()

	elif evento.is_action_pressed("ui_right", true):
		_mudar_valor(valor + passo_teclado)
		accept_event()


func _valor_na_posicao(x: float) -> float:
	return (x - area_barra.position.x) / area_barra.size.x


func _draw() -> void:

	var passo := area_barra.size.x / segmentos
	var preenchido := valor * segmentos

	for i in range(segmentos):

		var segmento := Rect2(area_barra.position.x + i * passo, area_barra.position.y, passo - 2.5, area_barra.size.y)
		draw_rect(segmento, COR_VAZIO)

		var fracao := clampf(preenchido - i, 0.0, 1.0)

		if fracao > 0.0:
			var parte := Rect2(segmento.position, Vector2(segmento.size.x * fracao, segmento.size.y))
			draw_rect(parte, _cor_do_segmento(i))
			# brilho na parte de cima, como na arte original
			draw_rect(Rect2(parte.position, Vector2(parte.size.x, 3.0)), Color(1, 1, 1, 0.3))

	# Botão branco na posição do valor
	var x := area_barra.position.x + area_barra.size.x * valor
	var botao := Rect2(x - 7.0, area_barra.position.y - 9.0, 14.0, area_barra.size.y + 18.0)
	draw_rect(botao.grow(2.0), COR_CONTORNO)
	draw_rect(botao, Color(0.97, 0.97, 0.97))
	draw_rect(Rect2(botao.position + Vector2(botao.size.x - 4.0, 0.0), Vector2(4.0, botao.size.y)), Color(0.78, 0.78, 0.82))

	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), COR_FOCO, false, 3.0)


## Igual à arte: sete segmentos verdes, um verde-limão e o resto amarelo.
func _cor_do_segmento(indice: int) -> Color:

	var proporcao := float(indice) / float(maxi(segmentos - 1, 1))

	if proporcao < 0.6:
		return COR_VERDE

	if proporcao < 0.68:
		return COR_LIMA

	return COR_AMARELO
