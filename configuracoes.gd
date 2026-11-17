extends Node
## Configurações do jogo (vídeo e áudio), salvas em user://configuracoes.cfg.
## Autoload "Configuracoes": carrega e aplica tudo assim que o jogo abre.
##
## - Vídeo: resolução da janela, modo de tela (janela ou tela cheia) e limite
##   de FPS. A resolução vale para o modo janela; em tela cheia o jogo usa a
##   resolução do monitor.
## - Áudio: volume geral (bus "Master"), música (bus "Musica") e efeitos
##   sonoros (bus "Efeitos"). Para a P7 basta tocar a música no bus "Musica"
##   e os sons no bus "Efeitos".
##
## Os valores ficam em `valores` (um Dictionary com as chaves de PADRAO).

## Emitido depois que novas configurações são aplicadas.
signal aplicadas

const ARQUIVO := "user://configuracoes.cfg"

const BUS_GERAL := "Master"
const BUS_MUSICA := "Musica"
const BUS_EFEITOS := "Efeitos"

const RESOLUCOES: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const MODOS: Array[String] = ["janela", "tela_cheia"]
const NOMES_MODOS := {"janela": "Janela", "tela_cheia": "Tela Cheia"}

## 0 = sem limite (o V-Sync ainda segura na taxa do monitor).
const OPCOES_FPS: Array[int] = [30, 60, 120, 144, 0]

const PADRAO := {
	"resolucao": Vector2i(1152, 648),
	"modo": "janela",
	"fps": 60,
	"volume_geral": 1.0,
	"volume_musica": 0.8,
	"volume_efeitos": 1.0,
}

var valores: Dictionary = PADRAO.duplicate()

## Onde as configurações são gravadas (os testes usam outro arquivo).
var caminho_arquivo: String = ARQUIVO


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS

	_garantir_buses()
	carregar()
	aplicar_tudo()


# ---------------------------------------------------------------------------
# Arquivo
# ---------------------------------------------------------------------------

## Lê o arquivo salvo. Valores ausentes ou inválidos ficam com o padrão.
func carregar() -> void:

	valores = PADRAO.duplicate()

	var arquivo := ConfigFile.new()

	if arquivo.load(caminho_arquivo) != OK:
		return

	var resolucao = arquivo.get_value("video", "resolucao", PADRAO.resolucao)
	if resolucao is Vector2i and resolucao in RESOLUCOES:
		valores.resolucao = resolucao

	var modo = arquivo.get_value("video", "modo", PADRAO.modo)
	if modo is String and modo in MODOS:
		valores.modo = modo

	var fps = arquivo.get_value("video", "fps", PADRAO.fps)
	if fps is int and fps in OPCOES_FPS:
		valores.fps = fps

	for chave in ["volume_geral", "volume_musica", "volume_efeitos"]:
		var volume = arquivo.get_value("audio", chave, PADRAO[chave])
		if volume is float or volume is int:
			valores[chave] = clampf(float(volume), 0.0, 1.0)


func salvar() -> Error:

	var arquivo := ConfigFile.new()

	arquivo.set_value("video", "resolucao", valores.resolucao)
	arquivo.set_value("video", "modo", valores.modo)
	arquivo.set_value("video", "fps", valores.fps)
	arquivo.set_value("audio", "volume_geral", valores.volume_geral)
	arquivo.set_value("audio", "volume_musica", valores.volume_musica)
	arquivo.set_value("audio", "volume_efeitos", valores.volume_efeitos)

	var erro := arquivo.save(caminho_arquivo)

	if erro != OK:
		push_warning("Não foi possível salvar as configurações (%s)." % error_string(erro))

	return erro


## Troca os valores, aplica e salva (botão SALVAR da tela de configurações).
func definir_e_salvar(novos: Dictionary) -> Error:

	for chave in PADRAO:
		if novos.has(chave):
			valores[chave] = novos[chave]

	aplicar_tudo()
	return salvar()


