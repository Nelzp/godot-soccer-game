
extends Node2D

@onready var botao_continuar: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoContinuar
@onready var botao_reiniciar: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoReiniciar
@onready var botao_sair: Button = $FundoEscuro/CenterContainer/VBoxContainer/BotaoSair

@onready var canvas_hud: CanvasLayer = get_parent()
@onready var sprite_personagem: Sprite2D = canvas_hud.get_node("Sprite2D")

var coracoes: Array[Node] = []


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


func _input(event: InputEvent) -> void:

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

	print("JOGO PAUSADO")


func continuar_jogo() -> void:

	visible = false
	get_tree().paused = false

	sprite_personagem.visible = true

	for coracao in coracoes:
		coracao.visible = true

	print("JOGO CONTINUANDO")


func reiniciar_jogo() -> void:

	get_tree().paused = false
	get_tree().reload_current_scene()

	print("FASE REINICIADA")


func sair_jogo() -> void:

	get_tree().paused = false
	get_tree().change_scene_to_file("res://cena_inicio.tscn")

	print("RETORNANDO AO MENU INICIAL")
