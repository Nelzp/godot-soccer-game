extends CharacterBody2D

var velocidade  = 500
var gravidade   = 30
var forca_pulo  = 800
var direcao     = 1 # 1 para direita, -1 para esquerda
var animando    = false


func _process(delta: float) -> void:
	velocity.x = 0
	velocity.y += gravidade
	
	if (Input.is_action_pressed("ir_para_esquerda")):
		velocity.x = -velocidade
		direcao = -1
		$Sprite2D.flip_h = true
	
	if (Input.is_action_pressed("ir_para_direita")):
		velocity.x = velocidade
		direcao = 1
		$Sprite2D.flip_h = false
		
	
	if (Input.is_action_just_pressed("pular") and is_on_floor()):
		velocity.y = -forca_pulo
				
	
	if (is_on_floor()):
		if ($AnimationPlayer.current_animation==""):
			animando = false
			
		if (not animando):
			if (velocity.x == 0):
				$AnimationPlayer.play("parado")
			else:
				$AnimationPlayer.play("correndo")
		
		if (Input.is_action_pressed("chutar")):
			$AnimationPlayer.play("chutando")
			animando = true
			
		if (Input.is_action_pressed("carrinho")):
			$AnimationPlayer.play("carrinho")
			animando = true
			
	else:
		$AnimationPlayer.play("pulando")

	move_and_slide()
	
func spawnar_bolar():
	var cena_bola = preload("res://cena_bola.tscn")
	var obj_bola  = cena_bola.instantiate()
	obj_bola.get_node("CharacterBody2D").direcao = direcao
	get_parent().add_child(obj_bola)
	
	var pos_x = abs($Marker2D.position.x)
	$Marker2D.position.x = pos_x * direcao
	
	obj_bola.global_position = $Marker2D.global_position
	
	


	
	
