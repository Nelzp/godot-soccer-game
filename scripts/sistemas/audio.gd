extends Node
## Áudio do jogo (autoload "Audio"): músicas e efeitos sonoros.
##
## - Músicas tocam no bus "Musica", uma de cada vez, com troca suave entre
##   faixas. Pedir a faixa que já está tocando não a recomeça.
## - Efeitos tocam no bus "Efeitos", num grupo de tocadores: o mesmo efeito não
##   toca duas vezes no mesmo instante e cada um tem no máximo 2 vozes.
## - Com o jogo pausado, a música fica mais baixa; ao continuar, volta.
## - Os volumes do jogador ficam nos buses (tela de configurações); aqui só
##   ficam os ajustes de cada arquivo, medidos para que todos soem parecidos.
##
## Para ligar um som novo: coloque o arquivo em recursos/sons/, acrescente o
## nome em MUSICAS ou EFEITOS (e o ajuste em VOLUMES) e chame
## Audio.tocar_efeito("nome") ou Audio.tocar_musica("nome"). Nomes sem arquivo
## (ver PENDENTES) são ignorados em silêncio.
##
## Sem placa de som de verdade (driver "Dummy", como nos testes headless), nada
## é tocado: o áudio só registra o que tocaria e por quanto tempo, para os
## testes conferirem (o driver Dummy não mistura o som, então nada terminaria).

const MUSICAS := {
	"menu": preload("res://recursos/sons/musica_menu.mp3"),
	"fase_1": preload("res://recursos/sons/musica_fase_1.mp3"),
	"fase_2": preload("res://recursos/sons/musica_fase_2.mp3"),
	"vitoria": preload("res://recursos/sons/musica_vitoria.mp3"),
}

const EFEITOS := {
	"chute": preload("res://recursos/sons/som_chute.mp3"),
	"pulo": preload("res://recursos/sons/som_pulo.mp3"),
	"dano": preload("res://recursos/sons/som_dano.mp3"),
	"game_over": preload("res://recursos/sons/som_game_over.wav"),
}

## Ações do jogo que ainda não têm arquivo de som (ficam em silêncio).
const PENDENTES: Array[String] = [
	"carrinho", "bola", "cartao", "soco_goleiro", "carrinho_zagueiro",
	"ataque_chefao", "dano_chefao", "morte_chefao", "portao", "transicao",
	"saida_liberada", "botao",
]

## Ajuste (dB) de cada arquivo, medido no jogo (RMS e pico): as músicas ficam
## com o mesmo volume percebido (a da Fase 1 foi gravada ~8 dB mais baixa e a
## da Fase 2 passa de 0 dBFS) e o game over, gravado muito baixo, sobe.
const VOLUMES := {
	"menu": -5.0, "fase_1": 2.0, "fase_2": -6.5, "vitoria": -2.5,
	"chute": -2.0, "pulo": 2.0, "dano": -2.0, "game_over": 12.0,
}

## Silêncio (s) no começo dos arquivos: o som começa depois dele, para casar
## com o quadro da animação (o chute no contato com a bola, por exemplo).
const INICIOS := {"chute": 0.05, "pulo": 0.05, "dano": 0.09}

const BUS_MUSICA := "Musica"
const BUS_EFEITOS := "Efeitos"

## Tempo (s) da troca entre músicas.
const TROCA_MUSICA := 0.8
## Quanto a música abaixa (dB) com o jogo pausado.
const ABAFAR_NA_PAUSA := -8.0
const TOCADORES_DE_EFEITO := 8
const VOZES_POR_EFEITO := 2
## O mesmo efeito não recomeça antes deste intervalo (s): evita som dobrado.
const INTERVALO_MINIMO := 0.05

## Nome da música tocando ("" = nenhuma).
var musica_atual: String = ""

