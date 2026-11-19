extends SceneTree
## Juiz: alcance, mira, intervalo entre lançamentos, obstáculos e portões que
## tapam a visão, lançamento só na tela, desvio pulando, alcance do cartão e
## morte. Monta um campo vazio só com chão, o jogador, o HUD e um Juiz.

const CENA_JOGADOR := "res://cena_jogador.tscn"
const CENA_JUIZ := "res://cena_juiz.tscn"
const CENA_HUD := "res://cena_hud.tscn"
const CENA_OBSTACULO := "res://cena_obstaculo.tscn"
const CENA_PORTAO := "res://cena_portao_fase.tscn"

const Y_CHAO := 529.5
const X_JUIZ := 3000.0

var falhas := 0
var verificacoes := 0

var mundo: Node2D
var jogador: CharacterBody2D
var juiz: CharacterBody2D
var hud: Node


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


func cartoes() -> Array[Node]:
	return get_nodes_in_group("projeteis_inimigos")


## Espera um cartão novo aparecer (devolve o corpo dele ou null).
func esperar_cartao(limite_quadros: int) -> Node:
	var antes := cartoes().size()
	for _i in range(limite_quadros):
		await physics_frame
		var lista := cartoes()
		if lista.size() > antes:
			return lista[lista.size() - 1]
	return null


func limpar_cartoes() -> void:
	for cartao in cartoes():
		cartao.get_parent().queue_free()


## Espera o Juiz terminar um lançamento já começado (ele não desiste no meio)
## e tira os cartões do caminho.
func esperar_juiz_parado() -> void:
	for _i in range(120):
		if juiz.estado == juiz.Estado.PARADO:
			break
		await physics_frame
	await esperar(2)
	limpar_cartoes()
	await esperar(1)


## Coloca o jogador parado no chão, olhando para `lado`, com a câmera já adiantada.
func posicionar_jogador(x: float, lado: int) -> void:
	jogador.global_position = Vector2(x, Y_CHAO - 48.5)
	jogador.velocity = Vector2.ZERO
	jogador.direcao = lado
	jogador._lado_camera = lado
	jogador.camera.position.x = jogador.antecipacao_camera * lado
	jogador.get_node("Sprite2D").flip_h = lado < 0
	await esperar(3)


func montar_mundo() -> void:
	mundo = Node2D.new()
	mundo.name = "Mundo"
	root.add_child(mundo)
	current_scene = mundo

	var chao := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(8000, 200)
	forma.shape = retangulo
	forma.position = Vector2(3000, Y_CHAO + 100.0)
	chao.add_child(forma)
	mundo.add_child(chao)

	hud = load(CENA_HUD).instantiate()
	hud.name = "Hud"
	mundo.add_child(hud)

	var cena_juiz: Node2D = load(CENA_JUIZ).instantiate()
	cena_juiz.position = Vector2(X_JUIZ, 488)
	mundo.add_child(cena_juiz)
	juiz = cena_juiz.get_node("Personagem")

	var cena_jogador: Node2D = load(CENA_JOGADOR).instantiate()
	cena_jogador.position = Vector2(2400, 477)
	mundo.add_child(cena_jogador)
	jogador = cena_jogador.get_node("Personagem")
	var camera: Camera2D = jogador.get_node("Camera2D")
	camera.limit_left = -10000
	camera.limit_right = 10000
	camera.limit_top = -10000
	camera.limit_bottom = 10000


