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
| `teste_chefao.gd` | Chefão: invulnerabilidade, portão, cartões, soco, bola, jogador em cima, troca de fase, rajada, morte e vitória |
| `teste_portao.gd` | Portão da arena com teclas: Goleiro não entra, jogador entra andando e não volta |
| `teste_configuracoes.gd` | Tela de configurações: padrões, prévia de áudio, salvar/voltar, teclado, arquivo, pausa |
| `teste_zagueiro.gd` | Zagueiro: patrulha, aviso, carrinho, recarga, pulo por cima, vida |
| `teste_obstaculos.gd` | Obstáculos sólidos e plataformas do cenário, bola, visão do Juiz e patrulhas |
| `teste_fluxo.gd` | Menu, fase, game over, tentar de novo, pausa (reiniciar/sair) e vitória com pausa |
| `teste_partida.gd` | Um "robô" joga a fase inteira só com teclas, derrota todos e chega à vitória |

Cada teste termina com `N verificações, M falhas` e sai com o número de falhas como código
de saída.
