# Gleicher Aufbau für eigene Repos

Gilt, wenn ein eigenes Projekt neu angelegt oder umgebaut wird: kleine
Ein-Personen-Projekte, meist auf Cloudflare Workers. Nicht für fremde oder
Arbeits-Repos mit eigenen Regeln. Welche Repos schon so aufgebaut sind und
als Vorlage dienen, steht in `repo-structure.local.md`.

## Grundsätze
- Gleiches gleich: gleiche Dateinamen, Workflow-Gliederung, Skriptnamen und
  Doku-Gliederung. Unterschiede nur, wo der Stack es verlangt (Code-Layout,
  Paketmanager, Ort der Header).
- Einfach vor vollständig, Löschen vor Hinzufügen. Jede Datei braucht einen
  konkreten Nutzen.
- Ein Fakt, ein Ort: Was als Kommentar am Code steht, nicht in die Doku
  kopieren, sondern darauf verweisen.
- Neues aus dem ähnlichsten Vorlagen-Repo übernehmen statt neu erfinden.
- Weicht ein Repo ab: nicht still angleichen, sondern die Abweichung nennen
  und fragen.

## Zielbaum
```
README.md                Was, Stack, Schnellstart, Aufbau, Links (≤ ~80 Zeilen)
AGENTS.md                Befehle, Aufbau, Regeln, Stolperfallen, Git und Deploy
CLAUDE.md                nur `@AGENTS.md`
SECURITY.md              Melden · Geltungsbereich · Schutzmaßnahmen · Restrisiken
.editorconfig            passend zum Formatter
.nvmrc                   Node-Major, einzige Quelle für lokal und CI
.pre-commit-config.yaml  Secrets und Hygiene, ohne Formatter
.dev.vars.example        nur mit Worker-Secrets (+ `!.dev.vars.example` in .gitignore)
.github/dependabot.yml
.github/pull_request_template.md
.github/workflows/ci-cd.yml   (dazu smoke.yml nur bei einer Live-Prüfung)
docs/operations.md       Betrieb
scripts/                 Prüfskripte ohne eigene Abhängigkeiten
migrations/              D1: `000N_beschreibung.sql`, angewandte nie ändern
```
LICENSE nur in öffentlichen Repos. Bewusst nicht: getrennte `deploy.yml`,
CODEOWNERS, CONTRIBUTING, CHANGELOG (dafür gibt es git log),
Issue-Templates, ADR-Ordner, Staging, CodeQL-/Trivy-Jobs.

## Skripte
`dev`, `build`, `preview`, `typecheck`, `format` (schreibt), `lint` (nur
mit ESLint), `check` (alles, was CI prüft, in derselben Form), `deploy`
(`check` + Deploy, nur von sauberem `main`). Ein Skript gibt es nur, wenn
das Werkzeug existiert. Kein `engines` neben `.nvmrc`. Mit pnpm heißt es
`pnpm run deploy`, weil pnpm einen eingebauten `deploy`-Befehl hat.

## Workflow `ci-cd.yml`
- `name: CI/CD`. Trigger: `pull_request`, `push` auf `main`,
  `workflow_dispatch`.
- `permissions: contents: read`; Concurrency-Gruppe pro Ref,
  `cancel-in-progress` nur für PRs (einen laufenden Deploy nie abbrechen).
- Job `check`: Checkout mit `persist-credentials: false`, setup-node mit
  `node-version-file: .nvmrc` und Cache, Install aus dem Lockfile, dann der
  `check`-Befehl.
- Job `deploy`: `needs: check`, nur bei push/dispatch auf `main`.
  `npx wrangler deploy` mit dem wrangler aus dem Lockfile, keine
  wrangler-action. `CLOUDFLARE_API_TOKEN` und `CLOUDFLARE_ACCOUNT_ID` nur
  als `env` dieses einen Schritts. Ein Build-Artefakt nur übergeben, wenn
  die Ausgabe für sich steht (statische Seite), sonst im Deploy-Job neu
  bauen.
- Jeder Job `timeout-minutes: 10`. Jede Action per Commit-SHA mit
  Versionskommentar (SHAs aus einem Vorlagen-Repo übernehmen, Dependabot
  pflegt sie). Kein `pull_request_target`, Event-Daten nur über `env`.
- Nach einem neuen oder umgebauten Workflow den ersten Lauf auf `main`
  beobachten.

## Dependabot und pre-commit
- Jedes genutzte Ökosystem: wöchentlich montags, `cooldown: default-days: 7`,
  Gruppe `<name>-minor-and-patch` mit `update-types: [minor, patch]`,
  Majors kommen einzeln. Ein Major, der bekannt nicht geht: `ignore` mit
  `versions` und einem Kommentar, warum. Alerts und Security-Updates in
  den Repo-Einstellungen einschalten (macht der Nutzer).
- pre-commit: pre-commit-hooks (`check-added-large-files`,
  `check-merge-conflict`, `check-yaml`, `check-toml`,
  `detect-private-key`) und gitleaks. Kein Formatter-Hook, kein CI-Job,
  einmal pro Klon `pre-commit install`.

## Doku und Sprache
- Code-Kommentare, Workflow-Kommentare und Commits auf Englisch
  (Conventional Commits). Die Doku ist einsprachig pro Repo; welche Sprache,
  steht in AGENTS.md.
- AGENTS.md: Was das ist · Grundsätze · Befehle (Tabelle, `check` = CI) ·
  Aufbau · Regeln · Stolperfallen · Git und Deploy (Agents pushen nicht) ·
  Wegweiser zur Doku.
- `docs/operations.md`: Cloudflare-Ressourcen · Secrets und Vars (nur
  Namen) · Zustand außerhalb des Repos (DNS, Redirect Rules, HSTS, Access,
  Turnstile, abgeschaltete Features) · Deploy und Rollback · Migrationen ·
  offene Punkte.
- HSTS nur an einer Stelle setzen: in der Zone, nicht zusätzlich im Worker
  (die Zone überschreibt den Header ohnehin).
