extends "res://inimigo_base.gd"
## Juiz: fica parado, vira para o jogador e lança cartões amarelos quando o enxerga.
## Vida, dano e morte vêm de inimigo_base.gd.
##
## - Enxerga o jogador até `alcance_visao` px, desde que nada sólido (parede,
##   portão fechado, obstáculo alto) tape a linha entre a mão dele e o jogador.
##   Outros inimigos e projéteis não tapam a visão.
## - Só lança estando visível na tela: o cartão nunca vem de fora da tela.
## - Cada lançamento: ergue o cartão (aviso), solta mirando no peito do jogador
##   (inclinação limitada; com o jogador no ar, sai reto) e descansa
##   `intervalo_ataque` s antes do próximo.
## - Dá para desviar pulando por cima do cartão ou escondendo atrás de um
##   obstáculo alto. Colado nele (menos de `distancia_minima`), não lança.

enum Estado {
	PARADO,
	LANCANDO,
}

@export_group("Cartões")
## Distância horizontal (px) em que o Juiz enxerga o jogador, para cada lado.
@export var alcance_visao: float = 640.0
## Velocidade do cartão (px/s).
@export var velocidade_cartao: float = 650.0
## Pausa (s) entre o fim de um lançamento e o começo do próximo.
@export var intervalo_ataque: float = 0.9
## Inclinação máxima (graus) do lançamento, para cima ou para baixo.
@export_range(0.0, 60.0, 1.0) var angulo_maximo: float = 25.0
## Distância (px) que o cartão percorre antes de sumir sozinho.
@export var alcance_cartao: float = 1000.0
## Mais perto que isto (px, de centro a centro) o Juiz não lança: o cartão
## nasceria dentro do jogador, sem chance de desvio.
@export var distancia_minima: float = 110.0
## Só lança quando o Juiz aparece na tela (com esta margem, em px).
@export var exigir_na_tela: bool = true
@export var margem_tela: float = 30.0

@export_group("Aparência")
## Cores do uniforme (ver variacoes_inimigos.gd).
@export_enum("Preto (original)", "Azul-marinho", "Vinho", "Verde", "Amarelo") var variacao: int = 0
## Sem ninguém à vista, de quanto em quanto tempo (s) ele confere o relógio.
@export var intervalo_relogio: float = 6.0

const CENA_CARTAO := preload("res://cena_cartao.tscn")

var estado: Estado = Estado.PARADO
## Tempo (s) até poder lançar de novo.
var recarga: float = 0.0
var direcao_inimigo: int = 1
var _tempo_ocioso: float = 0.0

@onready var animacao: AnimationPlayer = $AnimationPlayer
@onready var mao: Marker2D = $Visual/Marker2D


func _ready() -> void:
	aplicar_variacao("juiz", variacao)
	animacao.animation_finished.connect(_on_animacao_terminou)
	# Cada Juiz confere o relógio num momento diferente
	_tempo_ocioso = fmod(global_position.x * 0.37, intervalo_relogio)


func _physics_process(delta: float) -> void:

	if morrendo:
		return

	recarga = maxf(recarga - delta, 0.0)

	var jogador := buscar_jogador()

	if jogador == null:
		if estado == Estado.PARADO:
			_tocar_ocioso(delta, true)
		return

	_virar_para(jogador)

	if estado == Estado.PARADO:
		var vendo := ve_jogador()
		# Só começa com o jogador apoiado: o aviso (cartão erguido) sempre
		# aparece quando ainda dá para reagir
		if recarga <= 0.0 and vendo and _jogador_apoiado(jogador):
			_iniciar_lancamento()
		else:
			_tocar_ocioso(delta, not vendo)


## Parado, respirando; de vez em quando, sem ninguém à vista, olha o relógio
## (com o jogador à vista, para de olhar na hora).
func _tocar_ocioso(delta: float, pode_relogio: bool) -> void:

	if animacao.current_animation == "relogio" and animacao.is_playing():
		if pode_relogio:
			return
		_tocar("parado", true)
		return

	if not pode_relogio:
		_tempo_ocioso = 0.0
		_tocar("parado")
		return

	_tempo_ocioso += delta

	if _tempo_ocioso >= intervalo_relogio:
		_tempo_ocioso = 0.0
		animacao.play("relogio")
		return

	_tocar("parado")


func _jogador_apoiado(jogador: Node2D) -> bool:
	return not (jogador is CharacterBody2D) or (jogador as CharacterBody2D).is_on_floor()


## Vira o Juiz (e a mão que lança) para o lado do jogador.
func _virar_para(jogador: Node2D) -> void:

	var dx := jogador.global_position.x - global_position.x

	# Jogador quase em cima: mantém o lado atual (evita ficar virando)
	if absf(dx) < 4.0:
		return

	direcao_inimigo = 1 if dx > 0.0 else -1
	virar_visual(direcao_inimigo)


