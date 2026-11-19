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
| A | Atualização "duas fases": Fase 1 ampliada (≥ 60 s), mais inimigos com mais vida e uniformes variados, mais obstáculos, portões entre quadras, Fase 2 com o chefão e saída bloqueada | concluída (ver seção própria) |
| P7 | Áudio e música — só depois que os arquivos definitivos forem entregues. Nada de sons provisórios | ver "Polimento final" |
| PF | Polimento final: Fase 1 mais curta, inimigos com 3 de vida e redistribuídos, Juiz de longe, animações de combate, áudio, organização das pastas e revisão | em andamento (ver seção própria) |

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

## Atualização — duas fases (17/11/2026)

Fluxo novo: **menu → Fase 1 (4 quadras) → portão final → Fase 2 (arena do chefão) → saída
liberada → tela de vitória.** Nenhum áudio foi adicionado (fica para a P7).

### Fase 1 ampliada

- **Cenário sem distorção:** antes a imagem era esticada 23% na horizontal
  (1,499 × 1,216). Agora `cenario_fase1.gd` (`@tool`, aparece no editor) monta a fase com
  trechos de `cenario_principal.png` em escala 1,216 nos dois eixos. Os cortes ficam em
  colunas quase idênticas da imagem (x = 415, 1017, 1235 e 1246, achadas por comparação de
  pixels) ou em eixos de espelho, então os trechos emendam sem costura. Os trechos com
  pedaços soltos de marcação (semicírculos da área) foram evitados.
- **Quatro quadras** (início, duas de meio e final), 9.625 px no total. Cada quadra tem um
  círculo central; entre duas quadras, o gol e o prédio do fundo aparecem espelhados e viram
  uma divisória natural (prédio com duas janelas e dois gols de costas).
- Chão, paredes e câmera saem da largura do cenário (script da fase, `cena_fase.gd`, que antes
  não era usado). Nuvens em escala uniforme, repetidas com cópia espelhada.
- As plataformas de mão única (caixotes e barreiras desenhados) agora ficam na **camada de
  colisão 4**: só o jogador pisa nelas; bola, cartões, inimigos e a visão do Juiz passam
  direto (antes a bola chutada do alto "batia" na quina delas).

### Inimigos

| Inimigo | Vida | Quantidade na Fase 1 |
|---|---|---|
| Juiz | 3 | 10 |
| Goleiro | 5 | 6 |
| Zagueiro rival | 4 | 7 |

- Valores definidos nas cenas (`cena_juiz.tscn`, `goleiro.tscn`, `cena_inimigo2.tscn`) e
  configuráveis por instância no Inspetor (`vida_maxima`). Bola tira 1; carrinho tira 2.
- Distribuição por quadra: 4 / 7 / 6 / 6, com combinações (Zagueiro + Juiz, Goleiro + Zagueiro,
  Juiz + Goleiro guardando o portão final) e dificuldade crescente. Nenhum nasce sobreposto a
  outro ou dentro de obstáculo (conferido por teste).
- Balanceamento: Juiz e Goleiro passaram a piscar em vermelho a cada golpe (com mais vida, o
  jogador precisa saber que o golpe contou); o Juiz enxerga até 520 px (com 300 px dava para
  acertá-lo de longe sem risco); o Goleiro foi recentralizado na cena e ganhou raio de
  patrulha (antes andava a fase inteira).

### Variações visuais

`variacao_uniforme.gdshader` troca faixas de cor (camisa, detalhes, tecidos escuros) sem
mexer na pele nem no contorno; vale para todas as animações e mantém o piscar de dano. As
paletas ficam em `variacoes_inimigos.gd` e são escolhidas no Inspetor de cada inimigo
(propriedade `variacao`). Nenhum sprite novo foi criado.

| Inimigo | Variações |
|---|---|
| Juiz | Preto (original), Azul-marinho com detalhes brancos, Vinho, Verde com detalhes brancos, Amarelo com detalhes pretos — o cartão na mão continua amarelo |
| Goleiro | Vermelho e amarelo (original), Verde e branco, Azul e amarelo, Roxo e rosa, Laranja e preto — as luvas acompanham |
| Zagueiro | Roxo e preto (original), Vermelho e preto, Verde e branco (com calção e listras brancos), Azul e preto, Branco e preto, Amarelo e preto |

