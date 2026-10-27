import AppKit
_ = NSApplication.shared
import Foundation
import Darwin

let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
guard let handle = dlopen(path, RTLD_LAZY) else { fatalError("dlopen failed") }
guard let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { fatalError("no symbol") }
typealias Get = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
let get = unsafeBitCast(sym, to: Get.self)
var hits = 0
get(DispatchQueue.global()) { raw in
    hits += 1
    let info = raw as? [String: Any] ?? [:]
    print("callback #\(hits) keys=\(info.count)")
    if info.isEmpty { return }
    print("keys:", info.keys.sorted().joined(separator: ", "))
    for (k, v) in info.sorted(by: { $0.key < $1.key }) {
        if let d = v as? Data { print("\(k): Data(\(d.count))"); continue }
        print("\(k): \(String(describing: v).prefix(200))")
    }
    if let sym2 = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
        typealias GetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
        unsafeBitCast(sym2, to: GetPID.self)(DispatchQueue.global()) { pid in
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
            print("app:", name, "pid:", pid)
            exit(0)
        }
    } else { exit(0) }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
print("done, callbacks:", hits)