func _rodar() -> void:

	montar_mundo()
	await esperar(5)

	print("-- básico")
	checar(juiz.vida == 3 and juiz.vida_maxima == 3, "Juiz com 3 de vida")
	checar(juiz.alcance_visao >= 600.0 and juiz.alcance_visao <= 700.0, "alcance de visão entre 600 e 700 px (%.0f)" % juiz.alcance_visao)

	print("-- alcance")
	jogador.invencivel = true
	await posicionar_jogador(X_JUIZ - 600.0, 1)
	checar(juiz.ve_jogador(), "enxerga o jogador a 600 px")
	await posicionar_jogador(X_JUIZ - 700.0, 1)
	checar(not juiz.ve_jogador(), "não enxerga a 700 px (fora do alcance)")

	print("-- lançamento de longe acerta")
	jogador.invencivel = false
	hud.vidas = 5
	limpar_cartoes()
	juiz.recarga = 0.0
	await posicionar_jogador(X_JUIZ - 600.0, 1)
	var cartao = await esperar_cartao(120)
	checar(cartao != null, "lança o cartão no jogador a 600 px")
	if cartao != null:
		checar(cartao.vetor.x < -0.95 and absf(cartao.vetor.y) < 0.2, "cartão vai na direção do jogador (%.2f, %.2f)" % [cartao.vetor.x, cartao.vetor.y])
		var mao_x: float = juiz.mao.global_position.x
		checar(mao_x < X_JUIZ and absf(cartao.global_position.x - mao_x) < 20.0, "cartão sai da mão virada para o jogador")
	var acertou := false
	for _i in range(90):
		await physics_frame
		if hud.vidas < 5:
			acertou = true
			break
	checar(acertou, "cartão alcança e acerta o jogador parado a 600 px")

	print("-- intervalo entre lançamentos")
	jogador.invencivel = true
	limpar_cartoes()
	await esperar(2)
	var primeiro = await esperar_cartao(200)
	var quadro_primeiro := 0
	var quadro_segundo := -1
	if primeiro != null:
		for quadro in range(240):
			await physics_frame
			var lista := cartoes()
			var novo := false
			for c in lista:
				if c != primeiro and is_instance_valid(c) and not c.removendo and c.global_position.x > X_JUIZ - 100.0:
					novo = true
			if novo:
				quadro_segundo = quadro + 1
				break
	var intervalo := (quadro_segundo - quadro_primeiro) / 60.0
	var esperado: float = juiz.intervalo_ataque + juiz.animacao.get_animation("atirando").length
	checar(quadro_segundo > 0 and absf(intervalo - esperado) < 0.15, "intervalo de %.2f s entre dois lançamentos (esperado %.2f s)" % [intervalo, esperado])

	print("-- mira para cima")
	limpar_cartoes()
	var plataforma := StaticBody2D.new()
	plataforma.collision_layer = 8
	var forma_plataforma := CollisionShape2D.new()
	var retangulo_plataforma := RectangleShape2D.new()
	retangulo_plataforma.size = Vector2(160, 8)
	forma_plataforma.shape = retangulo_plataforma
	forma_plataforma.one_way_collision = true
	forma_plataforma.position = Vector2(X_JUIZ - 480.0, 384.0)
	plataforma.add_child(forma_plataforma)
	mundo.add_child(plataforma)
	jogador.invencivel = false
	hud.vidas = 5
	juiz.recarga = 0.0
	jogador.global_position = Vector2(X_JUIZ - 480.0, 300)
	jogador.velocity = Vector2.ZERO
	await esperar(30)
	checar(jogador.is_on_floor() and jogador.global_position.y < 400.0, "jogador em cima de uma plataforma alta")
	cartao = await esperar_cartao(150)
	checar(cartao != null and cartao.vetor.y < -0.1, "cartão sai inclinado para cima (%.2f)" % (cartao.vetor.y if cartao != null else 0.0))
	acertou = false
	for _i in range(90):
		await physics_frame
		if hud.vidas < 5:
			acertou = true
			break
	checar(acertou, "acerta o jogador no alto")
	plataforma.queue_free()

	print("-- obstáculo alto tapa a visão")
	jogador.invencivel = true
	var bonecos: StaticBody2D = load(CENA_OBSTACULO).instantiate()
	bonecos.tipo = 1
	bonecos.escala = 0.7
	bonecos.position = Vector2(X_JUIZ - 250.0, Y_CHAO)
	mundo.add_child(bonecos)
	await posicionar_jogador(X_JUIZ - 500.0, 1)
	await esperar_juiz_parado()
	checar(not juiz.ve_jogador(), "não enxerga o jogador escondido atrás dos bonecos")
	var tentou = await esperar_cartao(150)
	checar(tentou == null, "não lança com os bonecos no caminho")

	print("-- portão fechado tapa a visão")
	var portao: Node2D = load(CENA_PORTAO).instantiate()
	portao.position = Vector2(X_JUIZ - 250.0, Y_CHAO)
	mundo.add_child(portao)
	await esperar(3)
	portao._fechar()
	bonecos.queue_free()
	await esperar(3)
	await posicionar_jogador(X_JUIZ - 500.0, 1)
	await esperar_juiz_parado()
	checar(not juiz.ve_jogador(), "não enxerga através do portão fechado")
	tentou = await esperar_cartao(150)
	checar(tentou == null, "não lança através do portão fechado")
	portao._abrir(false)
	await esperar(3)
	checar(juiz.ve_jogador(), "com o portão aberto, volta a enxergar")
	portao.queue_free()
	await esperar(2)

	print("-- só lança aparecendo na tela")
	await posicionar_jogador(X_JUIZ - 560.0, -1)
	await esperar_juiz_parado()
	checar(not juiz.visivel_na_tela(), "jogador de costas: o Juiz fica fora da tela")
	tentou = await esperar_cartao(90)
	checar(tentou == null, "fora da tela, não lança")
	# Virando para o Juiz, a câmera se adianta e ele aparece
	Input.action_press("ir_para_direita")
	await esperar(2)
	Input.action_release("ir_para_direita")
	await posicionar_jogador(X_JUIZ - 560.0, 1)
	await esperar(60)
	checar(juiz.visivel_na_tela(), "olhando para o Juiz, ele aparece na tela")

	print("-- desviar pulando")
	limpar_cartoes()
	jogador.invencivel = false
	hud.vidas = 5
	juiz.recarga = 0.0
	await posicionar_jogador(X_JUIZ - 600.0, 1)
	cartao = await esperar_cartao(150)
	var pulou_em := -1
	var passou := false
	for quadro in range(120):
		await physics_frame
		if cartao == null or not is_instance_valid(cartao):
			break
		var distancia: float = cartao.global_position.x - jogador.global_position.x
		if pulou_em < 0 and distancia < 230.0:
			Input.action_press("pular")
			pulou_em = quadro
		elif pulou_em >= 0 and quadro >= pulou_em + 2:
			Input.action_release("pular")
		if distancia < -60.0:
			passou = true
			break
	Input.action_release("pular")
	checar(pulou_em >= 0 and passou and hud.vidas == 5, "pulando na hora certa o cartão passa por baixo (vidas %d)" % hud.vidas)

	print("-- alcance do cartão")
	var sumiu := false
	var x_inicial: float = juiz.mao.global_position.x
	var x_final := x_inicial
	for _i in range(150):
		await physics_frame
		if cartao == null or not is_instance_valid(cartao):
			sumiu = true
			break
		x_final = cartao.global_position.x
	checar(sumiu and absf(x_inicial - x_final) <= juiz.alcance_cartao + 40.0, "o cartão que errou some sozinho perto de %.0f px (voou %.0f px)" % [juiz.alcance_cartao, absf(x_inicial - x_final)])

	print("-- morte")
	jogador.invencivel = true
	await esperar(150)
	limpar_cartoes()
	juiz.recarga = 0.0
	await posicionar_jogador(X_JUIZ - 400.0, 1)
	for _i in range(60):
		await physics_frame
		if juiz.estado == juiz.Estado.LANCANDO:
			break
	checar(juiz.estado == juiz.Estado.LANCANDO and juiz.animacao.current_animation_position < 0.4, "Juiz começou a erguer o cartão")
	juiz.receber_dano(3)
	checar(juiz.morrendo and not juiz.is_in_group("inimigos"), "três golpes derrubam o Juiz")
	var animando_morto: bool = juiz.animacao.is_playing()
	tentou = await esperar_cartao(60)
	checar(tentou == null and not animando_morto, "morto no meio do lançamento, não solta o cartão")
	checar(not is_instance_valid(juiz), "Juiz some depois da animação de morte")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