var _musicas: Array[AudioStreamPlayer] = []
var _ativa: int = 0
var _fatores: Array[float] = [0.0, 0.0]
var _tween_musica: Tween
var _abafar: float = 0.0
var _efeitos: Array[AudioStreamPlayer] = []
var _nome_do_efeito := {}
var _ultimo_efeito := {}
var _tempo: float = 0.0
## Sem driver de áudio de verdade: só registra (ver acima).
var _sem_som: bool = false
## Efeitos registrados sem tocar: tocador -> instante (s) em que acabaria.
var _fim_registrado := {}


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	_sem_som = AudioServer.get_driver_name() == "Dummy"

	# Fechar a janela passa por fechar_jogo(): os sons param antes de sair
	get_tree().auto_accept_quit = false

	for i in range(2):
		var tocador := AudioStreamPlayer.new()
		tocador.name = "Musica%d" % (i + 1)
		tocador.bus = BUS_MUSICA
		add_child(tocador)
		_musicas.append(tocador)

	for i in range(TOCADORES_DE_EFEITO):
		var tocador := AudioStreamPlayer.new()
		tocador.name = "Efeito%d" % (i + 1)
		tocador.bus = BUS_EFEITOS
		add_child(tocador)
		_efeitos.append(tocador)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		fechar_jogo()


## Fecha o jogo sem cortar o som no meio: para tudo, espera o áudio soltar os
## sons e então sai (evita som "preso" na hora de fechar).
func fechar_jogo() -> void:

	if _tween_musica != null:
		_tween_musica.kill()

	for tocador in _musicas + _efeitos:
		tocador.stop()

	musica_atual = ""
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit()


## Ao fechar o jogo, solta os sons que ainda estavam tocando.
func _exit_tree() -> void:

	if _tween_musica != null:
		_tween_musica.kill()

	for tocador in _musicas + _efeitos:
		tocador.stop()
		tocador.stream = null


func _process(delta: float) -> void:

	_tempo += delta

	# Pausa: a música abaixa devagar; ao continuar, volta
	var alvo := ABAFAR_NA_PAUSA if get_tree().paused else 0.0
	if not is_equal_approx(_abafar, alvo):
		_abafar = move_toward(_abafar, alvo, 40.0 * delta)
		_atualizar_volumes_musica()


# ---------------------------------------------------------------------------
# Músicas
# ---------------------------------------------------------------------------

## Toca a música `nome` (troca suave). A mesma música que já toca continua.
func tocar_musica(nome: String) -> void:

	if not MUSICAS.has(nome):
		return

	# O som de game over termina quando outra música começa
	parar_efeito("game_over")

	if nome == musica_atual and _musica_tocando(_ativa):
		return

	var antiga := _ativa
	_ativa = 1 - _ativa
	musica_atual = nome

	var tocador := _musicas[_ativa]
	tocador.stream = MUSICAS[nome]
	_fatores[_ativa] = 0.0
	_atualizar_volumes_musica()
	if not _sem_som:
		tocador.play()

	_trocar_fatores(antiga, 1.0, TROCA_MUSICA)


## Para a música atual, abaixando aos poucos.
func parar_musica(duracao: float = 0.5) -> void:

	musica_atual = ""
	_trocar_fatores(_ativa, 0.0, duracao)


## Volume (dB) em que a música ativa está tocando agora (para testes).
func volume_musica_atual() -> float:
	return _musicas[_ativa].volume_db


## Quantas músicas estão tocando (só passa de 1 durante a troca).
func musicas_tocando() -> int:
	var n := 0
	for i in range(2):
		if _musica_tocando(i) and _fatores[i] > 0.01:
			n += 1
	return n


## Nome da música de cada tocador que está soando (para testes).
func musica_tocando_agora() -> String:
	return musica_atual if _musica_tocando(_ativa) else ""


func _musica_tocando(indice: int) -> bool:
	if _sem_som:
		return _musicas[indice].stream != null and _fatores[indice] > 0.001
	return _musicas[indice].playing


func _trocar_fatores(saindo: int, alvo_ativa: float, duracao: float) -> void:

	if _tween_musica != null:
		_tween_musica.kill()

	_tween_musica = create_tween().set_parallel()
	_tween_musica.tween_method(_definir_fator.bind(_ativa), _fatores[_ativa], alvo_ativa, duracao)

	if saindo != _ativa:
		_tween_musica.tween_method(_definir_fator.bind(saindo), _fatores[saindo], 0.0, duracao)

	_tween_musica.chain().tween_callback(_parar_musicas_mudas)


