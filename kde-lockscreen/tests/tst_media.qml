import QtQuick
import QtTest
import QtMultimedia

// Mirrors what manage.py's adapt_media writes into a theme's MediaPlayer: the
// source is empty until LockScreen.qml sets qylockMediaAllowed, and playback
// starts each time it becomes allowed (autoPlay alone fires only once).
TestCase {
    id: test
    name: "DeferredThemeMedia"
    when: windowShown
    width: 320
    height: 180
    property bool qylockMediaAllowed: false
    property var holder: null
    property var player: holder ? holder.player : null

    function init() {
        qylockMediaAllowed = false;
        holder = Qt.createQmlObject(`
            import QtQuick
            import QtMultimedia
            Item {
                property alias player: mediaplayer
                anchors.fill: parent
                MediaPlayer {
                    id: mediaplayer
                    readonly property bool qylockMediaGate: qylockMediaAllowed; onQylockMediaGateChanged: if (qylockMediaGate) Qt.callLater(() => play());
                    source: (qylockMediaAllowed ? ("bg.mp4") : "")
                    loops: MediaPlayer.Infinite
                    videoOutput: videoOutput
                }
                VideoOutput { id: videoOutput; anchors.fill: parent }
            }`, test, Qt.resolvedUrl("../../themes/pixel-munchlax/BackgroundVideo.qml"));
    }

    function cleanup() {
        holder.destroy();
        holder = null;
    }

    function test_no_decoder_until_allowed() {
        wait(200);
        compare(String(player.source), "");
        compare(player.mediaStatus, MediaPlayer.NoMedia);
        compare(player.playbackState, MediaPlayer.StoppedState);
    }

    function test_allowing_starts_and_disallowing_unloads() {
        qylockMediaAllowed = true;
        verify(String(player.source).endsWith("bg.mp4"), String(player.source));
        tryCompare(player, "playbackState", MediaPlayer.PlayingState, 5000);

        qylockMediaAllowed = false;
        tryCompare(player, "playbackState", MediaPlayer.StoppedState, 5000);
        compare(player.mediaStatus, MediaPlayer.NoMedia);

        // Re-arming after resume must restart playback, not only the first load.
        qylockMediaAllowed = true;
        tryCompare(player, "playbackState", MediaPlayer.PlayingState, 5000);
    }
}
