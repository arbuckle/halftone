//
//  AppState.swift
//  Halftone
//
//  Application state management with UserDefaults persistence
//

import Foundation

/// Dot size presets for halftone effect
enum DotSizePreset: Int, CaseIterable {
    case fine = 0
    case medium = 1
    case coarse = 2

    var dotSize: Float {
        switch self {
        case .fine: return 4.0
        case .medium: return 8.0
        case .coarse: return 16.0
        }
    }

    var displayName: String {
        switch self {
        case .fine: return "Fine"
        case .medium: return "Medium"
        case .coarse: return "Coarse"
        }
    }
}

/// Manages application state with automatic persistence
class AppState {

    static let shared = AppState()

    static let didChangeNotification = Notification.Name("AppStateDidChange")

    // MARK: - Keys

    private enum Keys {
        static let isEnabled = "halftone.isEnabled"
        static let dotSizePreset = "halftone.dotSizePreset"
        static let intensity = "halftone.intensity"
    }

    // MARK: - Properties

    var isEnabled: Bool {
        didSet {
            if oldValue != isEnabled {
                save()
                notifyChange()
            }
        }
    }

    var dotSizePreset: DotSizePreset {
        didSet {
            if oldValue != dotSizePreset {
                save()
                notifyChange()
            }
        }
    }

    var intensity: Float {
        didSet {
            let clamped = max(0.0, min(1.0, intensity))
            if intensity != clamped {
                intensity = clamped
            }
            if oldValue != intensity {
                save()
                notifyChange()
            }
        }
    }

    /// Current dot size in pixels
    var dotSize: Float {
        return dotSizePreset.dotSize
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.dotSizePreset = DotSizePreset(rawValue: defaults.integer(forKey: Keys.dotSizePreset)) ?? .medium

        // Default intensity to 1.0 if not set
        if defaults.object(forKey: Keys.intensity) != nil {
            self.intensity = defaults.float(forKey: Keys.intensity)
        } else {
            self.intensity = 1.0
        }
    }

    // MARK: - Persistence

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(dotSizePreset.rawValue, forKey: Keys.dotSizePreset)
        defaults.set(intensity, forKey: Keys.intensity)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
