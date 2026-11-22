# Kein push, pull oder fetch über SSH

Gilt in jedem Projekt.

## Git über SSH: Sache des Nutzers

Remotes laufen über SSH (`git@github.com:...`), die Keys haben eine
Passphrase, die Claude nicht kennt. Seit 2026-11-22 läuft ein ssh-agent pro
Login (systemd `ssh-agent.socket`, `SSH_AUTH_SOCK` aus `~/.bashrc`, Keys
kommen per `AddKeysToAgent` beim ersten Gebrauch hinein). Hat der Nutzer
seinen Key schon entsperrt, würde `git push` aus einer Claude-Sitzung
technisch funktionieren; sonst endet es mit `Permission denied (publickey)`.
Das ändert nichts an den Regeln unten.

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
