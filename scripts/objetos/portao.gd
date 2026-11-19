extends Node2D
## Portão do estádio (arte de portoes.png, com tom frio para combinar com o
## estádio azul). A origem fica no meio da base: posicione com y na linha do chão.
##
## - Fica fechado até todos os adversários da quadra serem derrotados: os
##   inimigos do grupo "inimigos" entre `inicio_quadra` e o portão.
##   Com `inicio_quadra` negativo, o portão já começa aberto.
## - Fechado, bloqueia a passagem (não dá para pular por cima) e mostra quantos
##   adversários faltam quando o jogador se aproxima.
## - Ao abrir: as folhas abrem com um pequeno tranco e aparece "PASSAGEM LIBERADA".
## - Se `proxima_cena` estiver definida, entrar no portão aberto leva até ela com
##   transição suave (é a passagem da Fase 1 para a Fase 2).

signal aberto

const REGIAO_FECHADO := Rect2(84, 123, 719, 614)
const REGIAO_ABERTO := Rect2(971, 123, 720, 613)

## x (global) onde começa a quadra guardada por este portão (-1 = sem trava).
@export var inicio_quadra: float = -1.0
## Cena carregada ao entrar no portão aberto (vazio = só passagem).
@export_file("*.tscn") var proxima_cena: String = ""
## Distância (px) em que o aviso de adversários restantes aparece.
@export var distancia_aviso: float = 650.0
## Desloca o aviso na horizontal (útil perto da borda da fase).
@export var deslocamento_aviso: float = 0.0

var esta_aberto: bool = false
var restantes: Array[Node] = []
var _saindo: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var parede: CollisionShape2D = $Parede/CollisionShape2D
@onready var entrada: Area2D = $Entrada
@onready var aviso: Label = $Aviso


func _ready() -> void:

	add_to_group("portoes")
	entrada.body_entered.connect(_on_entrada_body_entered)
	aviso.visible = false
	aviso.position.x += deslocamento_aviso

	if inicio_quadra < 0.0:
		_abrir(false)
		return

	# Os inimigos já estão na cena: guarda os da quadra e espera cada um cair
	_contar_inimigos.call_deferred()


func _contar_inimigos() -> void:

	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		var x: float = inimigo.global_position.x
		if x >= inicio_quadra and x <= global_position.x and inimigo.has_signal("derrotado"):
			restantes.append(inimigo)
			inimigo.derrotado.connect(_on_inimigo_derrotado)

	if restantes.is_empty():
		_abrir(false)
	else:
		_fechar()


func _on_inimigo_derrotado(inimigo: Node) -> void:

	restantes.erase(inimigo)
	_atualizar_aviso()

	if restantes.is_empty():
		_abrir(true)


func _process(_delta: float) -> void:

	if esta_aberto:
		return

	var jogador := get_tree().get_first_node_in_group("jogador") as Node2D

	aviso.visible = jogador != null and absf(jogador.global_position.x - global_position.x) <= distancia_aviso


func _fechar() -> void:

	esta_aberto = false
	sprite.region_rect = REGIAO_FECHADO
	parede.set_deferred("disabled", false)
	_atualizar_aviso()


func _abrir(com_efeito: bool) -> void:

	esta_aberto = true
	sprite.region_rect = REGIAO_ABERTO
	parede.set_deferred("disabled", true)

	if not com_efeito:
		aviso.visible = false
		aberto.emit()
		return

	# Tranco das folhas abrindo e aviso de passagem liberada
	var escala := sprite.scale
	var tween := create_tween()
	tween.tween_property(sprite, "scale", escala * Vector2(1.05, 0.96), 0.08)
	tween.tween_property(sprite, "scale", escala, 0.14)

	aviso.text = "PASSAGEM LIBERADA!"
	aviso.add_theme_color_override("font_color", Color(0.55, 1.0, 0.45))
	aviso.visible = true
	aviso.modulate.a = 1.0

	var tween_aviso := create_tween()
	tween_aviso.tween_interval(1.4)
	tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.6)
	tween_aviso.tween_callback(aviso.hide)

	aberto.emit()


func _atualizar_aviso() -> void:

	if esta_aberto:
		return

	var n := restantes.size()
	aviso.text = "DERROTE %d ADVERSÁRIO%s" % [n, "" if n == 1 else "S"]


func _on_entrada_body_entered(corpo: Node2D) -> void:

	if not esta_aberto or _saindo or proxima_cena.is_empty() or not corpo.is_in_group("jogador"):
		return

	_saindo = true

	# Ninguém mais machuca o jogador durante a troca de fase
	if "invencivel" in corpo:
		corpo.invencivel = true

	Transicao.ir_para(proxima_cena)
