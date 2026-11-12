
extends Node2D

var vidas: int = 5
var recebendo_dano: bool = false

@onready var animacao: AnimationPlayer = $CanvasLayer/AnimationPlayer


func receber_dano() -> void:
	if recebendo_dano or vidas <= 0:
		return

	recebendo_dano = true
	vidas -= 1

	if vidas <= 0:
		get_tree().change_scene_to_file("res://cena_game_over.tscn")
		return

	var nome_animacao = "piscar_coracao_" + str(vidas + 1)

	animacao.play(nome_animacao)
	await animacao.animation_finished

	recebendo_dano = false
