# Ideen

Was sich noch lohnen könnte, gesammelt am 2026-11-05. Nichts davon ist
umgesetzt. Jede Idee muss vor dem Bau noch durch die Prinzipien aus der
[README](README.md) (stock first, leicht, sicher, einfach, reproduzierbar);
Erledigtes fliegt hier raus und steht dann in der README.

## Zuerst: echte Lücken

- [ ] **Backup vom Home-Ordner.** Snapper sichert nur `/`, nicht `/home`, und
  Snapshots auf derselben SSD sind kein Backup. Sicher sind heute nur
  gepushte Git-Repos; `~/.ssh`, Dokumente, die KeePassXC-Datenbank wären bei
  einem SSD-Defekt weg. Vorschlag: `restic` (offizielles Repo, verschlüsselt)
  mit einem systemd-User-Timer. Offen: das Ziel (USB-Platte, Rechner im
  Homelab über Tailscale, Cloud-Speicher). Kopia hätte eine GUI, gibt es aber
  nur über AUR/mise.
- [ ] **GitHub Actions auf Commit-SHAs pinnen**, in den eigenen Repos, die
  noch Tags nutzen (`@v4`). Im März 2026 wurden bei `trivy-action` 76 von 77
  Tags auf Schadcode umgebogen (CVE-2026-33634); wer Tags nutzte, führte ihn
  aus. `pinact run` pinnt und behält die Version als Kommentar,
  `pinact run --check` als CI-Schritt hält es so. Dazu Dependabot für das
  Ökosystem `github-actions`, sonst veralten die SHAs.
- [ ] **`zizmor`** (offizielles Repo) über die Workflows: findet
  Template-Injection, zu breite Rechte, ungepinnte Actions.

## KI-Agenten

- [ ] **Ein Worktree pro Agent:** `herdr worktree create` legt einen
  Git-Worktree an und öffnet ihn als eigenen Workspace; Claude und Codex
  kommen sich nie in die Quere, `git-tidy` räumt danach auf. (`claude
  --worktree --tmux` bräuchte tmux, das hier entfernt ist.)
- [ ] **Agenten auf einem anderen Rechner:** `herdr machine add` /
  `herdr --remote` über Tailscale. Die Agenten belasten den Laptop nicht mehr
  (systemd-oomd hat bei parallelen Agenten schon das Terminal beendet) und
  laufen weiter, wenn er schläft. Braucht einen Rechner, der immer läuft.
- [ ] **Hooks als harte Leitplanke statt nur Regeln:** ein
  PreToolUse-Hook, der `git push`, `git add -A` in diesem Repo und
  schreibende `az`-Befehle blockiert. Die Regeln in `config/claude/rules/`
  stehen bisher nur als Text da.
- [ ] **Skill `/incident`:** schreibt aus der laufenden Session einen
  Incident nach der `TEMPLATE.md` des Incident-Repos und trägt ihn in dessen
  Index ein.
- [ ] **Skill `/ci-fix`:** holt das Log des fehlgeschlagenen Laufs (`gh run
  view --log-failed`, nur lesend) und schlägt den Fix vor.
- [ ] **Codex reviewt, was Claude gebaut hat**, über die Socket-API von
  herdr (ein Agent kann auf den anderen warten).
- [ ] **`/loop` für Deploys:** Claude beobachtet einen CI-Lauf oder Deploy
  und meldet sich über `ai-notify`, wenn er fertig ist.
- [ ] **Azure MCP Server** (Container-Apps-Logs aus Log Analytics in
  natürlicher Sprache). Vorbehalt: läuft mit dem eigenen `az`-Login und hat
  auch Deploy-Werkzeuge, also nur mit einer reinen Lese-Identität.
  Installationsweg ungeprüft.

## Leiste und Desktop

- [ ] **CI-Status in der Leiste:** ✓ / ✗ / ⟳ für den letzten Lauf, Klick
  öffnet ihn. Ein `type: command`-Modul in `shell.json` reicht (stock, kein
  Plugin), z. B. mit `gh run list -L1 --json status,conclusion`.
- [ ] **"Ungepusht"-Anzeige:** wie viele Repos ungepushte Commits haben
  (`git-all` als Grundlage). Der Push ist hier immer Handarbeit.
- [ ] **Azure in der Leiste:** Kosten des laufenden Monats (einmal am Tag)
  oder ob die Container-Apps-Revisionen gesund laufen.
