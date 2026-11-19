extends RefCounted
## Variações de uniforme dos inimigos, aplicadas pelo shader
## variacao_uniforme.gdshader (sem sprites novos; vale para todas as animações).
##
## Cada tipo tem uma lista de paletas. A posição 0 é sempre o uniforme original
## (sem shader). Os nomes aparecem no Inspetor de cada inimigo (propriedade
## "variacao") e precisam seguir a mesma ordem destas listas.

const SHADER := preload("res://scripts/personagens/variacao_uniforme.gdshader")

## Juiz: uniforme preto com detalhes amarelos (matiz ~48°).
const JUIZ: Array[Dictionary] = [
	{},
	# 1 — Azul-marinho com detalhes brancos
	{
		"escuros_ativo": true, "escuros_cor": Color(0.3, 0.45, 1.0),
		"escuros_val_min": 0.05, "escuros_val_max": 0.34, "escuros_sat_max": 0.5,
		"escuros_brilho_min": 0.24, "escuros_brilho_max": 0.8,
		"faixa1_ativa": true, "faixa1_centro": 48.0, "faixa1_largura": 14.0,
		"faixa1_sat_min": 0.45, "faixa1_val_min": 0.2, "faixa1_val_max": 0.78, "faixa1_sat": 0.0, "faixa1_val": 1.35,
	},
	# 2 — Vinho com detalhes amarelos
	{
		"escuros_ativo": true, "escuros_cor": Color(0.85, 0.16, 0.3),
		"escuros_val_min": 0.05, "escuros_val_max": 0.34, "escuros_sat_max": 0.5,
		"escuros_brilho_min": 0.25, "escuros_brilho_max": 0.8,
	},
	# 3 — Verde com detalhes brancos
	{
		"escuros_ativo": true, "escuros_cor": Color(0.2, 0.78, 0.4),
		"escuros_val_min": 0.05, "escuros_val_max": 0.34, "escuros_sat_max": 0.5,
		"escuros_brilho_min": 0.22, "escuros_brilho_max": 0.78,
		"faixa1_ativa": true, "faixa1_centro": 48.0, "faixa1_largura": 14.0,
		"faixa1_sat_min": 0.45, "faixa1_val_min": 0.2, "faixa1_val_max": 0.78, "faixa1_sat": 0.0, "faixa1_val": 1.35,
	},
	# 4 — Amarelo com detalhes pretos
	{
		"escuros_ativo": true, "escuros_cor": Color(1.0, 0.86, 0.12),
		"escuros_val_min": 0.05, "escuros_val_max": 0.34, "escuros_sat_max": 0.5,
		"escuros_brilho_min": 0.66, "escuros_brilho_max": 1.2,
		"faixa1_ativa": true, "faixa1_centro": 48.0, "faixa1_largura": 14.0,
		"faixa1_sat_min": 0.45, "faixa1_val_min": 0.2, "faixa1_val_max": 0.78, "faixa1_sat": 0.0, "faixa1_val": 0.3,
	},
]

## Goleiro: camisa vermelha (matiz ~357°) com metade amarela (matiz ~44°).
## A pele fica protegida entre 8° e 34° (o amarelo da camisa começa em ~36°).
const GOLEIRO: Array[Dictionary] = [
	{},
	# 1 — Verde e branco
	{
		"pele_matiz_min": 8.0, "pele_matiz_max": 34.0,
		"faixa1_ativa": true, "faixa1_centro": 357.0, "faixa1_largura": 13.0,
		"faixa1_sat_min": 0.55, "faixa1_val_min": 0.3, "faixa1_giro": 128.0, "faixa1_sat": 1.0, "faixa1_val": 1.1,
		"faixa2_ativa": true, "faixa2_centro": 44.0, "faixa2_largura": 12.0,
		"faixa2_sat_min": 0.5, "faixa2_val_min": 0.3, "faixa2_sat": 0.08, "faixa2_val": 1.25,
	},
	# 2 — Azul e amarelo
	{
		"pele_matiz_min": 8.0, "pele_matiz_max": 34.0,
		"faixa1_ativa": true, "faixa1_centro": 357.0, "faixa1_largura": 13.0,
		"faixa1_sat_min": 0.55, "faixa1_val_min": 0.3, "faixa1_giro": -137.0, "faixa1_sat": 1.0, "faixa1_val": 1.25,
	},
	# 3 — Roxo e rosa
	{
		"pele_matiz_min": 8.0, "pele_matiz_max": 34.0,
		"faixa1_ativa": true, "faixa1_centro": 357.0, "faixa1_largura": 13.0,
		"faixa1_sat_min": 0.55, "faixa1_val_min": 0.3, "faixa1_giro": -80.0, "faixa1_sat": 0.95, "faixa1_val": 1.2,
		"faixa2_ativa": true, "faixa2_centro": 44.0, "faixa2_largura": 12.0,
		"faixa2_sat_min": 0.5, "faixa2_val_min": 0.3, "faixa2_giro": -72.0, "faixa2_sat": 0.7, "faixa2_val": 1.1,
	},
	# 4 — Laranja e preto
	{
		"pele_matiz_min": 8.0, "pele_matiz_max": 34.0,
		"faixa1_ativa": true, "faixa1_centro": 357.0, "faixa1_largura": 13.0,
		"faixa1_sat_min": 0.55, "faixa1_val_min": 0.3, "faixa1_giro": 26.0, "faixa1_sat": 1.0, "faixa1_val": 1.3,
		"faixa2_ativa": true, "faixa2_centro": 44.0, "faixa2_largura": 12.0,
		"faixa2_sat_min": 0.5, "faixa2_val_min": 0.3, "faixa2_sat": 0.1, "faixa2_val": 0.35,
	},
]

