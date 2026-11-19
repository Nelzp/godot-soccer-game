extends CanvasLayer
## Barra de vida do chefão, na parte de baixo da tela.
## - mostrar(): aparece e enche a barra (apresentação do chefão).
## - atualizar(): a barra vermelha cai na hora e a amarela vem atrás.
## - marcar_furia(): destaca a fase 2.
## - esconder(): some aos poucos (morte do chefão).

@onready var painel: Control = $Painel
@onready var nome: Label = $Painel/Nome
@onready var barra: ProgressBar = $Painel/Moldura/Barra
@onready var barra_atraso: ProgressBar = $Painel/Moldura/BarraAtraso

var _tween_atraso: Tween
var _tween_furia: Tween


func _ready() -> void:

	visible = false

	# O menu de pausa esconde o painel junto com os corações
	painel.add_to_group("ocultar_na_pausa")


func mostrar(vida: int, vida_maxima: int) -> void:

	barra.max_value = vida_maxima
	barra_atraso.max_value = vida_maxima
	barra.value = 0.0
	barra_atraso.value = 0.0

	painel.modulate.a = 0.0
	visible = true

	var tween := create_tween()
	tween.tween_property(painel, "modulate:a", 1.0, 0.3)
	tween.tween_property(barra, "value", float(vida), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(barra_atraso, "value", float(vida), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func atualizar(vida: int, vida_maxima: int) -> void:

	barra.max_value = vida_maxima
	barra_atraso.max_value = vida_maxima
	barra.value = vida

	if _tween_atraso != null:
		_tween_atraso.kill()

	_tween_atraso = create_tween()
	_tween_atraso.tween_interval(0.35)
	_tween_atraso.tween_property(barra_atraso, "value", float(vida), 0.45)


func marcar_furia() -> void:

	nome.text = "CARTÃO VERMELHO - FÚRIA!"

	# O nome pulsa em vermelho durante a fase 2
	_tween_furia = create_tween().set_loops()
	_tween_furia.tween_property(nome, "modulate", Color(1.0, 0.55, 0.5), 0.45)
	_tween_furia.tween_property(nome, "modulate", Color(1, 1, 1), 0.45)


func esconder(duracao: float = 0.6) -> void:

	if _tween_furia != null:
		_tween_furia.kill()

	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(painel, "modulate:a", 0.0, duracao)
	tween.tween_callback(hide)
