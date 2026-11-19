# Testes automáticos

Roteiros que abrem as cenas do jogo na Godot sem janela (headless), simulam situações e
teclas e conferem o resultado. A pasta tem `.gdignore`: a Godot não importa nem exporta
nada daqui, então os testes não vão para o jogo final.

## Como rodar

No PowerShell, na pasta do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File testes\rodar_testes.ps1
```

Só alguns testes (rodando o script direto, para a lista funcionar):

```powershell
& .\testes\rodar_testes.ps1 -Testes teste_chefao, teste_fluxo
```

A Godot é procurada pelo parâmetro `-Godot`, pela variável de ambiente `GODOT`, na
instalação da Steam e no `PATH`.

Um teste avulso, direto pela Godot:

```powershell
godot --headless --path . --fixed-fps 60 --script res://testes/teste_fluxo.gd -- --ignorar-configuracoes
```

`--fixed-fps 60` deixa a física igual em qualquer máquina e `--ignorar-configuracoes` faz o
jogo abrir com as configurações padrão (o arquivo salvo do jogador não é lido). Os testes
que mexem em configurações gravam só em arquivos próprios de teste e conferem que o
arquivo do jogador continua igual.

No modo headless o driver de áudio é "Dummy" (não mistura som): o autoload `Audio` só
registra o que tocaria, e é isso que `teste_audio.gd` confere.

## O que cada teste cobre

| Arquivo | Cobre |
|---|---|
| `teste_estrutura.gd` | Fase 1 encurtada (20–25%) e sem distorção, câmera, vida 3 dos inimigos comuns, variações de uniforme com as animações, distribuição misturada dos adversários, portões, chefão só na Fase 2, dano da bola e do carrinho |
| `teste_juiz.gd` | Juiz: alcance (600–700 px), cartão que alcança e acerta, intervalo entre lançamentos, mira para cima, obstáculo alto e portão fechado tapando a visão, só lança na tela, desvio pulando, alcance do cartão, morte no meio do lançamento |
| `teste_jogador.gd` | Jogador: quadros alinhados e sem distorção, chute (bola no quadro do contato, direção travada), carrinho (desliza, corpo baixo, acerta só deslizando), dano (invulnerabilidade, pisca, não interrompe o ataque), transições (pulo, aterrissagem, corrida), morte e game over |
| `teste_inimigos.gd` | Animações e golpes do Juiz (aviso, cartão na mão no quadro certo, relógio), do Goleiro (soco por aproximação, aviso, passo à frente, golpe no impacto, dá para escapar) e do Zagueiro (aviso, corpo baixo, levantar); tranco ao levar golpe; morte que cai e some sem atacar depois |
| `teste_zagueiro.gd` | Zagueiro: patrulha, aviso, carrinho, recarga, pulo por cima, 3 de vida |
| `teste_obstaculos.gd` | Inimigos sem sobreposição, no chão e dentro da fase; obstáculos sólidos; plataformas do cenário (só o jogador pisa); visão do Juiz e patrulhas |
| `teste_portao.gd` | Portões da Fase 1: travados até vencer a quadra, aviso com a contagem, não dá para pular por cima, abertura, portão final → Fase 2 com transição |
| `teste_chefao.gd` | Chefão na Fase 2: invulnerabilidade, cartões, soco, bola, jogador em cima, troca de fase, rajada, saída bloqueada na luta, morte sem vitória automática, saída liberada, túnel → vitória → menu |
| `teste_fluxo.gd` | Menu, Fase 1, queda e game over que recomeça na fase certa (1 ou 2), pausa (reiniciar/sair) nas duas fases, saída liberada respeitando a pausa |
| `teste_configuracoes.gd` | Tela de configurações: padrões, prévia de áudio, salvar/voltar, teclado, arquivo, pausa |
| `teste_audio.gd` | Música de cada tela (uma de cada vez, sem recomeçar à toa, mais baixa na pausa), efeitos no quadro certo e sem duplicar, game over, buses e volumes |
| `teste_referencias.gd` | Organização: pastas, nomes em snake_case, nada solto na raiz, toda cena/script carrega, todo caminho `res://` existe, uids batem, autoloads, cena inicial, título e pasta de dados |
| `teste_partida.gd` | Dois "robôs" jogam só com teclas e medem a duração da Fase 1 (ver abaixo); o cuidadoso segue até a vitória |

### Sobre a duração medida em `teste_partida.gd`

- **Robô cuidadoso** (estimativa do jogador experiente): pula cartões e carrinhos, não
  encosta no Goleiro e só dá carrinho no Zagueiro parado. Não é invencível: os golpes que
  leva são contados (precisa terminar com menos de 5, ou seja, sem morrer).
- **Robô agressivo** (limite inferior): invencível, nunca desvia.

Os dois reagem instantaneamente e conhecem a fase. Um jogador experiente reage a cada
ameaça uns 0,2 s depois e erra alguns pulos, o que soma de 20% a 40% ao tempo do robô
cuidadoso. A faixa pedida (45 a 60 s de jogo ativo) corresponde a 35–50 s do robô
cuidadoso, que é o que o teste exige; o agressivo precisa levar pelo menos 28 s.

Cada teste termina com `N verificações, M falhas` e sai com o número de falhas como código
de saída.
