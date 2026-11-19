extends CanvasLayer
## Transição suave entre cenas (autoload "Transicao"): escurece a tela, troca
## a cena e clareia de novo. Funciona mesmo com o jogo pausado.
##
## Uso: Transicao.ir_para("res://cenas/fases/fase_2.tscn")

## Emitido quando a nova cena já está na tela (antes de clarear).
signal cena_trocada

## Fase em que o jogador está (cada fase se registra ao abrir). O "TENTAR
## NOVAMENTE" do game over volta para ela.
var fase_atual: String = "res://cenas/fases/fase_1.tscn"

var _cortina: ColorRect
var _ocupado: bool = false


func _ready() -> void:

	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cortina = ColorRect.new()
	_cortina.name = "Cortina"
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cortina)


func em_transicao() -> bool:
	return _ocupado


## Escurece, troca para `caminho` e clareia. Ignorada se já houver uma em andamento.
func ir_para(caminho: String, duracao: float = 0.5) -> void:

	if _ocupado:
		return

	_ocupado = true

	# Durante a troca, cliques não chegam à cena de baixo
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP

	var escurecer := create_tween()
	escurecer.tween_property(_cortina, "color:a", 1.0, duracao)
	await escurecer.finished

	get_tree().paused = false
	get_tree().change_scene_to_file(caminho)

	# Espera a cena nova entrar e desenhar o primeiro quadro
	await get_tree().process_frame
	await get_tree().process_frame
	cena_trocada.emit()

	var clarear := create_tween()
	clarear.tween_property(_cortina, "color:a", 0.0, duracao)
	await clarear.finished

	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ocupado = false
