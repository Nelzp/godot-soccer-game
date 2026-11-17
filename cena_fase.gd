extends Node2D
## Script das fases: ajusta a câmera do jogador aos limites da fase.
##
## Se `cenario` apontar para um nó com a propriedade `largura` (o cenário
## montado da Fase 1), o limite direito vem dele; senão vale limite_direito.

## Nó do cenário montado (opcional).
@export var cenario: Node
@export var limite_esquerdo: int = 0
@export var limite_topo: int = 3
@export var limite_direito: int = 2400
@export var limite_baixo: int = 650


func _ready() -> void:

	var direito := limite_direito

	if cenario != null and "largura" in cenario and cenario.largura > 0.0:
		direito = int(cenario.largura)

	var jogador := get_tree().get_first_node_in_group("jogador")
	var camera: Camera2D = null

	if jogador != null:
		camera = jogador.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return

	camera.limit_left = limite_esquerdo
	camera.limit_top = limite_topo
	camera.limit_right = direito
	camera.limit_bottom = limite_baixo
	camera.reset_smoothing()


## Largura jogável da fase (px).
func largura() -> float:

	if cenario != null and "largura" in cenario:
		return cenario.largura

	return float(limite_direito)
