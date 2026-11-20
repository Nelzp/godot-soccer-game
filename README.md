# As aventuras de um jogador

Jogo de plataforma 2D em pixel art feito na Godot 4.7 (renderizador Compatibility): o
jogador atravessa o estádio da Fase 1 derrotando Juízes, Goleiros e Zagueiros, enfrenta o
chefão "Cartão Vermelho" na Fase 2 e sai pelo túnel para a vitória.

## Controles

| Ação | Teclas |
|---|---|
| Andar | ← → ou A D |
| Pular | ↑ ou W |
| Chutar | C |
| Carrinho | Espaço |
| Pausa | Esc |

## Estrutura

```text
res://
├── project.godot, icon.svg, default_bus_layout.tres
├── cenas/
│   ├── menus/        menu inicial, configurações, pausa, HUD, game over, vitória
│   ├── fases/        fase_1, fase_2 e as nuvens
│   ├── personagens/  jogador, juiz, goleiro, zagueiro, chefão
│   └── objetos/      bola, cartões, obstáculo, portão
├── scripts/          mesmas pastas das cenas (o script de cenas/x/y.tscn é scripts/x/y.gd)
│   └── sistemas/     autoloads: configurações, transição entre cenas e áudio
├── recursos/
│   ├── imagens/      personagens, cenarios, objetos, interface
│   ├── sons/         músicas (musica_*) e efeitos (som_*)
│   └── fontes/       Pixelify Sans
├── testes/           testes automáticos (ver testes/README.md)
└── documentos/       registro das decisões e do andamento
```

`default_bus_layout.tres` (buses Master, Musica e Efeitos) fica na raiz porque é onde a
Godot procura o layout de áudio.