Limitação: acessórios novos (bonés, faixas, penteados) exigiriam sprites novos; as variações
são de cor (inclui os detalhes amarelos do Juiz e as luvas do Goleiro).

### Obstáculos

- 11 obstáculos sólidos da folha de sprites na linha do chão, em 4 tipos (barreira de salto,
  bonecos de treino, caixa de salto, barreira listrada), em sequências diferentes em cada
  quadra e em pontos sem objeto parecido desenhado atrás.
- Plataformas de mão única geradas em cima dos caixotes e barreiras desenhados em todos os
  trechos (23 corpos).

### Portões

- Arte de `portoes.png` com tom frio (combina com o estádio azul), base na linha do chão,
  cerca de duas vezes a altura do jogador e interior escuro de túnel, embutida nas divisórias
  entre as quadras e no prédio do fim da fase (`cena_portao_fase.tscn` + `portao_fase.gd`).
- Cada portão fica **fechado até os adversários da sua quadra caírem**: bloqueia a passagem
  (não dá para pular por cima), mostra "DERROTE N ADVERSÁRIOS" com contagem regressiva e, ao
  abrir, "PASSAGEM LIBERADA!". Isso garante o tempo mínimo da fase com conteúdo jogável (sem
  isso, dava para atravessar a fase pulando por cima de todos em ~20 s).
- O portão final leva à Fase 2 com transição suave (autoload `Transicao`: escurece, troca a
  cena e clareia, 0,5 s cada lado).

### Fase 2

- `cena_fase2.tscn` com `Luta com  Boss.png` (a única imagem nova encontrada; nome com dois
  espaços) em escala 0,79315 nos dois eixos, ocupando a altura da tela (1528 × 648).
- Chão na altura da boca do túnel "SAÍDA" (y = 590 na imagem, logo abaixo da linha do
  meio-campo): jogador e chefão apoiados no mesmo gramado, e o jogador cabe no túnel. Paredes
  na arquibancada da esquerda e no fundo do túnel; câmera presa ao estádio.
- Saída bloqueada por duas barreiras listradas diante do túnel (a arte do túnel fica intacta).
- O chefão (mesma cena, IA, 12 de vida, duas fases, soco, cartões, barra, morte) existe só
  aqui e acorda quando o jogador entra na arena. Na morte: cartões no ar somem, animação de
  morte, barra some, barreiras afundam e somem, a placa "SAÍDA" passa a brilhar e aparece
  "SAÍDA LIBERADA!". **Nada carrega sozinho**: só entrar no túnel leva à tela de vitória (com
  transição). A arena antiga da Fase 1 (`cena_arena_chefao.tscn`) foi removida.

### Correções

- Chute colado no inimigo não causava dano (a bola nascia dentro do corpo dele); agora a bola
  confere isso ao sair do pé.
- "TENTAR NOVAMENTE" do game over recomeça na fase em que o jogador perdeu (antes sempre
  voltava à Fase 1).

### Testes (Godot 4.7.2, headless)

Bateria completa (`testes/rodar_testes.ps1`): 8 roteiros, **187 verificações, 0 falhas**.

| Roteiro | Verificações |
|---|---|
| `teste_estrutura.gd` (novo) | 24 |
| `teste_portao.gd` (reescrito) | 15 |
| `teste_chefao.gd` (reescrito para a Fase 2) | 37 |
| `teste_zagueiro.gd` | 21 |
| `teste_obstaculos.gd` (reescrito) | 18 |
| `teste_fluxo.gd` (reescrito) | 17 |
| `teste_configuracoes.gd` | 48 |
| `teste_partida.gd` (robô das duas fases) | 7 |

Os 13 testes obrigatórios pedidos estão cobertos: Fase 1 inicia; vidas novas; variações com
animações; dano da bola e do carrinho; obstáculos não bloqueiam (o robô atravessa tudo);
portão → Fase 2; chefão só na Fase 2; as duas fases do chefão; saída bloqueada na luta;
morte libera a saída; saída → vitória; botão → menu; morrer/reiniciar nas duas fases.
Capturas renderizadas conferidas: trechos da Fase 1, variações lado a lado, portões fechado e
aberto, Fase 2 (chegada, luta, saída bloqueada, morte, saída liberada, transição, vitória).

### Duração da Fase 1

