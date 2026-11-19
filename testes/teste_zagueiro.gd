extends SceneTree
## Teste headless do Zagueiro rival (P4).

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

	root.get_node("Configuracoes").caminho_arquivo = "user://teste_zagueiro.cfg"
	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)

	var fase := current_scene
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var hud := fase.find_child("Hud", true, false)
	var zagueiro = fase.get_node_or_null("Inimigos/Zagueiro/Personagem")
	checar(zagueiro != null, "zagueiro na fase")
	if zagueiro == null:
		quit(1)
		return

	for inimigo in get_nodes_in_group("inimigos"):
		if inimigo != zagueiro:
			inimigo.process_mode = Node.PROCESS_MODE_DISABLED

	print("-- básico")
	checar(zagueiro.is_in_group("inimigos"), "zagueiro no grupo inimigos")
	checar(zagueiro.vida == 3 and zagueiro.vida_maxima == 3, "zagueiro com 3 de vida")
	await esperar(30)
	checar(zagueiro.is_on_floor(), "zagueiro apoiado no chão")

	print("-- patrulha")
	jogador.global_position = Vector2(150, 470)
	var x0: float = zagueiro._x_inicial
	var menor := INF
	var maior := -INF
	var virou := false
	var direcao_antes: int = zagueiro.direcao
	for _i in range(360):
		await physics_frame
		menor = minf(menor, zagueiro.global_position.x)
		maior = maxf(maior, zagueiro.global_position.x)
		if zagueiro.direcao != direcao_antes:
			virou = true
	checar(zagueiro.estado == zagueiro.Estado.PATRULHANDO, "patrulhando com o jogador longe")
	checar(virou, "vira nos limites da patrulha")
	checar(menor >= x0 - zagueiro.raio_patrulha - 12.0 and maior <= x0 + zagueiro.raio_patrulha + 12.0, "fica dentro do raio de patrulha (%.0f a %.0f; início %.0f)" % [menor, maior, x0])

	print("-- carrinho acerta o jogador parado")
	hud.vidas = 5
	zagueiro.recarga = 0.0
	jogador.global_position = Vector2(zagueiro.global_position.x - 200, 470)
	await esperar(2)
	var preparou := false
	var deslizou := false
	for _i in range(150):
		await physics_frame
		if zagueiro.estado == zagueiro.Estado.PREPARANDO:
			preparou = true
		if zagueiro.estado == zagueiro.Estado.DESLIZANDO:
			deslizou = true
		if hud.vidas < 5:
			break
	checar(preparou, "zagueiro se prepara antes (aviso)")
	checar(deslizou, "zagueiro dá o carrinho")
	checar(hud.vidas == 4, "carrinho tira 1 vida (vidas = %d)" % hud.vidas)
	checar(jogador.empurrao_x < 0.0, "carrinho empurra o jogador para trás")
	await esperar(2)
	checar(zagueiro.estado == zagueiro.Estado.RECUPERANDO, "depois do carrinho fica parado (vulnerável)")

	print("-- recarga")
	hud.vidas = 5
	await esperar(60)
	jogador.global_position = Vector2(zagueiro.global_position.x - 180, 470)
	await esperar(10)
	checar(zagueiro.estado != zagueiro.Estado.DESLIZANDO, "não repete o carrinho durante a recarga")

	print("-- pular por cima do carrinho")
	await esperar(120)
	hud.vidas = 5
	jogador.empurrao_x = 0.0
	# Campo livre à frente do zagueiro (os bonecos ficam mais à esquerda).
	# Um teletransporte por vez, para os dois corpos nunca se sobreporem.
	jogador.global_position = Vector2(700, 470)
	await esperar(2)
	zagueiro.recarga = 5.0
	zagueiro._mudar_estado(zagueiro.Estado.PATRULHANDO)
	zagueiro.global_position.x = zagueiro._x_inicial + zagueiro.raio_patrulha
	await esperar(2)
	jogador.global_position = Vector2(zagueiro.global_position.x - 230, 470)
	jogador.velocity = Vector2.ZERO
	await esperar(10)
	zagueiro.recarga = 0.0
	# Pula quando o zagueiro, já deslizando, chega perto (jogador no chão)
	for _i in range(120):
		await physics_frame
		if zagueiro.estado == zagueiro.Estado.DESLIZANDO and jogador.is_on_floor() and absf(zagueiro.global_position.x - jogador.global_position.x) < 190.0:
			break
	Input.action_press("pular")
	await esperar(2)
	Input.action_release("pular")
	var passou_por_baixo := false
	var lado_inicial := signf(jogador.global_position.x - zagueiro.global_position.x)
	for _i in range(90):
		await physics_frame
		if signf(jogador.global_position.x - zagueiro.global_position.x) != lado_inicial:
			passou_por_baixo = true
	checar(passou_por_baixo, "zagueiro passa por baixo do jogador que pulou")
	checar(hud.vidas == 5, "pulo na hora certa evita o carrinho (vidas = %d)" % hud.vidas)

	print("-- dano")
	await esperar(60)
	zagueiro.receber_dano(1)
	checar(zagueiro.vida == 2 and not zagueiro.morrendo, "bola tira 1 e ele continua vivo")
	checar(zagueiro.estado == zagueiro.Estado.ATORDOADO, "fica atordoado ao levar a bolada")
	zagueiro.receber_dano(1)
	checar(zagueiro.vida == 1 and not zagueiro.morrendo, "aguenta 2 boladas")
	zagueiro.receber_dano(1)
	checar(zagueiro.morrendo and not zagueiro.is_in_group("inimigos"), "a terceira bolada derruba")
	zagueiro.receber_dano(1)
	checar(zagueiro.vida == 0, "depois de derrubado não recebe mais dano")

	# Outro zagueiro: carrinhos do jogador (2 cada)
	var outro = load("res://cena_inimigo2.tscn").instantiate()
	fase.add_child(outro)
	outro.global_position = Vector2(600, 480)
	await esperar(5)
	var corpo = outro.get_node("Personagem")
	corpo.receber_dano(jogador.dano_carrinho)
	checar(corpo.vida == 1 and not corpo.morrendo, "um carrinho tira 2")
	corpo.receber_dano(jogador.dano_carrinho)
	checar(corpo.morrendo, "dois carrinhos derrubam o zagueiro")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_zagueiro.cfg"))
	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
