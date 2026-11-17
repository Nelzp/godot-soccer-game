extends SceneTree
## Teste headless do portão da arena com movimento de verdade (teclas simuladas).

var falhas := 0
var verificacoes := 0


func _initialize() -> void:
	_rodar.call_deferred()


func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if condicao:
		print("  ok   - ", descricao)
	else:
		falhas += 1
		print("  FALHA - ", descricao)


func esperar(quadros: int) -> void:
	for _i in range(quadros):
		await physics_frame


func _rodar() -> void:

	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)

	var fase := current_scene
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var arena := fase.get_node("ArenaChefao")
	var goleiro := fase.get_node("Goleiro/Personagem")
	var juiz := fase.get_node("Juiz/Personagem")
	juiz.process_mode = Node.PROCESS_MODE_DISABLED

	print("-- goleiro não entra na arena")
	jogador.global_position = Vector2(300, 470)
	goleiro.global_position = Vector2(1600, 445)
	goleiro.direcao = 1
	var maior_x := 0.0
	for _i in range(240):
		await physics_frame
		maior_x = maxf(maior_x, goleiro.global_position.x)
	checar(maior_x < 1750.0 - 80.0, "goleiro bateu no portão e voltou (maior x = %.0f)" % maior_x)
	goleiro.process_mode = Node.PROCESS_MODE_DISABLED

	print("-- jogador anda pelo portão aberto")
	jogador.global_position = Vector2(1600, 470)
	await esperar(10)
	Input.action_press("ir_para_direita")
	for _i in range(120):
		await physics_frame
		if arena.luta_iniciada:
			break
	Input.action_release("ir_para_direita")
	checar(arena.luta_iniciada, "andando, o jogador atravessa o portão e inicia a luta (x = %.0f)" % jogador.global_position.x)
	checar(jogador.global_position.x > 1770.0, "jogador do lado de dentro")

	print("-- portão fechado segura o jogador")
	Input.action_press("ir_para_esquerda")
	await esperar(90)
	Input.action_release("ir_para_esquerda")
	checar(jogador.global_position.x > 1770.0, "jogador não volta pelo portão fechado (x = %.0f)" % jogador.global_position.x)

	print("-- pulo não passa por cima do portão")
	Input.action_press("ir_para_esquerda")
	Input.action_press("pular")
	await esperar(2)
	Input.action_release("pular")
	await esperar(70)
	Input.action_release("ir_para_esquerda")
	checar(jogador.global_position.x > 1770.0, "pulando também não passa (x = %.0f)" % jogador.global_position.x)

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
