import CoreGraphics
import Darwin

enum DisplayBrightness {
    static func read() -> Double? {
        guard let get = load("DisplayServicesGetBrightness", Get.self) else { return nil }
        var value: Float = -1
        let status = get(CGMainDisplayID(), &value)
        guard status == 0, value >= 0, value <= 1 else { return nil }
        return Double(value * 100)
    }

    static func write(_ percent: Double) {
        guard let set = load("DisplayServicesSetBrightness", Set.self) else { return }
        let clamped = Float(min(100, max(0, percent)) / 100)
        _ = set(CGMainDisplayID(), clamped)
    }

    private typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (UInt32, Float) -> Int32

    private static func load<T>(_ name: String, _ type: T.Type) -> T? {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY), let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }
}
