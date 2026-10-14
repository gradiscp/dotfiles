# Kein push, pull oder fetch; `gh` nur lesend

Gilt in jedem Projekt.

## Git über SSH: geht nicht

Geprüft am 2026-09-13: Remotes laufen über SSH (`git@github.com:...`), der
Key `~/.ssh/id_ed25519` hat eine Passphrase, die Claude nicht kennt, und es
läuft kein ssh-agent (`SSH_AUTH_SOCK` leer). `git push`, `git pull`,
`git fetch` und alles andere über SSH endet deshalb mit
`Permission denied (publickey)`.

- Nicht versuchen, nicht wiederholen, nicht anbieten, es selbst zu tun.
  Stattdessen am Ende sagen, was zu pushen ist (Branch, Anzahl Commits) -
  der Push ist Sache des Nutzers.
- Nicht umgehen: keine Remote-URL auf HTTPS umstellen, keine Tokens oder
  Keys suchen oder anlegen, keinen Credential-Helper oder ssh-agent
  einrichten (auch nicht `gh auth setup-git`), nicht nach der Passphrase
  fragen.
- `origin/...` im lokalen Repo kann veraltet sein, weil nie gefetcht wird.
  Den Stand auf GitHub mit `gh` prüfen (siehe unten), wo das geht; sonst
  Aussagen wie "ist schon gepusht" oder "ahead by N" als ungeprüft
  kennzeichnen.

## `gh`: nur lesen, nur ein Repo

Seit 2026-10-06 ist `gh` angemeldet (Account `***REMOVED***`) mit einem
fine-grained Token, das nur `***REMOVED***/***REMOVED***`
sieht, nur lesend: Actions, Contents, Pull requests (Metadata automatisch).
Kein Lesezugriff auf Commit-Statuses, daher geht `gh pr checks` nicht:
stattdessen `gh run list` / `gh run view`. Das Token läuft am 2026-11-05 ab.

- Erlaubt: lesende Befehle für dieses Repo, z. B. `gh pr list`, `gh pr view`,
  `gh run list`, `gh run view --log-failed`, `gh api` mit GET.
- Nicht: schreibende `gh`-Befehle (Merge, Kommentar, Review, Branch löschen,
  Workflow starten) - das Token kann es nicht, und es ist Sache des Nutzers.
- Andere Repos (auch das alte `***REMOVED***`) sieht das Token nicht; dort gilt
  weiter: kein Zugriff auf GitHub.
- Schlägt `gh` mit 401 fehl, ist das Token abgelaufen: dem Nutzer sagen, nicht
  selbst ein neues besorgen.
