extends Control
## Tela de vitória: imagem oficial com um botão transparente sobre
## "RETORNAR AO MENU". Enter/Espaço também acionam o botão (ele começa
## com o foco).

@onready var botao_retornar: Button = $BotaoRetornar


func _ready() -> void:

	# Nada pode continuar pausado vindo da fase
	get_tree().paused = false

	Audio.tocar_musica("vitoria")

	botao_retornar.pressed.connect(retornar_ao_menu)
	botao_retornar.grab_focus()


func retornar_ao_menu() -> void:
	get_tree().change_scene_to_file("res://cena_inicio.tscn")
