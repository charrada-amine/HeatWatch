# HeatWatch

Petite app pour la barre des menus de macOS (Apple Silicon) qui surveille la température du
processeur et l'utilisation du CPU par app. Quand le Mac chauffe, elle dit **quelle app** est en
cause, **pourquoi**, et propose de la quitter.

## Installer et lancer

Il faut Xcode (ou les Command Line Tools) et macOS 14 ou plus récent.

```bash
scripts/install.sh
```

Le script compile en mode release, assemble `build/HeatWatch.app` (signé ad hoc), ferme l'ancienne
instance, copie l'app dans `~/Applications` et la lance. L'icône apparaît dans la barre des menus :
un thermomètre suivi de la température du processeur (ex. `48°`), avec un triangle quand une alerte
est active.

Autres commandes :

```bash
swift build && swift test             # compiler et lancer les tests
swift run HeatWatch --probe           # mesure unique en texte, sans interface
scripts/stress.sh 2 300               # charge de test : 2 cœurs pendant 300 s
scripts/calibrate.sh 180 180 4        # relevé des températures, au repos puis en charge
```

## Ce que montre le menu

1. La température du processeur (Normal / Tiède / Chaud) et celle de la batterie.
2. En cas d'alerte : l'app en cause, la raison, un conseil, et les boutons « Quitter {app} » (seulement
   pour une vraie app, jamais pour un processus système) et « Ignorer 1 h ».
3. Les 5 apps qui consomment le plus de CPU (100 % = un cœur entier, 800 % au maximum sur un M2).
4. Le contexte : batterie en charge, jours depuis le dernier redémarrage.
5. « Ouvrir le Moniteur d'activité », « Tester une alerte », « Lancer au démarrage », « Quitter HeatWatch ».

## Quand HeatWatch prévient

- une app dépasse 80 % de CPU pendant 3 minutes ;
- la température du processeur reste ≥ 80 °C pendant 2 minutes ;
- macOS signale lui-même une surchauffe (`thermalState` sérieux ou critique).

Pas plus d'une alerte toutes les 15 minutes pour la même app. « Ignorer 1 h » met l'app en pause.

## Autorisations

- **Notifications** : au premier lancement, macOS demande « HeatWatch souhaite vous envoyer des
  notifications » : clique sur **Autoriser**. Si la demande a été fermée ou refusée, le menu affiche
  « Notifications désactivées » et un lien « Activer les notifications… » qui ouvre Réglages Système ›
  Notifications › HeatWatch : active « Autoriser les notifications » et choisis le style « Alertes ».
  En attendant, les alertes s'affichent dans une fenêtre classique, avec les mêmes textes et boutons.
- **Lancer au démarrage** : coche « Lancer au démarrage » dans le menu, ou en ligne de commande :

  ```bash
  ~/Applications/HeatWatch.app/Contents/MacOS/HeatWatch --launch-at-login on   # ou off, status
  ```

  Si macOS demande une validation, Réglages Système › Général › Ouverture s'ouvre : active HeatWatch
  dans la liste. En cas d'erreur, ajoute l'app à la main : Réglages Système › Général › Ouverture ›
  « Ouvrir à la connexion » › bouton « + » › `~/Applications/HeatWatch.app`.

## Limites

- Lecture des capteurs par une API privée d'Apple (IOHIDEventSystem) : elle peut changer avec une
  future version de macOS.
- Le % CPU vient de `ps` : c'est une moyenne glissante sur environ une minute, donc une alerte arrive
  3 à 4 minutes après le début du problème.
- `kernel_task` n'apparaît pas dans la liste.
- HeatWatch ne force jamais la fermeture d'une app : il lui demande poliment de quitter.
- Pas de `sudo`, pas de `powermetrics`, aucune dépendance externe.

## Calibrage (MacBook Air 15" M2 sans ventilateur, 21/10/2026)

Relevé avec `scripts/calibrate.sh 180 180 4` (une mesure toutes les 10 s) :

| Phase | Min | Moyenne | Max |
|---|---|---|---|
| Repos, 3 min | 45,2 °C | 47,7 °C | 53,0 °C |
| 4 cœurs chargés (`yes`), 3 min | 47,4 °C | 72,8 °C | 78,7 °C |

Sous charge, la température monte d'environ 47 à 71 °C en 40 s, puis se stabilise autour de 77–78 °C.

Seuils retenus (`Sources/HeatWatchCore/HeatConfig.swift`) :

- **Tiède** à partir de 65 °C (au-dessus des pics observés au repos) ;
- **Chaud** à partir de 80 °C ;
- **Alerte** si la température reste ≥ 80 °C pendant 2 min.

Une app à plus de 80 % de CPU pendant 3 min déclenche l'alerte même si la température reste
modérée : c'est le cas le plus courant (ex. `Spotify Helper (Renderer)` bloqué à 130 %).
