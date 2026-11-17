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
| P3 | Configurações com `Configurações Neon de Futebol Pixel.png`: vídeo, FPS e volumes persistentes, pelo menu inicial e pela pausa. Sem idiomas, legendas ou remapeamento | concluída |
| P4 | Zagueiro rival reaproveitando `cena_inimigo2.tscn`, `personagem.gd` e as animações existentes | concluída |
| P5 | Obstáculos aproveitando o cenário e os sprites existentes, sem duplicação visual | concluída |
| P6 | Integração, testes e correções gerais | concluída |
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

## P3 — Configurações

### Decisões

- **Arte oficial intacta:** `cena_configuracoes.tscn` mostra a imagem esticada na tela
  inteira (mesma proporção da tela inicial) e cobre só os valores desenhados nela
  (caixas de vídeo, barras e porcentagens de áudio) com controles de verdade, nas mesmas
  posições. O nó `Painel` trabalha em pixels da imagem (1613 × 975) e é escalado para a tela;
  os textos desfazem essa escala e usam a fonte já no tamanho final (senão ficam borrados).
- **Vídeo:** resolução da janela (1152 × 648 até 3840 × 2160, só as que cabem no monitor),
  modo de tela (Janela / Tela Cheia) e limite de FPS (30, 60, 120, 144, Sem Limite).
  Em tela cheia vale a resolução do monitor e o campo de resolução fica apagado.
  O V-Sync continua ligado (padrão do projeto), então o limite real é o menor entre o FPS
  escolhido e a taxa do monitor. A física continua em 60 passos/s, então o jogo não muda.
- **Áudio:** Volume Geral (bus `Master`), Música (bus `Musica`) e Efeitos Sonoros
  (bus `Efeitos`). Os buses ficam em `default_bus_layout.tres` (aparecem no editor para a P7)
  e o autoload também os cria se faltarem. Padrões iguais aos da arte: 100% / 80% / 100%.
  0% deixa o bus mudo.
- **Salvar e voltar:** o vídeo só muda ao clicar em SALVAR; o áudio muda na hora para dar
  para ouvir (prévia). VOLTAR ou Esc descarta o que não foi salvo (o volume volta ao salvo).
  Um aviso amarelo "Alterações não salvas" aparece enquanto houver mudança pendente e
  "Configurações salvas!" aparece ao salvar.
- **Persistência:** autoload `Configuracoes` (`configuracoes.gd`) lê e aplica
  `user://configuracoes.cfg` ao abrir o jogo; valores inválidos voltam ao padrão e volumes
  são limitados a 0–100%.
- **Acesso:** botão CONFIGURAÇÕES do menu inicial (já existia, sem função) e novo botão
  CONFIGURAÇÕES no menu de pausa. A tela funciona com o jogo pausado; o Esc fecha só ela e a
  pausa continua aberta. Os quatro botões da pausa passaram a ter a mesma largura (340 px).
- **Ícone da pausa:** as engrenagens das imagens oficiais têm fundo opaco, então o botão usa
  `assets/icone_configuracoes.png`, uma engrenagem em pixel art gerada por código no estilo
  dos outros ícones (52 × 52, contorno escuro).
- **Teclado:** cima/baixo trocam de linha, esquerda/direita mudam o valor (5% por toque nas
  barras), Enter na caixa avança a opção; o foco não escapa para o menu de baixo.
- **Fonte:** Pixelify Sans, como no resto da interface. Observação: nessa fonte o "5" tem
  desenho parecido com "S" em qualquer peso e tamanho (é o desenho da fonte).

### Arquivos

Novos: `configuracoes.gd` (autoload), `configuracoes_tela.gd`, `cena_configuracoes.tscn`,
`barra_volume.gd`, `default_bus_layout.tres`, `assets/icone_configuracoes.png`,
`Configurações Neon de Futebol Pixel.png` (imagem oficial, sem alterações) e os
`.uid`/`.import` gerados pela Godot.
Alterados: `project.godot` (só a seção `[autoload]`), `script_inicio.gd`, `cena_pausa.gd`,
`cena_pausa.tscn`.

### Testes

- Configurações: 48 verificações, 0 falhas — padrões e buses, valores mostrados, prévia de
  áudio, VOLTAR descarta e não grava, SALVAR aplica e grava, tela cheia apaga a resolução,
  teclado (direita/baixo/esquerda/Esc), leitura do arquivo e arquivo inválido, abertura pela
  pausa com o jogo pausado e Esc em camadas. O teste usa um arquivo próprio
  (`user://teste_configuracoes.cfg`); o do jogador não é tocado.
