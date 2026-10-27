import Darwin
import AppKit

enum SystemNowPlaying {
    static func read() async -> MusicState? {
        await withCheckedContinuation { continuation in
            fetch { continuation.resume(returning: $0) }
        }
    }

    static func send(_ command: UInt32) {
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else { return }
        typealias Send = @convention(c) (UInt32, CFDictionary?) -> Bool
        _ = unsafeBitCast(symbol, to: Send.self)(command, nil)
    }

    static func seek(_ seconds: Double) {
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteSetElapsedTime") else { return }
        typealias Seek = @convention(c) (Double) -> Void
        unsafeBitCast(symbol, to: Seek.self)(seconds)
    }

    private static let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"

    private static func fetch(_ done: @escaping (MusicState?) -> Void) {
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            done(nil)
            return
        }
        typealias Get = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
        let get = unsafeBitCast(symbol, to: Get.self)
        get(DispatchQueue.global()) { raw in
            let info = raw as? [String: Any] ?? [:]
            let title = info[key(handle, "kMRMediaRemoteNowPlayingInfoTitle")] as? String ?? ""
            guard !title.isEmpty else { done(nil); return }
            let artist = info[key(handle, "kMRMediaRemoteNowPlayingInfoArtist")] as? String ?? ""
            let rate = (info[key(handle, "kMRMediaRemoteNowPlayingInfoPlaybackRate")] as? NSNumber)?.doubleValue ?? 0
            let elapsed = number(info[key(handle, "kMRMediaRemoteNowPlayingInfoElapsedTime")])
            let duration = number(info[key(handle, "kMRMediaRemoteNowPlayingInfoDuration")])
            let art = info[key(handle, "kMRMediaRemoteNowPlayingInfoArtworkData")] as? Data
            appName(handle) { name in
                done(MusicState(
                    source: name, title: title, artist: artist, playing: rate > 0,
                    elapsed: elapsed, duration: duration, art: art
                ))
            }
        }
    }

    private static func appName(_ handle: UnsafeMutableRawPointer, _ done: @escaping (String) -> Void) {
        guard let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") else {
            done("Now Playing")
            return
        }
        typealias GetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
        unsafeBitCast(symbol, to: GetPID.self)(DispatchQueue.global()) { pid in
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "Now Playing"
            done(name)
        }
    }

    private static func key(_ handle: UnsafeMutableRawPointer, _ name: String) -> String {
        guard let symbol = dlsym(handle, name) else { return name }
        return symbol.load(as: CFString.self) as String
    }

    private static func number(_ any: Any?) -> Double {
        (any as? NSNumber)?.doubleValue ?? 0
    }
}
