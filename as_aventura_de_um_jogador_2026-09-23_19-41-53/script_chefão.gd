extends CharacterBody2D

# Configurações de velocidade e gravidade
@export var velocidade: float = 200.0
@export var gravidade: float = 980.0

# Referência para o tempo do ataque e detecção
@export var distancia_ataque: float = 40.0

# Estado do Inimigo
var direcao: int = 1
var esta_atacando: bool = false

# Referências dos nós na árvore (certifique-se de que os nomes correspondem)
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Conecta o sinal de término de animação do AnimationPlayer
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	# Aplica gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0

	# Se estiver atacando, ele não anda nem muda de estado
	if esta_atacando:
		velocity.x = 0
		move_and_slide()
		return

	# Lógica de movimento simples (patrulha)
	velocity.x = direcao * velocidade
	move_and_slide()

	# Inverte a direção ao bater em uma parede
	if is_on_wall():
		inverter_direcao()

	# Atualiza direção visual e animação
	atualizar_animacao()

func inverter_direcao() -> void:
	direcao *= -1

# Função para iniciar o ataque (pode ser chamada por um RayCast2D ou Area2D de detecção)
func atacar() -> void:
	if not esta_atacando:
		esta_atacando = true
		velocity.x = 0
		
		# Inicia a animação de ataque
		if animation_player.has_animation("atacando"):
			animation_player.play("atacando")
		elif animation_player.has_animation("attack"):
			animation_player.play("attack")

# Função chamada quando qualquer animação chega ao fim
func _on_animation_finished(anim_name: String) -> void:
	# Quando o ataque terminar, volta ao estado normal
	if anim_name == "atacar" or anim_name == "attack":
		esta_atacando = false

func atualizar_animacao() -> void:
	# Ajusta o espelhamento da sprite
	if direcao > 0:
		sprite.flip_h = false
	elif direcao < 0:
		sprite.flip_h = true

	# Se estiver se movendo
	if abs(velocity.x) > 0:
		_tocar_animacao(["andando", "walk", "andar"])
	else:
		_tocar_animacao(["parado", "idle"])

# Função auxiliar para garantir que a animação não resete a cada frame
func _tocar_animacao(nomes_possiveis: Array) -> void:
	for nome in nomes_possiveis:
		if animation_player.has_animation(nome):
			if animation_player.current_animation != nome:
				animation_player.play(nome)
			break