- Chefão (46) e portão (5) rodados de novo: 0 falhas.
- Capturas renderizadas da tela pelo menu e pela pausa conferidas.

### Depois da P3

- Opção de linha de comando `-- --ignorar-configuracoes`: abre com os padrões sem ler o
  arquivo salvo (os testes com janela usam isso para não abrir em tela cheia; também serve
  para recuperar o jogo de uma configuração ruim). Commit separado.
- Um `user://configuracoes.cfg` com 1280 × 720 / Tela Cheia apareceu às 21:46 — gravado
  pelo jogo, não pelos testes (que usam arquivos próprios). Ele não foi tocado; o teste de
  configurações confere que ele continua igual.

## P4 — Zagueiro rival

### Decisões

- **Reaproveitamento:** `cena_inimigo2.tscn` + `personagem.gd` + as animações que já
  existiam (`correndo`, `parado`, `carrinho`). As células da folha `inimigo_1.png` são
  transparentes (só as linhas da grade são opacas), então os recortes antigos servem.
- **Cena:** o corpo estava a ~590 px do próprio desenho; os nós foram recentralizados (o
  corpo fica onde o boneco aparece). A raiz passou a se chamar `Zagueiro`, o RayCast2D sem
  uso saiu, `parado` ficou em loop e o zagueiro tem 2 de vida (`vida_maxima = 2`).
- **Comportamento (`personagem.gd`):** patrulha correndo num raio de 260 px em volta do ponto
  de partida (vira também em paredes e obstáculos). Com o jogador no chão, perto (≤ 250 px) e
  na mesma altura, vira para ele, para 0,4 s (aviso) e dá o carrinho por 1 s (480 px/s,
  perdendo força). Se encostar no jogador: 1 vida e empurrão; o carrinho termina ali.
  Batendo em parede/obstáculo, também termina. Depois fica 0,8 s parado (hora de atacar) e
  só repete após 1,6 s. Pulando na hora certa, o carrinho passa por baixo.
- **Dano:** a bola tira 1 (ele pisca em vermelho e fica 0,45 s atordoado); a segunda bolada
  derruba; o carrinho do jogador (2) derruba de uma vez.
- **Posição:** instanciado em `cena_fase.tscn` em x = 1200, entre o Juiz (715) e o Goleiro.

### Testes

- Zagueiro: 19 verificações, 0 falhas — grupo e vida, apoiado no chão, patrulha dentro do
  raio e virando, aviso antes do carrinho, carrinho tira 1 vida e empurra, recuperação
  parada, recarga, pulo na hora certa evita o carrinho, bola tira 1 e atordoa, segunda bolada
  derruba, carrinho do jogador derruba de uma vez.
- Bateria anterior rodada de novo (chefão 46, portão 5, configurações 48): 0 falhas.
- Capturas renderizadas (patrulha, preparo, carrinho, recuperação) conferidas: o zagueiro
  tem tamanho parecido com o do jogador.

## P5 — Obstáculos

### Decisões

- **Dois tipos de obstáculo, sem desenho repetido:**
  - Os objetos já desenhados em `cenario_principal.png` (caixotes, barreira listrada) ficam
    20–40 px "atrás" da linha em que o jogador anda. Eles viraram **plataformas de mão
    única**: o jogador passa na frente deles normalmente e pode pular de baixo para ficar em
    cima (a colisão fica exatamente no topo desenhado). Nada novo é desenhado por cima deles.
  - Os **sprites da folha de obstáculos** entram como obstáculos sólidos **na linha do chão**,
    em pontos sem objeto parecido desenhado atrás: uma barreira de salto (x = 330, 49 px de
    altura) e uma barreira de bonecos de treino (x = 960, 95 px, pulável).
- **Plataformas usadas (medidas na imagem):** caixotes A (x 645–721, topo y 431,6, com
  degraus em 460,5), barreira listrada (x 807–899, topo 469,3) e caixotes B (x 1432–1512,
  topo 432,5, degraus em 465). Os objetos do fundo da quadra (perto do alambrado), os bancos,
  os cones pequenos e os caixotes dentro da arena do chefão continuam só decoração.
