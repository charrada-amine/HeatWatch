# HeatWatch

Petite app pour la barre des menus de macOS (Apple Silicon) qui surveille la température du
processeur et l'utilisation du CPU par app. Quand le Mac chauffe, elle dit **quelle app** est en
cause, **pourquoi**, et propose de la quitter.

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
