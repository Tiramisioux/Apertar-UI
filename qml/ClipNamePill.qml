import QtQuick

// One rounded chip of the clip-name pattern. Used both in the pattern row and in the palette.
// A tap emits tapped(); a long press starts a drag (dragStarted/dragMoved/dragFinished carry
// pill-local mouse coordinates, the owner moves the ghost and decides what a drop means).
// A plain swipe before the long press is left to the page Flickable, so the page still scrolls.
Rectangle {
    id: pill

    property string label: ""
    property string kind: "token"     // "token", "text", "sep" or "action"
    property bool emphasis: false     // the clip number: accent colour, no remove button
    property bool selected: false
    property bool removable: false    // shows the x button
    property bool pillEnabled: true
    property bool dimmed: false       // the source pill while it is being dragged
    property int pillHeight: 40
    property int fontSize: 14
    signal tapped()
    signal removeRequested()
    signal dragStarted(real mx, real my)
    signal dragMoved(real mx, real my)
    signal dragFinished(real mx, real my, bool canceled)

    readonly property int horizontalPadding: Math.round(pillHeight * 0.4)
    readonly property int removeWidth: removable ? Math.round(pillHeight * 0.9) : 0

    height: pillHeight
    width: Math.max(pillHeight, horizontalPadding + labelText.implicitWidth + (removable ? removeWidth : horizontalPadding))
    radius: height / 2
    color: bodyArea.pressed && pill.pillEnabled
           ? "#24ffffff"
           : (pill.emphasis ? "#123d59" : (pill.kind === "text" ? "#1d2a1d" : "#171717"))
    border.width: pill.selected ? 2 : 1
    border.color: pill.selected ? "#e0b447"
                  : (pill.emphasis ? "#3fd0ff" : (pill.kind === "text" ? "#6cc070" : "#1affffff"))
    opacity: pill.pillEnabled ? (pill.dimmed ? 0.3 : 1.0) : 0.45

    FontLoader { id: interMedium; source: "qrc:/qml/fonts/Inter/Inter-Medium.ttf" }

    Text {
        id: labelText
        x: Math.max(pill.horizontalPadding, (pill.width - labelText.implicitWidth - pill.removeWidth) / 2)
        anchors.verticalCenter: parent.verticalCenter
        text: pill.label
        color: pill.emphasis ? "#e2f6ff" : "white"
        font.family: interMedium.font.family
        font.pixelSize: pill.fontSize
        font.italic: pill.kind === "text"
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: bodyArea
        anchors.fill: parent
        enabled: pill.pillEnabled
        pressAndHoldInterval: 350
        property bool holding: false

        onPressAndHold: {
            holding = true
            preventStealing = true   // from now on the page Flickable must not take the drag
            pill.dragStarted(mouseX, mouseY)
        }
        onPositionChanged: {
            if (holding)
                pill.dragMoved(mouseX, mouseY)
        }
        onReleased: {
            if (!holding)
                return
            preventStealing = false
            pill.dragFinished(mouseX, mouseY, false)
            // holding stays true until after clicked() would have fired, so a drag never taps
            releaseReset.restart()
        }
        onCanceled: {
            if (!holding)
                return
            preventStealing = false
            holding = false
            pill.dragFinished(mouseX, mouseY, true)
        }
        onClicked: {
            if (!holding)
                pill.tapped()
        }
    }

    Timer {
        id: releaseReset
        interval: 0
        onTriggered: bodyArea.holding = false
    }

    MouseArea {
        id: removeArea
        visible: pill.removable
        enabled: pill.pillEnabled && pill.removable
        width: pill.removeWidth
        height: parent.height
        anchors.right: parent.right
        z: 2
        onClicked: pill.removeRequested()

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#c8ccd2"
            font.family: interMedium.font.family
            font.pixelSize: pill.fontSize + 4
            renderType: Text.NativeRendering
        }
    }
}