- **Cena reutilizável:** `cena_obstaculo.tscn` + `obstaculo.gd` (`@tool`): escolhe o tipo
  (barreira de salto, barreira de bonecos, cone, caixa de salto, barreira listrada), a
  escala e o espelhamento no inspetor; recorte e colisão se ajustam sozinhos e a origem fica
  no meio da base (basta pôr y na linha do chão, 529,5). Grupo `obstaculos`.
- **Efeitos no jogo:** bola e cartões somem ao bater nos obstáculos sólidos; a visão do Juiz
  é bloqueada por eles; inimigos que patrulham dão meia-volta neles (o Zagueiro fica entre os
  bonecos e o portão). As plataformas não atrapalham quem anda no chão.
- **Juiz:** saiu de x = 715 (estava dentro dos caixotes A) para x = 760, entre os caixotes e a
  barreira listrada.

### Testes

- Obstáculos: 19 verificações, 0 falhas — quantidades e grupos, alturas e apoio no chão,
  jogador bloqueado andando e passando ao pular, bola some no obstáculo, jogador passa na
  frente dos caixotes, sobe por baixo e fica em cima (caixotes A, barreira, caixotes B e
  degrau), Juiz não enxerga através dos bonecos, Zagueiro vira nos bonecos, Goleiro anda por
  baixo das plataformas.
- Bateria completa rodada de novo: zagueiro 19, chefão 46, portão 5, configurações 48 — 0 falhas.
- Capturas renderizadas conferidas (barreira de salto, Juiz, jogador em cima dos caixotes,
  bonecos, caixotes B).

## P6 — Integração, testes e correções gerais

### Testes no repositório

- Pasta `testes/` com `.gdignore` (a Godot não importa nem exporta nada dali), os roteiros
  headless de todas as etapas, um executor (`testes/rodar_testes.ps1`, que acha a Godot pelo
  parâmetro `-Godot`, pela variável `GODOT`, na Steam ou no `PATH`) e um `README.md`.
- Novos roteiros da P6:
  - `teste_fluxo.gd` (15 verificações): menu → fase, game over → tentar de novo (vidas e
    chefão reiniciados), pausa → reiniciar e sair (sem ficar pausado), game over → sair,
    vitória que espera enquanto o jogo está pausado.
  - `teste_partida.gd` (4 verificações): um "robô" joga a fase só com teclas simuladas —
    anda, pula os obstáculos, chuta, entra na arena e derrota o chefão com bolas de verdade.
    Resultado: os 4 inimigos derrotados e tela de vitória em ~22 s de jogo (22 bolas,
    7 pulos), com o jogador invencível (o dano é coberto nos outros testes).
- Detalhe descoberto ao escrever o robô: na Godot 4.7 um aperto de tecla simulado durante a
  física só conta como "acabou de apertar" no quadro seguinte; o robô segura cada toque por
  dois quadros.
- Bateria completa pelo executor: 7 roteiros, 156 verificações, 0 falhas.
- Execução com janela (menu, fase, vitória, configurações) sem erros nem avisos.

### Correções

- **Menu inicial:** os botões invisíveis só tinham o estilo "normal"; ao passar o mouse
  aparecia a caixa cinza padrão da Godot e "INICIAR JOGO" parecia desativado. Agora o realce
  é um clareado leve com cantos arredondados (como na tela de vitória), com estados de
  clique e foco e cursor de mãozinha.

### Observações (não alteradas)

- Scripts sem uso em nenhuma cena: `animation_player.gd`, `cena_fase.gd` (procura nós
  `Personagem` e `TileMap` que não existem), `parallax_background.gd` e `script_hud.gd`.
  Ficaram como estavam; podem ser apagados quando o time quiser.
- O nome do projeto em `project.godot` é "As aventura de um jogador" (título da janela).
  Corrigir para "As aventuras..." muda também a pasta de dados do jogo (`user://`), o que
  faria o jogo "esquecer" as configurações já salvas; fica a critério do time.
- A tela inicial tem uma borda escura em cima e à direita que faz parte da própria imagem
  `Tela_inicial.png` (imagens oficiais não são editadas).
- Os `.import` e o `project.godot` continuam aparecendo como modificados só por fim de linha
  (LF/CRLF) e ficam fora dos commits.

## P7 — Áudio e música

Aguardando os arquivos definitivos. Já está pronto para receber: buses `Musica` e `Efeitos`
(em `default_bus_layout.tres`), volumes na tela de configurações e persistência. Nenhum som
provisório foi criado.
