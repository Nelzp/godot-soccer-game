extends SceneTree
## Animações e golpes dos inimigos comuns: lançamento do Juiz (aviso e cartão no
## quadro certo, relógio quando está sozinho), soco do Goleiro (aviso, passo à
## frente, golpe no impacto, dá para escapar), carrinho do Zagueiro (aviso,
## corpo baixo, quadro de levantar), reação ao golpe e morte (cai e some, sem
## atacar depois). Campo vazio montado pelo teste.

const CENA_JOGADOR := "res://cena_jogador.tscn"
const CENA_HUD := "res://cena_hud.tscn"
const CENA_JUIZ := "res://cena_juiz.tscn"
const CENA_GOLEIRO := "res://goleiro.tscn"
const CENA_ZAGUEIRO := "res://cena_inimigo2.tscn"

const Y_CHAO := 529.5

var falhas := 0
var verificacoes := 0

var mundo: Node2D
var jogador: CharacterBody2D
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

	var cena_jogador: Node2D = load(CENA_JOGADOR).instantiate()
	cena_jogador.position = Vector2(200, 477)
	mundo.add_child(cena_jogador)
	jogador = cena_jogador.get_node("Personagem")
	var camera: Camera2D = jogador.get_node("Camera2D")
	camera.limit_left = -10000
	camera.limit_right = 10000


func colocar(cena: String, x: float, y: float) -> CharacterBody2D:
	var instancia: Node2D = load(cena).instantiate()
	instancia.position = Vector2(x, y)
	mundo.add_child(instancia)
	return instancia.get_node("Personagem")


func posicionar_jogador(x: float, lado: int) -> void:
	jogador.global_position = Vector2(x, Y_CHAO - 47.5)
	jogador.velocity = Vector2.ZERO
	jogador.empurrao_x = 0.0
	jogador.virar(lado)
	jogador._lado_camera = lado
	jogador.camera.position.x = jogador.antecipacao_camera * lado
	await esperar(3)


