# HeatWatch : plan de développement

> Ce plan est écrit pour une session de développement (Opus 5.5, effort moyen).
> Suis-le jalon par jalon. Le code marqué **validé** a été compilé et exécuté sur ce Mac
> le 21/10/2026 : reprends-le tel quel.

## 1. Objectif

Une app pour la barre des menus de macOS qui :

1. mesure en continu la température du processeur et l'utilisation du CPU par chaque app ;
2. prévient tout de suite (notification) quand le Mac chauffe ;
3. dit **quelle app** fait chauffer le Mac et **pourquoi**, en français simple ;
4. propose un bouton pour **quitter l'app en cause**.

Usage personnel uniquement (pas d'App Store).

## 2. Contexte

- Mac : MacBook Air 15" M2 (`Mac14,15`), **sans ventilateur**, macOS 26.5, Xcode installé, Swift 6.2.1.
- Origine du projet (21/10/2026) : le processus `Spotify Helper (Renderer)`, qui affiche l'interface de
  Spotify, tournait à ~130 % de CPU depuis des heures. En même temps : WindowServer à 20–40 %, un onglet
  Chrome à 20–110 %, charge moyenne 7,5. Le Mac était chaud au toucher, mais
  `ProcessInfo.thermalState` restait `nominal` et `pmset -g therm` ne signalait rien.
- **Conséquence** : `thermalState` ne suffit pas. L'app mesure elle-même la température et le CPU par
  app. Une app à plus de 80 % de CPU pendant 3 minutes déclenche l'alerte, même si la température
  reste modérée.

## 3. Déjà vérifié sur ce Mac (ne pas re-tester)

| Donnée | Méthode | Résultat |
|---|---|---|
| Température du processeur | API privée IOHIDEventSystem (§6.1–6.3) | ✅ 38–39 capteurs, sans mot de passe. CPU = max des capteurs dont le nom contient `tdie` : 44–50 °C au repos |
| Température de la batterie | mêmes capteurs, nom contenant `battery` | ✅ 33–37 °C |
| CPU par processus | `/bin/ps -Ao pid=,pcpu=,comm=` (§6.4) | ✅ ~600 processus, y compris ceux de root (`ps` est setuid root), avec le chemin complet de l'exécutable |
| CPU par processus via `proc_pid_rusage` | libproc | ❌ refusé pour ~210 processus d'autres utilisateurs (dont WindowServer) : **ne pas utiliser** |
| Batterie (%, en charge, secteur) | `IOKit.ps` (§6.6) | ✅ |
| Jours depuis le démarrage | `sysctlbyname("kern.boottime")` (§6.6) | ✅ 88,1 jours |
| `thermalState` | `ProcessInfo` | ⚠️ `nominal` même quand le Mac est chaud : signal secondaire seulement |
| Package SPM avec une cible C et une cible Swift | `swift-tools-version: 5.9`, `swift build` | ✅ compile et tourne |

Dans les capteurs, ignore les noms contenant `tcal` (calibration) et les valeurs ≤ 0 ou ≥ 130
(capteurs inactifs, ex. `PMU tdev1 = -1.4`).
`kernel_task` (pid 0) n'apparaît pas dans `ps` : c'est normal, on l'ignore.

## 4. Choix techniques (imposés)

- **Swift Package Manager**, pas de `.xcodeproj`. Le bundle `.app` est assemblé par `scripts/build-app.sh`.
- `// swift-tools-version: 5.9` et `platforms: [.macOS(.v14)]` : mode Swift 5, les avertissements de
  concurrence ne bloquent pas la compilation. Ne passe pas en mode Swift 6.
- SwiftUI `MenuBarExtra` avec `.menuBarExtraStyle(.window)` ; `LSUIElement = true` (pas d'icône dans le Dock).
- Notifications : framework `UserNotifications`.
- Aucune dépendance externe. Jamais de `sudo` ni de `powermetrics`.
- Textes de l'interface **en français** ; code, noms et commentaires en anglais.
- Identifiant du bundle : `com.charrada.heatwatch`.
- Travail sur la branche `main` (dépôt vide, remote `origin` = github.com/charrada-amine/HeatWatch).
  Un commit par jalon. **Ne pousse pas** sur GitHub sans l'accord de l'utilisateur.

## 5. Arborescence cible

```
HeatWatch/
├── Package.swift
├── PLAN.md
├── README.md                     # en français : installer, lancer, réglages, limites
├── .gitignore                    # .build/  build/  .swiftpm/  .DS_Store
├── Resources/Info.plist
├── scripts/build-app.sh          # swift build -c release → build/HeatWatch.app signé ad hoc
├── scripts/install.sh            # build + copie dans ~/Applications + lancement
├── scripts/stress.sh             # charge de test (§9)
├── scripts/calibrate.sh          # relevé des températures (§9, jalon 5)
├── Sources/CSensors/include/CSensors.h
├── Sources/CSensors/sensors.c
├── Sources/HeatWatchCore/        # logique pure, sans interface, testable
│   ├── HeatConfig.swift          # tous les seuils
│   ├── TemperatureReader.swift   # wrapper Swift de CSensors + choix CPU / batterie
│   ├── ProcessSampler.swift      # lance ps et lit ses lignes
│   ├── AppGrouping.swift         # chemin d'exécutable → app (nom + chemin du .app)
│   ├── SystemContext.swift       # batterie, date de démarrage, thermalState
│   ├── Snapshot.swift            # une mesure complète
│   ├── Explainer.swift           # règles du « pourquoi » → textes en français
│   └── HeatAnalyzer.swift        # niveaux, durées, décision d'alerte, anti-spam
├── Sources/HeatWatch/            # exécutable : interface + notifications
│   ├── EntryPoint.swift          # @main : mode --probe ou lancement de l'app
│   ├── HeatWatchApp.swift        # App SwiftUI + MenuBarExtra
│   ├── AppDelegate.swift         # démarre la surveillance au lancement
│   ├── MonitorModel.swift        # @MainActor ObservableObject, mesure toutes les 5 s
│   ├── MenuView.swift
│   ├── Notifier.swift            # notifications + actions + repli NSAlert
│   ├── AppTerminator.swift       # quitter l'app en cause
│   └── Probe.swift               # mode texte --probe
└── Tests/HeatWatchCoreTests/     # XCTest
```

`Package.swift` :

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeatWatch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CSensors",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
        ),
        .target(name: "HeatWatchCore", dependencies: ["CSensors"]),
        .executableTarget(name: "HeatWatch", dependencies: ["HeatWatchCore"]),
        .testTarget(name: "HeatWatchCoreTests", dependencies: ["HeatWatchCore"]),
    ]
)
```

## 6. Code validé

### 6.1 `Sources/CSensors/include/CSensors.h`

```c
#ifndef CSENSORS_H
#define CSENSORS_H

