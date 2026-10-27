import AppKit
import Darwin

enum SystemNowPlaying {
    static func read() async -> MusicState? {
        await MainActor.run { readSync() }
    }

    static func readSync() -> MusicState? {
        guard let info = MediaRemoteFetch.dictionary() else { return nil }
        guard let handle = MediaRemoteFetch.mediaHandle() else { return nil }
        let title = string(info, handle, "kMRMediaRemoteNowPlayingInfoTitle")
            ?? string(info, handle, "kMRMediaRemoteNowPlayingInfoAlbum")
        guard let title, !title.isEmpty else { return nil }
        let artist = string(info, handle, "kMRMediaRemoteNowPlayingInfoArtist") ?? ""
        let rate = (info[MediaRemoteFetch.key(handle, "kMRMediaRemoteNowPlayingInfoPlaybackRate")] as? NSNumber)?.doubleValue ?? 0
        let elapsed = number(info[MediaRemoteFetch.key(handle, "kMRMediaRemoteNowPlayingInfoElapsedTime")])
        let duration = number(info[MediaRemoteFetch.key(handle, "kMRMediaRemoteNowPlayingInfoDuration")])
        let art = info[MediaRemoteFetch.key(handle, "kMRMediaRemoteNowPlayingInfoArtworkData")] as? Data
        let source = MediaRemoteFetch.playingAppName() ?? "Now Playing"
        return MusicState(
            source: source, title: title, artist: artist, playing: rate > 0,
            elapsed: elapsed, duration: duration, art: art
        )
    }

    static func send(_ command: UInt32) {
        guard let handle = MediaRemoteFetch.mediaHandle(),
              let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else { return }
        typealias Send = @convention(c) (UInt32, CFDictionary?) -> Bool
        _ = unsafeBitCast(symbol, to: Send.self)(command, nil)
    }

    static func seek(_ seconds: Double) {
        guard let handle = MediaRemoteFetch.mediaHandle(),
              let symbol = dlsym(handle, "MRMediaRemoteSetElapsedTime") else { return }
        typealias Seek = @convention(c) (Double) -> Void
        unsafeBitCast(symbol, to: Seek.self)(seconds)
    }

    private static func string(_ info: [String: Any], _ handle: UnsafeMutableRawPointer, _ name: String) -> String? {
        let value = info[MediaRemoteFetch.key(handle, name)] as? String
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func number(_ any: Any?) -> Double {
        (any as? NSNumber)?.doubleValue ?? 0
    }
}