- **64,3 s** medidos pelo robô de `teste_partida.gd`, que derrota os 23 adversários e passa
  pelos 4 portões. O robô é invencível e agressivo (chuta enquanto se aproxima, dá carrinho ao
  encostar, nunca desvia e tem reação perfeita): o tempo é um **limite inferior**. Um jogador
  humano experiente, que precisa desviar de cartões, carrinhos e socos para não morrer, leva
  mais. Não há esperas artificiais (os portões abrem na hora em que a quadra é vencida).
- O teste falha se esse tempo cair abaixo de 60 s.
- Validação manual sugerida: cronometrar uma partida do "INICIAR JOGO" até a tela escurecer no
  portão final, sem pausar e sem morrer. Pelo limite do robô, o resultado deve ficar acima de
  60 s com folga.

### Commits

| Commit | Conteúdo |
|---|---|
| `d0d4367` | Expansão e balanceamento da Fase 1 (com a arena do chefão provisória no fim) |
| `e5566e2` | Variações de uniforme |
| `d20b12b` | Criação da Fase 2 (estádio, chão, câmera, saída bloqueada) |
| `98fcba5` | Portões entre quadras, portão final e transição suave |
| `612161c` | Chefão na Fase 2 e liberação da saída |
| (este) | Testes, documentação e registro |

Cada commit intermediário carrega sem erros (o primeiro foi conferido isolado num *worktree*
temporário). Entre `98fcba5` e `612161c` a Fase 2 ainda não tinha o chefão.

### Pendências e limitações

- P7 (áudio) continua aguardando os arquivos definitivos; os volumes seguem funcionando.
- Scripts antigos ainda sem uso: `animation_player.gd`, `parallax_background.gd`,
  `script_hud.gd` (o `cena_fase.gd` voltou a ser usado como script das fases).
- O nome do projeto continua "As aventura de um jogador" (mudar altera a pasta de dados).
- Os `.import` e o `project.godot` aparecem modificados só por fim de linha e ficam fora dos
  commits.

## P7 — Áudio e música

Os arquivos definitivos chegaram junto com o pedido de polimento final; a integração está
na seção "Polimento final", etapa C.

## Polimento final (19/11/2026)

Pedido: Fase 1 mais curta (45 a 60 s para um jogador experiente), inimigos mais
espalhados e com 3 de vida, Juiz lançando de mais longe, animações de combate melhores,
áudio com os arquivos entregues, pastas organizadas em português e revisão geral. Ordem:
A (balanceamento), B (animações), C (áudio), D (organização), E (revisão). Um commit por
etapa, sem push.

### Etapa A — Balanceamento

**Fase 1 encurtada.** Saiu a quadra de meio mais curta (5 trechos): ficaram três quadras
(início, meio e final), 7.502 px em vez de 9.625 (−22%). As emendas, a escala uniforme e as
divisórias entre quadras continuam as mesmas. Câmera, chão e paredes saem da largura do
cenário; os portões foram reposicionados (x = 2.197, 4.850 e o final em 7.365).

**Inimigos redistribuídos** (17: 6 Juízes, 5 Goleiros, 6 Zagueiros — o 17º, um Zagueiro
logo depois da barreira inicial, entrou na etapa B, na calibragem da duração), em
encontros separados por trechos só de movimentação e com ordem diferente em cada quadra:

| Quadra | Encontros (da esquerda para a direita) |
|---|---|
| 1 (início) | barreira · Zagueiro · Juiz · bonecos · Zagueiro · Goleiro + Juiz guardando o portão |
| 2 (meio) | caixa · Goleiro · barreira · Juiz + Zagueiro · Juiz · bonecos · Zagueiro + Goleiro |
| 3 (final) | barreira · Zagueiro · caixa · Juiz atrás da caixa · Goleiro + Juiz · bonecos · Zagueiro + Goleiro |

- Distâncias variadas (155 a 670 px entre centros), nenhum tipo três vezes seguido, nenhum
  inimigo sobreposto, preso em obstáculo ou fora da área jogável (conferido por teste).
- Obstáculos: 8 (barreira de salto, bonecos, caixa de salto e barreira listrada), em pontos
  sem objeto parecido desenhado atrás. As variações de uniforme continuam (5 por tipo em uso).
- Posições fixas na cena (sem sorteio): o jogo e os testes são reproduzíveis.

