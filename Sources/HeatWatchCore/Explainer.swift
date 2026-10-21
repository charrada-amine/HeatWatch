import Foundation

public struct Explanation: Equatable, Sendable {
    public let reason: String
    public let advice: String
    public let canQuit: Bool
    /// At most two extra lines (battery, uptime, throttling).
    public let context: [String]

    public init(reason: String, advice: String, canQuit: Bool, context: [String]) {
        self.reason = reason
        self.advice = advice
        self.canQuit = canQuit
        self.context = context
    }
}

/// Turns "which process is busy" into a plain-French "why" and "what to do".
public enum Explainer {
    static let browsers: Set<String> = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Arc", "Opera", "Firefox"]
    static let spotlight: Set<String> = ["mds", "mds_stores", "mdworker", "mdworker_shared", "corespotlightd"]
    static let xprotect: Set<String> = ["XprotectService", "XProtect", "syspolicyd"]
    static let photos: Set<String> = ["photoanalysisd", "mediaanalysisd"]
    static let updates: Set<String> = ["softwareupdated", "installd"]
    static let devTools: Set<String> = ["swift-frontend", "clang", "ld", "xcodebuild", "node", "java", "gradle",
                                        "Unity", "Simulator", "Docker"]

    public static func explain(_ app: AppUsage, minutes: Int, snapshot: Snapshot? = nil) -> Explanation {
        let process = app.topProcess?.processName ?? app.name
        let name = app.name
        let quittable = isQuittable(app)
        let context = snapshot.map(contextLines(for:)) ?? []

        func make(_ reason: String, _ advice: String, _ canQuit: Bool) -> Explanation {
            Explanation(reason: reason, advice: advice, canQuit: canQuit && quittable, context: context)
        }

        if process.contains("(Renderer)") && browsers.contains(name) {
            return make("Un onglet ou une extension de \(name) consomme beaucoup (page lourde, vidéo, animation).",
                        "Ouvre le gestionnaire de tâches de \(name) (⋮ › Plus d'outils › Gestionnaire de tâches) pour trouver l'onglet et le fermer.",
                        true)
        }
        if process == "com.apple.WebKit.WebContent" {
            return make("Un onglet Safari consomme beaucoup.", "Ferme les onglets lourds (vidéo, animations).", false)
        }
        if process.contains("(Renderer)") {
            return make("L'interface de \(name) tourne en boucle. C'est un bug fréquent quand l'app reste ouverte plusieurs jours.",
                        "Quitte complètement \(name) (⌘Q) et rouvre-la.", true)
        }
        if process.contains("(GPU)") {
            return make("Les graphismes de \(name) travaillent beaucoup (vidéo, animations, 3D).",
                        "Mets en pause la vidéo ou l'animation, ou quitte \(name).", true)
        }
        if spotlight.contains(process) {
            return make("Spotlight indexe tes fichiers (normal après une grosse copie, une installation ou une mise à jour).",
                        "Laisse-le finir, ça se calme tout seul.", false)
        }
        if xprotect.contains(process) {
            return make("macOS vérifie une app ou un fichier récent (protection contre les logiciels malveillants).",
                        "Ça dure en général quelques minutes.", false)
        }
        if process == "WindowServer" {
            return make("L'affichage travaille beaucoup (animations, vidéos, beaucoup de fenêtres, écran externe).",
                        "Ferme les vidéos et les fenêtres inutiles.", false)
        }
        if process == "backupd" {
            return make("Time Machine fait une sauvegarde.", "Laisse-la finir.", false)
        }
        if photos.contains(process) {
            return make("Photos analyse ta photothèque.", "Ça s'arrête tout seul.", false)
        }
        if updates.contains(process) {
            return make("Une mise à jour s'installe.", "Laisse-la finir.", false)
        }
        if devTools.contains(process) || devTools.contains(name) || process.hasPrefix("qemu-system-") {
            return make("Un outil de développement travaille (compilation, émulateur, serveur local).",
                        "Normal pendant une compilation. Si ça dure, arrête le serveur ou l'émulateur que tu n'utilises plus.",
                        true)
        }
        return make("\(name) utilise \(Int(app.cpu.rounded())) % du processeur depuis \(minutes) min.",
                    "Si tu ne l'utilises pas, quitte-la.", true)
    }

    /// False for system paths, HeatWatch itself and processes outside any `.app`.
    public static func isQuittable(_ app: AppUsage) -> Bool {
        guard let bundle = app.bundlePath else { return false }
        if bundle.hasPrefix("/System/") { return false }
        if app.name == "HeatWatch" || (bundle as NSString).lastPathComponent == "HeatWatch.app" { return false }
        return true
    }

    public static func contextLines(for snapshot: Snapshot) -> [String] {
        var lines: [String] = []
        if let battery = snapshot.battery, battery.isCharging, battery.percent >= 0, battery.percent < 50 {
            lines.append("La batterie se recharge (\(battery.percent) %) : ça ajoute de la chaleur.")
        }
        if let days = snapshot.daysSinceBoot, days >= 14 {
            lines.append("Ton Mac n'a pas redémarré depuis \(Int(days)) jours : un redémarrage libère des ressources.")
        }
        if snapshot.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            lines.append("macOS ralentit déjà le processeur pour le refroidir.")
        }
        return Array(lines.prefix(2))
    }
}
