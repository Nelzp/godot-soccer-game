extends SceneTree
## Jogador: chute (bola no quadro do contato), carrinho (desliza, corpo baixo,
## acerta só deslizando), dano (invulnerabilidade sem interromper o ataque),
## transições de animação (pulo pela velocidade, aterrissagem, corrida sem
## reiniciar), quadros ancorados e morte. Campo vazio montado pelo teste.

const CENA_JOGADOR := "res://cenas/personagens/jogador.tscn"
const CENA_HUD := "res://cenas/menus/hud.tscn"
const CENA_ZAGUEIRO := "res://cenas/personagens/zagueiro.tscn"

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


func tocar(acao: String) -> void:
	Input.action_press(acao)
	await esperar(2)
	Input.action_release(acao)


func bolas() -> Array[Node]:
	return get_nodes_in_group("projeteis")


func posicionar(x: float) -> void:
	jogador.global_position = Vector2(x, Y_CHAO - 47.5)
	jogador.velocity = Vector2.ZERO
	jogador.empurrao_x = 0.0
	await esperar(4)


func montar_mundo() -> void:
	mundo = Node2D.new()
	mundo.name = "Mundo"
	root.add_child(mundo)
	current_scene = mundo

	var chao := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(6000, 200)
	forma.shape = retangulo
	forma.position = Vector2(2000, Y_CHAO + 100.0)
	chao.add_child(forma)
	mundo.add_child(chao)

	hud = load(CENA_HUD).instantiate()
	hud.name = "Hud"
	mundo.add_child(hud)

	var cena_jogador: Node2D = load(CENA_JOGADOR).instantiate()
	cena_jogador.position = Vector2(400, 477)
	mundo.add_child(cena_jogador)
	jogador = cena_jogador.get_node("Personagem")
	var camera: Camera2D = jogador.get_node("Camera2D")
	camera.limit_left = -10000
	camera.limit_right = 10000


