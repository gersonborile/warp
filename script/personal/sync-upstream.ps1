# Brings the latest changes from the official Warp repository into this fork.
#
#   .\script\personal\sync-upstream.ps1           # bring changes in and push them
#   .\script\personal\sync-upstream.ps1 -Check    # only report what would happen
#   .\script\personal\sync-upstream.ps1 -Build    # bring changes in, then start the Windows build
#
# What it does:
# 1. Downloads the new commits from warpdotdev/warp (remote `upstream`, branch `master`).
# 2. Checks, without touching any file, whether they merge cleanly with `personal`.
#    If they don't, it stops and lists the files in conflict; nothing is changed.
# 3. Updates `master` (the untouched mirror of upstream), locally and on GitHub.
# 4. Merges upstream into `personal` with a merge commit and pushes it.
#    This needs no force push and never rewrites history.
# 5. With -Build, it starts personal_build_windows.yml on GitHub Actions.
#
# The script runs locally and not as a GitHub Action, because upstream commits often touch
# .github/workflows. The Actions token cannot push those, and the local `gh` login can.
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
$repo = 'gersonborile/warp'
$identity = @('-c', 'user.name=gersonborile', '-c', 'user.email=gersonborile@users.noreply.github.com')

function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

Set-Location (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'personal') {
    Write-Host "Estás en la rama '$branch'. Cambiá a 'personal' primero (git switch personal)." -ForegroundColor Red
    exit 1
}
if (& git status --porcelain --untracked-files=no) {
    Write-Host 'Hay cambios sin guardar (commit). Guardalos o descartalos antes de sincronizar.' -ForegroundColor Red
    & git status --short --untracked-files=no
    exit 1
}

Write-Host 'Buscando novedades en Warp oficial...'
Invoke-Git fetch -q upstream master
Invoke-Git fetch -q origin personal

if ((& git rev-parse personal) -ne (& git rev-parse origin/personal)) {
    $ahead = [int](& git rev-list --count origin/personal..personal)
    $behind = [int](& git rev-list --count personal..origin/personal)
    if ($behind -gt 0) {
        Write-Host "GitHub tiene $behind cambio(s) en 'personal' que no están acá. Traelos primero (git pull)." -ForegroundColor Red
        exit 1
    }
    Write-Host "Nota: hay $ahead cambio(s) locales en 'personal' que todavía no se subieron; se suben junto con la sincronización."
}

$newCommits = [int](& git rev-list --count personal..upstream/master)
if ($newCommits -eq 0) {
    Write-Host 'Ya estás al día: no hay cambios nuevos en Warp oficial.' -ForegroundColor Green
    exit 0
}
Write-Host "Warp oficial tiene $newCommits cambio(s) nuevo(s):"
& git log --oneline --no-decorate -n 15 personal..upstream/master
if ($newCommits -gt 15) { Write-Host "  ... y $($newCommits - 15) más" }

# Merges in memory only, to find conflicts before touching anything.
$mergeTree = & git merge-tree --write-tree --name-only --no-messages personal upstream/master
$mergeExit = $LASTEXITCODE
if ($mergeExit -eq 1) {
    Write-Host ''
    Write-Host 'Los cambios de Warp chocan con los tuyos en estos archivos (no se tocó nada):' -ForegroundColor Yellow
    $mergeTree | Select-Object -Skip 1 | ForEach-Object { Write-Host "  $_" }
    Write-Host 'Pedile a Claude que resuelva la sincronización.' -ForegroundColor Yellow
    exit 2
} elseif ($mergeExit -ne 0) {
    throw "git merge-tree failed (exit $mergeExit)"
}
Write-Host 'Se pueden sumar sin choques.' -ForegroundColor Green

if ($Check) {
    Write-Host 'Modo -Check: no se cambió nada.'
    exit 0
}

Write-Host 'Actualizando la copia de Warp oficial (master)...'
Invoke-Git branch -f master upstream/master
Invoke-Git push -q origin upstream/master:refs/heads/master

Write-Host "Sumando los cambios a 'personal'..."
Invoke-Git @identity merge -q --no-edit -m 'sync: merge upstream warpdotdev/warp master' upstream/master
Invoke-Git push -q origin personal
Write-Host 'Listo: tu versión ya tiene los cambios nuevos de Warp.' -ForegroundColor Green

if ($Build) {
    & gh workflow run personal_build_windows.yml --ref personal -R $repo
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar la compilación' }
    Write-Host "Compilación iniciada: https://github.com/$repo/actions" -ForegroundColor Green
} else {
    Write-Host 'Para generar un instalador nuevo, corré de nuevo con -Build o pedíselo a Claude.'
}
