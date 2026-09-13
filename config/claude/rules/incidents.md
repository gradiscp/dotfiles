# Bekannte Incidents nicht wiederholen

Gilt für jede Aufgabe, in jedem Projekt.

`~/Projects/paulgradischnig/incidents` sammelt Postmortems zu Dingen, die auf
diesen Rechnern und in diesen Projekten schon kaputtgegangen sind: Ursache,
was nicht funktioniert hat, und was eine Wiederholung verhindert. Fehlt der
Ordner (anderer Rechner), einmal erwähnen und normal weitermachen.

## Am Anfang einer Aufgabe
- Nur die Index-Tabelle in `README.md` lesen, nicht alle Dateien.
- Incidents öffnen, deren Titel oder **Area** die Aufgabe berührt, und vor
  jeder Änderung deren Abschnitte **Prevention** und **What didn't work**
  beachten.
- Würde eine Änderung einer dort beschriebenen Prevention widersprechen
  (z. B. eine bewusst abgeschaltete Einstellung wieder einschalten): nicht
  still umsetzen, sondern den Incident nennen und nachfragen.

## Bei Fehlern
- Tritt ein Fehler oder unerwartetes Verhalten auf, zuerst im Repo nach dem
  Symptom suchen (`grep -ril <stichwort> ~/Projects/paulgradischnig/incidents`),
  bevor eigene Ursachen vermutet oder Lösungen ausprobiert werden.
- Passt ein Incident: **Resolution** und **What didn't work** lesen und
  bekannte Sackgassen nicht wiederholen.

## Nach dem Beheben eines echten Problems
- Vorschlagen, einen neuen Incident anzulegen - geschrieben wird er erst nach
  einem Ja. Dann nach `TEMPLATE.md`, Dateiname `YYYY-MM-DD-kurzer-slug.md`,
  plus eine Zeile in der Index-Tabelle der README.
- Die Regeln aus der README gelten: blameless, Belege statt plausibler
  Geschichten, Ungeprüftes unter **Unverified**, nichts Privates.
