#if os(iOS)
    import UIKit
#else
    import Foundation
#endif

extension Hardware: CollectableFamily {
    static func collect() -> Hardware {
        var manufacturer: String? {
            "Apple"
        }

        var model: String? {
            #if targetEnvironment(simulator)
                ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
            #else
                try? Sysctl.string(for: [CTL_HW, HW_MACHINE])
            #endif
        }

        var architecture: String? {
            guard let cpuType = try? Sysctl.value(to: cpu_type_t.self, for: "hw.cputype"),
                  let cpuSubtype = try? Sysctl.value(to: cpu_type_t.self, for: "hw.cpusubtype") else {
                return nil
            }
            switch cpuType {
            case CPU_TYPE_ARM64:
                return cpuSubtype & 0x00FF_FFFF == CPU_SUBTYPE_ARM64E ? "arm64e" : "arm64"
            case CPU_TYPE_X86, CPU_TYPE_X86_64:
                return "x86_64"
            default:
                return nil
            }
        }

        var cpuCount: Int32? {
            try? Sysctl.value(to: Int32.self, for: [CTL_HW, HW_AVAILCPU])
        }

        var cpuFrequency: Int32? {
            guard let hertz = try? Sysctl.value(to: UInt32.self, for: [CTL_HW, HW_CPU_FREQ]) else {
                return nil
            }
            return Int32(hertz / 1000)
        }

        var memorySize: Int64? {
            try? Sysctl.value(to: Int64.self, for: [CTL_HW, HW_MEMSIZE])
        }

        var displayResolution: DisplayResolution? {
            #if os(iOS)
                DisplayResolution.from(UIScreen.main.bounds)
            #else
                nil
            #endif
        }

        var displayScale: Float? {
            #if os(iOS)
                Float(UIScreen.main.scale)
            #else
                nil
            #endif
        }

        var displayPhysicalResolution: DisplayResolution? {
            #if os(iOS)
                DisplayResolution.from(UIScreen.main.nativeBounds)
            #else
                nil
            #endif
        }

        var displayPhysicalScale: Float? {
            #if os(iOS)
                Float(UIScreen.main.nativeScale)
            #else
                nil
            #endif
        }

        return Hardware(
            manufacturer: manufacturer,
            model: model,
            architecture: architecture,
            cpuCount: cpuCount,
            cpuFrequency: cpuFrequency,
            memorySize: memorySize,
            displayResolution: displayResolution,
            displayScale: displayScale,
            displayPhysicalResolution: displayPhysicalResolution,
            displayPhysicalScale: displayPhysicalScale
        )
    }
}

extension DisplayResolution {
    static func from(_ rect: CGRect) -> Self? {
        guard let width = Int32(exactly: rect.width.rounded()),
              let height = Int32(exactly: rect.height.rounded()) else {
            return nil
        }

        return Self(width: width, height: height)
    }
}
