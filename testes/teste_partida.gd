extends SceneTree
## "Robô" que joga a fase inteira só com teclas simuladas: anda, pula os
## obstáculos, chuta nos inimigos, entra na arena e derrota o chefão com bolas
## de verdade. O jogador fica invencível (o dano é testado em outros testes);
## aqui o objetivo é provar que a fase pode ser terminada.

const LIMITE_QUADROS := 60 * 150

var falhas := 0
var verificacoes := 0

var _apertadas := {}
## Ação -> quadro em que o toque deve ser solto.
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
	if ligado and not _apertadas.get(acao, false):
		Input.action_press(acao)
		_apertadas[acao] = true
	elif not ligado and _apertadas.get(acao, false):
		Input.action_release(acao)
		_apertadas[acao] = false


## Toque curto (para "just_pressed"): aperta e solta 2 quadros depois.
## Na Godot 4.7, um aperto feito durante a física só vale no quadro seguinte;
## reapertar antes disso adia o "acabou de apertar" e o toque se perde.
## Devolve false se a tecla ainda estava num toque anterior.
func tocar(acao: String) -> bool:
	if _apertadas.get(acao, false) or _soltar_em.has(acao):
		return false
	Input.action_press(acao)
	_apertadas[acao] = true
	_soltar_em[acao] = _quadro + 2
	return true


func _soltar_toques() -> void:
	for acao in _soltar_em.keys():
		if _quadro >= _soltar_em[acao]:
			Input.action_release(acao)
			_apertadas[acao] = false
			_soltar_em.erase(acao)


func _obstaculo_entre(a: float, b: float) -> bool:
	var menor := minf(a, b)
	var maior := maxf(a, b)
	for obstaculo in get_nodes_in_group("obstaculos"):
		var x: float = obstaculo.global_position.x
		if x > menor and x < maior:
			return true
	return false


func _obstaculo_a_frente(x: float, direcao: int, distancia: float) -> bool:
	for obstaculo in get_nodes_in_group("obstaculos"):
		var forma := obstaculo.get_node("CollisionShape2D") as CollisionShape2D
		var meia := (forma.shape as RectangleShape2D).size.x * 0.5
		var borda: float = obstaculo.global_position.x - meia * direcao
		var dx := (borda - x) * direcao
		if dx > 0.0 and dx < distancia:
			return true
	return false


func _rodar() -> void:

	change_scene_to_file("res://cena_fase.tscn")
	for _i in range(5):
		await physics_frame

	var fase := current_scene
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var arena = fase.get_node("ArenaChefao")
	var chefao = arena.get_node("Chefao")
	jogador.invencivel = true

	var inimigos_iniciais := get_nodes_in_group("inimigos").size()
	var nomes_derrotados: Array[String] = []
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.derrotado.connect(func(i): nomes_derrotados.append(String(i.get_parent().name) if i.get_parent() != fase else String(i.name)))

	var bolas := 0
	var pulos := 0
	var quadro_vitoria := -1
	var quadro_luta := -1
	var maior_x := 0.0
	var parado_desde := 0
	var ultimo_x := jogador.global_position.x

	for quadro in range(LIMITE_QUADROS):

		await physics_frame
		_quadro = quadro
		_soltar_toques()

		if current_scene == null or current_scene.scene_file_path == "res://cena_vitoria.tscn":
			quadro_vitoria = quadro
			break

		if not is_instance_valid(jogador):
			break

		var x := jogador.global_position.x
		maior_x = maxf(maior_x, x)
		var no_chao := jogador.is_on_floor()
		var ocupado: bool = jogador.animando

		if OS.get_cmdline_user_args().has("--depurar") and quadro < 40:
			print("q%d x=%.1f y=%.1f chao=%s ocupado=%s vel=%s dir=%s frente=%s" % [quadro, x, jogador.global_position.y, no_chao, ocupado, jogador.velocity, Input.is_action_pressed("ir_para_direita"), _obstaculo_a_frente(x, 1, 75.0)])

		if arena.luta_iniciada and quadro_luta < 0:
			quadro_luta = quadro

		# Escolhe o alvo: na arena, o chefão; fora dela, o inimigo vivo mais
		# próximo à frente, sem obstáculo sólido no meio
		var alvo: Node2D = null
		if arena.luta_iniciada:
			if is_instance_valid(chefao) and not chefao.morrendo:
				alvo = chefao
		else:
			var melhor := 380.0
			for inimigo in get_nodes_in_group("inimigos"):
				if inimigo == chefao:
					continue
				var dx: float = inimigo.global_position.x - x
				if dx > -40.0 and absf(dx) < melhor and not _obstaculo_entre(x, inimigo.global_position.x):
					melhor = absf(dx)
					alvo = inimigo

		if alvo != null:
			# Vira para o alvo, para e chuta
			var lado := 1 if alvo.global_position.x >= x else -1
			for direcao_tecla in ["ir_para_direita", "ir_para_esquerda"]:
				if not _soltar_em.has(direcao_tecla):
					segurar(direcao_tecla, false)
			if jogador.direcao != lado:
				tocar("ir_para_direita" if lado > 0 else "ir_para_esquerda")
			elif no_chao and not ocupado:
				if tocar("chutar"):
					bolas += 1
		else:
			# Anda para a direita e pula os obstáculos sólidos
			if not _soltar_em.has("ir_para_esquerda"):
				segurar("ir_para_esquerda", false)
			if not _soltar_em.has("ir_para_direita"):
				segurar("ir_para_direita", not ocupado)
			if no_chao and not ocupado and _obstaculo_a_frente(x, 1, 75.0):
				if tocar("pular"):
					pulos += 1

		# Preso no mesmo lugar por muito tempo (sem alvo): tenta pular
		if absf(x - ultimo_x) > 2.0:
			parado_desde = quadro
			ultimo_x = x
		elif alvo == null and quadro - parado_desde > 90 and no_chao:
			if tocar("pular"):
				pulos += 1
			parado_desde = quadro

	for acao in _apertadas:
		if _apertadas[acao]:
			Input.action_release(acao)

	print("  quadros até a luta: %d | até a vitória: %d | bolas chutadas: %d | pulos: %d" % [quadro_luta, quadro_vitoria, bolas, pulos])
	print("  derrotados: %s" % ", ".join(nomes_derrotados))

	checar(quadro_luta > 0, "o jogador chegou à arena e a luta começou")
	checar(nomes_derrotados.size() == inimigos_iniciais, "todos os %d inimigos derrotados (%d)" % [inimigos_iniciais, nomes_derrotados.size()])
	checar(quadro_vitoria > 0, "a tela de vitória apareceu (em %.1f s de jogo)" % (quadro_vitoria / 60.0))
	checar(pulos >= 2, "precisou pular obstáculos (%d pulos)" % pulos)

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
