extends Node2D

@onready var jogador = $Personagem # Nome do nó do seu jogador dentro da fase
@onready var tilemap = $TileMap    # Nome do nó de mapa/cenário da sua fase

func _ready() -> void:
	# Configura os limites da câmera do jogador ao tamanho exato do TileMap
	if tilemap and jogador.has_node("Camera2D"):
		var camera = jogador.get_node("Camera2D")
		var mapa_bounds = tilemap.get_used_rect()
		var tamanho_celula = tilemap.tile_set.tile_size
		
		camera.limit_left = mapa_bounds.position.x * tamanho_celula.x
		camera.limit_top = mapa_bounds.position.y * tamanho_celula.y
		camera.limit_right = mapa_bounds.end.x * tamanho_celula.x
		camera.limit_bottom = mapa_bounds.end.y * tamanho_celula.y
		camera.limit_enabled = true
