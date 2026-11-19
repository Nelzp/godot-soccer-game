extends SceneTree
## "Robôs" que jogam o jogo só com teclas simuladas, para medir a duração da
## Fase 1 (do primeiro quadro até a tela escurecer no portão final).
##
## 1. Robô CUIDADOSO (estimativa de um jogador experiente): pula os cartões e
##    os carrinhos que vêm na direção dele, não encosta no Goleiro (chuta de
##    longe) e só dá carrinho no Zagueiro quando ele fica parado. Não é
##    invencível: cada golpe que leva é contado e as vidas voltam, para a medida
##    seguir até o fim. Depois segue pela Fase 2 até a vitória.
## 2. Robô AGRESSIVO (limite inferior): invencível, nunca desvia, chuta enquanto
##    se aproxima e dá carrinho ao encostar. Ninguém termina mais rápido que ele.
##
## Os dois têm reação perfeita e conhecem a fase. Um jogador experiente reage a
## cada ameaça uns 0,2 s depois e erra alguns pulos: nas ~40 ameaças da fase
## (cartões, carrinhos, socos) isso soma de 20% a 40% ao tempo do robô
## cuidadoso. Por isso a faixa pedida (45 a 60 s de jogo ativo para um jogador
## experiente) corresponde a 35-50 s do robô cuidadoso (35 x 1,3 = 45,5 s e
## 50 x 1,2 = 60 s).

const LIMITE_QUADROS := 60 * 240
const FASE1 := "res://cena_fase.tscn"
const FASE2 := "res://cena_fase2.tscn"
const VITORIA := "res://cena_vitoria.tscn"

const JUIZ := "script_inimigo1.gd"
const GOLEIRO := "script_goleiro.gd"
const ZAGUEIRO := "personagem.gd"

var falhas := 0
var verificacoes := 0

var derrotados := 0
var chefao_derrotado := false

var _apertadas := {}
var _soltar_em := {}
var _quadro := 0

var _ultimo_x := 0.0
var _parado_desde := 0
## Até este quadro o robô não muda de direção (o toque de chute/carrinho só
## vale no quadro seguinte; virar antes faria o chute sair para o outro lado).
var _travado_ate := 0
var chutes := 0
var carrinhos := 0
var pulos := 0
var desvios := 0


func _initialize() -> void:
	_rodar.call_deferred()


func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if condicao:
		print("  ok   - ", descricao)
	else:
		falhas += 1
		print("  FALHA - ", descricao)


# ---------------------------------------------------------------------------
# Teclas
# ---------------------------------------------------------------------------

func segurar(acao: String, ligado: bool) -> void:
	if _soltar_em.has(acao):
		return
	if ligado and not _apertadas.get(acao, false):
		Input.action_press(acao)
		_apertadas[acao] = true
	elif not ligado and _apertadas.get(acao, false):
		Input.action_release(acao)
		_apertadas[acao] = false


## Toque curto (para "just_pressed"): aperta e solta 2 quadros depois.
## Na Godot 4.7, um aperto feito durante a física só vale no quadro seguinte;
## reapertar antes disso adia o "acabou de apertar" e o toque se perde.
func tocar(acao: String) -> bool:
	if _apertadas.get(acao, false) or _soltar_em.has(acao):
		return false
	Input.action_press(acao)
	_apertadas[acao] = true
	_soltar_em[acao] = _quadro + 2
	return true


func andar(lado: int) -> void:
	segurar("ir_para_direita", lado > 0)
	segurar("ir_para_esquerda", lado < 0)


func soltar_tudo() -> void:
	for acao in _apertadas.keys():
		if _apertadas[acao]:
			Input.action_release(acao)
			_apertadas[acao] = false
	_soltar_em.clear()


func _soltar_toques() -> void:
	for acao in _soltar_em.keys():
		if _quadro >= _soltar_em[acao]:
			Input.action_release(acao)
			_apertadas[acao] = false
			_soltar_em.erase(acao)


# ---------------------------------------------------------------------------
# Leitura do jogo
# ---------------------------------------------------------------------------

func tipo_de(inimigo: Node) -> String:
	var caminho: String = inimigo.get_script().resource_path
	for tipo in [JUIZ, GOLEIRO, ZAGUEIRO]:
		if caminho.ends_with(tipo):
			return tipo
	return ""


func _meia_largura(corpo: Node2D) -> float:
	var forma := corpo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma == null or not (forma.shape is RectangleShape2D):
		return 30.0
	return (forma.shape as RectangleShape2D).size.x * 0.5 * absf(forma.global_scale.x)