## Zagueiro: camisa listrada roxa (matiz ~285°) e preta, calção preto.
const ZAGUEIRO: Array[Dictionary] = [
	{},
	# 1 — Vermelho e preto
	{
		"faixa1_ativa": true, "faixa1_centro": 285.0, "faixa1_largura": 30.0,
		"faixa1_sat_min": 0.2, "faixa1_val_min": 0.08, "faixa1_giro": 75.0, "faixa1_sat": 1.7, "faixa1_val": 1.45,
	},
	# 2 — Verde e branco (listras pretas e calção viram brancos)
	{
		"faixa1_ativa": true, "faixa1_centro": 285.0, "faixa1_largura": 30.0,
		"faixa1_sat_min": 0.2, "faixa1_val_min": 0.08, "faixa1_giro": -160.0, "faixa1_sat": 1.6, "faixa1_val": 1.4,
		"escuros_ativo": true, "escuros_cor": Color(0.95, 0.96, 1.0),
		"escuros_val_min": 0.06, "escuros_val_max": 0.2, "escuros_sat_max": 0.5,
		"escuros_brilho_min": 0.55, "escuros_brilho_max": 0.95,
	},
	# 3 — Azul e preto
	{
		"faixa1_ativa": true, "faixa1_centro": 285.0, "faixa1_largura": 30.0,
		"faixa1_sat_min": 0.2, "faixa1_val_min": 0.08, "faixa1_giro": -62.0, "faixa1_sat": 1.7, "faixa1_val": 1.6,
	},
	# 4 — Branco e preto
	{
		"faixa1_ativa": true, "faixa1_centro": 285.0, "faixa1_largura": 30.0,
		"faixa1_sat_min": 0.2, "faixa1_val_min": 0.08, "faixa1_sat": 0.0, "faixa1_val": 3.2,
	},
	# 5 — Amarelo e preto
	{
		"faixa1_ativa": true, "faixa1_centro": 285.0, "faixa1_largura": 30.0,
		"faixa1_sat_min": 0.2, "faixa1_val_min": 0.08, "faixa1_giro": 128.0, "faixa1_sat": 1.9, "faixa1_val": 2.6,
	},
]


## Aplica a variação `indice` do `tipo` ("juiz", "goleiro", "zagueiro") no sprite.
## Índice 0 (ou inválido) deixa o uniforme original.
static func aplicar(sprite: CanvasItem, tipo: String, indice: int) -> void:

	if sprite == null:
		return

	var lista: Array[Dictionary] = []

	match tipo:
		"juiz":
			lista = JUIZ
		"goleiro":
			lista = GOLEIRO
		"zagueiro":
			lista = ZAGUEIRO

	if indice <= 0 or indice >= lista.size():
		sprite.material = null
		return

	var material := ShaderMaterial.new()
	material.shader = SHADER

	var parametros: Dictionary = lista[indice]

	for chave in parametros:
		material.set_shader_parameter(chave, parametros[chave])

	sprite.material = material


static func quantidade(tipo: String) -> int:

	match tipo:
		"juiz":
			return JUIZ.size()
		"goleiro":
			return GOLEIRO.size()
		"zagueiro":
			return ZAGUEIRO.size()

	return 1
