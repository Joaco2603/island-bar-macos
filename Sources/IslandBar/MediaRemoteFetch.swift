import AppKit
import Darwin
import Foundation

enum MediaRemoteFetch {
    static func probe() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            print("probe dlopen failed")
            return
        }
        typealias Get = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
        let get = unsafeBitCast(symbol, to: Get.self)
        var hits = 0
        get(DispatchQueue.global()) { raw in
            hits += 1
            let cfCount = raw.map { CFDictionaryGetCount($0) } ?? -1
            let info = raw as? [String: Any] ?? [:]
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            print("callback \(hits) cf=\(cfCount) swift=\(info.count) title=\(title)")
            fflush(stdout)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
        print("probe done callbacks=\(hits)")
    }

    static func dictionary() -> [String: Any]? {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return nil }
        typealias Get = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
        let get = unsafeBitCast(symbol, to: Get.self)
        var info: [String: Any]?
        var finished = false
        get(DispatchQueue.global()) { raw in
            let next = raw as? [String: Any] ?? [:]
            guard !next.isEmpty else { return }
            info = next
            finished = true
        }
        let deadline = Date(timeIntervalSinceNow: 0.4)
        while !finished, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        return info
    }

    static func playingAppName() -> String? {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") else { return nil }
        typealias GetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
        let getPID = unsafeBitCast(symbol, to: GetPID.self)
        var pid: Int32 = -1
        var finished = false
        getPID(DispatchQueue.global()) { value in
            pid = value
            finished = true
        }
        let deadline = Date(timeIntervalSinceNow: 2)
        while !finished, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        guard pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    static func key(_ handle: UnsafeMutableRawPointer, _ name: String) -> String {
        guard let symbol = dlsym(handle, name) else { return name }
        return symbol.load(as: CFString.self) as String
    }

    static func mediaHandle() -> UnsafeMutableRawPointer? {
        dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_LAZY
        )
    }
}
