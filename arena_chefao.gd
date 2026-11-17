extends Node2D
## Arena do chefão: portão, gatilho e o Chefão "Cartão Vermelho".
##
## - Antes da luta o portão fica aberto só para o jogador: os inimigos comuns
##   batem nele e não entram na arena.
## - Quando o jogador passa pelo gatilho, o portão se fecha atrás dele e o
##   chefão acorda.
## - Quando o chefão é derrotado: o jogador não leva mais dano, os cartões no
##   ar somem, o portão abre e, depois de alguns segundos, entra a tela de
##   vitória.
##
## O nó da arena fica no chão: y = 0 é a linha do gramado.

const CENA_VITORIA := "res://cena_vitoria.tscn"

## Recortes de portoes.png (portão fechado e aberto).
const REGIAO_PORTAO_FECHADO := Rect2(84, 123, 719, 614)
const REGIAO_PORTAO_ABERTO := Rect2(971, 123, 720, 613)

## Tempo (s) entre a derrota do chefão e a tela de vitória.
@export var atraso_vitoria: float = 2.8

var luta_iniciada: bool = false
var vitoria: bool = false

@onready var portao: StaticBody2D = $Portao
@onready var sprite_portao: Sprite2D = $Portao/Sprite2D
@onready var gatilho: Area2D = $Gatilho
@onready var chefao = $Chefao


func _ready() -> void:

	gatilho.body_entered.connect(_on_gatilho_body_entered)
	chefao.derrotado.connect(_on_chefao_derrotado)

	sprite_portao.region_rect = REGIAO_PORTAO_ABERTO

	# Portão aberto: só o jogador atravessa
	var jogador := _jogador()

	if jogador != null:
		portao.add_collision_exception_with(jogador)


func _jogador() -> PhysicsBody2D:
	return get_tree().get_first_node_in_group("jogador") as PhysicsBody2D


func _on_gatilho_body_entered(corpo: Node2D) -> void:

	if luta_iniciada or vitoria or not corpo.is_in_group("jogador"):
		return

	luta_iniciada = true
	_fechar_portao()
	chefao.ativar()


func _fechar_portao() -> void:

	var jogador := _jogador()

	if jogador != null:
		portao.remove_collision_exception_with(jogador)

	sprite_portao.region_rect = REGIAO_PORTAO_FECHADO

	# Pequeno "tranco" ao bater o portão
	var escala := sprite_portao.scale
	var tween := create_tween()
	tween.tween_property(sprite_portao, "scale", escala * Vector2(1.04, 0.96), 0.06)
	tween.tween_property(sprite_portao, "scale", escala, 0.12)


func _on_chefao_derrotado(_chefao: Node) -> void:

	if vitoria:
		return

	vitoria = true

	var jogador := _jogador()

	if jogador != null and "invencivel" in jogador:
		jogador.invencivel = true

	# Cartões que ainda estão no ar não acertam mais ninguém
	for projetil in get_tree().get_nodes_in_group("projeteis_inimigos"):
		if projetil.has_method("remover"):
			projetil.remover()

	# Portão aberto de novo (só para o jogador, como antes da luta)
	sprite_portao.region_rect = REGIAO_PORTAO_ABERTO

	if jogador != null:
		portao.add_collision_exception_with(jogador)

	# O timer para junto com o jogo pausado; se a fase for trocada antes,
	# a conexão some com a arena e nada acontece.
	get_tree().create_timer(atraso_vitoria, false).timeout.connect(_ir_para_vitoria)


func _ir_para_vitoria() -> void:
	get_tree().change_scene_to_file(CENA_VITORIA)
