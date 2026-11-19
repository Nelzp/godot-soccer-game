extends SceneTree
## "Robô" que joga o jogo inteiro só com teclas simuladas: Fase 1 (anda, pula
## obstáculos, derrota os adversários de cada quadra para abrir os portões e
## entra no portão final), Fase 2 (derrota o chefão e entra na saída) e chega
## à tela de vitória.
##
## Ele joga de forma agressiva e é invencível: chuta enquanto se aproxima e dá
## carrinho quando encosta, sem nunca desviar. Por isso o tempo medido é um
## LIMITE INFERIOR — um jogador humano, que precisa desviar de cartões, carrinhos
## e socos para não morrer, leva mais tempo.

const LIMITE_QUADROS := 60 * 300
const FASE1 := "res://cena_fase.tscn"
const FASE2 := "res://cena_fase2.tscn"
const VITORIA := "res://cena_vitoria.tscn"

var falhas := 0
var verificacoes := 0

var derrotados_fase1 := 0
var chefao_derrotado := false
var fase2_jogavel := false

var _apertadas := {}
var _soltar_em := {}
var _quadro := 0


func _initialize() -> void:
	_rodar.call_deferred()


func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if condicao:
		print("  ok   - ", descricao)
	else:
		falhas += 1
		print("  FALHA - ", descricao)


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


func _obstaculo_entre(a: float, b: float) -> bool:
	for obstaculo in get_nodes_in_group("obstaculos"):
		var x: float = obstaculo.global_position.x
		if x > minf(a, b) and x < maxf(a, b):
			return true
	return false


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


func _rodar() -> void:

	change_scene_to_file(FASE1)
	for _i in range(3):
		await physics_frame

	var quadro_fim_fase1 := -1
	var quadro_inicio_fase2 := -1
	var quadro_fim_fase2 := -1
	var quadro_vitoria := -1
	var inimigos_fase1 := get_nodes_in_group("inimigos").size()
	var chutes := 0
	var carrinhos := 0
	var pulos := 0

	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.derrotado.connect(func(_i): derrotados_fase1 += 1)

	var ultimo_x := 0.0
	var parado_desde := 0
	var cena_anterior := ""

	for quadro in range(LIMITE_QUADROS):

		await physics_frame
		_quadro = quadro
		_soltar_toques()

		var cena := current_scene.scene_file_path if current_scene != null else ""

		if cena != cena_anterior:
			cena_anterior = cena
			soltar_tudo()
			if cena == FASE2:
				quadro_inicio_fase2 = quadro
				var chefao_novo = current_scene.get_node("Arena/Chefao")
				chefao_novo.derrotado.connect(func(_c): chefao_derrotado = true)
			elif cena == VITORIA:
				quadro_vitoria = quadro
				break

		if root.get_node("Transicao").em_transicao():
			if cena == FASE1 and quadro_fim_fase1 < 0:
				quadro_fim_fase1 = quadro
			elif cena == FASE2 and quadro_fim_fase2 < 0 and fase2_jogavel:
				quadro_fim_fase2 = quadro
			soltar_tudo()
			continue

		if cena == FASE2 and not fase2_jogavel:
			fase2_jogavel = true
			quadro_inicio_fase2 = quadro

		var jogador := get_first_node_in_group("jogador") as CharacterBody2D
		if jogador == null:
			continue
		jogador.invencivel = true

		var x := jogador.global_position.x
		var no_chao := jogador.is_on_floor()
		var ocupado: bool = jogador.animando
		var alvo := _escolher_alvo(x)
		var direcao_andar := 1

		if alvo != null:
			var dx := alvo.global_position.x - x
			var lado := 1 if dx >= 0.0 else -1
			var contato := _meia_largura(alvo) + 28.0
			var acerta := _bola_acerta(jogador, alvo)
			# Bola passaria por cima e está colado: está em cima do inimigo
			var em_cima := not acerta and absf(dx) < contato + 10.0
			direcao_andar = lado

			if em_cima:
				# Desce pelo lado em que está
				direcao_andar = -lado
				segurar("ir_para_direita", direcao_andar > 0)
				segurar("ir_para_esquerda", direcao_andar < 0)
			elif not acerta or absf(dx) > contato:
				# Mais alto que o alvo (obstáculo/plataforma) ou longe: vai até ele
				segurar("ir_para_direita", lado > 0)
				segurar("ir_para_esquerda", lado < 0)
			else:
				segurar("ir_para_direita", false)
				segurar("ir_para_esquerda", false)

			if no_chao and not ocupado and acerta and jogador.direcao == lado:
				if absf(dx) <= contato:
					if tocar("carrinho"):
						carrinhos += 1
				elif absf(dx) <= 420.0:
					if tocar("chutar"):
						chutes += 1
		else:
			# Sem adversários na quadra: segue para a direita (portões, saída)
			segurar("ir_para_direita", true)
			segurar("ir_para_esquerda", false)

		# Pula obstáculos sólidos no caminho
		if no_chao and not ocupado and _obstaculo_a_frente(x, direcao_andar, 75.0):
			if tocar("pular"):
				pulos += 1

		# Preso andando sem sair do lugar: pula
		if absf(x - ultimo_x) > 2.0:
			parado_desde = quadro
			ultimo_x = x
		elif quadro - parado_desde > 40 and no_chao and (_apertadas.get("ir_para_direita", false) or _apertadas.get("ir_para_esquerda", false)):
			if tocar("pular"):
				pulos += 1
			parado_desde = quadro

	soltar_tudo()

	var tempo_fase1 := quadro_fim_fase1 / 60.0
	var tempo_fase2 := (quadro_fim_fase2 - quadro_inicio_fase2) / 60.0

	print("  Fase 1: %.1f s | Fase 2: %.1f s | chutes %d, carrinhos %d, pulos %d" % [tempo_fase1, tempo_fase2, chutes, carrinhos, pulos])

	checar(quadro_fim_fase1 > 0, "Fase 1 concluída pelo portão final (%.1f s)" % tempo_fase1)
	checar(derrotados_fase1 == inimigos_fase1, "todos os %d adversários da Fase 1 derrotados (%d)" % [inimigos_fase1, derrotados_fase1])
	# Limite inferior: ninguém passa mais rápido que o robô invencível (com 3 quadras,
	# todos os adversários com 3 de vida e o Juiz mais forte)
	checar(tempo_fase1 >= 30.0, "nem o robô invencível passa a Fase 1 em menos de 30 s (%.1f s)" % tempo_fase1)
	checar(quadro_inicio_fase2 > 0, "portão final levou à Fase 2")
	checar(chefao_derrotado, "chefão derrotado na Fase 2")
	checar(quadro_fim_fase2 > 0, "jogador entrou na saída liberada (%.1f s de Fase 2)" % tempo_fase2)
	checar(quadro_vitoria > 0, "tela de vitória carregada")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
