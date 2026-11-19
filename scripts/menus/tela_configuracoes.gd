extends CanvasLayer
## Tela de configurações sobre a imagem oficial
## "recursos/imagens/interface/tela_configuracoes.png".
##
## Os valores desenhados na imagem são cobertos por controles de verdade nas
## mesmas posições (o nó Painel usa pixels da imagem e é escalado para a tela).
##
## - Vídeo (resolução, modo de tela, FPS): vale ao clicar em SALVAR.
## - Áudio: muda na hora para dar para ouvir, mas só fica gravado ao SALVAR.
## - VOLTAR (ou Esc) descarta o que não foi salvo e fecha a tela.
## - Teclado: cima/baixo trocam de linha; esquerda/direita mudam o valor.
## Abre por cima do menu inicial ou do menu de pausa (funciona com o jogo pausado).

## Emitido quando a tela fecha (depois de VOLTAR ou Esc).
signal fechada

const TAMANHO_IMAGEM := Vector2(1613, 975)
const COR_AVISO := Color(1, 0.84, 0.25)
const COR_SALVO := Color(0.46, 0.97, 0.21)
const COR_ERRO := Color(1, 0.4, 0.4)
const TEXTO_PENDENTE := "Alterações não salvas"

var rascunho: Dictionary = {}

var _tween_aviso: Tween
var _mensagem_temporaria: bool = false

@onready var painel: Control = $Tela/Painel

@onready var linha_resolucao: Button = $Tela/Painel/LinhaResolucao
@onready var linha_modo: Button = $Tela/Painel/LinhaModo
@onready var linha_fps: Button = $Tela/Painel/LinhaFps

@onready var valor_resolucao: Label = $Tela/Painel/ValorResolucao
@onready var valor_modo: Label = $Tela/Painel/ValorModo
@onready var valor_fps: Label = $Tela/Painel/ValorFps

@onready var barra_geral = $Tela/Painel/BarraGeral
@onready var barra_musica = $Tela/Painel/BarraMusica
@onready var barra_efeitos = $Tela/Painel/BarraEfeitos

@onready var porcentagem_geral: Label = $Tela/Painel/PorcentagemGeral
@onready var porcentagem_musica: Label = $Tela/Painel/PorcentagemMusica
@onready var porcentagem_efeitos: Label = $Tela/Painel/PorcentagemEfeitos

@onready var aviso: Label = $Tela/Painel/Aviso
@onready var botao_salvar: Button = $Tela/Painel/BotaoSalvar
@onready var botao_voltar: Button = $Tela/Painel/BotaoVoltar


func _ready() -> void:

	rascunho = Configuracoes.valores.duplicate()

	_ligar_linha(linha_resolucao, $Tela/Painel/AnteriorResolucao, $Tela/Painel/ProximoResolucao, _mudar_resolucao)
	_ligar_linha(linha_modo, $Tela/Painel/AnteriorModo, $Tela/Painel/ProximoModo, _mudar_modo)
	_ligar_linha(linha_fps, $Tela/Painel/AnteriorFps, $Tela/Painel/ProximoFps, _mudar_fps)

	barra_geral.valor_alterado.connect(_mudar_volume.bind("volume_geral"))
	barra_musica.valor_alterado.connect(_mudar_volume.bind("volume_musica"))
	barra_efeitos.valor_alterado.connect(_mudar_volume.bind("volume_efeitos"))

	botao_salvar.pressed.connect(salvar)
	botao_voltar.pressed.connect(voltar)

	_ligar_foco()

	get_viewport().size_changed.connect(_ajustar_escala)
	_ajustar_escala()

	aviso.text = ""
	_atualizar(false)

	linha_resolucao.grab_focus.call_deferred()


func _input(evento: InputEvent) -> void:

	if evento.is_action_pressed("ui_cancel") and not evento.is_echo():
		get_viewport().set_input_as_handled()
		voltar()