**Vida padronizada em 3** para Juiz, Goleiro e Zagueiro (`vida_maxima` nas cenas, editável
por instância no Inspetor); o chefão continua com 12. Dano, piscar, morte única e o
"morto não ataca" continuam de `inimigo_base.gd`.

**Juiz** (`script_inimigo1.gd`, parâmetros no Inspetor, grupo "Cartões"):

| Parâmetro | Antes | Agora |
|---|---|---|
| `alcance_visao` | 520 px (300 no script) | 640 px |
| Ritmo | animação em laço de 1,2 s | aviso 0,45 s + lançamento + `intervalo_ataque` 0,9 s (ciclo de 1,85 s) |
| Mira | sempre reto | no peito do jogador apoiado (até 25° para cima/baixo); no ar, reto |
| `velocidade_cartao` | 700 px/s | 650 px/s |
| `alcance_cartao` | sem limite (4 s de vida) | 1.000 px e o cartão apaga |
| Visão | raio na altura do corpo | linha da mão até o peito do jogador; parede, portão fechado e obstáculo alto tapam |

- Só começa a lançar com o jogador apoiado e com o Juiz **visível na tela** (o cartão nunca
  vem de fora da tela). Para o alcance maior caber na tela, a câmera do jogador se adianta
  100 px para o lado em que ele anda (suave; virar parado para chutar não balança a câmera).
- Colado nele (menos de 110 px) não lança: o cartão nasceria dentro do jogador, sem chance
  de desvio. O cartão já erguido também não sai à queima-roupa.
- Dá para desviar pulando (o cartão passa por baixo) ou escondendo atrás dos bonecos.

**Correção encontrada no caminho:** cair por cima de um Zagueiro que ainda deslizava contava
como golpe do carrinho dele; agora só vale o encontro de frente.

**Duração (nesta etapa):** o robô agressivo e invencível (limite inferior) faz a Fase 1 em
33,6 s. A estimativa para um jogador experiente usa um robô "cuidadoso" (desvia, mantém
distância do Goleiro) e foi calibrada depois das animações novas (etapa B), porque o tempo
do chute muda o ritmo de combate.

### Etapa B — Animações de combate

Nenhum quadro novo foi desenhado: tudo usa as folhas existentes, com ordem, tempo,
alinhamento, deslocamento e sincronização ajustados.

**Alinhamento dos quadros (todos os personagens).** Os quadros das folhas têm tamanhos
diferentes e eram desenhados centralizados, então os pés subiam e desciam até 30 px e o
corpo deslizava de um quadro para outro. Agora cada quadro é ancorado (tronco/cabeça no
centro do corpo e pés na linha do chão) por um deslocamento por quadro, medido por script
nas folhas. O desenho fica num nó `Visual` com a origem nos pés, que vira pela escala
(`flip_h` não espelha o deslocamento). Conferido em folhas de contato renderizadas e por
teste (variação dos pés ≤ 5,5 px no jogador).

**Jogador** (`script_personagem.gd`, `cena_jogador.tscn`):

- Proporção: o desenho era esticado 24% na vertical (escala 0,42 × 0,52). Agora a escala
  é 0,5 nos dois eixos: mesma altura (106 px), largura do desenho original.
- Estados claros: livre, chutando, deslizando, levantando e morto.
- Chute: apoio (preparação) → contato com a faísca → acompanhamento → perna no alto →
  volta (0,52 s). A bola sai **no quadro do contato** (0,11 s; antes só saía no fim, aos
  0,6 s), do pé, para o lado do chute. Durante o chute anda a 35% e não vira.
- Carrinho: entrada → desliza → desliza baixo → levanta (0,6 s). Desliza ~150 px perdendo
  velocidade (antes ficava parado no lugar), com o corpo baixo (56 de 105 px: os cartões
  passam por cima). Acerta só enquanto desliza, no máximo um inimigo; para ao bater em
  parede ou obstáculo; levanta parado.
- Pulo: o quadro acompanha a velocidade vertical (subida, topo, descida); ao cair, agacha
  um instante. Corrida mais rápida (0,43 s por ciclo, antes 1 s: os pés "patinavam").
- Dano: 1 s de invulnerabilidade com pisca (começa num vermelho rápido) e recuo pequeno
  para longe de quem bateu; não interrompe chute nem carrinho.
