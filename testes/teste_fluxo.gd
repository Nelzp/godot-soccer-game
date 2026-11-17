extends SceneTree
## Teste headless do fluxo entre telas: menu, fase, game over, pausa e vitória.

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


func _rodar() -> void:

	print("-- menu inicial")
	change_scene_to_file("res://cena_inicio.tscn")
	await esperar(5)
	checar(cena_atual() == "res://cena_inicio.tscn", "menu inicial carregado")
	current_scene.get_node("BotaoIniciar").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cena_fase.tscn", "INICIAR JOGO abre a fase")

	print("-- game over")
	var jogador := get_first_node_in_group("jogador")
	var hud := current_scene.find_child("Hud", true, false)
	checar(hud.vidas == 5, "começa com 5 vidas")
	hud.vidas = 1
	jogador.receber_dano()
	await esperar(5)
	checar(cena_atual() == "res://cena_game_over.tscn", "sem vidas, vai para o game over")
	current_scene.get_node("ButtonTentar").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cena_fase.tscn", "TENTAR NOVAMENTE reabre a fase")
	hud = current_scene.find_child("Hud", true, false)
	checar(hud.vidas == 5, "vidas cheias de novo")
	var chefao = current_scene.get_node("ArenaChefao/Chefao")
	checar(chefao.vida == 12 and chefao.estado == chefao.Estado.INATIVO, "chefão reiniciado")

	print("-- pausa")
	var pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	checar(paused and pausa.visible, "pausa abre")
	pausa.botao_reiniciar.pressed.emit()
	await esperar(5)
	checar(not paused and cena_atual() == "res://cena_fase.tscn", "REINICIAR recarrega a fase despausada")
	pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	pausa.botao_sair.pressed.emit()
	await esperar(5)
	checar(not paused and cena_atual() == "res://cena_inicio.tscn", "SAIR volta ao menu despausado")

	print("-- game over: sair")
	change_scene_to_file("res://cena_game_over.tscn")
	await esperar(5)
	current_scene.get_node("ButtonSair").pressed.emit()
	await esperar(5)
	checar(cena_atual() == "res://cena_inicio.tscn", "SAIR do game over volta ao menu")

	print("-- vitória com a pausa no meio")
	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)
	jogador = get_first_node_in_group("jogador")
	var arena = current_scene.get_node("ArenaChefao")
	chefao = arena.get_node("Chefao")
	jogador.global_position = Vector2(1900, 470)
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
	await esperar(400)
	checar(cena_atual() == "res://cena_fase.tscn", "com o jogo pausado, a vitória espera")
	pausa.continuar_jogo()
	await esperar(250)
	checar(cena_atual() == "res://cena_vitoria.tscn", "despausado, a tela de vitória aparece")
	checar(not paused, "tela de vitória sem pausa")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