## A bola chutada daqui passaria na altura do corpo do alvo?
func _bola_acerta(jogador: Node2D, alvo: Node2D) -> bool:
	var forma := alvo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma == null or not (forma.shape is RectangleShape2D):
		return true
	var meia_altura := (forma.shape as RectangleShape2D).size.y * 0.5 * absf(forma.global_scale.y)
	return absf(jogador.global_position.y + 29.0 - forma.global_position.y) < meia_altura + 10.0


func _obstaculo_a_frente(x: float, direcao: int, distancia: float) -> bool:
	for obstaculo in get_nodes_in_group("obstaculos"):
		var meia := _meia_largura(obstaculo)
		var dx: float = (obstaculo.global_position.x - meia * direcao - x) * direcao
		if dx > 0.0 and dx < distancia:
			return true
	return false


## Primeiro portão fechado à frente (x), ou INF.
func _barreira_a_frente(x: float) -> float:
	var menor := INF
	for portao in get_nodes_in_group("portoes"):
		if not portao.esta_aberto and portao.global_position.x > x - 40.0:
			menor = minf(menor, portao.global_position.x)
	return menor


## Inimigo vivo mais próximo do lado de cá do próximo portão fechado.
func _escolher_alvo(x: float) -> Node2D:
	var barreira := _barreira_a_frente(x)
	var alvo: Node2D = null
	var melhor := INF
	for inimigo in get_nodes_in_group("inimigos"):
		var ix: float = inimigo.global_position.x
		if ix > barreira:
			continue
		var dist := absf(ix - x)
		# Mais adiante, só se estiver perto; para trás, só o que ficou na quadra
		if ix > x + 900.0:
			continue
		if dist < melhor:
			melhor = dist
			alvo = inimigo
	return alvo


## Quanto falta (s) para o próximo cartão que vem na direção do jogador, na
## altura do corpo dele, chegar (INF se nenhum vem).
func _tempo_cartao(jogador: CharacterBody2D) -> float:
	var forma := jogador.get_node("CollisionShape2D") as CollisionShape2D
	var meia_altura := (forma.shape as RectangleShape2D).size.y * 0.5
	var menor := INF
	for cartao in get_nodes_in_group("projeteis_inimigos"):
		if cartao.removendo:
			continue
		var rel: float = cartao.global_position.x - forma.global_position.x
		var vx: float = cartao.velocity.x
		if rel * vx >= 0.0 or absf(vx) < 1.0:
			continue
		if absf(cartao.global_position.y - forma.global_position.y) > meia_altura + 20.0:
			continue
		menor = minf(menor, (absf(rel) - 30.0) / absf(vx))
	return menor


## Quanto falta (s) para um Zagueiro que desliza na direção do jogador
## encostar nele (INF se nenhum vem).
func _tempo_carrinho(jogador: CharacterBody2D) -> float:
	var menor := INF
	for inimigo in get_nodes_in_group("inimigos"):
		if tipo_de(inimigo) != ZAGUEIRO:
			continue
		# Preparando (o aviso antes do carrinho) também conta: falta o resto
		# do preparo mais o caminho até o jogador
		var preparando: bool = inimigo.estado == inimigo.Estado.PREPARANDO
		if not preparando and inimigo.estado != inimigo.Estado.DESLIZANDO:
			continue
		var dx: float = jogador.global_position.x - inimigo.global_position.x
		if dx * inimigo.direcao <= 0.0:
			continue
		var folga := absf(dx) - _meia_largura(inimigo) - 22.0
		var aproximacao: float = inimigo.velocidade_carrinho if preparando else absf(inimigo.velocity.x)
		if signf(jogador.velocity.x) == -signf(dx):
			aproximacao += absf(jogador.velocity.x)
		var espera: float = maxf(inimigo.tempo_preparo - inimigo.tempo_no_estado, 0.0) if preparando else 0.0
		# No começo do preparo o melhor é chutar (o golpe interrompe o carrinho);
		# só conta como ameaça quando ele já vai sair deslizando
		if preparando and espera > 0.12:
			continue
		menor = minf(menor, espera + maxf(folga, 0.0) / maxf(aproximacao, 1.0))
	return menor


# ---------------------------------------------------------------------------
# Um quadro de jogo do robô
# ---------------------------------------------------------------------------

