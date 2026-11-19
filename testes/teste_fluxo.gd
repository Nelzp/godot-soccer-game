extends SceneTree
## Fluxo entre telas: menu, Fase 1, Fase 2, game over (recomeça na fase em que
## o jogador perdeu), pausa (reiniciar/sair) e liberação da saída com pausa.

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
		await process_frame


func cena_atual() -> String:
	return current_scene.scene_file_path if current_scene else ""


## Tira a última vida: o jogador cai (animação) e só depois o game over abre,
## com a tela escurecendo.
func perder() -> void:
	var fase := cena_atual()
	var hud := current_scene.find_child("Hud", true, false)
	var jogador := get_first_node_in_group("jogador")
	hud.vidas = 1
	jogador.receber_dano()
	await esperar(5)
	checar(jogador.morto and cena_atual() == fase, "última vida: o jogador cai antes do game over")
	for _i in range(240):
		await process_frame
		if cena_atual() == "res://cenas/menus/game_over.tscn":
			break
	await esperar(5)


func _rodar() -> void:

	print("-- menu inicial")
	change_scene_to_file("res://cenas/menus/menu_inicial.tscn")
	await esperar(5)
	checar(cena_atual() == "res://cenas/menus/menu_inicial.tscn", "menu inicial carregado")
	current_scene.get_node("BotaoIniciar").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cenas/fases/fase_1.tscn", "INICIAR JOGO abre a Fase 1")

	print("-- game over na Fase 1")
	await perder()
	checar(cena_atual() == "res://cenas/menus/game_over.tscn", "sem vidas, vai para o game over")
	current_scene.get_node("ButtonTentar").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cenas/fases/fase_1.tscn", "TENTAR NOVAMENTE volta à Fase 1")
	var hud := current_scene.find_child("Hud", true, false)
	checar(hud.vidas == 5, "vidas cheias de novo")
	var fechados := 0
	for portao in get_nodes_in_group("portoes"):
		if not portao.esta_aberto:
			fechados += 1
	checar(fechados == 3, "portões e adversários reiniciados")

	print("-- pausa na Fase 1")
	var pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	checar(paused and pausa.visible, "pausa abre")
	pausa.botao_reiniciar.pressed.emit()
	await esperar(5)
	checar(not paused and cena_atual() == "res://cenas/fases/fase_1.tscn", "REINICIAR recarrega a Fase 1 sem pausa")
	pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	pausa.botao_sair.pressed.emit()
	await esperar(5)
	checar(not paused and cena_atual() == "res://cenas/menus/menu_inicial.tscn", "SAIR volta ao menu sem pausa")

	print("-- game over na Fase 2")
	change_scene_to_file("res://cenas/fases/fase_2.tscn")
	await esperar(5)
	await perder()
	checar(cena_atual() == "res://cenas/menus/game_over.tscn", "perdeu na Fase 2: game over")
	current_scene.get_node("ButtonTentar").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cenas/fases/fase_2.tscn", "TENTAR NOVAMENTE recomeça na Fase 2")
	var chefao = current_scene.get_node("Arena/Chefao")
	checar(chefao.vida == 12 and chefao.estado == chefao.Estado.INATIVO, "chefão reiniciado")

	print("-- pausa na Fase 2")
	pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	pausa.botao_reiniciar.pressed.emit()
	await esperar(5)
	checar(not paused and cena_atual() == "res://cenas/fases/fase_2.tscn", "REINICIAR recarrega a Fase 2")

	print("-- saída liberada respeita a pausa")
	var arena = current_scene.get_node("Arena")
	chefao = arena.get_node("Chefao")
	get_first_node_in_group("jogador").global_position = Vector2(560, 410)
	await esperar(100)
	chefao.estado = chefao.Estado.PERSEGUINDO
	for _i in range(20):
		if chefao.vida <= 0:
			break
		if chefao.estado == chefao.Estado.TRANSICAO:
			chefao.estado = chefao.Estado.PERSEGUINDO
		chefao.receber_dano(2)
		await esperar(1)
	checar(arena.vitoria, "chefão derrotado")
	pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(200)
	checar(not arena.liberada, "com o jogo pausado, a saída espera")
	pausa.continuar_jogo()
	await esperar(120)
	checar(arena.liberada and cena_atual() == "res://cenas/fases/fase_2.tscn", "despausado, a saída é liberada (e nada carrega sozinho)")

	print("-- game over: sair")
	change_scene_to_file("res://cenas/menus/game_over.tscn")
	await esperar(5)
	current_scene.get_node("ButtonSair").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cenas/menus/menu_inicial.tscn", "SAIR do game over volta ao menu")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
