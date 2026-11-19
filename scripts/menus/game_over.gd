extends Node2D


func _ready() -> void:

	# Sem música no game over: só o som de game over (que começa na queda do
	# jogador; se a tela abrir de outro jeito, começa aqui)
	Audio.parar_musica(0.3)

	if not Audio.efeito_tocando("game_over"):
		Audio.tocar_efeito("game_over")


## Recomeça na fase em que o jogador perdeu (Fase 1 ou Fase 2).
func tentar_novamente() -> void:
	get_tree().change_scene_to_file(Transicao.fase_atual)


func sair() -> void:
	get_tree().change_scene_to_file("res://cenas/menus/menu_inicial.tscn")
