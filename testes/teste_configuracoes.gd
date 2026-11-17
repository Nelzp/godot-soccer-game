extends SceneTree
## Teste headless da tela de configurações (P3).
## Faz backup de user://configuracoes.cfg e restaura no final.

var falhas := 0
var verificacoes := 0
var backup: PackedByteArray = PackedByteArray()
var tinha_arquivo := false


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


func volume_bus(nome: String) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(nome)))


func acao(nome: String) -> void:
	var evento := InputEventAction.new()
	evento.action = nome
	evento.pressed = true
	root.push_input(evento)
	var soltar := InputEventAction.new()
	soltar.action = nome
	soltar.pressed = false
	root.push_input(soltar)


func _rodar() -> void:

	# Arquivo só do teste: o do jogador nunca é tocado (conferido no final)
	var real := "user://configuracoes.cfg"
	tinha_arquivo = FileAccess.file_exists(real)
	if tinha_arquivo:
		backup = FileAccess.get_file_as_bytes(real)
	var caminho := "user://teste_configuracoes.cfg"
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))

	var cfg = root.get_node_or_null("Configuracoes")
	checar(cfg != null, "autoload Configuracoes carregado")
	if cfg == null:
		quit(1)
		return
	cfg.caminho_arquivo = caminho

	print("-- padrões")
	cfg.carregar()
	cfg.aplicar_tudo()
	checar(AudioServer.get_bus_index("Musica") != -1 and AudioServer.get_bus_index("Efeitos") != -1, "buses Musica e Efeitos existem")
	checar(AudioServer.get_bus_send(AudioServer.get_bus_index("Musica")) == &"Master", "Musica manda para Master")
	checar(Engine.max_fps == 60, "FPS padrão 60")
	checar(is_equal_approx(volume_bus("Master"), 1.0), "volume geral 100%")
	checar(absf(volume_bus("Musica") - 0.8) < 0.01, "música 80% (como na arte)")
	checar(is_equal_approx(volume_bus("Efeitos"), 1.0), "efeitos 100%")

	print("-- tela pelo menu inicial")
	change_scene_to_file("res://cena_inicio.tscn")
	await esperar(5)
	var menu := current_scene
	menu._on_botao_configuracao_pressed()
	await esperar(3)
	var tela = menu.tela_configuracoes
	checar(tela != null and tela.is_inside_tree(), "tela de configurações aberta")
	var p := "Tela/Painel/"
	checar(tela.get_node(p + "ValorResolucao").text == "1152 × 648", "resolução mostrada: %s" % tela.get_node(p + "ValorResolucao").text)
	checar(tela.get_node(p + "ValorModo").text == "Janela", "modo mostrado: Janela")
	checar(tela.get_node(p + "ValorFps").text == "60 FPS", "FPS mostrado: 60 FPS")
	checar(tela.get_node(p + "PorcentagemMusica").text == "80%", "música mostrada: 80%")
	checar(tela.get_node(p + "Aviso").text == "", "sem aviso ao abrir")
	checar(tela.get_node(p + "LinhaResolucao").has_focus(), "foco começa na resolução")

	print("-- mudar sem salvar")
	tela.get_node(p + "ProximoFps").pressed.emit()
	checar(tela.get_node(p + "ValorFps").text == "120 FPS", "seta direita do FPS: 120 FPS")
	checar(Engine.max_fps == 60, "FPS só muda ao salvar")
	checar(tela.get_node(p + "Aviso").text == "Alterações não salvas", "aviso de alterações não salvas")
	tela.get_node(p + "BarraMusica")._mudar_valor(0.3)
	checar(absf(volume_bus("Musica") - 0.3) < 0.01, "prévia: música toca a 30% na hora")
	checar(tela.get_node(p + "PorcentagemMusica").text == "30%", "porcentagem acompanha a barra")
	tela.get_node(p + "BotaoVoltar").pressed.emit()
	await esperar(2)
	checar(not is_instance_valid(tela), "VOLTAR fecha a tela")
	checar(absf(volume_bus("Musica") - 0.8) < 0.01, "VOLTAR desfaz a prévia de volume")
	checar(cfg.valores.fps == 60, "VOLTAR não salva o FPS")
	checar(not FileAccess.file_exists(caminho), "nada gravado em disco")

	print("-- salvar")
	menu._on_botao_configuracao_pressed()
	await esperar(3)
	tela = menu.tela_configuracoes
	tela.get_node(p + "ProximoFps").pressed.emit()
	tela.get_node(p + "BarraMusica")._mudar_valor(0.5)
	tela.get_node(p + "BarraEfeitos")._mudar_valor(0.0)
	tela.get_node(p + "AnteriorModo").pressed.emit()
	checar(tela.get_node(p + "ValorModo").text == "Tela Cheia", "modo alterna para Tela Cheia")
	checar(tela.get_node(p + "ValorResolucao").modulate.a < 0.5, "resolução apagada em tela cheia")
	tela.get_node(p + "ProximoModo").pressed.emit()
	checar(tela.get_node(p + "ValorModo").text == "Janela", "e volta para Janela")
	tela.get_node(p + "BotaoSalvar").pressed.emit()
	await esperar(2)
	checar(Engine.max_fps == 120, "SALVAR aplica o FPS")
	checar(cfg.valores.volume_musica == 0.5, "SALVAR guarda a música")
	checar(AudioServer.is_bus_mute(AudioServer.get_bus_index("Efeitos")), "efeitos em 0% ficam mudos")
	checar(FileAccess.file_exists(caminho), "arquivo de configurações gravado")
	checar(tela.get_node(p + "Aviso").text == "Configurações salvas!", "mensagem de salvo")
	checar(not tela.tem_alteracoes(), "nada pendente depois de salvar")

	print("-- teclado")
	var linha_fps: Control = tela.get_node(p + "LinhaFps")
	linha_fps.grab_focus()
	await esperar(1)
	acao("ui_right")
	await esperar(1)
	checar(tela.get_node(p + "ValorFps").text == "144 FPS", "direita no FPS: 144 FPS (%s)" % tela.get_node(p + "ValorFps").text)
	checar(linha_fps.has_focus(), "foco continua na linha")
	acao("ui_down")
	await esperar(1)
	checar(tela.get_node(p + "BarraGeral").has_focus(), "baixo leva à barra de volume geral")
	acao("ui_left")
	await esperar(1)
	checar(tela.get_node(p + "PorcentagemGeral").text == "95%", "esquerda baixa 5%% (%s)" % tela.get_node(p + "PorcentagemGeral").text)
	acao("ui_cancel")
	await esperar(2)
	checar(not is_instance_valid(tela), "Esc fecha a tela")
	checar(Engine.max_fps == 120, "Esc descartou o 144 não salvo")

	print("-- persistência")
	cfg.valores = cfg.PADRAO.duplicate()
	cfg.carregar()
	checar(cfg.valores.fps == 120 and is_equal_approx(cfg.valores.volume_musica, 0.5) and is_equal_approx(cfg.valores.volume_efeitos, 0.0), "valores lidos do arquivo")

	var ruim := ConfigFile.new()
	ruim.set_value("video", "fps", 999)
	ruim.set_value("video", "modo", "qualquer")
	ruim.set_value("audio", "volume_geral", 7.5)
	ruim.save(caminho)
	cfg.carregar()
	checar(cfg.valores.fps == 60 and cfg.valores.modo == "janela" and is_equal_approx(cfg.valores.volume_geral, 1.0), "arquivo inválido volta aos padrões e limita volumes")

	print("-- pela pausa")
	change_scene_to_file("res://cena_fase.tscn")
	await esperar(5)
	var pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	checar(paused, "jogo pausado")
	checar(pausa.botao_configuracoes.text == "CONFIGURAÇÕES", "botão CONFIGURAÇÕES na pausa")
	pausa.botao_configuracoes.pressed.emit()
	await esperar(3)
	tela = pausa.tela_configuracoes
	checar(tela != null and tela.is_inside_tree(), "configurações abertas pela pausa")
	tela.get_node(p + "ProximoFps").pressed.emit()
	checar(tela.get_node(p + "ValorFps").text != "60 FPS", "tela funciona com o jogo pausado")
	acao("ui_cancel")
	await esperar(2)
	checar(not is_instance_valid(tela), "Esc fecha só as configurações")
	checar(paused and pausa.visible, "pausa continua aberta")
	acao("ui_cancel")
	await esperar(2)
	checar(not paused and not pausa.visible, "Esc de novo fecha a pausa")

	# Apaga o arquivo do teste
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	if tinha_arquivo:
		checar(FileAccess.get_file_as_bytes(real) == backup, "arquivo do jogador continua igual")
	else:
		checar(not FileAccess.file_exists(real), "arquivo do jogador não foi criado pelo teste")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