- Morte: na última vida o jogador para, dá um pulinho, tomba para trás e apaga; o game
  over abre com transição (antes a cena trocava na hora).

**Inimigos:**

| Inimigo | Mudanças |
|---|---|
| Juiz | Lançamento ancorado nos pés (o corpo inclina, os pés ficam plantados); mão do cartão no quadro de soltar; respira parado e, sozinho, confere o relógio de vez em quando (quadros "checando o relógio" da folha) |
| Goleiro | Soco: guarda agachado → guarda (aviso, 0,36 s, ainda vira para o jogador) → soco com rastro e passo à frente → impacto (o golpe conta aqui) → volta. Começa quando o jogador chega perto e à frente (antes só ao encostar). Caixa de colisão do tamanho do corpo: 104 × 140 (era 179 × 145, mais larga que o desenho) e escala uniforme 1,1 (era 1,21 × 1,09) |
| Zagueiro | Aviso do carrinho: pose de arrancada e o corpo pulsa em laranja; carrinho com arrancada, queda no deslize e quatro quadros deslizando; corpo baixo (60 de 89 px) enquanto desliza; quadro de levantar no fim. A corrida tinha um quadro "parado" no meio do ciclo (dava um tranco); corrigido |
| Todos | Golpe que não mata: pisca em vermelho e dá um tranco curto para trás. Morte: clarão, recuo com pulinho para longe do jogador, tomba e apaga (antes só piscava e sumia). Morto não ataca (a animação para no quadro em que estava) |

**Limitações dos sprites:** não há quadros de dano nem de morte para nenhum personagem, nem
de preparação do chute (perna para trás); esses momentos usam movimento, cor e rotação do
desenho existente. O Goleiro tem quadros de "ataque de garras" que não foram usados (não
fazem parte do pedido).

**Duração da Fase 1 (calibrada aqui).** `teste_partida.gd` tem dois robôs que jogam só
com teclas simuladas:

| Robô | Como joga | Fase 1 |
|---|---|---|
| Cuidadoso (estimativa do jogador experiente) | pula cartões e carrinhos, não encosta no Goleiro, só dá carrinho no Zagueiro parado; conta os golpes | 37,2 s (levou 1 golpe) |
| Agressivo (limite inferior) | invencível, nunca desvia | 32,5 s |

Os dois reagem instantaneamente e conhecem a fase. Um jogador experiente reage a cada
ameaça uns 0,2 s depois e erra alguns pulos; nas ~40 ameaças da fase isso soma de 20% a 40%
ao tempo do robô cuidadoso: **estimativa de 45 a 52 s** para um jogador experiente, dentro
da faixa pedida (45 a 60 s). O teste exige o robô cuidadoso entre 35 e 50 s (equivalente à
faixa) e o agressivo acima de 28 s. Sem esperas artificiais.

**Correções:** o cartão nascia dentro do jogador quando o Juiz lançava colado nele (agora
não lança à queima-roupa); quem caía por cima do Zagueiro deslizando levava o golpe; o
game over cortava a cena sem mostrar a morte.

### Etapa C — Áudio

Arquivos entregues (movidos para `recursos/sons/`, conteúdo idêntico conferido por hash;
os `.mpeg` eram MP3 por dentro e a Godot não importa essa extensão):

| Arquivo original | Novo nome | Formato | Duração | Uso |
|---|---|---|---|---|
| Musica Menu.mp3.mpeg | musica_menu.mp3 | MP3 48 kHz estéreo | 21,2 s | música do menu (laço) |
| som primeira fase.mp3.mpeg | musica_fase_1.mp3 | MP3 48 kHz estéreo | 17,5 s | música da Fase 1 (laço) |
| Musica Segunda Fase.mpeg | musica_fase_2.mp3 | MP3 44,1 kHz estéreo | 21,5 s | música da Fase 2 (laço) |
| Musica vitoria.mpeg | musica_vitoria.mp3 | MP3 48 kHz estéreo | 16,2 s | música da vitória (laço) |
| Som chute da bola.mp3.mpeg | som_chute.mp3 | MP3 24 kHz | 0,79 s | chute, no quadro do contato |
| som pulo.mp3.mpeg | som_pulo.mp3 | MP3 44,1 kHz | 1,24 s | pulo |
| Som Dano.mp3.mpeg | som_dano.mp3 | MP3 48 kHz | 0,33 s | jogador leva dano |
| Som Game Over.wav | som_game_over.wav | WAV 22 kHz mono | 5,34 s | queda do jogador e tela de game over |

