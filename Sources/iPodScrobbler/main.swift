import Foundation
import iPodReader
import LastFM

var playCountsFileURL = URL(fileURLWithPath: "/users/daniel/Documents", isDirectory: true)
playCountsFileURL.appendPathComponent("iPodReaderProject", isDirectory: true)
playCountsFileURL.appendPathComponent("Play Counts", isDirectory: false)

var fileURL = URL(fileURLWithPath: "/users/daniel/Documents", isDirectory: true)
fileURL.appendPathComponent("iPodReaderProject", isDirectory: true)
fileURL.appendPathComponent("iTunesDB", isDirectory: false)

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

let lastFM = LastFM(apiKey: "7c7122a665cd094a27b30ed568b1d22f", apiSecret: "ffbbc1e211fbe62e2f006c0821d1bf5f")
let sessionKey = "XNzCkbhBuY9EtwPjjrySL5DxgcuuvqeM"
var scrobbleParams = ScrobbleParams()
// 2024-09-05 11:05:44 +0000
let lastScrobble = DateComponents(calendar: .current, timeZone: .init(secondsFromGMT: 0), year: 2024, month: 11, day: 07, hour: 21, minute: 01, second: 11).date!.timeIntervalSince1970 + 2082844800

for (track, playcount) in sortedPlayedTracks {
    if ![TrackItem.MediaType.Audio, TrackItem.MediaType.MusicVideo].contains(track.mediaType) || playcount.lastPlayed <= UInt32(lastScrobble) {
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
    
    let rawDate = Date(timeIntervalSince1970: TimeInterval(playcount.lastPlayed - 2082844800))
    let lastPlayed = rawDate.addingTimeInterval(TimeInterval(TimeZone.current.secondsFromGMT()) * -1)
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
        }
    
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

    }
}

RunLoop.main.run()
