
extends Node2D

@onready var botao_continuar: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoContinuar
@onready var botao_reiniciar: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoReiniciar
@onready var botao_sair: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoSair
@onready var botao_configuracoes: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoConfiguracoes

@onready var canvas_hud: CanvasLayer = get_parent()
@onready var sprite_personagem: Sprite2D = canvas_hud.get_node("Sprite2D")

const CENA_CONFIGURACOES := preload("res://cenas/menus/configuracoes.tscn")

var coracoes: Array[Node] = []

## Tela de configurações aberta por cima da pausa (ou null).
var tela_configuracoes: Node = null


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	coracoes = [
		canvas_hud.get_node("coracao1"),
		canvas_hud.get_node("coracao2"),
		canvas_hud.get_node("coracao3"),
		canvas_hud.get_node("coracao4"),
		canvas_hud.get_node("coracao5")
	]

	botao_continuar.pressed.connect(continuar_jogo)
	botao_reiniciar.pressed.connect(reiniciar_jogo)
	botao_sair.pressed.connect(sair_jogo)
	botao_configuracoes.pressed.connect(abrir_configuracoes)


func _input(event: InputEvent) -> void:

	# Com as configurações abertas, o Esc é delas (fecha só aquela tela)
	if is_instance_valid(tela_configuracoes):
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():

		if visible:
			continuar_jogo()
		else:
			abrir_menu()

		get_viewport().set_input_as_handled()


func abrir_menu() -> void:

	visible = true
	get_tree().paused = true

	sprite_personagem.visible = false

	for coracao in coracoes:
		coracao.visible = false

	# Outros elementos da tela (ex.: barra de vida do chefão)
	for elemento in get_tree().get_nodes_in_group("ocultar_na_pausa"):
		elemento.visible = false

	print("JOGO PAUSADO")


func continuar_jogo() -> void:

	visible = false
	get_tree().paused = false

	sprite_personagem.visible = true

	for coracao in coracoes:
		coracao.visible = true

	for elemento in get_tree().get_nodes_in_group("ocultar_na_pausa"):
		elemento.visible = true

	print("JOGO CONTINUANDO")


func abrir_configuracoes() -> void:

	if is_instance_valid(tela_configuracoes):
		return

	tela_configuracoes = CENA_CONFIGURACOES.instantiate()
	add_child(tela_configuracoes)
	tela_configuracoes.fechada.connect(_on_configuracoes_fechada)


func _on_configuracoes_fechada() -> void:

	tela_configuracoes = null
	botao_configuracoes.grab_focus()


func reiniciar_jogo() -> void:

	get_tree().paused = false
	get_tree().reload_current_scene()

	print("FASE REINICIADA")


func sair_jogo() -> void:

	get_tree().paused = false
	get_tree().change_scene_to_file("res://cenas/menus/menu_inicial.tscn")

	print("RETORNANDO AO MENU INICIAL")