- Autoload `Audio` (`scripts/sistemas/audio.gd`): músicas no bus Musica (uma de cada vez,
  troca suave, a mesma faixa não recomeça ao reiniciar a fase, mais baixa na pausa);
  efeitos no bus Efeitos (máx. 2 vozes por efeito, o mesmo som não dobra no mesmo
  instante). Cada fase escolhe a música no Inspetor (`musica`).
- Volumes medidos no jogo e equilibrados por arquivo (a música da Fase 1 estava ~8 dB mais
  baixa, a da Fase 2 passava de 0 dBFS, o game over tinha pico de −19 dBFS). Conferido com
  o driver real (Master mudo): as quatro músicas ficam entre −16 e −19 dBFS no bus.
- Os MP3 têm 50–90 ms de silêncio no começo; os efeitos começam depois dele. O som do chute
  chega ao bus ~33 ms depois do quadro da bola (já com a latência do driver).
- Sem arquivo, ficam em silêncio (pendentes): carrinho, bola batendo, cartão do Juiz, soco
  do Goleiro, carrinho do Zagueiro, ataques/dano/morte do chefão, portões, transição,
  saída liberada e botões dos menus. "Som Dano" não foi reaproveitado para o chefão nem
  para os inimigos (seria associar por associar).
- Teste novo `teste_audio.gd` (25 verificações). Nos testes headless o driver é "Dummy" e o
  `Audio` só registra o que tocaria (o Dummy não mistura o som e nada terminaria).

### Etapa D — Organização das pastas

Estrutura simples, em português, com as pastas pedidas; `scripts/` repete as pastas de
`cenas/` (o script de `cenas/x/y.tscn` fica em `scripts/x/y.gd`) e ganhou `menus/` e
`objetos/`, porque a referência pedida não tinha lugar para os scripts das telas e dos
objetos. As imagens ficaram em quatro subpastas (personagens, cenarios, objetos,
interface), todas com vários arquivos.

Como foi feito: um script move cada arquivo com `git mv` junto com o `.import` e o `.uid`
(que guardam os identificadores), troca todas as referências `"res://..."` (cenas,
scripts, autoloads, testes) e a Godot reimporta tudo. Os uids não mudaram: as cenas
continuam achando os recursos pelo uid e pelo caminho. Conferido pelo teste novo
`teste_referencias.gd` (19 cenas instanciam, 27 scripts/shaders carregam, 177 caminhos
citados existem, 54 uids batem com o caminho) e pela bateria inteira.

