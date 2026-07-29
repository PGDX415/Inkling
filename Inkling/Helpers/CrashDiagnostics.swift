import MetricKit

/// Subscribes to MetricKit for crash & hang diagnostics.
/// Reports appear in Xcode Organizer → Crashes and App Store Connect.
/// No third-party SDK — fully privacy-preserving.
final class CrashDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashDiagnostics()

    private var hasPendingDiagnostics = false

    private override init() {
        super.init()
    }

    /// Call once at app launch to start collecting diagnostics
    func start() {
        MXMetricManager.shared.add(self)
        print("[CrashDiagnostics] MetricKit subscriber registered.")
    }

    // MARK: - MXMetricManagerSubscriber
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        hasPendingDiagnostics = true
        for payload in payloads {
            if let crashes = payload.crashDiagnostics {
                for crash in crashes {
                    print("[CrashDiagnostics] Crash: \(crash.terminationReason ?? "unknown")")
                }
            }
            if let hangs = payload.hangDiagnostics {
                for hang in hangs {
                    print("[CrashDiagnostics] Hang: \(hang.hangDuration.value) \(hang.hangDuration.unit)")
                }
            }
            if let cpuExceptions = payload.cpuExceptionDiagnostics {
                for cpu in cpuExceptions {
                    print("[CrashDiagnostics] CPU exception: \(cpu.totalCPUTime.value) \(cpu.totalCPUTime.unit)")
                }
            }
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // Regular metrics (launch time, memory, etc.) — forwarded to App Store Connect
    }
}