typedef struct {
    char name[64];
    double celsius;
} hw_sensor_reading;

/// Fills `out` with up to `max` temperature readings. Returns how many were written.
int hw_read_temperatures(hw_sensor_reading *out, int max);

#endif
```

### 6.2 `Sources/CSensors/sensors.c`

```c
// Reads Apple Silicon temperature sensors through the private IOHIDEventSystem API
// (same approach as Stats / macmon). Works without root.
#include "CSensors.h"
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEvent *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)

static IOHIDEventSystemClientRef shared_client(void) {
    static IOHIDEventSystemClientRef client = NULL;
    if (client) return client;
    client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return NULL;
    int page = 0xff00, usage = 5; // Apple vendor page, temperature sensors
    CFNumberRef nPage = CFNumberCreate(NULL, kCFNumberIntType, &page);
    CFNumberRef nUsage = CFNumberCreate(NULL, kCFNumberIntType, &usage);
    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *vals[] = { nPage, nUsage };
    CFDictionaryRef match = CFDictionaryCreate(NULL, keys, vals, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDEventSystemClientSetMatching(client, match);
    CFRelease(match);
    CFRelease(nPage);
    CFRelease(nUsage);
    return client;
}

int hw_read_temperatures(hw_sensor_reading *out, int max) {
    IOHIDEventSystemClientRef client = shared_client();
    if (!client) return 0;
    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) return 0;
    int written = 0;
    CFIndex count = CFArrayGetCount(services);
    for (CFIndex i = 0; i < count && written < max; i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;
        hw_sensor_reading *r = &out[written++];
        r->celsius = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);
        r->name[0] = '\0';
        CFTypeRef name = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        if (name) {
            if (CFGetTypeID(name) == CFStringGetTypeID())
                CFStringGetCString((CFStringRef)name, r->name, sizeof(r->name), kCFStringEncodingUTF8);
            CFRelease(name);
        }
    }
    CFRelease(services);
    return written;
}
```

`hw_read_temperatures` n'est pas fait pour être appelé depuis deux threads en même temps : appelle-le
uniquement depuis la tâche de mesure.

### 6.3 Lecture en Swift (`TemperatureReader`)

```swift
import CSensors

