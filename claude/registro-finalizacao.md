# Registro da finalização

Projeto: `C:\Users\Pichau\OneDrive\Documentos\Projetos\godot-soccer-game`
Branch: `finalizacao-jogo` (somente commits locais, sem push)
Engine: Godot 4.7.2 (Steam): `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

> Os arquivos `claude/diagnostico-e-plano-finalizacao.md` e `claude/registro-finalizacao.md`
> não existiam na pasta quando a P2 começou. O planejamento abaixo foi repassado na
> conversa e este registro foi criado a partir dele.

## Planejamento

| Etapa | Conteúdo | Situação |
|---|---|---|
| P1 | Base comum de inimigos, dano da bola/carrinho, ajustes de Juiz/Goleiro/cartão | concluída (`8dfae22`) |
| P2 | Chefão "Cartão Vermelho" (`cena_chefao.tscn` + `script_chefão.gd`): 12 HP, duas fases, soco, cartões vermelhos, barra de vida, morte → tela de vitória (`Tela de vitoria.jpeg`, botão transparente sobre "RETORNAR AO MENU") | concluída |
| P3 | Configurações com `Configurações Neon de Futebol Pixel.png`: vídeo, FPS e volumes persistentes, pelo menu inicial e pela pausa. Sem idiomas, legendas ou remapeamento | pendente |
| P4 | Zagueiro rival reaproveitando `cena_inimigo2.tscn`, `personagem.gd` e as animações existentes | pendente |
| P5 | Obstáculos aproveitando o cenário e os sprites existentes, sem duplicação visual | pendente |
| P6 | Integração, testes e correções gerais | pendente |
| P7 | Áudio e música — só depois que os arquivos definitivos forem entregues. Nada de sons provisórios | aguardando arquivos |

Regras combinadas: não descartar alterações preexistentes, não fazer push, preservar as
imagens oficiais (nenhuma é editada; recortes são feitos com `region_rect`), não alterar
arquivos só para normalizar fins de linha (os `.import` e o `project.godot` aparecem como
modificados apenas por LF/CRLF e ficam fora dos commits).

## P1 — commit `8dfae22`

- `inimigo_base.gd`: grupo `inimigos`, vida própria, `receber_dano(quantidade)`, morte única.
- Bola tira 1 de vida; carrinho tira 2 e acerta no máximo um inimigo por uso.
- Cartões do Juiz atravessam outros inimigos e projéteis; Juiz só atira se enxerga o jogador.
- Goleiro: soco com checagem de alcance no quadro do impacto.

## P2 — Chefão "Cartão Vermelho"

### Decisões

- **Onde acontece a luta:** no fim da fase atual (x ≈ 1750–2400, em frente ao gol da
  direita), dentro de uma arena (`cena_arena_chefao.tscn`) instanciada em `cena_fase.tscn`.
- **Portão da arena:** usa `portoes.png` (recorte aberto/fechado). Antes da luta ele fica
  "aberto só para o jogador" (exceção de colisão): os inimigos comuns batem nele e não entram.
  Ao entrar na arena (zona de gatilho que cobre a arena toda), o portão fecha atrás do jogador
  e o chefão acorda. Na vitória ele abre de novo.
- **Sprites:** `chefao.png` tem quatro fileiras (parado, correndo, batendo, atirando) desenhadas
  em escalas ligeiramente diferentes. As animações foram refeitas com recortes medidos no
  arquivo, com `offset` por quadro (o corpo fica parado no lugar) e `scale` por fileira
  (o chefão não "encolhe" ao atacar). O lado para onde olha é controlado pelo nó `Visual`
  (`scale.x = ±1`), então o ponto de lançamento acompanha.
- **Vida e dano:** 12 HP (bola = 1, carrinho = 2). Invulnerável enquanto espera, na
  apresentação (barra enchendo) e na troca de fase; golpes nesses momentos só dão um brilho fraco.
- **Fase 1:** persegue o jogador; de perto dá um combo de socos (jab, gancho com meia-lua e
  soco vermelho — acerta no máximo uma vez por ataque, com empurrão); de longe
  (≥ 280 px) lança um cartão vermelho rasteiro (é preciso pular). Os quadros em que o cartão
  "carrega" na mão servem de aviso.
- **Fase 2 (≤ 6 HP):** pausa de "fúria" (pisca em vermelho, câmera treme, nome da barra muda),
  depois fica mais rápido (anda 185 px/s, animações 1,3×) e lança dois cartões: um rasteiro e,
  ~1 s depois, um alto (passa por cima de quem fica no chão e acerta quem pula na hora errada).
  Brilho vermelho pulsante durante a fase.
- **Jogador na cabeça do chefão:** é empurrado para o lado, sem dano, e o chefão respira
  0,45 s antes de voltar a perseguir (evita ficar parado em cima e também o soco imediato).
- **Cartão vermelho:** `cena_cartao_vermelho.tscn` reaproveita `script_cartao.gd` (o mesmo
  do Juiz), agora com `velocidade` exportada e `altura_alvo` opcional (o cartão sai da mão e
  desce/sobe até a altura escolhida). Arte: o cartão avulso da fileira "atirando".
- **Barra de vida:** `barra_chefao.gd`, na parte de baixo da tela (não cobre o menu de pausa),
  com barra "atrasada" amarela, marca de metade (fase 2) e fonte Pixelify Sans. Some durante
  a pausa (grupo `ocultar_na_pausa`, tratado em `cena_pausa.gd`).
- **Morte e vitória:** clarão, tremor, pisca, tomba e some. A arena deixa o jogador
  invencível, remove cartões no ar e, 2,8 s depois (o tempo para durante a pausa), troca
  para `cena_vitoria.tscn`: imagem oficial esticada na tela e botão transparente sobre
  "RETORNAR AO MENU" (realce leve ao passar o mouse; começa com foco, então Enter funciona).
- **Jogador:** ganhou `empurrar(impulso)` (empurrão que perde força) e `invencivel`.
- **Inimigo base:** a animação de morte virou `_animar_morte()`, que o chefão sobrescreve.
- **Tremor de câmera:** limitado às bordas da fase (o `offset` da Camera2D ignora os limites).

### Arquivos

Novos: `arena_chefao.gd`, `cena_arena_chefao.tscn`, `barra_chefao.gd`,
`cena_cartao_vermelho.tscn`, `cena_vitoria.tscn`, `script_vitoria.gd`, `Tela de vitoria.jpeg`
(imagem oficial, sem alterações) e os `.uid`/`.import` gerados pela Godot.
Alterados: `cena_chefao.tscn`, `script_chefão.gd`, `cena_fase.tscn`, `inimigo_base.gd`,
`script_cartao.gd`, `script_personagem.gd`, `cena_pausa.gd`.

### Testes (Godot 4.7.2, headless, `--fixed-fps 60`)

- Importação e execução da fase sem erros nem avisos de script.
- Roteiro da luta: 46 verificações, 0 falhas — inativo/apresentação/transição invulneráveis,
  portão fecha, cartão rasteiro acerta o jogador parado, soco tira 1 vida e empurra, bola de
  verdade tira 1, carrinho tira 2, jogador em cima é empurrado sem dano e cai fora do alcance,
  troca de fase em 6 HP, rajada rasteiro + alto na fase 2, morte, jogador invencível, cartões
  removidos, tela de vitória, botão volta ao menu.
- Portão com teclas simuladas: 5 verificações, 0 falhas — Goleiro não entra, jogador atravessa
  andando, portão fechado segura o jogador (andando e pulando).
- Capturas de tela renderizadas (portão, apresentação, cartão, soco, fúria, fase 2, morte,
  vitória) conferidas visualmente.

Os scripts de teste ficaram fora do projeto (pasta temporária da sessão); a P6 decide se
entram no repositório.
