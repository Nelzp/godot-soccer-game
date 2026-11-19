extends Node2D

const CENA_CONFIGURACOES := preload("res://cenas/menus/configuracoes.tscn")

## Tela de configurações aberta por cima do menu (ou null).
var tela_configuracoes: Node = null


func _ready() -> void:
	Audio.tocar_musica("menu")


func iniciar_jogo() -> void:
	get_tree().change_scene_to_file("res://cenas/fases/fase_1.tscn")


func sair_jogo() -> void:
	get_tree().quit()


func _on_botao_configuracao_pressed() -> void:

	if is_instance_valid(tela_configuracoes):
		return

	tela_configuracoes = CENA_CONFIGURACOES.instantiate()
	add_child(tela_configuracoes)
	tela_configuracoes.fechada.connect(_on_configuracoes_fechada)


func _on_configuracoes_fechada() -> void:
	tela_configuracoes = null