# ---------------------------------------------------------------------------
# Aplicação
# ---------------------------------------------------------------------------

func aplicar_tudo() -> void:

	aplicar_video()
	aplicar_audio()
	aplicadas.emit()


func aplicar_video() -> void:

	Engine.max_fps = int(valores.fps)

	# Sem janela de verdade (testes headless, servidor): nada a fazer
	if DisplayServer.get_name() == "headless":
		return

	var janela := get_window()

	if valores.modo == "tela_cheia":
		janela.mode = Window.MODE_FULLSCREEN
		return

	if janela.mode != Window.MODE_WINDOWED:
		janela.mode = Window.MODE_WINDOWED

	# O tamanho vai depois da troca de modo (a janela restaurada pode
	# reaplicar o tamanho antigo no mesmo quadro)
	_ajustar_janela.call_deferred(resolucao_valida(valores.resolucao))


func _ajustar_janela(tamanho: Vector2i) -> void:

	var janela := get_window()

	if janela.mode != Window.MODE_WINDOWED:
		return

	var area := DisplayServer.screen_get_usable_rect(janela.current_screen)

	janela.size = tamanho
	janela.position = area.position + (area.size - tamanho) / 2


## Aplica os volumes de `fonte` (por padrão, os valores salvos). A tela de
## configurações usa isto para o jogador ouvir a mudança antes de salvar.
func aplicar_audio(fonte: Dictionary = {}) -> void:

	var origem := valores if fonte.is_empty() else fonte

	_definir_volume(BUS_GERAL, float(origem.get("volume_geral", 1.0)))
	_definir_volume(BUS_MUSICA, float(origem.get("volume_musica", 1.0)))
	_definir_volume(BUS_EFEITOS, float(origem.get("volume_efeitos", 1.0)))


func _definir_volume(bus: String, linear: float) -> void:

	var indice := AudioServer.get_bus_index(bus)

	if indice < 0:
		return

	AudioServer.set_bus_mute(indice, linear <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(linear, 0.001)))


## Os buses vêm de default_bus_layout.tres; isto só garante que existam.
func _garantir_buses() -> void:

	for nome in [BUS_MUSICA, BUS_EFEITOS]:

		if AudioServer.get_bus_index(nome) != -1:
			continue

		AudioServer.add_bus()
		var indice := AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, nome)
		AudioServer.set_bus_send(indice, BUS_GERAL)


# ---------------------------------------------------------------------------
# Opções
# ---------------------------------------------------------------------------

## Resoluções que cabem no monitor atual (sempre pelo menos a menor).
func resolucoes_disponiveis() -> Array[Vector2i]:

	var lista: Array[Vector2i] = []
	var limite := Vector2i(1 << 20, 1 << 20)

	if DisplayServer.get_name() != "headless":
		limite = DisplayServer.screen_get_size(get_window().current_screen)

	for resolucao in RESOLUCOES:
		if resolucao.x <= limite.x and resolucao.y <= limite.y:
			lista.append(resolucao)

	if lista.is_empty():
		lista.append(RESOLUCOES[0])

	return lista


## A resolução pedida, ou a maior disponível se ela não couber no monitor.
func resolucao_valida(resolucao: Vector2i) -> Vector2i:

	var lista := resolucoes_disponiveis()

	if resolucao in lista:
		return resolucao

	return lista[lista.size() - 1]


## Tamanho do monitor em que a janela está (para mostrar em tela cheia).
func resolucao_do_monitor() -> Vector2i:

	if DisplayServer.get_name() == "headless":
		return RESOLUCOES[0]

	return DisplayServer.screen_get_size(get_window().current_screen)


static func texto_resolucao(resolucao: Vector2i) -> String:
	return "%d × %d" % [resolucao.x, resolucao.y]


static func texto_fps(fps: int) -> String:
	return "Sem Limite" if fps <= 0 else "%d FPS" % fps
