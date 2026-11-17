extends SceneTree
## Obstáculos e plataformas da Fase 1, e posicionamento justo dos inimigos.

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


func retangulo(corpo: Node2D) -> Rect2:
	var forma := corpo.get_node("CollisionShape2D") as CollisionShape2D
	var tamanho := (forma.shape as RectangleShape2D).size * forma.global_scale.abs()
	return Rect2(forma.global_position - tamanho * 0.5, tamanho)


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
	await esperar(3)

	var fase := current_scene
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var hud := fase.find_child("Hud", true, false)
	jogador.invencivel = true

	print("-- posicionamento dos inimigos (ao nascer)")
	var inimigos := get_nodes_in_group("inimigos")
	var obstaculos := get_nodes_in_group("obstaculos")
	var sobrepostos := 0
	var presos := 0
	for i in range(inimigos.size()):
		var a := retangulo(inimigos[i]).grow(-2.0)
		for j in range(i + 1, inimigos.size()):
			if a.intersects(retangulo(inimigos[j]).grow(-2.0)):
				sobrepostos += 1
				print("     sobrepostos: ", inimigos[i].get_parent().name, " e ", inimigos[j].get_parent().name)
		for obstaculo in obstaculos:
			if a.intersects(retangulo(obstaculo)):
				presos += 1
				print("     preso: ", inimigos[i].get_parent().name, " em ", obstaculo.name)
	checar(sobrepostos == 0, "nenhum inimigo nasce sobreposto a outro")
	checar(presos == 0, "nenhum inimigo nasce dentro de obstáculo")
	await esperar(40)
	# O Juiz não se move (sem gravidade): confere pela base do corpo
	var no_chao := 0
	for inimigo in inimigos:
		var base := retangulo(inimigo).end.y
		if absf(base - 529.5) <= 4.0:
			no_chao += 1
		else:
			print("     fora do chão: ", inimigo.get_parent().name, " base em ", base)
	checar(no_chao == inimigos.size(), "todos os %d inimigos apoiados no chão" % inimigos.size())

	for inimigo in inimigos:
		inimigo.process_mode = Node.PROCESS_MODE_DISABLED

	print("-- obstáculos sólidos")
	checar(obstaculos.size() >= 10, "%d obstáculos sólidos (barreiras, bonecos, caixas)" % obstaculos.size())
	var tipos := {}
	for obstaculo in obstaculos:
		tipos[obstaculo.tipo] = true
	checar(tipos.size() >= 4, "%d tipos diferentes de obstáculo" % tipos.size())
	checar(get_nodes_in_group("plataformas").size() >= 20, "plataformas do cenário em todos os trechos (%d)" % get_nodes_in_group("plataformas").size())

	var barreira: StaticBody2D = fase.get_node("Obstaculos/BarreiraDeSalto")
	var borda := retangulo(barreira).position.x
	jogador.global_position = Vector2(220, 470)
	await esperar(10)
	await andar("ir_para_direita", 40)
	checar(jogador.global_position.x < borda, "andando, o jogador para na barreira de salto (x = %.0f)" % jogador.global_position.x)
	jogador.global_position.x = borda - 70.0
	await esperar(5)
	Input.action_press("ir_para_direita")
	await pular()
	await esperar(40)
	Input.action_release("ir_para_direita")
	checar(jogador.global_position.x > barreira.global_position.x + 40.0, "pulando, passa por cima (x = %.0f)" % jogador.global_position.x)

	jogador.global_position = Vector2(barreira.global_position.x - 160, 470)
	jogador.direcao = 1
	await esperar(10)
	jogador.spawnar_bolar()
	await esperar(3)
	var bolas := get_nodes_in_group("projeteis").size()
	await esperar(40)
	checar(bolas > 0 and get_nodes_in_group("projeteis").size() == 0, "bola some ao bater na barreira")

	print("-- plataformas do cenário (caixotes e barreira desenhados)")
	jogador.global_position = Vector2(450, 470)
	await esperar(10)
	await andar("ir_para_direita", 30)
	checar(jogador.global_position.x > 640.0 and absf(pes(jogador) - 529.5) < 3.0, "passa na frente dos caixotes sem bater (x = %.0f)" % jogador.global_position.x)
	jogador.global_position = Vector2(555, 470)
	jogador.velocity = Vector2.ZERO
	await esperar(10)
	await pular()
	await esperar(60)
	checar(jogador.is_on_floor() and absf(pes(jogador) - 431.6) < 4.0, "sobe por baixo e fica em cima dos caixotes (pés em %.1f)" % pes(jogador))

	# Do alto, a bola não bate nas plataformas desenhadas (camada própria)
	jogador.direcao = 1
	jogador.spawnar_bolar()
	await esperar(2)
	var bola = null
	for projetil in get_nodes_in_group("projeteis"):
		bola = projetil
	await esperar(25)
	checar(bola != null and is_instance_valid(bola) and bola.global_position.x > 750.0, "bola chutada do alto atravessa a barreira desenhada")

	jogador.global_position = Vector2(691, 380)
	jogador.velocity = Vector2.ZERO
	await esperar(40)
	checar(jogador.is_on_floor() and absf(pes(jogador) - 469.3) < 4.0, "fica em cima da barreira desenhada (pés em %.1f)" % pes(jogador))

	print("-- visão do Juiz e patrulhas")
	var juiz2 = fase.get_node("Inimigos/Juiz2/Personagem")
	juiz2.process_mode = Node.PROCESS_MODE_INHERIT
	jogador.global_position = Vector2(1200, 470)
	await esperar(10)
	checar(not juiz2.ve_jogador(), "Juiz não enxerga através dos bonecos")
	jogador.global_position = Vector2(1420, 470)
	await esperar(10)
	checar(juiz2.ve_jogador(), "Juiz enxerga com o caminho livre")
	juiz2.process_mode = Node.PROCESS_MODE_DISABLED

	var bonecos: StaticBody2D = fase.get_node("Obstaculos/Bonecos")
	var zagueiro = fase.get_node("Inimigos/Zagueiro/Personagem")
	zagueiro.process_mode = Node.PROCESS_MODE_INHERIT
	zagueiro.raio_patrulha = 0.0
	zagueiro.direcao = 1
	jogador.global_position = Vector2(150, 470)
	var maior := -INF
	for _i in range(200):
		await physics_frame
		maior = maxf(maior, zagueiro.global_position.x)
	checar(maior < retangulo(bonecos).position.x, "zagueiro dá meia-volta nos bonecos (maior x %.0f)" % maior)
	zagueiro.process_mode = Node.PROCESS_MODE_DISABLED

	var goleiro = fase.get_node("Inimigos/Goleiro/Personagem")
	goleiro.process_mode = Node.PROCESS_MODE_INHERIT
	goleiro.raio_patrulha = 0.0
	goleiro.direcao = -1
	var menor := INF
	for _i in range(120):
		await physics_frame
		menor = minf(menor, goleiro.global_position.x)
	checar(menor < 1800.0, "plataformas não atrapalham quem anda no chão (goleiro passou dos caixotes)")
	goleiro.process_mode = Node.PROCESS_MODE_DISABLED

	checar(hud.vidas == 5, "nenhum dano durante o teste")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
