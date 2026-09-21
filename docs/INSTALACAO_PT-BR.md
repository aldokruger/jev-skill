# Jev Orchestration no OMP — instalação e uso

Guia completo para instalar, selecionar agentes, escolher o escopo e usar a skill
`jev-orchestration` com o [Oh My Pi (OMP)](https://github.com/aldokruger/jev-skill).

## 1. Pré-requisitos

### OMP

A skill é descoberta pelo OMP em uma nova sessão. O instalador não precisa alterar o
código do OMP.

### Python 3

Necessário para executar `scripts/jev.py` e o selftest:

```bash
python3 --version
```

No Windows:

```powershell
python --version
# ou
py -3 --version
```

### Credencial Jev

O cliente usa `TYPESAFE_API_KEY`. Para os julgamentos internos do OMP, a opção
recomendada é armazenar a credencial pelo próprio OMP:

```text
omp
/login typesafe
```

O instalador nunca solicita, grava ou imprime a chave.

Para executar `jev.py` fora do OMP, a variável também precisa estar disponível no
ambiente do processo:

Linux/macOS/WSL:

```bash
export TYPESAFE_API_KEY="sua-chave"
```

PowerShell:

```powershell
$env:TYPESAFE_API_KEY = "sua-chave"
```

## 2. Instalação rápida

### Linux, macOS e WSL

```bash
curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.sh | bash
```

O padrão é:

- agente: `omp`;
- escopo: `global`;
- modo: `copy`;
- destino: `~/.omp/agent/skills/jev-orchestration`.

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.ps1 | iex
```

O padrão é:

```text
%USERPROFILE%\.omp\agent\skills\jev-orchestration
```

Forma mais explícita e auditável:

```powershell
$script = "$env:TEMP\jev-install.ps1"
irm https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.ps1 -OutFile $script
powershell -ExecutionPolicy Bypass -File $script
```

## 3. Instalação a partir de um checkout

```bash
git clone https://github.com/aldokruger/jev-skill.git
cd jev-skill
./install.sh
```

No Windows:

```powershell
git clone https://github.com/aldokruger/jev-skill.git
cd jev-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## 4. Agentes suportados

Os instaladores suportam estas raízes de skills:

| Nome | Escopo global |
|---|---|
| `omp` | `~/.omp/agent/skills` |
| `claude` | `~/.claude/skills` |
| `codex` | `~/.codex/skills` |
| `gemini` | `~/.gemini/skills` |
| `opencode` | `~/.config/opencode/skills` |
| `agents` | `~/.agents/skills` |

No Windows, `~` representa `%USERPROFILE%`.

A detecção verifica se a pasta de skills conhecida existe. Não verifica se o
executável do agente está instalado nem se o agente está autenticado.

Liste os destinos:

```bash
./install.sh --list-agents
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ListAgents
```

## 5. Escolher agentes

### Agentes específicos

```bash
./install.sh --agent omp,claude,opencode
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Agent omp,claude,opencode
```

### Todos os agentes

```bash
./install.sh --all
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -All
```

### Seleção interativa

```bash
./install.sh --interactive
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Interactive
```

Sem parâmetros e sem terminal interativo, o instalador escolhe apenas `omp`. Isso
evita instalar globalmente em agentes que o usuário não solicitou.

## 6. Escopo global ou de projeto

### Global

A instalação fica disponível para todos os projetos e sessões do usuário:

```bash
./install.sh --agent omp,claude --scope global
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp,claude `
  -Scope global
```

### Projeto

A instalação fica dentro do projeto informado:

```bash
./install.sh \
  --agent omp,agents \
  --scope project \
  --project /caminho/do/projeto
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp,agents `
  -Scope project `
  -Project C:\src\meu-projeto
```

O diretório do projeto precisa existir. Os destinos serão, por exemplo:

```text
<projeto>/.omp/skills/jev-orchestration
<projeto>/.agents/skills/jev-orchestration
```

Use projeto quando a skill deve acompanhar o repositório, ser revisada junto com
o código ou não deve ficar ativa em outros projetos.

Use global quando a skill é uma preferência pessoal para todas as sessões.

## 7. Cópia ou symlink

### Cópia — recomendada para uso normal

```bash
./install.sh --agent omp --mode copy
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp `
  -Mode copy
```

A cópia é independente do checkout. Atualizações no repositório não alteram a
instalação até executar o instalador novamente.

### Symlink — recomendada para desenvolvimento

Execute a partir de um checkout local:

```bash
./install.sh --agent omp --mode symlink
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp `
  -Mode symlink
```

O destino aponta para a pasta local `jev-orchestration`. Alterações no checkout
ficam disponíveis imediatamente.

`symlink` não pode ser combinado com `--from-git`, porque o clone é temporário e
o link apontaria para uma pasta que seria removida ao terminar o instalador.

No Windows, a criação do symlink pode exigir Developer Mode ou PowerShell elevado.

## 8. Repositório, branch e versão

Usar o checkout local:

```bash
./install.sh
```

Usar o repositório remoto:

```bash
./install.sh --from-git
```

Usar branch ou tag:

```bash
./install.sh --from-git --ref main
./install.sh --from-git --ref v1.0.0
```

A skill é instalada em uma cópia temporária e movida para o destino. Isso evita
expor uma instalação parcialmente escrita.

## 9. Destino customizado

`--dest` instala em uma única raiz customizada e ignora as raízes geradas pelos
agentes selecionados:

```bash
./install.sh --dest /opt/omp/skills --force
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Destination C:\tools\omp\skills `
  -Force
```

## 10. Preview, atualização e colisões

Preview sem alteração:

```bash
./install.sh --agent omp,claude --dry-run
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp,claude `
  -DryRun
```

Por segurança, uma instalação existente não é substituída automaticamente:

```text
erro: .../jev-orchestration ja existe; use --force
```

Substituir explicitamente:

```bash
./install.sh --agent omp --force
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Agent omp -Force
```

## 11. Verificação após instalar

A descoberta de skills ocorre no início da sessão do OMP. Reinicie o OMP e confirme
que a skill resolve:

```text
read skill://jev-orchestration
```

Selftest direto:

```bash
python3 ~/.omp/agent/skills/jev-orchestration/scripts/jev.py selftest
```

No Windows:

```powershell
py -3 "$env:USERPROFILE\.omp\agent\skills\jev-orchestration\scripts\jev.py" selftest
```

O selftest faz chamadas reais ao Jev e possui custo pequeno. Sem a API key, a
instalação ainda pode ser concluída, mas o selftest é omitido.

## 12. Uso da skill

A skill pode ser ativada por correspondência de descrição quando o pedido envolve:

- reduzir tokens de modelos caros;
- filtrar diff, log, lista de arquivos ou conjunto recuperado;
- escolher tier, modelo ou skill;
- verificar uma saída de modelo barato;
- selecionar um candidato entre vários;
- detectar injeção em contexto recuperado;
- decidir quando escalar para um modelo mais caro.

Ativação explícita:

```text
Use skill://jev-orchestration para filtrar este log antes de enviá-lo ao modelo caro.
```

Comando interativo, quando habilitado:

```text
/skill:jev-orchestration
```

O arquivo implementa quatro primitivas:

| Primitiva | Função |
|---|---|
| `screen_evidence` | filtra relevância, evidência, injeção e contradição |
| `route` | escolhe o tier mais barato suficiente e indica necessidade humana |
| `verify` | verifica campos extraídos contra uma fonte |
| `pick` | escolhe um candidato entre vários ou retorna `None` quando ambíguo |

Regras fundamentais:

1. Faça todas as perguntas independentes em uma requisição Jev.
2. Nomeie o caminho do item em cada pergunta (`passages[3]`, por exemplo).
3. Use perguntas em inglês; o `state` pode estar em português.
4. Confie em thresholds e probabilidades somente depois de calibrar seu domínio.
5. `None` ou baixa confiança significa escalar ou coletar mais evidência, nunca
   chutar.
6. Jev decide tipos e rótulos; não gera código, resumo, texto ou ferramentas.

## 13. Limitações conhecidas

- Jev é English-primary; perguntas em português podem perder precisão.
- Contexto irrelevante reduz a precisão.
- O estado combinado com a maior pergunta deve permanecer dentro do limite de
  contexto documentado pela API.
- Não use Jev para contagem, aritmética, ordenação ou comparação de datas.
- Probabilidades de perguntas separadas não são necessariamente complementares.
- `copy` é snapshot; `symlink` depende do checkout local existir.
- Skills globais podem ser descobertas em qualquer projeto; skills de projeto só
  são descobertas quando o OMP é iniciado no projeto correspondente.

## 14. Desinstalação manual

Remova somente os destinos que você instalou:

```bash
rm -rf ~/.omp/agent/skills/jev-orchestration
```

Para instalação de projeto:

```bash
rm -rf /caminho/do/projeto/.omp/skills/jev-orchestration
```

Depois reinicie o OMP para atualizar a descoberta.