func passo(jogador: CharacterBody2D, cuidadoso: bool) -> void:

	var x := jogador.global_position.x
	var no_chao := jogador.is_on_floor()
	var ocupado: bool = jogador.animando
	var alvo := _escolher_alvo(x)
	var direcao_andar := 1
	var pular := false
	var recuando := false

	# Desvios: o pulo começa 2 quadros depois do toque e só fica acima da
	# altura do cartão entre ~0,13 s e ~0,75 s; a janela boa é esta
	var cartao_vindo := false
	if cuidadoso and no_chao:
		var t_cartao := _tempo_cartao(jogador)
		cartao_vindo = t_cartao < 0.9
		if (t_cartao > 0.16 and t_cartao < 0.42) or _tempo_carrinho(jogador) < 0.3:
			pular = true
			desvios += 1

	if alvo != null:
		var tipo := tipo_de(alvo)
		var dx := alvo.global_position.x - x
		var lado := 1 if dx >= 0.0 else -1
		var distancia := absf(dx)
		var contato := _meia_largura(alvo) + 28.0
		var acerta := _bola_acerta(jogador, alvo)
		# Bola passaria por cima e está colado: está em cima do inimigo
		var em_cima := not acerta and distancia < contato + 10.0
		var pode_carrinho := true
		# Distância mínima que o robô cuidadoso mantém do alvo
		var longe := 0.0

		if cuidadoso and tipo == GOLEIRO:
			longe = alvo.meia_largura() + alvo.alcance_golpe + 50.0
			pode_carrinho = false
		elif cuidadoso and tipo == ZAGUEIRO:
			pode_carrinho = alvo.estado in [alvo.Estado.RECUPERANDO, alvo.Estado.ATORDOADO]

		# Com um cartão chegando, o robô cuidadoso guarda o carrinho e pula
		if cartao_vindo:
			pode_carrinho = false

		direcao_andar = lado

		if _quadro < _travado_ate:
			# Acabou de apertar chute/carrinho: não vira até o toque valer
			andar(0)
		elif em_cima:
			# Desce pelo lado em que está
			direcao_andar = -lado
			andar(direcao_andar)
		elif longe > 0.0 and acerta and distancia < longe and not _obstaculo_a_frente(x, -lado, 110.0):
			# Perto demais do Goleiro: recua (se não houver obstáculo atrás)
			direcao_andar = -lado
			andar(direcao_andar)
			recuando = true
		elif longe > 0.0 and acerta and distancia < longe + 60.0:
			# Na distância certa: vira para ele e chuta
			andar(lado if jogador.direcao != lado else 0)
		elif not acerta or distancia > contato:
			andar(lado)
		else:
			andar(0)

		if no_chao and not ocupado and acerta and jogador.direcao == lado and not pular and not recuando:
			if distancia <= contato and pode_carrinho:
				if tocar("carrinho"):
					carrinhos += 1
					_travado_ate = _quadro + 3
			elif distancia <= 420.0:
				if tocar("chutar"):
					chutes += 1
					_travado_ate = _quadro + 3
	else:
		# Sem adversários na quadra: segue para a direita (portões, saída)
		andar(1)

	# Pula obstáculos sólidos no caminho (não quando está só recuando)
	if no_chao and not ocupado and not recuando and _obstaculo_a_frente(x, direcao_andar, 75.0):
		pular = true

	# Preso andando sem sair do lugar: pula
	if absf(x - _ultimo_x) > 2.0:
		_parado_desde = _quadro
		_ultimo_x = x
	elif _quadro - _parado_desde > 40 and no_chao and (_apertadas.get("ir_para_direita", false) or _apertadas.get("ir_para_esquerda", false)):
		pular = true
		_parado_desde = _quadro

	if pular and no_chao and tocar("pular"):
		pulos += 1


# ---------------------------------------------------------------------------
# Partidas
# ---------------------------------------------------------------------------

