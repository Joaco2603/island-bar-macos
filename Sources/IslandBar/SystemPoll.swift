import Darwin
import Foundation
import IOKit.ps
import IslandCore

struct SystemState: Equatable {
    var cpu = 0.0
    var memory = 0.0
    var battery = 100
    var charging = true
    var volume = 50.0
    var brightness = 50.0
    var address = "—"
    var idleTicks: UInt32 = 0
    var totalTicks: UInt32 = 0
}

enum SystemPoll {
    static func sample(previous: SystemState) -> SystemState {
        var next = previous
        if let ticks = CpuProbe.ticks() {
            let idleDelta = ticks.idle &- previous.idleTicks
            let totalDelta = ticks.total &- previous.totalTicks
            if previous.totalTicks > 0, totalDelta > 0 {
                next.cpu = min(1, max(0, 1 - Double(idleDelta) / Double(totalDelta)))
            }
            next.idleTicks = ticks.idle
            next.totalTicks = ticks.total
        }
        next.memory = CpuProbe.memoryUsed()
        let power = BatteryRead.current()
        next.battery = power.percent
        next.charging = power.charging
        next.address = InterfaceRead.address()
        return next
    }

    static func volume() -> Double? {
        let raw = Shell.run("/usr/bin/osascript", ["-e", "output volume of (get volume settings)"])
        return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum CpuProbe {
    static func ticks() -> (idle: UInt32, total: UInt32)? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = info.cpu_ticks.0
        let system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2
        let nice = info.cpu_ticks.3
        return (idle, user &+ system &+ idle &+ nice)
    }

    static func memoryUsed() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = Double(vm_kernel_page_size)
        let used = Double(stats.active_count + stats.wire_count + stats.compressor_page_count) * page
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        return total == 0 ? 0 : used / total
    }
}

enum BatteryRead {
    static func current() -> (percent: Int, charging: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return (100, true)
        }
        for item in list {
            guard let info = IOPSGetPowerSourceDescription(blob, item)?.takeUnretainedValue() as? [String: Any] else { continue }
            let current = number(info[kIOPSCurrentCapacityKey as String])
            let max = number(info[kIOPSMaxCapacityKey as String])
            let charging = (info[kIOPSIsChargingKey as String] as? Bool) ?? ((info[kIOPSIsChargingKey as String] as? Int) == 1)
            return (max > 0 ? current * 100 / max : current, charging)
        }
        return (100, true)
    }

    private static func number(_ any: Any?) -> Int {
        if let value = any as? Int { return value }
        if let value = any as? NSNumber { return value.intValue }
        return 0
    }
}

enum InterfaceRead {
    static func address() -> String {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return "—" }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            let name = String(cString: item.pointee.ifa_name)
            if name == "en0", let addr = item.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return "\(name) \(String(cString: host))"
                }
            }
            cursor = item.pointee.ifa_next
        }
        return "—"
    }
}

