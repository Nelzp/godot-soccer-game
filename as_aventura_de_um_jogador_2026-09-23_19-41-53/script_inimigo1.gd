extends CharacterBody2D

var direcao_inimigo = 1

func _process(delta: float) -> void:
	
	if $RayCast2D.get_collider()!=null && $RayCast2D.get_collider().name == "Personagem":
		$AnimationPlayer.play("atirando")
	else:
		$AnimationPlayer.play("parado")
	
	
	#get_tree().root.print_tree()
	var personagem = get_tree().root.get_node("Fase/Jogador/Personagem")	
	var personagem_pos_x = personagem.global_position.x
	
	if global_position.x < personagem_pos_x:
		$Sprite2D.flip_h = false
		$Marker2D.position.x = abs($Marker2D.position.x)
		direcao_inimigo = 1
	else:
		$Sprite2D.flip_h = true
		$Marker2D.position.x = -abs($Marker2D.position.x)
		direcao_inimigo = -1
		
		



func atirar_cartao():
	var cena_cartao = preload("res://cena_cartao.tscn")
	var obj_cartao  = cena_cartao.instantiate()
	get_parent().add_child(obj_cartao)
	obj_cartao.get_node("CharacterBody2D").direcao = direcao_inimigo
	obj_cartao.global_position = $Marker2D.global_position
	
	
	
	
