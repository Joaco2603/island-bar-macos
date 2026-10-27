import Foundation

public enum BluetoothRead {
    public static func connected(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var names: [String] = []
        walk(json, into: &names)
        return Array(Set(names)).sorted()
    }

    private static func walk(_ any: Any, into names: inout [String]) {
        if let list = any as? [Any] {
            for value in list { walk(value, into: &names) }
            return
        }
        guard let dict = any as? [String: Any] else { return }
        if let devices = dict["device_connected"] {
            collect(devices, into: &names)
        }
        for (key, value) in dict where key != "device_connected" && key != "device_not_connected" {
            walk(value, into: &names)
        }
    }

    private static func collect(_ any: Any, into names: inout [String]) {
        if let list = any as? [Any] {
            for value in list { collect(value, into: &names) }
            return
        }
        guard let dict = any as? [String: Any] else { return }
        for (key, value) in dict {
            let info = value as? [String: Any]
            let battery = info?["device_batteryLevelMain"] as? String ?? ""
            let level = battery.filter { $0.isNumber || $0 == "%" }
            names.append(level.isEmpty ? key : "\(key) \(level)")
        }
    }
}
