extends Node2D


## Recomeça na fase em que o jogador perdeu (Fase 1 ou Fase 2).
func tentar_novamente() -> void:
	get_tree().change_scene_to_file(Transicao.fase_atual)


func sair() -> void:
	get_tree().change_scene_to_file("res://cena_inicio.tscn")
