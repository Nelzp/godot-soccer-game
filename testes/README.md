# Testes automáticos

Roteiros que abrem as cenas do jogo na Godot sem janela (headless), simulam situações e
teclas e conferem o resultado. A pasta tem `.gdignore`: a Godot não importa nem exporta
nada daqui, então os testes não vão para o jogo final.

## Como rodar

No PowerShell, na pasta do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File testes\rodar_testes.ps1
```

Só alguns testes:

```powershell
powershell -ExecutionPolicy Bypass -File testes\rodar_testes.ps1 -Testes teste_chefao, teste_fluxo
```

A Godot é procurada pelo parâmetro `-Godot`, pela variável de ambiente `GODOT`, na
instalação da Steam e no `PATH`.

Um teste avulso, direto pela Godot:

```powershell
godot --headless --path . --fixed-fps 60 --script res://testes/teste_fluxo.gd -- --ignorar-configuracoes
```

`--fixed-fps 60` deixa a física igual em qualquer máquina e `--ignorar-configuracoes` faz o
jogo abrir com as configurações padrão (o arquivo salvo do jogador não é lido). O teste de
configurações grava só em `user://teste_configuracoes.cfg` e confere que o arquivo do
jogador continua igual.

## O que cada teste cobre

| Arquivo | Cobre |
|---|---|
| `teste_estrutura.gd` | As duas fases: cenário sem distorção, câmera, vida dos inimigos (Juiz 3, Goleiro 5, Zagueiro 4), variações de uniforme com as animações, portões, chefão só na Fase 2, dano da bola e do carrinho |
| `teste_portao.gd` | Portões da Fase 1: travados até vencer a quadra, aviso com a contagem, não dá para pular por cima, abertura, portão final → Fase 2 com transição |
| `teste_chefao.gd` | Chefão na Fase 2: invulnerabilidade, cartões, soco, bola, jogador em cima, troca de fase, rajada, saída bloqueada na luta, morte sem vitória automática, saída liberada, túnel → vitória → menu |
| `teste_zagueiro.gd` | Zagueiro: patrulha, aviso, carrinho, recarga, pulo por cima, 4 de vida |
| `teste_obstaculos.gd` | Inimigos sem sobreposição e no chão, obstáculos sólidos, plataformas do cenário (só o jogador pisa), visão do Juiz e patrulhas |
| `teste_fluxo.gd` | Menu, Fase 1, game over que recomeça na fase certa (1 ou 2), pausa (reiniciar/sair) nas duas fases, saída liberada respeitando a pausa |
| `teste_configuracoes.gd` | Tela de configurações: padrões, prévia de áudio, salvar/voltar, teclado, arquivo, pausa |
| `teste_partida.gd` | Um "robô" joga o jogo inteiro só com teclas (quatro quadras, portões, chefão, saída) e mede o tempo da Fase 1 |

### Sobre o tempo medido em `teste_partida.gd`

O robô é invencível e agressivo: chuta enquanto se aproxima e dá carrinho quando encosta,
sem nunca desviar. O tempo dele é um **limite inferior** — um jogador humano, que precisa
desviar de cartões, carrinhos e socos para não morrer, leva mais. O teste falha se a Fase 1
levar menos de 60 s nesse ritmo.

Cada teste termina com `N verificações, M falhas` e sai com o número de falhas como código
de saída.
