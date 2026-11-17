extends Node2D
## Arena da Fase 2: o Chefão "Cartão Vermelho" e a saída do estádio.
##
## - O chefão acorda quando o jogador entra na arena (gatilho).
## - A saída (o túnel "SAÍDA" desenhado no cenário) fica bloqueada por duas
##   barreiras listradas enquanto o chefão estiver vivo.
## - Quando o chefão é derrotado: os cartões no ar somem, ele faz a animação de
##   morte, a barra some, as barreiras saem, a placa "SAÍDA" passa a brilhar e
##   aparece "SAÍDA LIBERADA!". O jogador continua no controle (nada carrega
##   sozinho).
## - Entrando no túnel liberado, a tela escurece e abre a tela de vitória.

## Emitido quando as barreiras saem e o túnel fica livre.
signal saida_liberada

const CENA_VITORIA := "res://cena_vitoria.tscn"

## Tempo (s) entre a derrota do chefão e a saída ser liberada.
@export var atraso_liberacao: float = 1.2

var luta_iniciada: bool = false
var vitoria: bool = false
var liberada: bool = false

var _saindo: bool = false

@onready var gatilho: Area2D = $Gatilho
@onready var chefao = $Chefao
@onready var bloqueio: CollisionShape2D = $Saida/Bloqueio/CollisionShape2D
@onready var barreiras: Node2D = $Saida/Barreiras
@onready var entrada: Area2D = $Saida/Entrada
@onready var brilho: CanvasItem = $Saida/Brilho
@onready var aviso: Label = $Saida/Aviso


func _ready() -> void:

	gatilho.body_entered.connect(_on_gatilho_body_entered)
	entrada.body_entered.connect(_on_entrada_body_entered)
	chefao.derrotado.connect(_on_chefao_derrotado)

	brilho.visible = false
	aviso.visible = false


func _on_gatilho_body_entered(corpo: Node2D) -> void:

	if luta_iniciada or vitoria or not corpo.is_in_group("jogador"):
		return

	luta_iniciada = true
	chefao.ativar()


func _on_chefao_derrotado(_chefao: Node) -> void:

	if vitoria:
		return

	vitoria = true

	# Ataques interrompidos: cartões que ainda estão no ar somem
	for projetil in get_tree().get_nodes_in_group("projeteis_inimigos"):
		if projetil.has_method("remover"):
			projetil.remover()

	var jogador := get_tree().get_first_node_in_group("jogador")

	if jogador != null and "invencivel" in jogador:
		jogador.invencivel = true

	# O timer para junto com o jogo pausado
	get_tree().create_timer(atraso_liberacao, false).timeout.connect(_liberar_saida)


func _liberar_saida() -> void:

	if liberada:
		return

	liberada = true
	bloqueio.set_deferred("disabled", true)

	# As barreiras afundam e somem
	var tween := create_tween().set_parallel()

	for barreira in barreiras.get_children():
		tween.tween_property(barreira, "position:y", barreira.position.y + 24.0, 0.6).set_ease(Tween.EASE_IN)
		tween.tween_property(barreira, "modulate:a", 0.0, 0.6)

	tween.chain().tween_callback(barreiras.hide)

	# A placa "SAÍDA" passa a brilhar, pulsando devagar
	brilho.visible = true
	brilho.modulate.a = 0.0

	var pulso := create_tween().set_loops()
	pulso.tween_property(brilho, "modulate:a", 1.0, 0.7)
	pulso.tween_property(brilho, "modulate:a", 0.35, 0.7)

	# Aviso discreto, que some sozinho
	aviso.visible = true
	aviso.modulate.a = 0.0

	var tween_aviso := create_tween()
	tween_aviso.tween_property(aviso, "modulate:a", 1.0, 0.3)
	tween_aviso.tween_interval(2.2)
	tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.8)
	tween_aviso.tween_callback(aviso.hide)

	saida_liberada.emit()


func _on_entrada_body_entered(corpo: Node2D) -> void:

	if not liberada or _saindo or not corpo.is_in_group("jogador"):
		return

	_saindo = true
	Transicao.ir_para(CENA_VITORIA)
