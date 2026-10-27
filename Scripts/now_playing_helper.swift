import AppKit
import Darwin
import Foundation

let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
guard let handle = dlopen(path, RTLD_LAZY),
      let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
    fputs("now playing unavailable\n", stderr)
    exit(1)
}

typealias Get = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
let get = unsafeBitCast(symbol, to: Get.self)

func mediaKey(_ name: String) -> String {
    guard let symbol = dlsym(handle, name) else { return name }
    return symbol.load(as: CFString.self) as String
}

func appName() -> String {
    guard let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") else { return "Now Playing" }
    typealias GetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    var name = "Now Playing"
    var done = false
    unsafeBitCast(symbol, to: GetPID.self)(DispatchQueue.global()) { pid in
        name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "Now Playing"
        done = true
    }
    let deadline = Date(timeIntervalSinceNow: 1)
    while !done, Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
    }
    return name
}

func snapshot() -> String {
    var line = ""
    var done = false
    get(DispatchQueue.global()) { raw in
        let info = raw as? [String: Any] ?? [:]
        let title = info[mediaKey("kMRMediaRemoteNowPlayingInfoTitle")] as? String ?? ""
        let artist = info[mediaKey("kMRMediaRemoteNowPlayingInfoArtist")] as? String ?? ""
        let rate = (info[mediaKey("kMRMediaRemoteNowPlayingInfoPlaybackRate")] as? NSNumber)?.doubleValue ?? 0
        let elapsed = (info[mediaKey("kMRMediaRemoteNowPlayingInfoElapsedTime")] as? NSNumber)?.doubleValue ?? 0
        let duration = (info[mediaKey("kMRMediaRemoteNowPlayingInfoDuration")] as? NSNumber)?.doubleValue ?? 0
        let art = (info[mediaKey("kMRMediaRemoteNowPlayingInfoArtworkData")] as? Data)?.base64EncodedString() ?? ""
        let payload: [String: Any] = [
            "title": title,
            "artist": artist,
            "source": "",
            "playing": rate > 0,
            "elapsed": elapsed,
            "duration": duration,
            "art": art
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let text = String(data: data, encoding: .utf8) {
            line = text
        }
        done = true
    }
    let deadline = Date(timeIntervalSinceNow: 2)
    while !done, Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
    }
    guard !line.isEmpty,
          let data = line.data(using: .utf8),
          var payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return line }
    payload["source"] = appName()
    guard let encoded = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: encoded, encoding: .utf8) else { return line }
    return text
}

let once = CommandLine.arguments.contains("--once")
repeat {
    let line = snapshot()
    if !line.isEmpty {
        print(line)
        fflush(stdout)
    }
    if once { break }
    Thread.sleep(forTimeInterval: 1)
} while true