| Antes | Agora |
|---|---|
| `cena_inicio.tscn`, `cena_configuracoes.tscn`, `cena_pausa.tscn`, `cena_hud.tscn`, `cena_game_over.tscn`, `cena_vitoria.tscn` | `cenas/menus/menu_inicial.tscn`, `configuracoes.tscn`, `pausa.tscn`, `hud.tscn`, `game_over.tscn`, `vitoria.tscn` |
| `cena_fase.tscn`, `cena_fase2.tscn`, `cena_nuvem.tscn` | `cenas/fases/fase_1.tscn`, `fase_2.tscn`, `nuvens.tscn` |
| `cena_jogador.tscn`, `cena_juiz.tscn`, `goleiro.tscn`, `cena_inimigo2.tscn`, `cena_chefao.tscn` | `cenas/personagens/jogador.tscn`, `juiz.tscn`, `goleiro.tscn`, `zagueiro.tscn`, `chefao.tscn` |
| `cena_bola.tscn`, `cena_cartao.tscn`, `cena_cartao_vermelho.tscn`, `cena_obstaculo.tscn`, `cena_portao_fase.tscn` | `cenas/objetos/bola.tscn`, `cartao_amarelo.tscn`, `cartao_vermelho.tscn`, `obstaculo.tscn`, `portao.tscn` |
| `script_inicio.gd`, `configuracoes_tela.gd`, `barra_volume.gd`, `cena_pausa.gd`, `hud.gd`, `script_game_over.gd`, `script_vitoria.gd` | `scripts/menus/menu_inicial.gd`, `tela_configuracoes.gd`, `barra_volume.gd`, `pausa.gd`, `hud.gd`, `game_over.gd`, `vitoria.gd` |
| `cena_fase.gd`, `cenario_fase1.gd`, `arena_chefao.gd`, `script_nuvem.gd` | `scripts/fases/fase.gd`, `cenario_fase_1.gd`, `arena_chefao.gd`, `nuvens.gd` |
| `script_personagem.gd`, `inimigo_base.gd`, `script_inimigo1.gd`, `script_goleiro.gd`, `personagem.gd`, `script_chefão.gd`, `barra_chefao.gd`, `variacoes_inimigos.gd`, `variacao_uniforme.gdshader` | `scripts/personagens/jogador.gd`, `inimigo_base.gd`, `juiz.gd`, `goleiro.gd`, `zagueiro.gd`, `chefao.gd`, `barra_vida_chefao.gd`, `variacoes_inimigos.gd`, `variacao_uniforme.gdshader` |
| `script_bola.gd`, `script_cartao.gd`, `obstaculo.gd`, `portao_fase.gd` | `scripts/objetos/bola.gd`, `cartao.gd`, `obstaculo.gd`, `portao.gd` |
| `configuracoes.gd`, `transicao.gd` | `scripts/sistemas/configuracoes.gd`, `transicao.gd` (com `audio.gd`) |
| `jogador-Photoroom.png`, `Juiz.png`, `inimigo_goleiro.png`, `inimigo_1.png`, `chefao.png` | `recursos/imagens/personagens/jogador.png`, `juiz.png`, `goleiro.png`, `zagueiro.png`, `chefao.png` |
| `cenario_principal.png`, `cenario_principal.jfif`, `Luta com  Boss.png`, `nuvem.png` | `recursos/imagens/cenarios/estadio_fase_1.png`, `estadio_fase_1_original.jfif`, `estadio_fase_2.png`, `nuvens.png` |
| `Bola.png`, `Cartao.png`, `portoes.png`, `obstáculos/Sprites 2D de Obstáculos para Futebol-Photoroom.png` | `recursos/imagens/objetos/bola.png`, `cartao.png`, `portoes.png`, `obstaculos.png` |
| `Tela_inicial.png`, `Configurações Neon de Futebol Pixel.png`, `game_over.png`, `Tela de vitoria.jpeg`, `avatar.png`, `coracao.png`, `assets/placa_pausa.png`, `assets/icone_*.png` | `recursos/imagens/interface/tela_inicial.png`, `tela_configuracoes.png`, `tela_game_over.png`, `tela_vitoria.jpeg`, `avatar_jogador.png`, `coracao.png`, `placa_pausa.png`, `icone_*.png` |
| `assets/font/PixelifySans-*.ttf` | `recursos/fontes/pixelify_sans_*.ttf` |
| `claude/registro-finalizacao.md` | `documentos/registro_finalizacao.md` (este arquivo) |

Ficaram na raiz: `project.godot`, `icon.svg` e `default_bus_layout.tres` (onde a Godot
procura o layout de áudio), mais um `README.md` novo com controles e estrutura. Os nós
raiz das telas também ganharam nomes claros (`MenuInicial`, `GameOver`, `Vitoria`).

**Arquivos sem uso:**

- Removidos (commit próprio): `animation_player.gd`, `parallax_background.gd` e
  `script_hud.gd` (com os `.uid`), sem referência em nenhuma cena, script ou configuração.
- Mantidos: `estadio_fase_1_original.jfif` (antigo `cenario_principal.jfif`) não é usado,
  mas é outra versão da imagem (1778 × 592, contra 1600 × 533 do PNG), provavelmente o
  original, então não é seguro dizer que está obsoleto. As fontes Pixelify Sans Regular e
  SemiBold também não são usadas, mas fazem parte da mesma família das que são.

**Nome do projeto:** o título agora é "As aventuras de um jogador". Para as configurações
salvas continuarem valendo, a pasta de dados foi fixada no caminho antigo
(`config/custom_user_dir_name = "Godot/app_userdata/As aventura de um jogador"`);
conferido que `user://` continua o mesmo e o arquivo salvo é encontrado.

### Situação

Etapas A, B, C e D concluídas. Falta a E (revisão final e relatório).
