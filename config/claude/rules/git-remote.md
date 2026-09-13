# Kein push, pull oder fetch

Gilt in jedem Projekt.

Claude kann nicht mit GitHub reden. Geprüft am 2026-09-13: Remotes laufen
über SSH (`git@github.com:...`), der Key `~/.ssh/id_ed25519` hat eine
Passphrase, die Claude nicht kennt, es läuft kein ssh-agent
(`SSH_AUTH_SOCK` leer), und `gh` ist nicht angemeldet. `git push`,
`git pull`, `git fetch` und alles andere über SSH endet deshalb mit
`Permission denied (publickey)`.

- Nicht versuchen, nicht wiederholen, nicht anbieten, es selbst zu tun.
  Stattdessen am Ende sagen, was zu pushen ist (Branch, Anzahl Commits) -
  der Push ist Sache des Nutzers.
- Nicht umgehen: keine Remote-URL auf HTTPS umstellen, keine Tokens oder
  Keys suchen oder anlegen, keinen Credential-Helper oder ssh-agent
  einrichten, nicht nach der Passphrase fragen.
- `origin/...` im lokalen Repo kann veraltet sein, weil nie gefetcht wird.
  Aussagen wie "ist schon gepusht" oder "ahead by N" daher als ungeprüft
  kennzeichnen.