## O painel usa pixels da imagem; aqui ele acompanha o tamanho da tela.
## Os textos desfazem a escala do painel e usam a fonte já no tamanho final:
## texto encolhido depois de desenhado fica borrado (o "5" vira "S").
func _ajustar_escala() -> void:

	var escala := get_viewport().get_visible_rect().size / TAMANHO_IMAGEM
	painel.scale = escala

	for rotulo in _rotulos():

		if not rotulo.has_meta("tamanho_imagem"):
			rotulo.set_meta("tamanho_imagem", rotulo.size)
			rotulo.set_meta("fonte_imagem", rotulo.get_theme_font_size("font_size"))

		var tamanho: Vector2 = rotulo.get_meta("tamanho_imagem")
		var fonte: int = rotulo.get_meta("fonte_imagem")

		rotulo.scale = Vector2.ONE / escala
		rotulo.size = tamanho * escala
		rotulo.add_theme_font_size_override("font_size", maxi(roundi(fonte * minf(escala.x, escala.y)), 8))


func _rotulos() -> Array[Label]:
	return [valor_resolucao, valor_modo, valor_fps, porcentagem_geral, porcentagem_musica, porcentagem_efeitos, aviso]


# ---------------------------------------------------------------------------
# Ligações
# ---------------------------------------------------------------------------

## Uma linha de opção: clicar na caixa ou nas setas troca o valor; com foco,
## esquerda/direita também trocam.
func _ligar_linha(linha: Button, anterior: Button, proximo: Button, acao: Callable) -> void:

	linha.pressed.connect(acao.bind(1))
	anterior.pressed.connect(acao.bind(-1))
	proximo.pressed.connect(acao.bind(1))
	linha.gui_input.connect(_setas_na_linha.bind(linha, acao))


func _setas_na_linha(evento: InputEvent, linha: Control, acao: Callable) -> void:

	if evento.is_action_pressed("ui_left", true):
		acao.call(-1)
		linha.accept_event()

	elif evento.is_action_pressed("ui_right", true):
		acao.call(1)
		linha.accept_event()


## Ordem do foco: as seis linhas de cima para baixo e os dois botões.
## O foco não sai da tela (nem com Tab) para os menus que ficam por baixo.
func _ligar_foco() -> void:

	var ordem: Array[Control] = [linha_resolucao, linha_modo, linha_fps, barra_geral, barra_musica, barra_efeitos, botao_salvar, botao_voltar]

	for i in range(ordem.size()):
		var atual := ordem[i]
		var seguinte := ordem[(i + 1) % ordem.size()]
		var anterior := ordem[(i - 1 + ordem.size()) % ordem.size()]
		atual.focus_next = atual.get_path_to(seguinte)
		atual.focus_previous = atual.get_path_to(anterior)

	for i in range(6):
		var atual := ordem[i]
		atual.focus_neighbor_top = atual.get_path_to(ordem[i - 1] if i > 0 else botao_salvar)
		atual.focus_neighbor_bottom = atual.get_path_to(ordem[i + 1])

	for botao in [botao_salvar, botao_voltar]:
		botao.focus_neighbor_top = botao.get_path_to(barra_efeitos)
		botao.focus_neighbor_bottom = botao.get_path_to(linha_resolucao)

	botao_salvar.focus_neighbor_left = botao_salvar.get_path_to(botao_voltar)
	botao_salvar.focus_neighbor_right = botao_salvar.get_path_to(botao_voltar)
	botao_voltar.focus_neighbor_left = botao_voltar.get_path_to(botao_salvar)
	botao_voltar.focus_neighbor_right = botao_voltar.get_path_to(botao_salvar)


# ---------------------------------------------------------------------------
# Mudanças
# ---------------------------------------------------------------------------

func _mudar_resolucao(passo: int) -> void:

	# Em tela cheia vale a resolução do monitor
	if rascunho.modo == "tela_cheia":
		return

	var opcoes := Configuracoes.resolucoes_disponiveis()
	var indice := opcoes.find(Configuracoes.resolucao_valida(rascunho.resolucao))
	rascunho.resolucao = opcoes[wrapi(indice + passo, 0, opcoes.size())]
	_atualizar()


