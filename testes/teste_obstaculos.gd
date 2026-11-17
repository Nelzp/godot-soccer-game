extends SceneTree
## Teste headless dos obstáculos (P5).

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


func pes(jogador: CharacterBody2D) -> float:
	var forma := jogador.get_node("CollisionShape2D") as CollisionShape2D
	return forma.global_position.y + (forma.shape as RectangleShape2D).size.y * 0.5


func andar(acao: String, quadros: int) -> void:
	Input.action_press(acao)
	await esperar(quadros)
	Input.action_release(acao)


func pular() -> void:
	Input.action_press("pular")
	await esperar(2)
	Input.action_release("pular")


func _rodar() -> void:

	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)

	var fase := current_scene
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var hud := fase.find_child("Hud", true, false)

	# Inimigos parados, para não interferir (alguns testes os religam)
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.process_mode = Node.PROCESS_MODE_DISABLED

	var obstaculos := get_nodes_in_group("obstaculos")
	checar(obstaculos.size() == 2, "dois obstáculos sólidos na fase (%d)" % obstaculos.size())
	checar(get_nodes_in_group("plataformas").size() == 3, "três plataformas do cenário")

	var barreira: StaticBody2D = fase.get_node("Obstaculos/BarreiraDeSalto")
	var bonecos: StaticBody2D = fase.get_node("Obstaculos/BarreiraDeBonecos")
	var forma_barreira := barreira.get_node("CollisionShape2D") as CollisionShape2D
	var altura_barreira := (forma_barreira.shape as RectangleShape2D).size.y
	var altura_bonecos := (bonecos.get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	checar(altura_barreira > 40.0 and altura_barreira < 70.0, "barreira de salto baixa (%.0f px)" % altura_barreira)
	checar(altura_bonecos > 80.0 and altura_bonecos < 120.0, "barreira de bonecos mais alta, mas pulável (%.0f px)" % altura_bonecos)
	var base_barreira := forma_barreira.global_position.y + altura_barreira * 0.5
	checar(absf(base_barreira - 529.5) < 1.0, "barreira apoiada no chão (base %.1f)" % base_barreira)

	print("-- barreira de salto")
	jogador.global_position = Vector2(200, 470)
	await esperar(10)
	await andar("ir_para_direita", 40)
	var limite := barreira.global_position.x - (forma_barreira.shape as RectangleShape2D).size.x * 0.5
	checar(jogador.global_position.x < limite, "andando, o jogador para na barreira (x = %.0f)" % jogador.global_position.x)
	jogador.global_position.x = limite - 70
	await esperar(5)
	Input.action_press("ir_para_direita")
	await pular()
	await esperar(50)
	Input.action_release("ir_para_direita")
	checar(jogador.global_position.x > barreira.global_position.x + 40, "pulando, passa por cima (x = %.0f)" % jogador.global_position.x)

	print("-- bola para no obstáculo")
	jogador.global_position = Vector2(barreira.global_position.x - 150, 470)
	jogador.direcao = 1
	await esperar(10)
	jogador.spawnar_bolar()
	await esperar(3)
	var bolas := get_nodes_in_group("projeteis").size()
	await esperar(40)
	checar(bolas > 0 and get_nodes_in_group("projeteis").size() == 0, "bola some ao bater na barreira")

	print("-- plataformas do cenário")
	# Passa na frente dos caixotes sem ser bloqueado
	jogador.global_position = Vector2(600, 470)
	await esperar(10)
	await andar("ir_para_direita", 30)
	checar(jogador.global_position.x > 740, "anda na frente dos caixotes A sem bater (x = %.0f)" % jogador.global_position.x)
	checar(absf(pes(jogador) - 529.5) < 3.0, "continua no chão")

	# Pula de baixo e para em cima do caixote do topo
	jogador.global_position = Vector2(685, 470)
	jogador.velocity = Vector2.ZERO
	await esperar(10)
	await pular()
	await esperar(60)
	checar(jogador.is_on_floor() and absf(pes(jogador) - 431.6) < 4.0, "sobe por baixo e fica em cima dos caixotes A (pés em %.1f)" % pes(jogador))

	# Cai em cima da barreira desenhada
	jogador.global_position = Vector2(853, 380)
	jogador.velocity = Vector2.ZERO
	await esperar(40)
	checar(jogador.is_on_floor() and absf(pes(jogador) - 469.3) < 4.0, "fica em cima da barreira (pés em %.1f)" % pes(jogador))

	# Caixotes B (topo e degrau)
	jogador.global_position = Vector2(1472, 360)
	jogador.velocity = Vector2.ZERO
	await esperar(40)
	checar(jogador.is_on_floor() and absf(pes(jogador) - 432.5) < 4.0, "fica em cima dos caixotes B (pés em %.1f)" % pes(jogador))
	jogador.global_position = Vector2(1505, 400)
	jogador.velocity = Vector2.ZERO
	await esperar(40)
	checar(jogador.is_on_floor() and absf(pes(jogador) - 465.0) < 4.0, "e no degrau dos caixotes B (pés em %.1f)" % pes(jogador))

	print("-- inimigos e obstáculos")
	var juiz = fase.get_node("Juiz/Personagem")
	juiz.process_mode = Node.PROCESS_MODE_INHERIT
	jogador.global_position = Vector2(1030, 470)
	await esperar(10)
	checar(not juiz.ve_jogador(), "Juiz não enxerga o jogador atrás dos bonecos")
	jogador.global_position = Vector2(880, 470)
	await esperar(10)
	checar(juiz.ve_jogador(), "Juiz enxerga o jogador sem nada na frente")
	juiz.process_mode = Node.PROCESS_MODE_DISABLED

	var zagueiro = fase.get_node("Zagueiro/Personagem")
	zagueiro.process_mode = Node.PROCESS_MODE_INHERIT
	jogador.global_position = Vector2(150, 470)
	zagueiro.global_position = Vector2(1100, 480)
	zagueiro.direcao = -1
	var menor := INF
	for _i in range(200):
		await physics_frame
		menor = minf(menor, zagueiro.global_position.x)
	var borda_bonecos := bonecos.global_position.x + 147.0 * 0.7 * 0.9 * 0.5
	checar(menor > borda_bonecos, "zagueiro dá meia-volta nos bonecos (menor x %.0f, bonecos até %.0f)" % [menor, borda_bonecos])
	zagueiro.process_mode = Node.PROCESS_MODE_DISABLED

	var goleiro = fase.get_node("Goleiro/Personagem")
	goleiro.process_mode = Node.PROCESS_MODE_INHERIT
	goleiro.global_position = Vector2(1600, 445)
	goleiro.direcao = -1
	var passou_caixotes := false
	for _i in range(200):
		await physics_frame
		if goleiro.global_position.x < 1420:
			passou_caixotes = true
	checar(passou_caixotes, "plataformas não bloqueiam quem anda no chão (goleiro passou dos caixotes B)")
	goleiro.process_mode = Node.PROCESS_MODE_DISABLED

	checar(hud.vidas == 5, "nenhum dano durante o teste")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
