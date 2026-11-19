extends SceneTree
## Áudio: músicas de cada tela (uma de cada vez, sem recomeçar à toa), música
## mais baixa na pausa, efeitos no quadro certo e sem duplicar, game over,
## buses e volumes. No modo headless o driver de áudio é "Dummy": o autoload
## Audio registra o que tocaria (ver scripts/sistemas/audio.gd).

var falhas := 0
var verificacoes := 0
var audio: Node


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


func esperar_cena(caminho: String, limite: int = 240) -> void:
	for _i in range(limite):
		await process_frame
		if cena_atual() == caminho and not root.get_node("Transicao").em_transicao():
			break
	await esperar(5)


func _rodar() -> void:

	audio = root.get_node_or_null("Audio")
	root.get_node("Configuracoes").caminho_arquivo = "user://teste_audio.cfg"

	print("-- arquivos e buses")
	checar(audio != null, "autoload Audio carregado")
	var esperados := ["menu", "fase_1", "fase_2", "vitoria"]
	var musicas_ok := true
	for nome in esperados:
		musicas_ok = musicas_ok and audio.MUSICAS.has(nome) and audio.MUSICAS[nome] is AudioStream
	checar(musicas_ok, "quatro músicas: menu, Fase 1, Fase 2 e vitória")
	var efeitos_ok := true
	for nome in ["chute", "pulo", "dano", "game_over"]:
		efeitos_ok = efeitos_ok and audio.EFEITOS.has(nome) and audio.EFEITOS[nome] is AudioStream
	checar(efeitos_ok, "quatro efeitos: chute, pulo, dano e game over")
	var laco_ok := true
	for nome in esperados:
		laco_ok = laco_ok and audio.MUSICAS[nome].loop
	for nome in ["chute", "pulo", "dano"]:
		laco_ok = laco_ok and not audio.EFEITOS[nome].loop
	checar(laco_ok, "músicas em laço, efeitos tocam uma vez")
	var buses_ok := true
	for tocador in audio.get_children():
		if tocador is AudioStreamPlayer:
			var esperado: String = "Musica" if tocador.name.begins_with("Musica") else "Efeitos"
			buses_ok = buses_ok and tocador.bus == esperado and AudioServer.get_bus_index(tocador.bus) != -1
	checar(buses_ok, "músicas no bus Musica e efeitos no bus Efeitos")
	checar(audio.tocar_efeito("carrinho") == null and audio.tocar_efeito("portao") == null, "sons ainda sem arquivo (carrinho, portão...) ficam em silêncio, sem erro")

	print("-- música de cada tela")
	change_scene_to_file("res://cena_inicio.tscn")
	await esperar(60)
	checar(audio.musica_tocando_agora() == "menu", "menu inicial: música do menu")
	current_scene.get_node("BotaoIniciar").pressed.emit()
	await esperar(10)
	checar(audio.musica_atual == "fase_1", "INICIAR JOGO: música da Fase 1")
	var durante_troca: int = audio.musicas_tocando()
	await esperar(60)
	checar(durante_troca <= 2 and audio.musicas_tocando() == 1, "a troca é suave e depois só uma música toca")

	# Reiniciar a fase não recomeça a mesma música
	var tocador_antes: Variant = audio._ativa
	var pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(30)
	var volume_pausado: float = audio.volume_musica_atual()
	pausa.continuar_jogo()
	await esperar(30)
	var volume_normal: float = audio.volume_musica_atual()
	checar(volume_pausado < volume_normal - 5.0, "na pausa a música fica mais baixa (%.1f dB) e volta (%.1f dB)" % [volume_pausado, volume_normal])
	pausa = current_scene.find_child("pausa", true, false)
	pausa.abrir_menu()
	await esperar(2)
	pausa.botao_reiniciar.pressed.emit()
	await esperar(10)
	checar(audio.musica_atual == "fase_1" and audio._ativa == tocador_antes and audio.musicas_tocando() == 1, "REINICIAR: a música da fase continua (sem recomeçar nem dobrar)")

	print("-- efeitos do jogador")
	var jogador := get_first_node_in_group("jogador") as CharacterBody2D
	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.set_physics_process(false)
	await esperar(10)
	Input.action_press("pular")
	await esperar(2)
	Input.action_release("pular")
	await esperar(2)
	checar(audio.efeito_tocando("pulo"), "pulo: som do pulo")
	await esperar(60)
	var antes := get_nodes_in_group("projeteis").size()
	Input.action_press("chutar")
	var quadro_som := -1
	var quadro_bola := -1
	for quadro in range(30):
		await physics_frame
		if quadro == 1:
			Input.action_release("chutar")
		if quadro_som < 0 and audio.efeito_tocando("chute"):
			quadro_som = quadro
		if quadro_bola < 0 and get_nodes_in_group("projeteis").size() > antes:
			quadro_bola = quadro
	Input.action_release("chutar")
	checar(quadro_som >= 0 and quadro_som == quadro_bola, "chute: o som sai no mesmo quadro da bola (quadro %d e %d)" % [quadro_som, quadro_bola])
	audio.parar_efeitos()
	jogador.receber_dano()
	var tocadores_dano := 0
	for tocador in audio._efeitos:
		if audio._efeito_ativo(tocador) and audio._nome_do_efeito.get(tocador, "") == "dano":
			tocadores_dano += 1
	jogador.receber_dano()
	jogador.receber_dano()
	var tocadores_depois := 0
	for tocador in audio._efeitos:
		if audio._efeito_ativo(tocador) and audio._nome_do_efeito.get(tocador, "") == "dano":
			tocadores_depois += 1
	checar(tocadores_dano == 1 and tocadores_depois == 1, "dano: um som por golpe (invulnerável, sem som dobrado)")
	audio.parar_efeitos()
	var primeiro = audio.tocar_efeito("chute")
	var no_mesmo_instante = audio.tocar_efeito("chute")
	checar(primeiro != null and no_mesmo_instante == null, "o mesmo efeito no mesmo instante toca uma vez só")

	print("-- game over")
	await esperar(70)
	var hud := current_scene.find_child("Hud", true, false)
	hud.vidas = 1
	jogador.receber_dano()
	await esperar(3)
	checar(audio.efeito_tocando("game_over") and audio.musica_atual == "", "última vida: a música para e o som de game over toca na queda")
	await esperar_cena("res://cena_game_over.tscn")
	checar(cena_atual() == "res://cena_game_over.tscn" and audio.efeito_tocando("game_over") and audio.musicas_tocando() == 0, "tela de game over: som de game over, sem música")
	current_scene.get_node("ButtonTentar").pressed.emit()
	await esperar(10)
	checar(audio.musica_atual == "fase_1" and not audio.efeito_tocando("game_over"), "TENTAR NOVAMENTE: o som de game over para e a música da fase volta")

	print("-- Fase 2 e vitória")
	change_scene_to_file("res://cena_fase2.tscn")
	await esperar(60)
	checar(audio.musica_tocando_agora() == "fase_2" and audio.musicas_tocando() == 1, "Fase 2: música da Fase 2 (e só ela)")
	root.get_node("Transicao").ir_para("res://cena_vitoria.tscn")
	await esperar_cena("res://cena_vitoria.tscn")
	await esperar(60)
	checar(audio.musica_tocando_agora() == "vitoria" and audio.musicas_tocando() == 1, "tela de vitória: música da vitória")
	current_scene.get_node("BotaoRetornar").pressed.emit()
	await esperar(60)
	checar(audio.musica_tocando_agora() == "menu", "de volta ao menu: música do menu")

	print("-- volumes")
	var configuracoes = root.get_node("Configuracoes")
	configuracoes.aplicar_audio({"volume_geral": 1.0, "volume_musica": 0.3, "volume_efeitos": 0.6})
	var musica_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica"))
	var efeitos_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efeitos"))
	checar(absf(musica_db - linear_to_db(0.3)) < 0.1 and absf(efeitos_db - linear_to_db(0.6)) < 0.1, "volumes de música e efeitos vão para os buses (%.1f dB e %.1f dB)" % [musica_db, efeitos_db])
	configuracoes.aplicar_audio({"volume_geral": 1.0, "volume_musica": 0.0, "volume_efeitos": 1.0})
	checar(AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")), "música em 0%: bus da música mudo")
	configuracoes.aplicar_audio()
	checar(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")), "voltando aos valores salvos, a música volta")
	var volumes_ok := true
	for nome in audio.VOLUMES:
		volumes_ok = volumes_ok and absf(audio.VOLUMES[nome]) <= 14.0
	checar(volumes_ok and audio.VOLUMES["fase_1"] > audio.VOLUMES["fase_2"] and audio.VOLUMES["game_over"] > 0.0, "ajustes por arquivo equilibram as gravações (Fase 1 sobe, Fase 2 desce, game over sobe)")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_audio.cfg"))
	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