func _mudar_modo(passo: int) -> void:

	var opcoes := Configuracoes.MODOS
	var indice := maxi(opcoes.find(rascunho.modo), 0)
	rascunho.modo = opcoes[wrapi(indice + passo, 0, opcoes.size())]
	_atualizar()


func _mudar_fps(passo: int) -> void:

	var opcoes := Configuracoes.OPCOES_FPS
	var indice := maxi(opcoes.find(rascunho.fps), 0)
	rascunho.fps = opcoes[wrapi(indice + passo, 0, opcoes.size())]
	_atualizar()


func _mudar_volume(valor: float, chave: String) -> void:

	rascunho[chave] = valor

	# Prévia: ouve-se o volume novo, mas nada é gravado ainda
	Configuracoes.aplicar_audio(rascunho)
	_atualizar()


# ---------------------------------------------------------------------------
# Botões
# ---------------------------------------------------------------------------

func salvar() -> void:

	var erro := Configuracoes.definir_e_salvar(rascunho)
	rascunho = Configuracoes.valores.duplicate()
	_atualizar(false)

	if erro == OK:
		_mostrar_mensagem("Configurações salvas!", COR_SALVO)
	else:
		_mostrar_mensagem("Não foi possível salvar", COR_ERRO)


func voltar() -> void:

	# Desfaz a prévia de volume que não foi salva
	Configuracoes.aplicar_audio()

	fechada.emit()
	queue_free()


func tem_alteracoes() -> bool:

	for chave in Configuracoes.PADRAO:

		var salvo = Configuracoes.valores[chave]
		var novo = rascunho[chave]

		if salvo is float or novo is float:
			if not is_equal_approx(float(salvo), float(novo)):
				return true
		elif salvo != novo:
			return true

	return false


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

## Redesenha os valores. `mudou` = o jogador acabou de mudar algo (aí a
## mensagem temporária dá lugar ao aviso de alterações não salvas).
func _atualizar(mudou: bool = true) -> void:

	if mudou:
		_cancelar_mensagem()

	var tela_cheia: bool = rascunho.modo == "tela_cheia"

	if tela_cheia:
		valor_resolucao.text = Configuracoes.texto_resolucao(Configuracoes.resolucao_do_monitor())
	else:
		valor_resolucao.text = Configuracoes.texto_resolucao(Configuracoes.resolucao_valida(rascunho.resolucao))

	# Em tela cheia a resolução não se escolhe: fica apagada
	valor_resolucao.modulate.a = 0.4 if tela_cheia else 1.0

	valor_modo.text = Configuracoes.NOMES_MODOS[rascunho.modo]
	valor_fps.text = Configuracoes.texto_fps(rascunho.fps)

	_mostrar_volume(barra_geral, porcentagem_geral, rascunho.volume_geral)
	_mostrar_volume(barra_musica, porcentagem_musica, rascunho.volume_musica)
	_mostrar_volume(barra_efeitos, porcentagem_efeitos, rascunho.volume_efeitos)

	if not _mensagem_temporaria:
		_mostrar_pendencia()


func _mostrar_volume(barra, rotulo: Label, valor: float) -> void:
	barra.definir_valor(valor)
	rotulo.text = "%d%%" % roundi(valor * 100.0)


func _mostrar_pendencia() -> void:

	aviso.add_theme_color_override("font_color", COR_AVISO)
	aviso.modulate.a = 1.0
	aviso.text = TEXTO_PENDENTE if tem_alteracoes() else ""


## Mensagem que some sozinha depois de um tempo (ex.: "Configurações salvas!").
func _mostrar_mensagem(texto: String, cor: Color) -> void:

	_cancelar_mensagem()

	_mensagem_temporaria = true
	aviso.text = texto
	aviso.add_theme_color_override("font_color", cor)
	aviso.modulate.a = 1.0

	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(1.6)
	_tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.5)
	_tween_aviso.tween_callback(_fim_da_mensagem)


func _fim_da_mensagem() -> void:
	_mensagem_temporaria = false
	_mostrar_pendencia()


func _cancelar_mensagem() -> void:

	if _tween_aviso != null:
		_tween_aviso.kill()

	_mensagem_temporaria = false