func _rodar() -> void:

	montar_mundo()
	await esperar(5)

	# -----------------------------------------------------------------------
	print("-- Juiz")
	var juiz := colocar(CENA_JUIZ, 1200, 488)
	await esperar(5)
	checar(juiz.get_node("Visual/Sprite2D") != null and juiz.lado_visual() != 0, "desenho no nó Visual (vira pela escala)")
	# Sozinho, de vez em quando confere o relógio
	jogador.invencivel = true
	await posicionar_jogador(200, -1)
	juiz._tempo_ocioso = juiz.intervalo_relogio - 0.05
	await esperar(10)
	checar(juiz.animacao.current_animation == "relogio", "sem ninguém à vista, olha o relógio")
	await posicionar_jogador(800, 1)
	await esperar(3)
	checar(juiz.animacao.current_animation != "relogio", "com o jogador à vista, para de olhar o relógio")
	# Lançamento: aviso com o cartão erguido e cartão no quadro de soltar
	for _i in range(120):
		await physics_frame
		if juiz.estado == juiz.Estado.LANCANDO:
			break
	var regioes := {}
	var tempo_cartao := -1.0
	var posicao_mao := Vector2.ZERO
	var posicao_cartao := Vector2.ZERO
	var antes := get_nodes_in_group("projeteis_inimigos").size()
	for quadro in range(60):
		await physics_frame
		regioes[juiz.sprite_visual().region_rect] = true
		if tempo_cartao < 0.0 and get_nodes_in_group("projeteis_inimigos").size() > antes:
			tempo_cartao = juiz.animacao.current_animation_position
			posicao_mao = juiz.mao.global_position
			var lista := get_nodes_in_group("projeteis_inimigos")
			posicao_cartao = lista[lista.size() - 1].global_position
	checar(tempo_cartao >= 0.44 and tempo_cartao <= 0.5, "cartão sai no quadro do lançamento (%.2f s da animação; o aviso vem antes)" % tempo_cartao)
	checar(regioes.size() >= 5, "lançamento passa pelos quadros de aviso, soltura e volta (%d quadros)" % regioes.size())
	checar(posicao_cartao.distance_to(posicao_mao) < 30.0 and posicao_mao.x < juiz.global_position.x, "cartão nasce na mão, do lado do jogador")
	juiz.get_parent().queue_free()
	await esperar(30)
	for cartao in get_nodes_in_group("projeteis_inimigos"):
		cartao.get_parent().queue_free()
	await esperar(2)

	# -----------------------------------------------------------------------
	print("-- Goleiro")
	jogador.invencivel = false
	hud.vidas = 5
	var goleiro := colocar(CENA_GOLEIRO, 1200, 455)
	goleiro.raio_patrulha = 0.0
	await esperar(10)
	var forma_goleiro := goleiro.get_node("CollisionShape2D") as CollisionShape2D
	checar((forma_goleiro.shape as RectangleShape2D).size.x <= 120.0, "caixa do Goleiro do tamanho do corpo (%.0f px)" % (forma_goleiro.shape as RectangleShape2D).size.x)
	# Parado de frente, perto, sem encostar: o soco começa
	goleiro.set_physics_process(false)
	goleiro.virar_visual(-1)
	goleiro.direcao = -1
	await posicionar_jogador(goleiro.global_position.x - 115.0, 1)
	goleiro.set_physics_process(true)
	var atacou := false
	for _i in range(20):
		await physics_frame
		if goleiro.estado == goleiro.Estado.ATACANDO:
			atacou = true
			break
	checar(atacou, "jogador perto e à frente (sem encostar): o Goleiro soca")
	var x_antes := goleiro.global_position.x
	var vidas_no_aviso := 5
	for _i in range(20):
		await physics_frame
		if goleiro.animation_player.current_animation_position < goleiro.INICIO_SOCO:
			vidas_no_aviso = hud.vidas
	checar(vidas_no_aviso == 5, "durante o aviso (guarda), ainda não machuca")
	for _i in range(30):
		await physics_frame
	checar(hud.vidas == 4, "o golpe conta no quadro do impacto (vidas %d)" % hud.vidas)
	checar(goleiro.global_position.x < x_antes - 8.0, "o soco sai com um passo à frente (%.0f px)" % (x_antes - goleiro.global_position.x))
	await esperar(80)
	# Recuando no aviso, escapa
	hud.vidas = 5
	goleiro.aguardando_afastamento = false
	goleiro.jogador_alvo = null
	goleiro.estado = goleiro.Estado.PATRULHANDO
	goleiro.set_physics_process(false)
	goleiro.virar_visual(-1)
	await posicionar_jogador(goleiro.global_position.x - 115.0, 1)
	goleiro.set_physics_process(true)
	for _i in range(20):
		await physics_frame
		if goleiro.estado == goleiro.Estado.ATACANDO:
			break
	Input.action_press("ir_para_esquerda")
	await esperar(25)
	Input.action_release("ir_para_esquerda")
	await esperar(30)
	checar(hud.vidas == 5, "recuando durante o aviso, o soco não pega")
	# Golpe e morte no meio do aviso: não soca depois de morto
	await esperar(60)
	hud.vidas = 5
	goleiro.aguardando_afastamento = false
	goleiro.jogador_alvo = null
	goleiro.estado = goleiro.Estado.PATRULHANDO
	goleiro.set_physics_process(false)
	goleiro.virar_visual(-1)
	await posicionar_jogador(goleiro.global_position.x - 115.0, 1)
	goleiro.set_physics_process(true)
	for _i in range(20):
		await physics_frame
		if goleiro.estado == goleiro.Estado.ATACANDO:
			break
	goleiro.receber_dano(1)
	var visual_goleiro: Node2D = goleiro.get_node("Visual")
	await esperar(3)
	checar(goleiro.vida == 2 and visual_goleiro.position.x != 0.0, "golpe que não mata: pisca e dá um tranco")
	goleiro.receber_dano(5)
	await esperar(30)
	checar(goleiro.morrendo and absf(visual_goleiro.rotation) > 1.0, "golpe final: o Goleiro tomba")
	await esperar(20)
	checar(hud.vidas == 5, "morto no meio do soco, não machuca")
	await esperar(30)
	checar(not is_instance_valid(goleiro), "depois de cair, some")

	# -----------------------------------------------------------------------
	print("-- Zagueiro")
	jogador.invencivel = true
	var zagueiro := colocar(CENA_ZAGUEIRO, 1600, 483)
	zagueiro.raio_patrulha = 0.0
	await esperar(20)
	var forma_zagueiro := zagueiro.get_node("CollisionShape2D") as CollisionShape2D
	var altura_em_pe: float = (forma_zagueiro.shape as RectangleShape2D).size.y
	# O carrinho só pode começar depois que o teste já estiver olhando
	zagueiro.recarga = 99.0
	zagueiro._mudar_estado(zagueiro.Estado.PATRULHANDO)
	await posicionar_jogador(zagueiro.global_position.x - 220.0, 1)
	zagueiro.recarga = 0.0
	var preparou := false
	var avisou := false
	var abaixou := false
	var levantou := false
	var pes_ok := true
	for _i in range(150):
		await physics_frame
		if zagueiro.estado == zagueiro.Estado.PREPARANDO:
			preparou = preparou or zagueiro.animation_player.current_animation == "preparando"
			var cor: Color = zagueiro.get_node("Visual").modulate
			avisou = avisou or (cor.r > 1.05 and cor.b < 0.95)
		elif zagueiro.estado == zagueiro.Estado.DESLIZANDO:
			var tamanho: Vector2 = (forma_zagueiro.shape as RectangleShape2D).size
			abaixou = abaixou or tamanho.y < altura_em_pe * 0.75
			pes_ok = pes_ok and absf(forma_zagueiro.global_position.y + tamanho.y * 0.5 - Y_CHAO) < 3.0
		elif zagueiro.estado == zagueiro.Estado.RECUPERANDO:
			levantou = levantou or zagueiro.animation_player.current_animation == "levantando"
			if zagueiro.tempo_no_estado > 0.3:
				break
	checar(preparou and avisou, "antes do carrinho: pose de arrancada e corpo pulsando (aviso)")
	checar(abaixou and pes_ok, "deslizando, o corpo fica baixo e apoiado no chão")
	checar(levantou, "depois do carrinho, o quadro de levantar aparece")
	checar(is_equal_approx((forma_zagueiro.shape as RectangleShape2D).size.y, altura_em_pe), "levantou: o corpo volta à altura normal")
	# Morte no meio do carrinho: não acerta depois
	jogador.invencivel = false
	hud.vidas = 5
	zagueiro.recarga = 0.0
	zagueiro._mudar_estado(zagueiro.Estado.PATRULHANDO)
	await posicionar_jogador(zagueiro.global_position.x - 230.0, 1)
	for _i in range(90):
		await physics_frame
		if zagueiro.estado == zagueiro.Estado.DESLIZANDO:
			break
	zagueiro.receber_dano(9)
	await esperar(60)
	checar(hud.vidas == 5, "morto no meio do carrinho, não acerta o jogador")
	checar(not is_instance_valid(zagueiro) or zagueiro.morrendo, "Zagueiro derrubado")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
