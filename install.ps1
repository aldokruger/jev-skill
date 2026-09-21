[CmdletBinding()]
param(
    [string]$Repository = "https://github.com/aldokruger/jev-skill.git",
    [string]$Ref = "main",
    [string]$Destination = "",
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$SkillName = "jev-orchestration"

function Write-Usage {
    @"
Install the jev-orchestration skill into the OMP agent skills directory.

  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Repository https://github.com/aldokruger/jev-skill.git
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Ref v1.0.0
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Force
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun

Parameters:
  -Repository URL  GitHub repository containing jev-orchestration (default: aldokruger/jev-skill)
  -Ref REF         Branch, tag, or commit (default: main)
  -Destination DIR Skills root (default: %USERPROFILE%\.omp\agent\skills)
  -Force            Replace an existing installation
  -DryRun           Print the plan without changing files
"@
}

if ($Help) {
    Write-Usage
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $AgentDir = if ($env:OMP_AGENT_DIR) { $env:OMP_AGENT_DIR } else { Join-Path $env:USERPROFILE ".omp\agent" }
    $Destination = Join-Path $AgentDir "skills"
}
$Target = Join-Path $Destination $SkillName
$TempRoot = $null

try {
    $ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { "" }
    $LocalSource = if ($ScriptDir) { Join-Path $ScriptDir $SkillName } else { "" }
    $Source = $null

    if ($LocalSource -and (Test-Path (Join-Path $LocalSource "SKILL.md")) -and (Test-Path (Join-Path $LocalSource "scripts\jev.py"))) {
        $Source = $LocalSource
        Write-Output "origem     : $Source"
    } else {
        $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("jev-skill-" + [guid]::NewGuid().ToString("N"))
        $CloneDir = Join-Path $TempRoot "repo"
        New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

        $Git = Get-Command git -ErrorAction SilentlyContinue
        if ($Git) {
            Write-Output "clonando $Repository (ref $Ref)"
            if (-not $DryRun) {
                & $Git.Source clone --quiet --depth 1 --branch $Ref $Repository $CloneDir
                if ($LASTEXITCODE -ne 0) { throw "falha no clone de $Repository (ref $Ref)" }
            }
            $Source = Join-Path $CloneDir $SkillName
        } else {
            $RepoBase = $Repository -replace '\.git$',''
            $ArchiveUrl = "$RepoBase/archive/refs/heads/$Ref.zip"
            $Archive = Join-Path $TempRoot "repo.zip"
            Write-Output "baixando $ArchiveUrl"
            if (-not $DryRun) {
                Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUrl -OutFile $Archive
                Expand-Archive -LiteralPath $Archive -DestinationPath $TempRoot -Force
                $Extracted = Get-ChildItem -LiteralPath $TempRoot -Directory | Where-Object { $_.Name -ne "repo" } | Select-Object -First 1
                if (-not $Extracted) { throw "arquivo GitHub sem diretorio raiz" }
                $Source = Join-Path $Extracted.FullName $SkillName
            }
        }
    }

    Write-Output "skill      : $SkillName"
    Write-Output "destino    : $Target"

    if ($DryRun) {
        if (Test-Path $Target) { Write-Output "  [dry-run] $Target existe: a copia real exigiria -Force" }
        Write-Output "  [dry-run] copiar SKILL.md e scripts\jev.py"
        exit 0
    }

    if (-not (Test-Path (Join-Path $Source "SKILL.md"))) { throw "SKILL.md nao encontrado em $Source" }
    if (-not (Test-Path (Join-Path $Source "scripts\jev.py"))) { throw "scripts\jev.py nao encontrado em $Source" }
    if ((Test-Path $Target) -and (-not $Force)) { throw "$Target ja existe. Use -Force para substituir." }

    $Stage = Join-Path $Destination ("." + $SkillName + ".tmp-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage "scripts") | Out-Null
    Copy-Item -LiteralPath (Join-Path $Source "SKILL.md") -Destination (Join-Path $Stage "SKILL.md")
    Copy-Item -LiteralPath (Join-Path $Source "scripts\jev.py") -Destination (Join-Path $Stage "scripts\jev.py")
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    if (Test-Path $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
    Move-Item -LiteralPath $Stage -Destination $Target

    Write-Output "instalado  : $Target"
    Get-ChildItem -LiteralPath $Target -Recurse -File | ForEach-Object {
        Write-Output ("  {0} {1} bytes" -f $_.FullName, $_.Length)
    }

    $Python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $Python) { $Python = Get-Command py -ErrorAction SilentlyContinue }
    if ($env:TYPESAFE_API_KEY -and $Python) {
        Write-Output "verificacao : selftest Jev"
        if ($Python.Name -eq "py.exe") { & $Python.Source -3 (Join-Path $Target "scripts\jev.py") selftest } else { & $Python.Source (Join-Path $Target "scripts\jev.py") selftest }
        if ($LASTEXITCODE -ne 0) { throw "selftest Jev falhou" }
    } elseif (-not $env:TYPESAFE_API_KEY) {
        Write-Output "verificacao : TYPESAFE_API_KEY ausente; selftest nao rodado"
        Write-Output "  No OMP, rode /login typesafe e confirme em uma nova sessao."
    } else {
        Write-Output "verificacao : Python nao encontrado; instale Python 3 para rodar o selftest"
    }

    Write-Output "A skill e descoberta no start do OMP; reinicie a sessao e confirme com read skill://$SkillName"
} finally {
    if ($TempRoot -and (Test-Path $TempRoot)) { Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