## O jogador está ao alcance, à vista (sem nada sólido no caminho) e o Juiz
## aparece na tela?
func ve_jogador() -> bool:

	var jogador := buscar_jogador()

	if jogador == null:
		return false

	var alvo := ponto_alvo(jogador)
	var origem := mao.global_position
	var distancia := absf(alvo.x - global_position.x)

	if distancia > alcance_visao or distancia < distancia_minima:
		return false

	# Alto ou baixo demais para a mira
	var diferenca := alvo - origem
	if rad_to_deg(atan2(absf(diferenca.y), maxf(absf(diferenca.x), 1.0))) > angulo_maximo + 10.0:
		return false

	if exigir_na_tela and not visivel_na_tela():
		return false

	return _linha_livre(origem, alvo)


## Ponto do jogador para onde o cartão é mirado: a altura do peito dele em pé
## (pela origem do corpo, que não muda no carrinho; deslizando, o cartão passa
## por cima).
func ponto_alvo(jogador: Node2D) -> Vector2:
	return jogador.global_position + Vector2(0.0, -20.0)


## O Juiz aparece na tela agora (pela câmera atual)?
func visivel_na_tela() -> bool:

	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()

	if camera == null:
		return true

	var tamanho := viewport.get_visible_rect().size / camera.zoom
	var tela := Rect2(camera.get_screen_center_position() - tamanho * 0.5, tamanho)

	return tela.grow(-margem_tela).has_point(global_position)


## Nada sólido entre `origem` e `alvo`? Inimigos e projéteis não contam.
func _linha_livre(origem: Vector2, alvo: Vector2) -> bool:

	var espaco := get_world_2d().direct_space_state
	var consulta := PhysicsRayQueryParameters2D.create(origem, alvo, 1)
	var ignorar: Array[RID] = [get_rid()]

	for _i in range(8):

		consulta.exclude = ignorar
		var resultado := espaco.intersect_ray(consulta)

		if resultado.is_empty():
			return true

		var objeto = resultado.get("collider")

		if objeto is Node and objeto.is_in_group("jogador"):
			return true

		if objeto is Node and (objeto.is_in_group("inimigos") or objeto.is_in_group("projeteis")):
			ignorar.append(resultado.get("rid"))
			continue

		# Parede, portão fechado ou obstáculo
		return false

	return false


func _iniciar_lancamento() -> void:

	estado = Estado.LANCANDO
	animacao.play("atirando")
	animacao.seek(0.0, true)


## Chamado pela animação "atirando" no quadro em que o braço se estica.
func atirar_cartao() -> void:

	if morrendo or estado != Estado.LANCANDO:
		return

	# O jogador chegou colado durante o aviso: não solta o cartão à queima-roupa
	var jogador := buscar_jogador()
	if jogador != null and absf(jogador.global_position.x - global_position.x) < distancia_minima:
		return

	var cartao := CENA_CARTAO.instantiate()
	var corpo := cartao.get_node("CharacterBody2D")

	# Direção e velocidade antes de entrar na cena, para o cartão já nascer certo
	corpo.vetor = direcao_do_lancamento()
	corpo.velocidade = velocidade_cartao
	corpo.alcance_maximo = alcance_cartao

	get_parent().add_child(cartao)
	cartao.global_position = mao.global_position


## Direção do cartão: para o peito do jogador, com a inclinação limitada.
## Sai reto sem jogador à frente ou com o jogador no ar (pular sempre desvia;
## a mira só vale para quem está apoiado em outra altura, como numa plataforma).
func direcao_do_lancamento() -> Vector2:

	var reta := Vector2(direcao_inimigo, 0.0)
	var jogador := buscar_jogador()

	if jogador == null:
		return reta

	if not _jogador_apoiado(jogador):
		return reta

	var diferenca := ponto_alvo(jogador) - mao.global_position

	if diferenca.x * direcao_inimigo <= 0.0:
		return reta

	var limite := deg_to_rad(angulo_maximo)
	var angulo := clampf(atan2(diferenca.y, absf(diferenca.x)), -limite, limite)

	return Vector2(cos(angulo) * direcao_inimigo, sin(angulo))


func _on_animacao_terminou(nome: StringName) -> void:

	if morrendo:
		return

	if nome == &"relogio":
		_tocar("parado", true)
		return

	if nome != &"atirando" or estado != Estado.LANCANDO:
		return

	estado = Estado.PARADO
	recarga = intervalo_ataque
	_tempo_ocioso = 0.0
	_tocar("parado", true)


func _tocar(nome: StringName, reiniciar: bool = false) -> void:

	if reiniciar or animacao.current_animation != nome:
		animacao.play(nome)
