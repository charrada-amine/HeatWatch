import ServiceManagement

/// "Lancer au démarrage", shared by the menu toggle and `HeatWatch --launch-at-login on|off|status`.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message for the menu, or nil on success.
    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        var message: String?
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Can fail with an ad hoc signature: the README explains the manual setup.
            message = "Impossible de modifier l'ouverture au démarrage : \(error.localizedDescription) "
                + "Ajoute HeatWatch à la main dans Réglages Système › Général › Ouverture."
        }
        let status = SMAppService.mainApp.status
        if enabled, status == .requiresApproval {
            message = "Autorise HeatWatch dans Réglages Système › Général › Ouverture."
            SMAppService.openSystemSettingsLoginItems()
        }
        Log.alerts.notice("launch at login requested=\(enabled) status=\(describe(status), privacy: .public)")
        return message
    }

    static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "activé"
        case .notRegistered: return "désactivé"
        case .requiresApproval: return "en attente d'autorisation"
        case .notFound: return "introuvable"
        @unknown default: return "inconnu"
        }
    }

    /// Command-line mode; must run from the installed bundle so that `mainApp` is HeatWatch.app.
    static func runCommand(_ argument: String?) {
        switch argument {
        case "on": if let error = set(true) { print(error) }
        case "off": if let error = set(false) { print(error) }
        case "status", nil: break
        default:
            print("Usage : HeatWatch --launch-at-login on|off|status")
            return
        }
        print("Lancer au démarrage : \(describe(SMAppService.mainApp.status))")
    }
}