- [ ] **Projekt-Starter im Omarchy-Menü** (`extensions/`): Repo wählen,
  herdr-Workspace, Code und Browser öffnen sich für dieses Projekt.
- [ ] **Ablauf-Erinnerungen** mit `omarchy-reminder` für Tokens und
  Zertifikate.
- Schon da, nur nutzen: **Quake-Konsole** (`SUPER+^`, Terminal zum
  Einblenden, z. B. für einen schnellen Claude) und **Scratchpad**
  (`SUPER+S`).

## Terminal

- [ ] **mise `[env]` und `[tasks]` pro Projekt:** Umgebungsvariablen
  (Azure-Subscription, Kube-Kontext) beim Betreten des Ordners, gleiche
  Befehle in jedem Projekt (`mise run dev`, `mise run deploy`), die auch
  Agenten nutzen. mise ist schon aktiv, nichts Neues.
- [ ] **Azure-Subscription und Kube-Kontext im Prompt:** Starship hat dafür
  Module (`azure`, `kubernetes`), standardmäßig aus. Schützt vor dem Deploy
  in die falsche Umgebung.
- [ ] **`gh-dash`:** Terminal-Übersicht über PRs und Issues aller Repos
  (gh-Erweiterung).

## Sicherheit

- [ ] **Pre-commit-Check in diesem öffentlichen Repo:** `gitleaks`
  (offizielles Repo) plus eine lokale, ungetrackte Sperrliste (Arbeitgeber,
  Hostnamen, IPs). Die mechanische Variante der Regel "nichts Privates".
- [ ] **Wöchentlich `security-audit packages`** (oder `all`) per
  systemd-User-Timer; das Skript schickt das Ergebnis schon als Toast.
- [ ] **SSH-Key auf einem FIDO2-Schlüssel** (`ed25519-sk`, `libfido2`):
  der Key verlässt die Hardware nicht. Ob das zum SSH-Ablauf passt, ist
  ungeprüft.

## DevOps, Azure, Kubernetes

- [ ] **Bicep `what-if` in jedem PR:** die CI zeigt vor dem Merge, was sich
  in Azure ändern würde.
- [ ] **Vorschau-Umgebung pro PR:** eine Container-Apps-Revision mit Label,
  die nach dem Merge verschwindet.
- [ ] **Images signieren und inventarisieren:** `cosign` (keyless über
  GitHub OIDC) und `syft` für die SBOM, beide im offiziellen Repo.
- [ ] **Kubernetes lernen:** `k3d` mit `kubectl`, `k9s`, `helm` über mise,
  nur in einem eigenen Lern-Ordner. k3d nutzt das vorhandene Docker und
  braucht im Leerlauf laut einem Vergleich etwa 350 MB (minikube ~1 GB),
  wichtig bei 30 GB RAM. Lernpfad: eine eigene App mit Helm-Chart in k3d,
  dann GitOps mit Flux oder Argo CD, später k3s in einer Proxmox-VM, erreichbar
  über den Tailscale-Operator.

## Bewusst nicht

- Lokale KI: Claude und Codex reichen, der Laptop (nur integrierte Grafik) lohnt es nicht.
- atuin: Strg+R mit fzf, zoxide und starship bringt Omarchy schon mit.
- lazygit, lazydocker: bewusst entfernt.
- `act` (Actions lokal): schwer, und Schritte mit Cloud-Login laufen lokal
  ohnehin nicht.

## Quellen

- Trivy-Kompromittierung: [CVE-2026-33634](https://cve.circl.lu/cve/CVE-2026-33634),
  [Analyse](https://safedep.io/trivy-teampcp-supply-chain-compromise/)
- [SHA-Pinning mit pinact](https://semgrep.dev/blog/2026/sha-pinning-for-github-actions-org-wide),
  [zizmor](https://rywalker.com/research/zizmor)
- [herdr Agent-Guide](https://herdr.dev/agent-guide.md)
- [Azure MCP Server](https://learn.microsoft.com/en-us/azure/developer/azure-mcp-server/tools/azure-deploy)
- [gh-dash](https://github.com/dlvhdr/gh-dash)
- [kind vs k3d vs minikube](https://devopsboys.com/blog/kind-vs-k3d-vs-minikube-local-kubernetes-2026)
- [restic vs borg vs kopia](https://techfuelhq.com/homelab/restic-vs-borg-vs-kopia-2026/)