public struct SensorReading: Equatable {
    public let name: String
    public let celsius: Double
}

public enum TemperatureReader {
    public static func readAll() -> [SensorReading] {
        var buffer = [hw_sensor_reading](repeating: hw_sensor_reading(), count: 128)
        let count = Int(hw_read_temperatures(&buffer, Int32(buffer.count)))
        return buffer.prefix(count).map { reading in
            var raw = reading.name
            let name = withUnsafeBytes(of: &raw) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            return SensorReading(name: name, celsius: reading.celsius)
        }
    }
}
```

À écrire (non fourni) :

- `cpuTemperature(from:) -> Double?` : max des lectures dont le nom contient `tdie`, sans `tcal`,
  avec 0 < t < 130. S'il n'y en a aucune, max des lectures valides hors `battery` et `tcal`.
- `batteryTemperature(from:) -> Double?` : max des lectures dont le nom contient `battery`.

### 6.4 CPU par processus avec `ps`

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/ps")
process.arguments = ["-Ao", "pid=,pcpu=,comm="]
let pipe = Pipe()
process.standardOutput = pipe
try process.run()
let data = pipe.fileHandleForReading.readDataToEndOfFile() // lire AVANT waitUntilExit, sinon blocage
process.waitUntilExit()

for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
    let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
    guard parts.count == 3, let pid = Int32(parts[0]), let cpu = Double(parts[1]) else { continue }
    let path = parts[2].trimmingCharacters(in: .whitespaces)
    // ...
}
```

Le `pcpu` de `ps` est une moyenne glissante sur environ une minute : il est déjà lissé, inutile de
calculer des différences entre deux mesures. 100 % = un cœur entier ; le M2 a 8 cœurs (800 % au maximum).

### 6.5 Regroupement par app

```swift
/// ".../Spotify.app/Contents/Frameworks/Spotify Helper (Renderer).app/Contents/MacOS/Spotify Helper (Renderer)" → "Spotify"
/// "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer" → "WindowServer"
func appName(forExecutablePath path: String) -> String {
    if let range = path.range(of: ".app/") {
        return (String(path[..<range.lowerBound]) as NSString).lastPathComponent
    }
    return (path as NSString).lastPathComponent
}
```

Le premier `.app/` du chemin correspond au bundle le plus extérieur, c'est-à-dire l'app que
l'utilisateur connaît. Garde aussi le chemin de ce bundle (`/Applications/Spotify.app`) pour pouvoir
quitter l'app. Résultat observé sur ce Mac : « Google Chrome », « WindowServer », « XprotectService »,
« coreaudiod »…

### 6.6 Batterie, date de démarrage, état thermique

```swift
import IOKit.ps

if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
   let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
    for source in list {
        guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else { continue }
        let percent = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
    }
}

// Date de démarrage (inclut les mises en veille, contrairement à ProcessInfo.systemUptime)
var boot = timeval()
var size = MemoryLayout<timeval>.stride
if sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 {
    let bootDate = Date(timeIntervalSince1970: TimeInterval(boot.tv_sec))
}

let thermal = ProcessInfo.processInfo.thermalState // .nominal, .fair, .serious, .critical
```

## 7. Logique

### 7.1 Modèles