## Joga a Fase 1 do começo ao portão final. Devolve o tempo (s), os golpes que
## o robô levou e se todos os adversários caíram. Com `seguir`, continua pela
## Fase 2 (invencível) até a tela de vitória.
func jogar(cuidadoso: bool, seguir: bool) -> Dictionary:

	soltar_tudo()
	chutes = 0
	carrinhos = 0
	pulos = 0
	desvios = 0
	derrotados = 0
	chefao_derrotado = false
	_travado_ate = 0
	_parado_desde = 0
	_ultimo_x = 0.0

	change_scene_to_file(FASE1)
	for _i in range(3):
		await physics_frame

	var total := get_nodes_in_group("inimigos").size()
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.derrotado.connect(_contar_derrota)

	var resultado := {"tempo": -1.0, "golpes": 0, "todos": false, "fase2": false, "chefao": false, "saida": false, "vitoria": false, "tempo_fase2": 0.0}
	var hud: Node = current_scene.find_child("Hud", true, false)
	var quadro_inicio_fase2 := -1
	var fase2_jogavel := false
	var cena_anterior := FASE1

	for quadro in range(LIMITE_QUADROS):

		await physics_frame
		_quadro = quadro
		_soltar_toques()

		var cena := current_scene.scene_file_path if current_scene != null else ""

		# Durante a troca de cena há quadros sem cena atual
		if cena.is_empty():
			continue

		if cena != cena_anterior:
			cena_anterior = cena
			soltar_tudo()
			if cena == FASE2:
				resultado.fase2 = true
				current_scene.get_node("Arena/Chefao").derrotado.connect(_contar_chefao)
			elif cena == VITORIA:
				resultado.vitoria = true
				break
			elif cena != FASE1:
				break

		if root.get_node("Transicao").em_transicao():
			if cena == FASE1 and resultado.tempo < 0.0:
				resultado.tempo = quadro / 60.0
				resultado.todos = derrotados == total
				if not seguir:
					break
			elif cena == FASE2 and fase2_jogavel and not resultado.saida:
				resultado.saida = true
				resultado.tempo_fase2 = (quadro - quadro_inicio_fase2) / 60.0
			soltar_tudo()
			continue

		if cena == FASE2 and not fase2_jogavel:
			fase2_jogavel = true
			quadro_inicio_fase2 = quadro

		var jogador := get_first_node_in_group("jogador") as CharacterBody2D
		if jogador == null:
			continue

		# Na Fase 2 os dois robôs são invencíveis (a medida é da Fase 1)
		jogador.invencivel = not cuidadoso or cena == FASE2

		# Conta os golpes do robô cuidadoso e devolve as vidas
		if cena == FASE1 and is_instance_valid(hud) and hud.vidas < 5:
			resultado.golpes += 5 - hud.vidas
			hud.vidas = 5

		passo(jogador, cuidadoso and cena == FASE1)

	resultado.chefao = chefao_derrotado
	soltar_tudo()
	return resultado


func _contar_derrota(_inimigo: Node) -> void:
	derrotados += 1


func _contar_chefao(_chefao: Node) -> void:
	chefao_derrotado = true


func _rodar() -> void:

	print("-- robô cuidadoso (jogador experiente)")
	var cuidadoso := await jogar(true, true)
	print("  Fase 1: %.1f s | golpes levados %d | chutes %d, carrinhos %d, pulos %d (desvios %d) | Fase 2: %.1f s" % [cuidadoso.tempo, cuidadoso.golpes, chutes, carrinhos, pulos, desvios, cuidadoso.tempo_fase2])
	checar(cuidadoso.tempo > 0.0, "Fase 1 concluída pelo portão final")
	checar(cuidadoso.todos, "todos os adversários da Fase 1 derrotados")
	checar(cuidadoso.golpes < 5, "jogando com cuidado, terminaria sem morrer (%d golpes; 5 vidas)" % cuidadoso.golpes)
	checar(cuidadoso.tempo >= 35.0 and cuidadoso.tempo <= 50.0, "robô cuidadoso na faixa de 35 a 50 s (%.1f s; estimativa para um jogador experiente: %.0f a %.0f s)" % [cuidadoso.tempo, cuidadoso.tempo * 1.2, cuidadoso.tempo * 1.4])
	checar(cuidadoso.fase2, "portão final levou à Fase 2")
	checar(cuidadoso.chefao, "chefão derrotado na Fase 2")
	checar(cuidadoso.saida, "jogador entrou na saída liberada (%.1f s de Fase 2)" % cuidadoso.tempo_fase2)
	checar(cuidadoso.vitoria, "tela de vitória carregada")

	print("-- robô agressivo (limite inferior)")
	# Espera a tela da vitória clarear antes de começar de novo
	for _i in range(120):
		if not root.get_node("Transicao").em_transicao():
			break
		await process_frame
	var agressivo := await jogar(false, false)
	print("  Fase 1: %.1f s | chutes %d, carrinhos %d, pulos %d" % [agressivo.tempo, chutes, carrinhos, pulos])
	checar(agressivo.tempo > 0.0 and agressivo.todos, "Fase 1 concluída derrotando todos")
	checar(agressivo.tempo >= 28.0, "nem o robô invencível passa em menos de 28 s (%.1f s)" % agressivo.tempo)

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
