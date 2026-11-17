<#
.SYNOPSIS
    Roda os testes automáticos do jogo (Godot em modo headless).

.DESCRIPTION
    Cada arquivo testes/teste_*.gd é um roteiro que abre as cenas do jogo,
    simula situações (e teclas) e confere o resultado. A pasta tem .gdignore,
    então a Godot não importa nem exporta estes arquivos.

    O executável da Godot é procurado, nesta ordem: parâmetro -Godot,
    variável de ambiente GODOT, instalação da Steam e "godot" no PATH.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File testes\rodar_testes.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File testes\rodar_testes.ps1 -Testes teste_chefao, teste_fluxo
#>
param(
    [string]$Godot = $env:GODOT,
    [string[]]$Testes = @(),
    [int]$LimiteSegundos = 300
)

$projeto = Split-Path -Parent $PSScriptRoot

if (-not $Godot) {
    $steam = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    if (Test-Path -LiteralPath $steam) {
        $Godot = $steam
    } else {
        $comando = Get-Command godot -ErrorAction SilentlyContinue
        if ($comando) { $Godot = $comando.Source }
    }
}

if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    Write-Host "Godot não encontrada. Use -Godot <caminho do executável> ou a variável GODOT." -ForegroundColor Red
    exit 1
}

$arquivos = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "teste_*.gd" | Sort-Object Name
if ($Testes.Count -gt 0) {
    $arquivos = $arquivos | Where-Object { $Testes -contains $_.BaseName -or $Testes -contains $_.Name }
}

$temporaria = Join-Path ([System.IO.Path]::GetTempPath()) "testes-godot-soccer"
New-Item -ItemType Directory -Force $temporaria | Out-Null

$totalFalhas = 0
$resumo = @()

foreach ($arquivo in $arquivos) {

    Write-Host "== $($arquivo.Name)" -ForegroundColor Cyan

    $saida = Join-Path $temporaria "$($arquivo.BaseName).out.txt"
    $erros = Join-Path $temporaria "$($arquivo.BaseName).err.txt"

    $argumentos = @(
        '--headless', '--path', "`"$projeto`"", '--fixed-fps', '60', '--quit-after', '20000',
        '--script', "res://testes/$($arquivo.Name)", '--', '--ignorar-configuracoes'
    )

    $processo = Start-Process -FilePath $Godot -ArgumentList $argumentos -RedirectStandardOutput $saida `
        -RedirectStandardError $erros -NoNewWindow -PassThru
    $null = $processo.Handle

    if (-not $processo.WaitForExit($LimiteSegundos * 1000)) {
        $processo.Kill()
        Write-Host "   tempo esgotado" -ForegroundColor Red
        $totalFalhas += 1
        $resumo += "{0,-26} TEMPO ESGOTADO" -f $arquivo.Name
        continue
    }

    $linhas = [System.IO.File]::ReadAllLines($saida, [System.Text.Encoding]::UTF8)
    $linhas | Where-Object { $_ -match '^\s+(ok|FALHA)|^--|verificações' } | ForEach-Object {
        if ($_ -match 'FALHA') { Write-Host $_ -ForegroundColor Red } else { Write-Host $_ }
    }

    $textoErros = [System.IO.File]::ReadAllLines($erros, [System.Text.Encoding]::UTF8)
    if ($textoErros.Count -gt 0) {
        Write-Host "   saída de erro:" -ForegroundColor Yellow
        $textoErros | Select-Object -First 20 | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
    }

    $falhas = $processo.ExitCode
    if ($textoErros -match 'SCRIPT ERROR' -and $falhas -eq 0) { $falhas = 1 }
    $totalFalhas += $falhas

    $final = ($linhas | Where-Object { $_ -match 'verificações' } | Select-Object -Last 1)
    $resumo += "{0,-26} {1}" -f $arquivo.Name, $(if ($final) { $final.Trim() } else { "sem resultado (código $falhas)" })
}

Write-Host ""
Write-Host "Resumo" -ForegroundColor Cyan
$resumo | ForEach-Object { Write-Host "  $_" }

if ($totalFalhas -eq 0) {
    Write-Host "Tudo certo." -ForegroundColor Green
} else {
    Write-Host "$totalFalhas falha(s)." -ForegroundColor Red
}

exit $totalFalhas