func _definir_fator(valor: float, indice: int) -> void:
	_fatores[indice] = valor
	_atualizar_volumes_musica()


func _atualizar_volumes_musica() -> void:

	for i in range(2):
		var tocador := _musicas[i]
		var base: float = 0.0
		if tocador.stream != null:
			base = VOLUMES.get(_nome_da_musica(tocador.stream), 0.0)
		tocador.volume_db = base + _abafar + linear_to_db(maxf(_fatores[i], 0.0001))


func _parar_musicas_mudas() -> void:

	for i in range(2):
		if _fatores[i] <= 0.001:
			_musicas[i].stop()
			if _sem_som:
				_musicas[i].stream = null


func _nome_da_musica(stream: AudioStream) -> String:

	for nome in MUSICAS:
		if MUSICAS[nome] == stream:
			return nome

	return ""


# ---------------------------------------------------------------------------
# Efeitos
# ---------------------------------------------------------------------------

## Toca o efeito `nome` (com `ajuste_db` a mais ou a menos). Devolve o tocador
## usado, ou null se o som não tiver arquivo ou tiver acabado de tocar.
func tocar_efeito(nome: String, ajuste_db: float = 0.0) -> AudioStreamPlayer:

	if not EFEITOS.has(nome):
		return null

	# Mesmo efeito no mesmo instante (ex.: dois golpes no mesmo quadro): um só
	if _tempo - float(_ultimo_efeito.get(nome, -1.0)) < INTERVALO_MINIMO:
		return null

	_ultimo_efeito[nome] = _tempo

	var tocador := _escolher_tocador(nome)
	var stream: AudioStream = EFEITOS[nome]
	var inicio := float(INICIOS.get(nome, 0.0))
	tocador.stream = stream
	tocador.volume_db = float(VOLUMES.get(nome, 0.0)) + ajuste_db
	_nome_do_efeito[tocador] = nome

	if _sem_som:
		_fim_registrado[tocador] = _tempo + maxf(stream.get_length() - inicio, 0.0)
	else:
		tocador.play(inicio)

	return tocador


## O efeito `nome` está tocando agora?
func efeito_tocando(nome: String) -> bool:

	for tocador in _efeitos:
		if _efeito_ativo(tocador) and _nome_do_efeito.get(tocador, "") == nome:
			return true

	return false


func parar_efeito(nome: String) -> void:

	for tocador in _efeitos:
		if _nome_do_efeito.get(tocador, "") == nome:
			tocador.stop()
			_fim_registrado.erase(tocador)


func parar_efeitos() -> void:
	for tocador in _efeitos:
		tocador.stop()
	_fim_registrado.clear()


func _efeito_ativo(tocador: AudioStreamPlayer) -> bool:
	if _sem_som:
		return _tempo < float(_fim_registrado.get(tocador, -1.0))
	return tocador.playing


## Um tocador livre; se o efeito já está no limite de vozes, ou nenhum está
## livre, reaproveita o que começou há mais tempo.
func _escolher_tocador(nome: String) -> AudioStreamPlayer:

	var mesmo_efeito: Array[AudioStreamPlayer] = []

	for tocador in _efeitos:
		if _efeito_ativo(tocador) and _nome_do_efeito.get(tocador, "") == nome:
			mesmo_efeito.append(tocador)

	if mesmo_efeito.size() >= VOZES_POR_EFEITO:
		return _mais_antigo(mesmo_efeito)

	for tocador in _efeitos:
		if not _efeito_ativo(tocador):
			return tocador

	return _mais_antigo(_efeitos)


func _mais_antigo(lista: Array[AudioStreamPlayer]) -> AudioStreamPlayer:

	var escolhido := lista[0]

	for tocador in lista:
		if _quanto_tocou(tocador) > _quanto_tocou(escolhido):
			escolhido = tocador

	return escolhido


func _quanto_tocou(tocador: AudioStreamPlayer) -> float:
	if _sem_som:
		return -float(_fim_registrado.get(tocador, 0.0))
	return tocador.get_playback_position()
