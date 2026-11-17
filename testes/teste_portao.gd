extends SceneTree
## Portões da Fase 1: travados até a quadra ser vencida, aviso de adversários
## restantes, abertura e o portão final levando à Fase 2 com transição suave.

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


func andar(acao: String, quadros: int, pular: bool = false) -> void:
	Input.action_press(acao)
	if pular:
		Input.action_press("pular")
	await esperar(2)
	Input.action_release("pular")
	await esperar(quadros)
	Input.action_release(acao)


func _rodar() -> void:

	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	jogador.invencivel = true

	var portoes := get_nodes_in_group("portoes")
	portoes.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var p1 = portoes[0]
	var final = portoes[portoes.size() - 1]

	print("-- portão da quadra 1")
	var da_quadra := []
	for inimigo in get_nodes_in_group("inimigos"):
		if inimigo.global_position.x < p1.global_position.x:
			da_quadra.append(inimigo)
	checar(not p1.esta_aberto and p1.restantes.size() == da_quadra.size(), "fechado, esperando os %d adversários da quadra" % da_quadra.size())

	# Inimigos parados para não atrapalhar
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.set_physics_process(false)

	jogador.global_position = Vector2(p1.global_position.x - 150, 470)
	await esperar(10)
	checar(p1.aviso.visible and p1.aviso.text == "DERROTE %d ADVERSÁRIOS" % da_quadra.size(), "aviso perto do portão: \"%s\"" % p1.aviso.text)
	var limite: float = p1.global_position.x - 30.0
	await andar("ir_para_direita", 50)
	checar(jogador.global_position.x < limite, "andando, o jogador para no portão (x = %.0f)" % jogador.global_position.x)
	await andar("ir_para_direita", 60, true)
	checar(jogador.global_position.x < limite, "pulando também não passa (x = %.0f)" % jogador.global_position.x)

	da_quadra[0].receber_dano(99)
	await esperar(2)
	checar(p1.aviso.text == "DERROTE %d ADVERSÁRIOS" % (da_quadra.size() - 1), "o aviso conta os que faltam: \"%s\"" % p1.aviso.text)
	for inimigo in da_quadra:
		if is_instance_valid(inimigo) and not inimigo.morrendo:
			inimigo.receber_dano(99)
	await esperar(5)
	checar(p1.esta_aberto and p1.get_node("Parede/CollisionShape2D").disabled, "quadra vencida: portão aberto")
	checar(p1.aviso.text == "PASSAGEM LIBERADA!", "aviso de passagem liberada")
	await andar("ir_para_direita", 50)
	checar(jogador.global_position.x > p1.global_position.x + 60, "jogador atravessa o portão (x = %.0f)" % jogador.global_position.x)
	checar(not portoes[1].esta_aberto, "o portão da quadra seguinte continua fechado")

	print("-- portão final")
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.receber_dano(99)
	await esperar(5)
	checar(final.esta_aberto, "sem adversários, o portão final abre")
	jogador.global_position = Vector2(final.global_position.x - 200, 470)
	await esperar(10)
	await andar("ir_para_direita", 40)
	var transicao = root.get_node("Transicao")
	checar(transicao.em_transicao(), "entrar no portão final inicia a transição suave")
	await esperar(90)
	checar(current_scene != null and current_scene.scene_file_path == "res://cena_fase2.tscn", "a transição carrega a Fase 2")
	checar(transicao.fase_atual == "res://cena_fase2.tscn", "Fase 2 registrada como fase atual")
	var jogador2 := get_first_node_in_group("jogador") as CharacterBody2D
	checar(jogador2 != null and jogador2 != jogador and not jogador2.invencivel, "jogador novo na Fase 2, sem estado antigo")
	await esperar(40)
	checar(not transicao.em_transicao(), "a tela clareia de novo")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