func _rodar() -> void:

	montar_mundo()
	await esperar(10)

	print("-- quadros")
	var sprite: Sprite2D = jogador.get_node("Visual/Sprite2D")
	var animacao: AnimationPlayer = jogador.get_node("AnimationPlayer")
	checar(is_equal_approx(sprite.scale.x, sprite.scale.y), "jogador sem distorção (escala %.3f x %.3f)" % [sprite.scale.x, sprite.scale.y])
	var menor_base := INF
	var maior_base := -INF
	for nome in ["parado", "correndo", "chutando", "carrinho", "pulando", "aterrissando"]:
		var anim := animacao.get_animation(nome)
		var regioes := anim.find_track(NodePath("Visual/Sprite2D:region_rect"), Animation.TYPE_VALUE)
		var deslocamentos := anim.find_track(NodePath("Visual/Sprite2D:offset"), Animation.TYPE_VALUE)
		for k in range(anim.track_get_key_count(regioes)):
			var regiao: Rect2 = anim.track_get_key_value(regioes, k)
			var deslocamento: Vector2 = anim.track_get_key_value(deslocamentos, k)
			# Borda de baixo do desenho, relativa aos pés (origem do Visual)
			var base := (deslocamento.y + regiao.size.y * 0.5) * sprite.scale.y
			menor_base = minf(menor_base, base)
			maior_base = maxf(maior_base, base)
	checar(maior_base - menor_base <= 7.0, "pés na mesma linha em todos os quadros (variação %.1f px)" % (maior_base - menor_base))

	print("-- chute")
	await posicionar(400)
	jogador.virar(1)
	await esperar(3)
	var antes := bolas().size()
	Input.action_press("chutar")
	var quadro_bola := -1
	for quadro in range(40):
		await physics_frame
		if quadro == 1:
			Input.action_release("chutar")
		if quadro_bola < 0 and bolas().size() > antes:
			quadro_bola = quadro
	Input.action_release("chutar")
	checar(quadro_bola > 0 and quadro_bola <= 12, "a bola sai no quadro do contato (%d quadros = %.2f s depois do toque)" % [quadro_bola, quadro_bola / 60.0])
	var bola = bolas()[bolas().size() - 1] if bolas().size() > 0 else null
	checar(bola != null and bola.direcao == 1 and bola.global_position.x > jogador.global_position.x + 20.0, "bola nasce no pé, à frente do jogador")
	await esperar(30)
	checar(jogador.estado == jogador.Estado.LIVRE and animacao.current_animation == "parado", "depois do chute volta a ficar parado")

	# Virar no meio do chute não muda o lado da bola
	await posicionar(400)
	jogador.virar(1)
	Input.action_press("chutar")
	await esperar(2)
	Input.action_release("chutar")
	Input.action_press("ir_para_esquerda")
	await esperar(10)
	var x_meio := jogador.global_position.x
	checar(jogador.direcao == 1, "não vira durante o chute")
	await esperar(10)
	Input.action_release("ir_para_esquerda")
	var andou := absf(jogador.global_position.x - x_meio)
	checar(andou > 0.0 and andou < 0.5 * jogador.velocidade * 10.0 / 60.0, "anda mais devagar durante o chute (%.0f px em 10 quadros)" % andou)
	var ultima = bolas()[bolas().size() - 1]
	checar(ultima.direcao == 1, "a bola sai para o lado do chute")
	await esperar(40)

	print("-- carrinho")
	await posicionar(400)
	jogador.virar(1)
	var forma := jogador.get_node("CollisionShape2D") as CollisionShape2D
	var altura_em_pe: float = (forma.shape as RectangleShape2D).size.y
	var x0 := jogador.global_position.x
	Input.action_press("carrinho")
	await esperar(2)
	Input.action_release("carrinho")
	await esperar(6)
	var altura_deslizando: float = (forma.shape as RectangleShape2D).size.y
	checar(jogador.estado == jogador.Estado.DESLIZANDO and altura_deslizando < altura_em_pe * 0.7, "deslizando, o corpo fica baixo (%.0f de %.0f px)" % [altura_deslizando, altura_em_pe])
	var pes_deslizando := forma.global_position.y + altura_deslizando * 0.5
	checar(absf(pes_deslizando - Y_CHAO) < 3.0, "corpo baixo continua apoiado no chão")
	await esperar(40)
	var deslize := jogador.global_position.x - x0
	checar(deslize > 100.0 and deslize < 260.0, "carrinho desliza para a frente (%.0f px)" % deslize)
	checar(is_equal_approx((forma.shape as RectangleShape2D).size.y, altura_em_pe), "depois do deslize o corpo volta à altura normal")
	await esperar(20)
	checar(jogador.estado == jogador.Estado.LIVRE, "levanta e volta ao controle")

	# Acerta só deslizando, no máximo um inimigo
	var cena_zagueiro: Node2D = load(CENA_ZAGUEIRO).instantiate()
	cena_zagueiro.position = Vector2(700, 483)
	mundo.add_child(cena_zagueiro)
	var zagueiro = cena_zagueiro.get_node("Personagem")
	await esperar(5)
	zagueiro.set_physics_process(false)
	await posicionar(560)
	jogador.virar(1)
	Input.action_press("carrinho")
	await esperar(2)
	Input.action_release("carrinho")
	await esperar(50)
	checar(zagueiro.vida == zagueiro.vida_maxima - jogador.dano_carrinho, "carrinho acerta o inimigo no caminho (vida %d)" % zagueiro.vida)
	# Encostado, mas já levantando: não acerta
	zagueiro.vida = zagueiro.vida_maxima
	await posicionar(zagueiro.global_position.x - 70.0)
	Input.action_press("carrinho")
	await esperar(2)
	Input.action_release("carrinho")
	for _i in range(60):
		await physics_frame
		if jogador.estado == jogador.Estado.LEVANTANDO:
			break
	zagueiro.vida = zagueiro.vida_maxima
	jogador.carrinho_atingiu_inimigo = false
	await esperar(10)
	checar(zagueiro.vida == zagueiro.vida_maxima, "levantando, o carrinho não acerta mais")
	cena_zagueiro.queue_free()
	await esperar(30)

	print("-- dano")
	hud.vidas = 5
	await posicionar(400)
	jogador.receber_dano()
	await esperar(3)
	var alfa_piscando: float = jogador.get_node("Visual").modulate.a
	jogador.receber_dano()
	await esperar(20)
	jogador.receber_dano()
	checar(hud.vidas == 4, "invulnerável logo depois do golpe (vidas %d)" % hud.vidas)
	checar(alfa_piscando < 1.0, "pisca enquanto está invulnerável")
	await esperar(60)
	jogador.receber_dano()
	checar(hud.vidas == 3, "depois da invulnerabilidade, volta a levar dano (vidas %d)" % hud.vidas)
	await esperar(70)
	checar(is_equal_approx(jogador.get_node("Visual").modulate.a, 1.0), "para de piscar no fim")

	# Golpe no meio do chute não interrompe o chute
	await posicionar(400)
	jogador.virar(1)
	antes = bolas().size()
	Input.action_press("chutar")
	await esperar(2)
	Input.action_release("chutar")
	await esperar(1)
	jogador.receber_dano()
	var saiu := false
	for _i in range(20):
		await physics_frame
		if bolas().size() > antes:
			saiu = true
	checar(saiu and hud.vidas == 2, "golpe durante o chute não interrompe: a bola sai assim mesmo")
	await esperar(80)

	print("-- transições")
	await posicionar(400)
	Input.action_press("ir_para_direita")
	await esperar(10)
	var posicao_corrida := animacao.current_animation_position
	await esperar(3)
	checar(animacao.current_animation == "correndo" and animacao.current_animation_position != posicao_corrida, "correndo, a animação segue sem reiniciar")
	Input.action_release("ir_para_direita")
	await esperar(3)
	checar(animacao.current_animation == "parado", "soltando a direção, fica parado")
	Input.action_press("pular")
	await esperar(2)
	Input.action_release("pular")
	var quadros_pulo := {}
	var aterrissou := false
	for _i in range(80):
		await physics_frame
		if not jogador.is_on_floor():
			quadros_pulo[snappedf(animacao.current_animation_position, 0.1)] = true
		elif animacao.current_animation == "aterrissando":
			aterrissou = true
	checar(quadros_pulo.size() >= 4, "no ar, os quadros acompanham subida, topo e descida (%d quadros)" % quadros_pulo.size())
	checar(aterrissou, "ao cair, agacha um instante (aterrissando)")
	await esperar(10)
	checar(animacao.current_animation == "parado", "depois da aterrissagem, volta ao parado")

	print("-- morte")
	hud.vidas = 1
	await esperar(70)
	jogador.receber_dano()
	await esperar(30)
	var visual: Node2D = jogador.get_node("Visual")
	checar(jogador.morto and absf(visual.rotation) > 1.0, "última vida: o jogador tomba")
	Input.action_press("ir_para_direita")
	var x_morto := jogador.global_position.x
	await esperar(20)
	Input.action_release("ir_para_direita")
	checar(absf(jogador.global_position.x - x_morto) < 1.0, "caído, não se mexe mais")
	var game_over := false
	for _i in range(150):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://cenas/menus/game_over.tscn":
			game_over = true
			break
	checar(game_over, "depois da queda, abre o game over")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