```swift
public struct ProcessSample { pid: Int32; cpu: Double; executablePath: String; processName: String } // processName = dernier composant du chemin
public struct AppUsage { name: String; bundlePath: String?; cpu: Double /* somme */; processes: [ProcessSample] /* CPU décroissant */ }
public struct BatteryState { percent: Int; isCharging: Bool; onAC: Bool }
public struct Snapshot {
    date: Date; cpuTemperature: Double?; batteryTemperature: Double?
    apps: [AppUsage] /* CPU décroissant */; battery: BatteryState?; bootDate: Date?
    thermalState: ProcessInfo.ThermalState
}
```

Exclus de `apps` : HeatWatch lui-même et `ps`.

### 7.2 Seuils (`HeatConfig`, valeurs par défaut)

| Réglage | Défaut | Rôle |
|---|---|---|
| `sampleInterval` | 5 s | fréquence des mesures |
| `appCPUThreshold` | 80 % | une app au-dessus de ce seuil… |
| `appSustained` | 180 s | …pendant 3 min déclenche l'alerte |
| `tempWarm` | 70 °C | icône « tiède » |
| `tempHot` | 85 °C | icône « chaud » |
| `tempAlert` / `tempSustained` | 85 °C / 120 s | température soutenue : alerte |
| `alertCooldown` | 900 s | pas de nouvelle alerte pour le même coupable pendant 15 min |
| `snoozeDuration` | 3600 s | bouton « Ignorer 1 h » |

Les seuils de température sont provisoires : ils sont ajustés au jalon 5.

### 7.3 `HeatAnalyzer`

Testable : la date vient toujours du `Snapshot`, jamais de `Date()` à l'intérieur.

- Niveau `.normal` / `.warm` / `.hot` selon `cpuTemperature` ; `.hot` aussi quand une alerte est active.
- Pour chaque app, retient depuis quand elle est ≥ `appCPUThreshold` ; remet à zéro dès qu'elle repasse
  en dessous. Même principe pour la température ≥ `tempAlert`.
- Déclenche une alerte si une app dépasse `appSustained`, si la température dépasse `tempSustained`, ou
  si `thermalState` ≥ `.serious`.
- Coupable : l'app qui a dépassé le seuil (s'il y en a plusieurs, celle qui consomme le plus). Pour une
  alerte de température ou de `thermalState`, l'app la plus gourmande du moment.
- Anti-spam : pas d'alerte si le coupable en a déjà eu une depuis moins de `alertCooldown`, ou s'il est
  en pause (« Ignorer 1 h »).
- Résultat : `HeatAlert { culprit: AppUsage; explanation: Explanation; cpuTemperature: Double?; minutesAbove: Int }`.

### 7.4 `Explainer` : le « pourquoi »

`Explanation { reason: String; advice: String; canQuit: Bool; context: [String] }`.
La première règle qui correspond s'applique, en regardant le processus le plus gourmand de l'app.

