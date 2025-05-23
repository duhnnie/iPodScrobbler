import Foundation
import iPodReader
import LastFM

let semaphore = DispatchSemaphore(value: 0)

var preferencesFileURL = URL(fileURLWithPath: "/users/daniel/Documents", isDirectory: true)
preferencesFileURL.appendPathComponent("iPodReaderProject", isDirectory: true)
preferencesFileURL.appendPathComponent("Preferences", isDirectory: false)

var playCountsFileURL = URL(fileURLWithPath: "/users/daniel/Documents", isDirectory: true)
playCountsFileURL.appendPathComponent("iPodReaderProject", isDirectory: true)
playCountsFileURL.appendPathComponent("Play Counts", isDirectory: false)

var fileURL = URL(fileURLWithPath: "/users/daniel/Documents", isDirectory: true)
fileURL.appendPathComponent("iPodReaderProject", isDirectory: true)
fileURL.appendPathComponent("iTunesDB", isDirectory: false)

let preferences = try iPodReader.Preferences(fileURL: preferencesFileURL)
print("offset: \(preferences.timeOffsetInSeconds)")

let iTunesDB = try iPodReader.ITunesDB(fileURL: fileURL)
let playCountsDB = try iPodReader.PlayCountsDB(fileURL: playCountsFileURL)
let playedTracks = try playCountsDB.getPlayedTracks(database: iTunesDB)

let sortedPlayedTracks: [PlayCountsDB.TrackPlayCount] = playedTracks.sorted { trackA, trackB in
    return trackA.playcount.lastPlayed < trackB.playcount.lastPlayed
}.reduce([PlayCountsDB.TrackPlayCount]()) { partialResult, trackPlayCount in
    var partialResult = partialResult
    let playcount = trackPlayCount.playcount
    let track = trackPlayCount.track
    
    for i in (0...trackPlayCount.playcount.playCount - 1).reversed() {
        let newPlaycount = iPodReader.PlayCountEntry(
            playcount: playcount.playCount,
            lastPlayed: playcount.lastPlayed - (i  * (track.length / 1000)),
            audioBookmark: playcount.audioBookmark,
            rating: playcount.rating,
            skipCount: playcount.skipCount,
            lastSkipped: playcount.lastSkipped
        )
        
        partialResult.append((
            trackPlayCount.track,
            newPlaycount
        ))
    }
    
    return partialResult
}

let lastFM = LastFM(apiKey: "API_KEY", apiSecret: "API_SECRET")
let sessionKey = "SESSION_KEY"
var scrobbleParams = ScrobbleParams()
// 2024-09-05 11:05:44 +0000
let lastScrobble = DateComponents(calendar: .current, timeZone: .init(secondsFromGMT: 0), year: 2025, month: 4, day: 25, hour: 3, minute: 28, second: 37).date!

for (track, playcount) in sortedPlayedTracks {
    let rawDate = Date(timeIntervalSince1970: TimeInterval(playcount.lastPlayed - 2082844800))
    let lastPlayed = rawDate.addingTimeInterval(TimeInterval(TimeZone.current.secondsFromGMT()) * -1)
    
    if ![TrackItem.MediaType.Audio, TrackItem.MediaType.MusicVideo].contains(track.mediaType) || lastPlayed <= lastScrobble {
        continue
    }
    
    let trackStrings = try track.getItems()
    
    guard
        let artist = trackStrings.first(where: { $0.type == DataObject.DataObjectType.artist }),
        let title = trackStrings.first(where: { $0.type == DataObject.DataObjectType.title })
    else {
        print("Error")
        exit(EX_OK)
    }
    
    let album = trackStrings.first { $0.type == DataObject.DataObjectType.album }
    let albumArtist = trackStrings.first { $0.type == DataObject.DataObjectType.albumArtist }
    
    print("\(playcount.playCount) - \(artist.value) - \"\(title.value)\" - \(lastPlayed)")
    
    let scrobbleItem = ScrobbleParamItem(
        artist: artist.value,
        track: title.value,
        date: lastPlayed,
        album: album?.value,
        context: nil,
        streamId: nil,
        chosenByUser: nil,
        trackNumber: UInt(track.trackNumber),
        mbid: nil,
        albumArtist: albumArtist?.value,
        duration: UInt(track.length / 1000)
    )

    try scrobbleParams.addItem(item: scrobbleItem)

    if scrobbleParams.count == 50 {
        let tracksToScrobble = scrobbleParams.count

        print("scrobbling \(tracksToScrobble) tracks...")

        try lastFM.Track.scrobble(params: scrobbleParams, sessionKey: sessionKey) { result in
            switch (result) {

            case .success(_):
                print("scrobbled \(tracksToScrobble)")
            case .failure(let error):
                print("error for \(tracksToScrobble) : \(error)")
            }

            semaphore.signal()
        }
    
        semaphore.wait()
        scrobbleParams.clearItems()
    }
}

if scrobbleParams.count > 0 {
    let tracksToScrobble = scrobbleParams.count

    print("scrobbling \(tracksToScrobble) tracks...")

    try lastFM.Track.scrobble(params: scrobbleParams, sessionKey: sessionKey) { result in
        switch (result) {

        case .success(_):
            print("scrobbled \(tracksToScrobble)")
        case .failure(let error):
            print("error for \(tracksToScrobble) : \(error)")
        }

        semaphore.signal()
    }
    
    semaphore.wait()
}

print("Program ended")
