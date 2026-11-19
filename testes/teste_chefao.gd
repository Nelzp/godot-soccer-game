extends SceneTree
## Teste headless da luta contra o chefão na Fase 2 e da saída do estádio.

var falhas := 0
var verificacoes := 0
var derrotado := false


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

	change_scene_to_file("res://cenas/fases/fase_2.tscn")
	await esperar(5)

	var fase := current_scene
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var arena = fase.get_node("Arena")
	var chefao = arena.get_node("Chefao")
	var hud := fase.find_child("Hud", true, false)
	var bloqueio: CollisionShape2D = arena.get_node("Saida/Bloqueio/CollisionShape2D")
	checar(chefao != null and jogador != null, "Fase 2 com jogador e chefão")

	print("-- estado inicial")
	checar(chefao.vida == 12 and chefao.vida_maxima == 12, "chefão com 12 de vida")
	checar(chefao.estado == chefao.Estado.INATIVO, "chefão começa inativo")
	checar(not chefao.get_node("BarraVida").visible, "barra de vida escondida antes da luta")
	checar(not bloqueio.disabled and arena.get_node("Saida/Barreiras").visible, "saída bloqueada pelas barreiras")
	chefao.receber_dano(1)
	checar(chefao.vida == 12, "inativo não recebe dano")

	print("-- início da luta")
	jogador.global_position = Vector2(560, 410)
	await esperar(3)
	checar(arena.luta_iniciada, "entrar na arena inicia a luta")
	checar(chefao.estado == chefao.Estado.APRESENTACAO, "chefão em apresentação")
	checar(chefao.get_node("BarraVida").visible, "barra de vida visível")
	chefao.receber_dano(1)
	checar(chefao.vida == 12, "não recebe dano na apresentação")

	# Longe do chefão para provocar os cartões
	jogador.global_position = Vector2(300, 410)
	await esperar(95)
	checar(chefao.estado != chefao.Estado.APRESENTACAO, "apresentação terminou")

	print("-- cartões (fase 1)")
	var achou := false
	var rasteiro := false
	for _i in range(140):
		await physics_frame
		var cartoes := get_nodes_in_group("projeteis_inimigos")
		if cartoes.size() > 0:
			achou = true
			rasteiro = absf(cartoes[0].altura_alvo - (chefao.global_position.y - chefao.altura_cartao_baixo)) < 0.5
			break
	checar(achou, "chefão lança cartão com o jogador longe")
	checar(rasteiro, "cartão da fase 1 é rasteiro")
	var vidas: int = hud.vidas
	for _i in range(150):
		await physics_frame
		if hud.vidas < vidas:
			break
	checar(hud.vidas == vidas - 1, "cartão rasteiro tira 1 vida do jogador parado")

	print("-- soco")
	await esperar(60)
	hud.vidas = 5
	jogador.global_position = Vector2(chefao.global_position.x - 95, 410)
	vidas = hud.vidas
	var socou := false
	for _i in range(160):
		await physics_frame
		if chefao.estado == chefao.Estado.SOCANDO:
			socou = true
		if hud.vidas < vidas:
			break
	checar(socou, "chefão soca com o jogador perto")
	checar(hud.vidas == vidas - 1, "soco tira 1 vida")
	checar(jogador.empurrao_x < 0.0 or jogador.global_position.x < chefao.global_position.x - 100, "soco empurra o jogador")

	print("-- bola de verdade")
	hud.vidas = 5
	await esperar(70)
	var vida_antes: int = chefao.vida
	jogador.global_position = Vector2(chefao.global_position.x - 260, 410)
	await esperar(10)
	jogador.direcao = 1
	jogador.spawnar_bolar()
	for _i in range(60):
		await physics_frame
		if chefao.vida < vida_antes:
			break
	checar(chefao.vida == vida_antes - 1, "bola chutada tira 1 de vida")

	print("-- jogador em cima da cabeça")
	hud.vidas = 5
	await esperar(40)
	jogador.global_position = Vector2(chefao.global_position.x, chefao._topo() - 70)
	jogador.velocity = Vector2.ZERO
	var esteve := false
	var empurrado := false
	for _i in range(120):
		await physics_frame
		if chefao._jogador_esta_em_cima(jogador):
			esteve = true
		if esteve and jogador.empurrao_x != 0.0:
			empurrado = true
			break
	checar(esteve and empurrado, "jogador em cima é empurrado para fora")
	checar(hud.vidas == 5, "empurrão de cima não tira vida")

	print("-- saída bloqueada durante a luta")
	hud.vidas = 5
	chefao.global_position.x = 600.0
	jogador.global_position = Vector2(1100, 410)
	await esperar(5)
	Input.action_press("ir_para_direita")
	await esperar(60)
	Input.action_release("ir_para_direita")
	checar(jogador.global_position.x < 1225.0, "barreiras seguram o jogador (x = %.0f)" % jogador.global_position.x)
	checar(current_scene == fase, "nada de vitória durante a luta")

	print("-- troca de fase do chefão")
	hud.vidas = 5
	chefao.vida = 12
	jogador.global_position = Vector2(350, 410)
	await esperar(30)
	for _i in range(6):
		chefao.receber_dano(1)
		await esperar(2)
	checar(chefao.vida == 6 and chefao.estado == chefao.Estado.TRANSICAO, "metade da vida: transição de fase")
	chefao.receber_dano(2)
	checar(chefao.vida == 6, "invulnerável na transição")
	await esperar(100)
	checar(chefao.fase == 2 and chefao.animacao.speed_scale > 1.0, "fase 2 ativa e mais rápida")

	print("-- rajada da fase 2")
	hud.vidas = 5
	for c in get_nodes_in_group("projeteis_inimigos"):
		c.remover()
	chefao.global_position.x = 1150.0
	jogador.global_position = Vector2(330, 410)
	chefao.cartoes_na_rajada = 0
	chefao._mudar_estado(chefao.Estado.PERSEGUINDO)
	await esperar(2)
	chefao.recarga_cartao = 0.0
	var alturas: Array[float] = []
	var vistos := {}
	for _i in range(220):
		await physics_frame
		for c in get_nodes_in_group("projeteis_inimigos"):
			if not vistos.has(c):
				vistos[c] = true
				alturas.append(chefao.global_position.y - c.altura_alvo)
		if alturas.size() >= 2:
			break
	checar(alturas.size() >= 2 and absf(alturas[0] - chefao.altura_cartao_baixo) < 1.0 and absf(alturas[1] - chefao.altura_cartao_alto) < 1.0, "fase 2: cartão rasteiro e depois alto (%s)" % str(alturas))

	print("-- carrinho tira 2")
	vida_antes = chefao.vida
	chefao.receber_dano(jogador.dano_carrinho)
	checar(chefao.vida == vida_antes - 2, "carrinho tira 2 de vida")

	print("-- morte e saída")
	hud.vidas = 5
	chefao.derrotado.connect(func(_c): derrotado = true)
	for _i in range(20):
		if chefao.vida <= 0:
			break
		chefao.receber_dano(1)
		await esperar(1)
	checar(derrotado and chefao.morrendo and not chefao.is_in_group("inimigos"), "chefão derrotado, fora do grupo inimigos")
	checar(jogador.invencivel, "jogador protegido depois da vitória")
	await esperar(5)
	checar(get_nodes_in_group("projeteis_inimigos").size() == 0, "cartões no ar removidos")
	await esperar(300)
	checar(current_scene == fase, "a vitória NÃO carrega sozinha (5 s depois, ainda na Fase 2)")
	checar(arena.liberada and bloqueio.disabled, "saída liberada")
	checar(not arena.get_node("Saida/Barreiras").visible and arena.get_node("Saida/Brilho").visible, "barreiras somem e a placa SAÍDA brilha")
	checar(not is_instance_valid(chefao), "chefão e sua barra de vida saíram de cena")

	print("-- entrar na saída")
	jogador.global_position = Vector2(1150, 410)
	await esperar(5)
	Input.action_press("ir_para_direita")
	await esperar(60)
	Input.action_release("ir_para_direita")
	await esperar(120)
	checar(current_scene != null and current_scene.scene_file_path == "res://cenas/menus/vitoria.tscn", "entrar na saída leva à tela de vitória")
	if current_scene != null and current_scene.scene_file_path == "res://cenas/menus/vitoria.tscn":
		var botao: Button = current_scene.get_node("BotaoRetornar")
		checar(botao.has_focus(), "botão RETORNAR AO MENU com foco")
		botao.pressed.emit()
		await esperar(5)
		checar(current_scene != null and current_scene.scene_file_path == "res://cenas/menus/menu_inicial.tscn", "botão volta ao menu inicial")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
