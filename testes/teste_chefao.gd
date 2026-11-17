extends SceneTree
## Teste headless da luta contra o chefão (P2).
## Uso: godot --headless --path <projeto> --fixed-fps 60 --script <este arquivo>

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
	checar(fase != null and fase.name == "Fase", "fase carregada")

	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var arena := fase.get_node_or_null("ArenaChefao")
	var chefao := arena.get_node_or_null("Chefao") if arena else null
	var hud := fase.find_child("Hud", true, false)

	checar(jogador != null, "jogador encontrado")
	checar(arena != null, "arena encontrada")
	checar(chefao != null, "chefão encontrado")
	if jogador == null or chefao == null:
		quit(1)
		return

	print("-- estado inicial")
	checar(chefao.vida == 12 and chefao.vida_maxima == 12, "chefão com 12 de vida")
	checar(chefao.estado == chefao.Estado.INATIVO, "chefão começa inativo")
	checar(not chefao.get_node("BarraVida").visible, "barra de vida escondida antes da luta")
	checar(chefao.is_in_group("inimigos"), "chefão está no grupo inimigos")
	checar(absf(chefao.global_position.y - 529.0) < 3.0, "chefão apoiado no chão (y=%.1f)" % chefao.global_position.y)

	chefao.receber_dano(1)
	checar(chefao.vida == 12, "inativo não recebe dano")

	print("-- portão aberto só para o jogador")
	var portao: StaticBody2D = arena.get_node("Portao")
	checar(jogador in portao.get_collision_exceptions(), "jogador atravessa o portão aberto")

	print("-- entrada na arena")
	jogador.global_position = Vector2(1930, 470)
	await esperar(3)
	checar(arena.luta_iniciada, "gatilho iniciou a luta")
	checar(not (jogador in portao.get_collision_exceptions()), "portão fechou para o jogador")
	checar(chefao.estado == chefao.Estado.APRESENTACAO, "chefão em apresentação")
	checar(chefao.get_node("BarraVida").visible, "barra de vida visível")
	chefao.receber_dano(1)
	checar(chefao.vida == 12, "não recebe dano na apresentação")

	# Deixa o jogador longe para provocar o lançamento de cartões
	jogador.global_position = Vector2(1830, 470)
	await esperar(95)
	checar(chefao.estado != chefao.Estado.APRESENTACAO, "apresentação terminou")

	print("-- cartões (fase 1)")
	var achou_cartao := false
	var altura_ok := false
	for _i in range(120):
		await physics_frame
		var cartoes := get_nodes_in_group("projeteis_inimigos")
		if cartoes.size() > 0:
			achou_cartao = true
			var c = cartoes[0]
			altura_ok = absf(c.altura_alvo - (chefao.global_position.y - chefao.altura_cartao_baixo)) < 0.5
			break
	checar(achou_cartao, "chefão lançou cartão com o jogador longe")
	checar(altura_ok, "cartão da fase 1 é rasteiro")

	# O cartão rasteiro acerta o jogador parado no chão
	var vidas_antes: int = hud.vidas
	for _i in range(150):
		await physics_frame
		if hud.vidas < vidas_antes:
			break
	checar(hud.vidas == vidas_antes - 1, "cartão rasteiro tirou 1 vida do jogador parado (%d -> %d)" % [vidas_antes, hud.vidas])

	print("-- soco")
	await esperar(60)
	hud.vidas = 5
	jogador.global_position = Vector2(chefao.global_position.x - 95, 470)
	vidas_antes = hud.vidas
	var socou := false
	for _i in range(160):
		await physics_frame
		if chefao.estado == chefao.Estado.SOCANDO:
			socou = true
		if hud.vidas < vidas_antes:
			break
	checar(socou, "chefão socou com o jogador perto")
	checar(hud.vidas == vidas_antes - 1, "soco tirou 1 vida (%d -> %d)" % [vidas_antes, hud.vidas])
	checar(jogador.empurrao_x < 0.0 or jogador.global_position.x < chefao.global_position.x - 100, "soco empurrou o jogador para longe")

	print("-- bola de verdade")
	hud.vidas = 5
	await esperar(70)
	var vida_b: int = chefao.vida
	jogador.global_position = Vector2(chefao.global_position.x - 260, 470)
	jogador.direcao = 1
	jogador.spawnar_bolar()
	for _i in range(60):
		await physics_frame
		if chefao.vida < vida_b:
			break
	checar(chefao.vida == vida_b - 1, "bola chutada tira 1 de vida (%d -> %d)" % [vida_b, chefao.vida])

	print("-- jogador em cima da cabeça")
	hud.vidas = 5
	await esperar(40)
	jogador.global_position = Vector2(chefao.global_position.x, chefao._topo() - 70)
	jogador.velocity = Vector2.ZERO
	var empurrado := false
	var esteve_em_cima := false
	for _i in range(120):
		await physics_frame
		if chefao._jogador_esta_em_cima(jogador):
			esteve_em_cima = true
		if esteve_em_cima and jogador.empurrao_x != 0.0:
			empurrado = true
			break
	checar(esteve_em_cima, "jogador pousou em cima do chefão")
	checar(empurrado, "jogador em cima é empurrado para fora")
	checar(hud.vidas == 5, "empurrão de cima não tira vida")
	await esperar(40)
	checar(not chefao._jogador_esta_em_cima(jogador), "jogador não fica em cima")
	var distancia_queda := absf(jogador.global_position.x - chefao.global_position.x)
	checar(distancia_queda > chefao._meia_largura() + chefao.alcance_soco + 20.0, "jogador cai fora do alcance do soco (%.0f px)" % distancia_queda)

	print("-- dano e troca de fase")
	hud.vidas = 5
	# volta a vida para 12 (a bola de verdade tirou 1) para o restante do roteiro
	chefao.vida = 12
	chefao.get_node("BarraVida").atualizar(12, 12)
	jogador.global_position = Vector2(1830, 470)
	await esperar(30)
	for _i in range(6):
		chefao.receber_dano(1)
		await esperar(2)
	checar(chefao.vida == 6, "6 golpes de bola: vida 6 (vida=%d)" % chefao.vida)
	checar(chefao.estado == chefao.Estado.TRANSICAO, "entrou na transição de fase")
	chefao.receber_dano(2)
	checar(chefao.vida == 6, "invulnerável na transição")
	await esperar(100)
	checar(chefao.fase == 2, "fase 2 ativa")
	checar(chefao.animacao.speed_scale > 1.0, "animações mais rápidas na fase 2")

	print("-- rajada da fase 2")
	hud.vidas = 5
	for c in get_nodes_in_group("projeteis_inimigos"):
		c.remover()
	chefao.global_position.x = 2250.0
	jogador.global_position = Vector2(1810, 470)
	chefao.cartoes_na_rajada = 0
	chefao._mudar_estado(chefao.Estado.PERSEGUINDO)
	await esperar(2)
	chefao.recarga_cartao = 0.0
	var alturas: Array[float] = []
	var vistos := {}
	for _i in range(200):
		await physics_frame
		for c in get_nodes_in_group("projeteis_inimigos"):
			if not vistos.has(c):
				vistos[c] = true
				alturas.append(chefao.global_position.y - c.altura_alvo)
		if alturas.size() >= 2:
			break
	checar(alturas.size() >= 2, "fase 2 lança dois cartões seguidos")
	if alturas.size() >= 2:
		checar(absf(alturas[0] - chefao.altura_cartao_baixo) < 1.0 and absf(alturas[1] - chefao.altura_cartao_alto) < 1.0, "primeiro rasteiro, segundo alto (%s)" % str(alturas))

	print("-- carrinho tira 2")
	var vida_antes: int = chefao.vida
	chefao.receber_dano(jogador.dano_carrinho)
	checar(chefao.vida == vida_antes - 2, "carrinho tira 2 de vida")

	print("-- morte e vitória")
	hud.vidas = 5
	var derrotado := [false]
	chefao.derrotado.connect(func(_c): derrotado[0] = true)
	for _i in range(20):
		if chefao.vida <= 0:
			break
		chefao.receber_dano(1)
		await esperar(1)
	checar(derrotado[0], "sinal derrotado emitido")
	checar(chefao.morrendo, "chefão morrendo")
	checar(not chefao.is_in_group("inimigos"), "chefão saiu do grupo inimigos")
	checar(jogador.invencivel, "jogador ficou invencível")
	await esperar(5)
	checar(get_nodes_in_group("projeteis_inimigos").size() == 0, "cartões no ar foram removidos")
	jogador.receber_dano()
	checar(hud.vidas == 5, "jogador não leva dano depois da vitória")

	await esperar(200)
	var cena := current_scene
	checar(cena != null and cena.scene_file_path == "res://cena_vitoria.tscn", "tela de vitória carregada (%s)" % (cena.scene_file_path if cena else "nada"))
	if cena != null and cena.scene_file_path == "res://cena_vitoria.tscn":
		var botao: Button = cena.get_node("BotaoRetornar")
		checar(botao.has_focus(), "botão de retorno com foco")
		botao.pressed.emit()
		await esperar(5)
		checar(current_scene != null and current_scene.scene_file_path == "res://cena_inicio.tscn", "botão volta ao menu inicial")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