| Condition | Raison | Conseil | Quitter ? |
|---|---|---|---|
| processus contenant `(Renderer)` et app de navigateur (Google Chrome, Brave Browser, Microsoft Edge, Arc, Opera, Firefox) | « Un onglet ou une extension de {app} consomme beaucoup (page lourde, vidéo, animation). » | « Ouvre le gestionnaire de tâches de {app} (⋮ › Plus d'outils › Gestionnaire de tâches) pour trouver l'onglet et le fermer. » | oui |
| processus `com.apple.WebKit.WebContent` | « Un onglet Safari consomme beaucoup. » | « Ferme les onglets lourds (vidéo, animations). » | non |
| processus contenant `(Renderer)` (Spotify, Discord, Slack, Code…) | « L'interface de {app} tourne en boucle. C'est un bug fréquent quand l'app reste ouverte plusieurs jours. » | « Quitte complètement {app} (⌘Q) et rouvre-la. » | oui |
| processus contenant `(GPU)` | « Les graphismes de {app} travaillent beaucoup (vidéo, animations, 3D). » | « Mets en pause la vidéo ou l'animation, ou quitte {app}. » | oui |
| `mds`, `mds_stores`, `mdworker`, `mdworker_shared`, `corespotlightd` | « Spotlight indexe tes fichiers (normal après une grosse copie, une installation ou une mise à jour). » | « Laisse-le finir, ça se calme tout seul. » | non |
| `XprotectService`, `XProtect`, `syspolicyd` | « macOS vérifie une app ou un fichier récent (protection contre les logiciels malveillants). » | « Ça dure en général quelques minutes. » | non |
| `WindowServer` | « L'affichage travaille beaucoup (animations, vidéos, beaucoup de fenêtres, écran externe). » | « Ferme les vidéos et les fenêtres inutiles. » | non |
| `backupd` | « Time Machine fait une sauvegarde. » | « Laisse-la finir. » | non |
| `photoanalysisd`, `mediaanalysisd` | « Photos analyse ta photothèque. » | « Ça s'arrête tout seul. » | non |
| `softwareupdated`, `installd` | « Une mise à jour s'installe. » | « Laisse-la finir. » | non |
| `swift-frontend`, `clang`, `ld`, `xcodebuild`, `node`, `java`, `gradle`, `qemu-system-*`, `Unity`, `Simulator`, `Docker` | « Un outil de développement travaille (compilation, émulateur, serveur local). » | « Normal pendant une compilation. Si ça dure, arrête le serveur ou l'émulateur que tu n'utilises plus. » | si .app hors `/System/` |
| sinon | « {app} utilise {cpu} % du processeur depuis {min} min. » | « Si tu ne l'utilises pas, quitte-la. » | si .app hors `/System/` |

`canQuit` est toujours faux pour un chemin qui commence par `/System/`, pour HeatWatch et pour un
processus sans `.app`.

Lignes de contexte (2 au maximum) :

- batterie en charge et < 50 % → « La batterie se recharge ({x} %) : ça ajoute de la chaleur. »
- au moins 14 jours depuis le démarrage → « Ton Mac n'a pas redémarré depuis {n} jours : un redémarrage libère des ressources. »
- `thermalState` ≥ `.serious` → « macOS ralentit déjà le processeur pour le refroidir. »

## 8. Interface et alertes

### 8.1 Lancement : pièges connus

- `@main` est interdit dans un fichier nommé `main.swift`. Utilise `EntryPoint.swift` :

  ```swift
  @main
  enum EntryPoint {
      static func main() {
          if CommandLine.arguments.contains("--probe") { Probe.run(); return }
          HeatWatchApp.main()
      }
  }
  ```

  `HeatWatchApp` est une `App` SwiftUI **sans** `@main`.
- Le contenu d'un `MenuBarExtra` n'est créé qu'à l'ouverture du menu : son `onAppear` ne s'exécute
  pas au lancement. **Démarre la surveillance dans `AppDelegate.applicationDidFinishLaunching`**
  (`@NSApplicationDelegateAdaptor`). L'`AppDelegate` possède le `MonitorModel` ; la vue du menu et
  l'étiquette de la barre des menus l'observent.
- `UNUserNotificationCenter.current()` plante hors d'un bundle `.app` (avec `swift run` ou `--probe`).
  N'initialise le `Notifier` que si `Bundle.main.bundleIdentifier != nil`.

### 8.2 Barre des menus

- Étiquette : SF Symbol `thermometer.low`, `thermometer.medium` ou `thermometer.high` selon le niveau,
  suivi du texte `48°`. Ajoute `exclamationmark.triangle.fill` quand une alerte est active. SwiftUI
  affiche l'étiquette en monochrome : ne cherche pas à la colorer.
- Fenêtre du menu (environ 320 pt de large) :
  1. « Processeur : 48 °C · Normal » (Normal / Tiède / Chaud) et, en plus petit, « Batterie : 33 °C ».
  2. Si une alerte est active : un encadré « Ton Mac chauffe », la raison, le conseil, et les boutons
     « Quitter {app} » (si `canQuit`) et « Ignorer 1 h ».
  3. « Ce qui consomme le plus » : les 5 premières apps, avec nom, % CPU et une petite barre
     (`ProgressView`, plafonnée à 200 %).
  4. Les lignes de contexte (batterie, redémarrage).
  5. Boutons : « Ouvrir le Moniteur d'activité », « Tester une alerte », interrupteur « Lancer au
     démarrage », « Quitter HeatWatch ».

### 8.3 `MonitorModel`

- `@MainActor final class MonitorModel: ObservableObject` avec `@Published snapshot` et
  `@Published activeAlert`.
- Un `Timer` toutes les `sampleInterval` secondes. La mesure (ps + capteurs + contexte) s'exécute
  **hors du thread principal** (`Task.detached(priority: .utility)`), puis le résultat revient sur le
  main actor. Ne lance pas de nouvelle mesure tant que la précédente n'est pas terminée.
- HeatWatch doit rester léger : moins de 2 % de CPU en moyenne.

### 8.4 Notifications (`Notifier`)

- Catégorie `HEAT_ALERT` avec deux actions : `QUIT_APP` (« Quitter l'app ») et `SNOOZE` (« Ignorer 1 h »).
  Le nom de l'app et le chemin de son bundle vont dans `userInfo`.
- Contenu : titre « Ton Mac chauffe (78 °C) », sous-titre « Spotify : 130 % du processeur depuis 4 min »,
  corps = raison + conseil.
- `userNotificationCenter(_:willPresent:)` renvoie `[.banner, .sound]`, sinon rien ne s'affiche quand
  l'app est au premier plan.
- « Tester une alerte » passe par le même chemin qu'une vraie alerte, avec un coupable fictif « Test »
  sans bundle (donc sans bouton Quitter).
- **Repli** si l'autorisation est refusée ou échoue (possible avec une signature ad hoc) : `NSAlert`
  avec les mêmes textes et boutons, affichée après `NSApp.activate()` (`activate(ignoringOtherApps:)`
  est obsolète). Ne passe pas de temps sur la signature : le repli suffit.

### 8.5 Quitter l'app en cause (`AppTerminator`)

```swift
let target = URL(fileURLWithPath: bundlePath).standardizedFileURL
let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.standardizedFileURL == target }
apps.forEach { $0.terminate() } // jamais forceTerminate automatiquement
```

Refuse si `bundlePath` commence par `/System/` ou désigne HeatWatch.

### 8.6 Lancer au démarrage

`SMAppService.mainApp.register()` / `.unregister()` (`import ServiceManagement`). L'appel peut échouer
avec une signature ad hoc : dans ce cas, affiche l'erreur dans le menu et explique dans le README comment
ajouter l'app à la main (Réglages Système › Général › Ouverture).

### 8.7 Packaging

`Resources/Info.plist` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.charrada.heatwatch</string>
    <key>CFBundleName</key><string>HeatWatch</string>
    <key>CFBundleDisplayName</key><string>HeatWatch</string>
    <key>CFBundleExecutable</key><string>HeatWatch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSUserNotificationAlertStyle</key><string>alert</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
```

`NSUserNotificationAlertStyle = alert` demande que la notification reste affichée jusqu'à un clic.
Si macOS l'ignore, l'utilisateur peut choisir le style « Alertes » dans Réglages Système › Notifications.

`scripts/build-app.sh` :

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/HeatWatch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HeatWatch "$APP/Contents/MacOS/HeatWatch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "OK : $APP"
```

`scripts/install.sh` : lance `build-app.sh`, ferme l'ancienne instance (`pkill -x HeatWatch || true`),
copie l'app dans `~/Applications/`, puis `open ~/Applications/HeatWatch.app`.

### 8.8 Mode `--probe`

`HeatWatch --probe` (ou `swift run HeatWatch --probe`) affiche en texte, sans interface : température
du CPU et de la batterie, nombre de capteurs, les 5 apps les plus gourmandes, l'état de la batterie, les
jours depuis le démarrage, `thermalState`, et l'explication que l'app donnerait pour l'app la plus
gourmande. Ce mode sert à vérifier chaque jalon sans cliquer.

## 9. Jalons

Après chaque jalon : `swift build` et `swift test` sans erreur, puis un commit sur `main` avec un
message clair.

| # | Contenu | Vérification |
|---|---|---|
| 0 | `Package.swift`, `.gitignore`, CSensors (§6.1–6.2), cibles minimales, `PLAN.md` | `swift build` OK |
| 1 | `TemperatureReader`, `ProcessSampler`, `AppGrouping`, `SystemContext`, `Snapshot`, mode `--probe` | `swift run HeatWatch --probe` : CPU entre 40 et 60 °C au repos, ~600 processus, top 5 cohérent avec `top -l 2 -o cpu` |
| 2 | `Explainer`, `HeatAnalyzer`, `HeatConfig` + tests du §10 | `swift test` vert |
| 3 | App de la barre des menus : `Info.plist`, `build-app.sh`, `EntryPoint`, `AppDelegate`, `MonitorModel`, `MenuView` | `scripts/build-app.sh && open build/HeatWatch.app` : `pgrep -x HeatWatch` trouve l'app ; CPU de HeatWatch < 2 % (`ps -o pcpu= -p $(pgrep -x HeatWatch)`) |
| 4 | `Notifier`, repli `NSAlert`, `AppTerminator`, « Tester une alerte », « Ignorer 1 h », `scripts/stress.sh` | Lance `scripts/stress.sh 2 300` en arrière-plan : une alerte doit nommer `yes` en 3 à 4 min, sans bouton Quitter. Vérifie ensuite que `pgrep -x yes` ne trouve plus rien |
| 5 | Calibrage : `scripts/calibrate.sh` | Relève la température du CPU toutes les 10 s, 3 min au repos puis 3 min avec `scripts/stress.sh 4 180`. Ajuste `tempWarm`, `tempHot` et `tempAlert`, et note les mesures dans le README |
| 6 | « Lancer au démarrage », `install.sh`, README en français | `scripts/install.sh` installe et lance l'app depuis `~/Applications` |

`scripts/stress.sh` :

```bash
#!/bin/bash
# Usage : scripts/stress.sh <cœurs> <secondes>
# Occupe des cœurs avec `yes`, puis les arrête, même si le script est interrompu.
workers=${1:-2}
seconds=${2:-240}
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null; }
trap cleanup EXIT INT TERM
for _ in $(seq "$workers"); do
    yes > /dev/null &
    pids+=($!)
done
sleep "$seconds" & wait $!
```

Les tests de charge durent plusieurs minutes : lance-les en arrière-plan, puis vérifie toujours qu'il ne
reste aucun `yes` (`pgrep -x yes`, sinon `killall yes`).

## 10. Tests unitaires (XCTest, cible `HeatWatchCoreTests`)

- **Regroupement** : chemin de `Spotify Helper (Renderer)` → « Spotify » + `/Applications/Spotify.app` ;
  `/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/154.0.8037.57/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)`
  → « Google Chrome » ; chemin de WindowServer → « WindowServer », sans bundle.
- **Lecture de `ps`** : lignes avec espaces au début, chemins avec espaces et parenthèses, ligne invalide ignorée.
- **Températures** : ignore `tcal` et les valeurs ≤ 0 ; prend le max des `tdie`.
- **Analyzer** (dates simulées) : Spotify à 130 % → pas d'alerte à 2 min, alerte à 3 min ; pas de
  deuxième alerte 1 min plus tard (cooldown) ; pas d'alerte pendant « Ignorer 1 h » ; repasse sous 80 %
  → compteur remis à zéro.
- **Explainer** : Spotify Renderer → la raison contient « interface de Spotify » et `canQuit` est vrai ;
  Chrome Renderer → contient « onglet » ; `mds_stores` → Spotlight, `canQuit` faux ; WindowServer →
  `canQuit` faux.

## 11. Règles pour la session de développement

- Suis les jalons dans l'ordre ; ne passe au suivant que si la vérification réussit.
- Reprends le code validé du §6 sans le « simplifier ».
- Si tu bloques deux fois sur le même problème, arrête-toi et décris-le dans ton rapport au lieu de
  tourner en rond.
- Jamais de `sudo`. Arrête tous les `yes` lancés pour les tests.
- Les autorisations de macOS (notifications, ouverture au démarrage) doivent être acceptées par
  l'utilisateur : dis-lui exactement quoi cliquer.
- Ne pousse pas sur GitHub sans accord.
- Rapport final : ce qui marche, ce qui a été vérifié et comment, ce qui reste à faire, et les
  températures mesurées au calibrage.
