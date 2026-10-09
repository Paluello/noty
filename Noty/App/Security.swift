import LocalAuthentication
import SwiftUI

/// Face ID, Touch ID or the passcode (DAT-7, ADR-0012).
enum Biometrics {
    /// Whether the iPad has any way to check the owner (a passcode at least).
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Asks for Face ID or the passcode. Without a passcode on the iPad there
    /// is nothing to check against, so it lets the user in (see ADR-0012).
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Covers the app until the owner unlocks it, when "Lock Noty" is on.
struct AppLockGate<Content: View>: View {
    @ViewBuilder let content: Content
    @AppStorage(SettingsKey.appLock) private var isLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false

    var body: some View {
        content
            .overlay {
                if isLockEnabled && !isUnlocked {
                    lockScreen
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .background:
                    isUnlocked = false
                case .active:
                    if isLockEnabled && !isUnlocked {
                        Task { await unlock() }
                    }
                default:
                    break
                }
            }
    }

    private var lockScreen: some View {
        ZStack {
            AmbientBackground()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
                Text("Noty is locked")
                    .font(.title2.bold())
                Button("Unlock", systemImage: "faceid") {
                    Task { await unlock() }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
    }

    private func unlock() async {
        isUnlocked = await Biometrics.authenticate(reason: String(localized: "Unlock Noty"))
    }
}
