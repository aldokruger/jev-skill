[CmdletBinding()]
param(
    [string]$Repository = "https://github.com/aldokruger/jev-skill.git",
    [string]$Ref = "main",
    [string]$Agent = "",
    [switch]$All,
    [switch]$ListAgents,
    [switch]$Interactive,
    [ValidateSet("global", "project")][string]$Scope = "global",
    [string]$Project = (Get-Location).Path,
    [ValidateSet("copy", "symlink")][string]$Mode = "copy",
    [string]$Destination = "",
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$SkillName = "jev-orchestration"
$Supported = @("omp", "claude", "codex", "gemini", "opencode", "agents")

function Write-Usage {
@"
Install jev-orchestration for one or more agent providers.

  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Agent omp,claude
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -All
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Scope project -Project .
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Mode symlink

Parameters:
  -Agent LIST       comma-separated: omp,claude,codex,gemini,opencode,agents
  -All              select every supported agent
  -ListAgents       show detected agents and target roots
  -Interactive      prompt for selection
  -Scope SCOPE      global (default) or project
  -Project DIR      project root for project scope
  -Mode MODE        copy (default) or symlink (local checkout only)
  -Destination DIR override the generated skills root
  -Repository URL   repository to fetch when no local checkout exists
  -Ref REF          branch, tag, or commit
  -Force             replace existing installations
  -DryRun            preview changes
"@
}
if ($Help) { Write-Usage; exit 0 }

function Get-AgentRoot([string]$Name) {
    if ($Scope -eq "global") {
        switch ($Name) {
            "omp" { if ($env:OMP_AGENT_DIR) { return Join-Path $env:OMP_AGENT_DIR "skills" }; return Join-Path $env:USERPROFILE ".omp\agent\skills" }
            "claude" { return Join-Path $env:USERPROFILE ".claude\skills" }
            "codex" { return Join-Path $env:USERPROFILE ".codex\skills" }
            "gemini" { return Join-Path $env:USERPROFILE ".gemini\skills" }
            "opencode" { return Join-Path $env:USERPROFILE ".config\opencode\skills" }
            "agents" { return Join-Path $env:USERPROFILE ".agents\skills" }
        }
    } else {
        switch ($Name) {
            "omp" { return Join-Path $Project ".omp\skills" }
            "claude" { return Join-Path $Project ".claude\skills" }
            "codex" { return Join-Path $Project ".codex\skills" }
            "gemini" { return Join-Path $Project ".gemini\skills" }
            "opencode" { return Join-Path $Project ".config\opencode\skills" }
            "agents" { return Join-Path $Project ".agents\skills" }
        }
    }
}
function Show-Agents {
    foreach ($Name in $Supported) {
        $Root = Get-AgentRoot $Name
        $State = if (Test-Path $Root) { "detectado" } else { "nao detectado (sera criado)" }
        Write-Output ("{0,-12} {1} [{2}]" -f $Name, $Root, $State)
    }
}
if ($ListAgents) { Show-Agents; exit 0 }
if ($Scope -eq "project" -and -not (Test-Path $Project)) { throw "projeto inexistente: $Project" }

$Selected = @()
if ($All) { $Selected = $Supported }
elseif ($Agent) { $Selected = $Agent.Split(',') | ForEach-Object { $_.Trim() } }
elseif ($Interactive) {
    Show-Agents
    $Answer = Read-Host "Escolha agentes separados por virgula [omp]"
    $Selected = if ($Answer) { $Answer.Split(',') | ForEach-Object { $_.Trim() } } else { @("omp") }
} else { $Selected = @("omp") }
foreach ($Name in $Selected) { if ($Supported -notcontains $Name) { throw "agente desconhecido: $Name" } }
if ($Mode -eq "symlink" -and -not $MyInvocation.MyCommand.Path) { throw "-Mode symlink exige checkout local" }

if ($Destination) { $Roots = @($Destination) } else { $Roots = @($Selected | ForEach-Object { Get-AgentRoot $_ }) }
$TempRoot = $null
try {
    $ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { "" }
    $LocalSource = if ($ScriptDir) { Join-Path $ScriptDir $SkillName } else { "" }
    if (Test-Path (Join-Path $LocalSource "SKILL.md")) { $Source = $LocalSource }
    else {
        $TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("jev-skill-" + [guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Force $TempRoot | Out-Null
        $Git = Get-Command git -ErrorAction SilentlyContinue
        if ($Git) {
            Write-Output "clonando $Repository (ref $Ref)"
            if (-not $DryRun) { & $Git.Source clone --quiet --depth 1 --branch $Ref $Repository (Join-Path $TempRoot "repo"); if ($LASTEXITCODE -ne 0) { throw "falha no clone" } }
            $Source = Join-Path $TempRoot "repo\$SkillName"
        } else {
            $Archive = Join-Path $TempRoot "repo.zip"; $Url = ($Repository -replace '\.git$','') + "/archive/refs/heads/$Ref.zip"
            Write-Output "baixando $Url"
            if (-not $DryRun) { Invoke-WebRequest -UseBasicParsing $Url -OutFile $Archive; Expand-Archive $Archive $TempRoot -Force; $Root = Get-ChildItem $TempRoot -Directory | Where-Object Name -ne repo | Select-Object -First 1; $Source = Join-Path $Root.FullName $SkillName }
        }
    }
    foreach ($Root in $Roots) {
        $Target = Join-Path $Root $SkillName
        Write-Output "destino: $Target (mode=$Mode, scope=$Scope)"
        if ($DryRun) { Write-Output "  [dry-run] instalar"; continue }
        if ((Test-Path $Target) -and -not $Force) { throw "$Target ja existe. Use -Force." }
        if (-not (Test-Path (Join-Path $Source "SKILL.md"))) { throw "SKILL.md nao encontrado em $Source" }
        New-Item -ItemType Directory -Force $Root | Out-Null
        if ($Mode -eq "symlink") { if (-not $ScriptDir) { throw "symlink exige checkout local" }; if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }; New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null }
        else { $Stage = Join-Path $Root ("." + $SkillName + ".tmp-" + [guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Force (Join-Path $Stage "scripts") | Out-Null; Copy-Item (Join-Path $Source "SKILL.md") (Join-Path $Stage "SKILL.md"); Copy-Item (Join-Path $Source "scripts\jev.py") (Join-Path $Stage "scripts\jev.py"); if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }; Move-Item $Stage $Target }
        Write-Output "instalado: $Target"
    }
    if ($DryRun) { Write-Output "dry-run: nada foi alterado"; exit 0 }
    Write-Output "TYPESAFE_API_KEY ausente ou selftest omitido; rode /login typesafe no OMP."
    Write-Output "Reinicie o OMP e confirme com read skill://$SkillName"
} finally { if ($TempRoot -and (Test-Path $TempRoot)) { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue } }
