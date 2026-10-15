# Kein push, pull oder fetch über SSH

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
  Den Stand auf GitHub mit `gh` prüfen, wo ein lesender Token dafür
  eingerichtet ist (steht in einer lokalen `*.local.md`-Regel); sonst
  Aussagen wie "ist schon gepusht" oder "ahead by N" als ungeprüft
  kennzeichnen.
