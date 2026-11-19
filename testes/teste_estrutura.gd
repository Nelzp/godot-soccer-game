extends SceneTree
## Estrutura das duas fases: cenário, câmera, inimigos (vida e variações),
## portões, chefão só na Fase 2 e dano da bola e do carrinho.

const SHADER_VARIACAO := "res://variacao_uniforme.gdshader"

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


func tipo_de(inimigo: Node) -> String:
	var caminho: String = inimigo.get_script().resource_path
	if caminho.ends_with("script_inimigo1.gd"):
		return "juiz"
	if caminho.ends_with("script_goleiro.gd"):
		return "goleiro"
	if caminho.ends_with("personagem.gd"):
		return "zagueiro"
	if caminho.ends_with("script_chefão.gd"):
		return "chefao"
	return "?"


func _rodar() -> void:

	print("-- Fase 1")
	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)
	var fase := current_scene
	checar(fase != null and fase.scene_file_path == "res://cena_fase.tscn", "Fase 1 carregada")

	var cenario = fase.get_node("Cenario")
	# Antes: 9.625 px em 4 quadras. Pedido: 20% a 25% menor.
	var reducao: float = 1.0 - cenario.largura / 9625.2
	checar(reducao >= 0.20 and reducao <= 0.25, "Fase 1 encurtada (%.0f px, %.0f%% menor que 9.625 px)" % [cenario.largura, reducao * 100.0])
	var escala_ok := true
	for filho in cenario.get_children():
		if filho is Sprite2D and not is_equal_approx(filho.scale.x, filho.scale.y):
			escala_ok = false
	checar(escala_ok, "cenário sem distorção (mesma escala nos dois eixos)")

	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	var camera := jogador.get_node("Camera2D") as Camera2D
	checar(camera.limit_right == int(cenario.largura), "câmera acompanha a fase inteira (limite %d)" % camera.limit_right)
	checar(jogador.is_on_floor(), "jogador começa no chão")

	var contagem := {"juiz": 0, "goleiro": 0, "zagueiro": 0, "chefao": 0}
	var vidas_ok := true
	var variacoes := {"juiz": {}, "goleiro": {}, "zagueiro": {}}
	var material_ok := true
	for inimigo in get_nodes_in_group("inimigos"):
		var tipo := tipo_de(inimigo)
		contagem[tipo] = contagem.get(tipo, 0) + 1
		var esperado: int = {"juiz": 3, "goleiro": 3, "zagueiro": 3}.get(tipo, -1)
		if inimigo.vida_maxima != esperado or inimigo.vida != esperado:
			vidas_ok = false
		if variacoes.has(tipo):
			variacoes[tipo][inimigo.variacao] = true
			var material = inimigo.get_node("Sprite2D").material
			if inimigo.variacao == 0:
				material_ok = material_ok and material == null
			else:
				material_ok = material_ok and material is ShaderMaterial and material.shader.resource_path == SHADER_VARIACAO
	checar(contagem.juiz >= 4 and contagem.goleiro >= 4 and contagem.zagueiro >= 4, "adversários dos três tipos na Fase 1 (%d juízes, %d goleiros, %d zagueiros)" % [contagem.juiz, contagem.goleiro, contagem.zagueiro])
	checar(contagem.chefao == 0, "chefão não está na Fase 1")
	checar(vidas_ok, "vidas padronizadas: Juiz 3, Goleiro 3, Zagueiro 3")
	checar(variacoes.juiz.size() >= 4 and variacoes.goleiro.size() >= 4 and variacoes.zagueiro.size() >= 5, "várias variações de uniforme em uso (juiz %d, goleiro %d, zagueiro %d)" % [variacoes.juiz.size(), variacoes.goleiro.size(), variacoes.zagueiro.size()])
	checar(material_ok, "variação 0 sem shader; demais com o shader de uniforme")

	# Animações continuam funcionando com a variação aplicada
	var juiz_variado: Node = null
	for inimigo in get_nodes_in_group("inimigos"):
		if tipo_de(inimigo) == "juiz" and inimigo.variacao > 0:
			juiz_variado = inimigo
			break
	var sprite: Sprite2D = juiz_variado.get_node("Sprite2D")
	var animacao: AnimationPlayer = juiz_variado.get_node("AnimationPlayer")
	animacao.play("atirando")
	animacao.seek(0.0, true)
	var regiao_inicial := sprite.region_rect
	animacao.seek(0.45, true)
	checar(sprite.region_rect != regiao_inicial and sprite.material is ShaderMaterial, "animação troca os quadros e mantém a variação")

	print("-- distribuição dos adversários")
	var portoes := get_nodes_in_group("portoes")
	portoes.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var lista := get_nodes_in_group("inimigos")
	lista.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var inicio_quadra := 0.0
	var quadras_mistas := 0
	var ordens := {}
	var maior_trecho_livre := []
	for portao in portoes:
		var tipos := ""
		var xs := [inicio_quadra + 300.0]
		for inimigo in lista:
			var x: float = inimigo.global_position.x
			if x >= inicio_quadra and x <= portao.global_position.x:
				tipos += tipo_de(inimigo).substr(0, 1).to_upper()
				xs.append(x)
		xs.append(portao.global_position.x)
		if tipos.contains("J") and tipos.contains("G") and tipos.contains("Z"):
			quadras_mistas += 1
		ordens[tipos] = true
		var livre := 0.0
		for i in range(xs.size() - 1):
			livre = maxf(livre, xs[i + 1] - xs[i])
		maior_trecho_livre.append(int(livre))
		inicio_quadra = portao.global_position.x
	checar(quadras_mistas == portoes.size(), "Juiz, Goleiro e Zagueiro misturados em todas as quadras")
	checar(ordens.size() == portoes.size(), "cada quadra tem uma ordem diferente de adversários (%s)" % ", ".join(ordens.keys()))
	var seguidos := 1
	var maior_sequencia := 1
	var distancias := {}
	for i in range(1, lista.size()):
		seguidos = seguidos + 1 if tipo_de(lista[i]) == tipo_de(lista[i - 1]) else 1
		maior_sequencia = maxi(maior_sequencia, seguidos)
		distancias[int((lista[i].global_position.x - lista[i - 1].global_position.x) / 100.0)] = true
	checar(maior_sequencia <= 2, "sem sequência de 3 adversários iguais seguidos")
	checar(distancias.size() >= 5, "distâncias variadas entre os encontros (%d faixas de 100 px)" % distancias.size())
	var com_respiro := true
	for livre in maior_trecho_livre:
		com_respiro = com_respiro and livre >= 350
	checar(com_respiro, "cada quadra tem um trecho só de movimentação (maior trecho livre: %s px)" % str(maior_trecho_livre))

	checar(portoes.size() == 3, "3 portões (2 entre quadras + 1 final)")
	var final_ok := false
	var fechados := 0
	for portao in portoes:
		if not portao.esta_aberto:
			fechados += 1
		if portao.proxima_cena == "res://cena_fase2.tscn":
			final_ok = true
	checar(final_ok, "o portão final leva à Fase 2")
	checar(fechados == 3, "portões começam fechados (há adversários em todas as quadras)")

	print("-- dano")
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.set_physics_process(false)
	var juiz = fase.get_node("Inimigos/Juiz/Personagem")
	jogador.global_position = Vector2(juiz.global_position.x - 250, 470)
	jogador.direcao = 1
	await esperar(10)
	jogador.spawnar_bolar()
	for _i in range(40):
		await physics_frame
		if juiz.vida < 3:
			break
	checar(juiz.vida == 2, "bola de verdade tira 1 do Juiz (3 -> %d)" % juiz.vida)

	var zagueiro = fase.get_node("Inimigos/Zagueiro/Personagem")
	jogador.global_position = Vector2(zagueiro.global_position.x - 70, 470)
	await esperar(20)
	Input.action_press("carrinho")
	await esperar(2)
	Input.action_release("carrinho")
	await esperar(30)
	checar(zagueiro.vida == 1, "carrinho de verdade tira 2 do Zagueiro (3 -> %d)" % zagueiro.vida)

	print("-- Fase 2")
	change_scene_to_file("res://cena_fase2.tscn")
	await esperar(5)
	fase = current_scene
	checar(fase.scene_file_path == "res://cena_fase2.tscn", "Fase 2 carregada")
	var chefoes := 0
	var outros := 0
	for inimigo in get_nodes_in_group("inimigos"):
		if tipo_de(inimigo) == "chefao":
			chefoes += 1
		else:
			outros += 1
	checar(chefoes == 1 and outros == 0, "na Fase 2 só existe o chefão")
	var chefao = fase.get_node("Arena/Chefao")
	checar(chefao.vida == 12, "chefão com 12 de vida")
	checar(absf(chefao.global_position.y - 468.0) < 4.0, "chefão apoiado no chão da arena")
	jogador = get_first_node_in_group("jogador") as CharacterBody2D
	checar(jogador.is_on_floor() and absf(jogador.global_position.y + 51.0 - 468.0) < 4.0, "jogador apoiado no mesmo chão")
	var fundo: Sprite2D = fase.get_node("Fundo")
	checar(is_equal_approx(fundo.scale.x, fundo.scale.y), "cenário da Fase 2 sem distorção")
	camera = jogador.get_node("Camera2D") as Camera2D
	checar(camera.limit_right == 1528 and camera.limit_bottom == 648, "câmera presa ao estádio da Fase 2")
	checar(not fase.get_node("Arena/Saida/Bloqueio/CollisionShape2D").disabled, "saída começa bloqueada")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
