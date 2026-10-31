import QtQuick

Rectangle {
    id: root

    FontLoader { id: interBold;    source: "qrc:/qml/fonts/Inter/Inter-Bold.ttf" }

    property bool recording: false
    property bool timelapse: false
    property bool writing: false
    property bool storagePreroll: false // storage pre-roll running: blue PRE-ROLL pill unless really recording
    property bool mediaMounted: true
    property real backgroundOpacity: 1.0
    property bool compact: false
    property bool largeCompact: false
    property bool extraLargeCompact: false
    property bool oversizedCompact: false
    property bool darkBackground: false
    property bool useControlBackground: false
    property real bufferFill: 0.0
    property bool bufferBarVisible: false
    property bool bufferDrain: false // safety stop: pill is READY green, text hidden, bar green and emptying

    readonly property bool noMedia: !mediaMounted
    readonly property bool activeCapture: recording || timelapse
    readonly property bool prerollOnly: storagePreroll && !activeCapture
    readonly property real chipScale: compact ? (oversizedCompact ? 1.38 : (extraLargeCompact ? 1.16 : (largeCompact ? 0.96 : 0.80))) : 1.0
    readonly property int dotContainerSize: compact ? (oversizedCompact ? 18 : (extraLargeCompact ? 15 : (largeCompact ? 12 : 10))) : 12
    readonly property int dotSize: compact ? (oversizedCompact ? 14 : (extraLargeCompact ? 12 : (largeCompact ? 10 : 8))) : 10
    readonly property color controlFill: darkBackground
                                         ? fadedColor(0x00, 0x00, 0x00, 0.329)
                                         : fadedColor(0xff, 0xff, 0xff, 0.141)
    readonly property color controlBorder: darkBackground
                                           ? fadedColor(0xff, 0xff, 0xff, 0.165)
                                           : fadedColor(0xff, 0xff, 0xff, 0.188)
    readonly property color stateFill: prerollOnly ? (compact ? (darkBackground
                                                                 ? fadedColor(0x0f, 0x3f, 0x8d, 0.66)
                                                                 : fadedColor(0x11, 0x46, 0xa0, 0.58))
                                                               : fadedColor(0x12, 0x4e, 0xb7, 0.50))
                                              : noMedia ? (compact ? (darkBackground
                                                             ? fadedColor(0x4a, 0x38, 0x00, 0.66)
                                                             : fadedColor(0x52, 0x3f, 0x00, 0.58))
                                                           : fadedColor(0x6b, 0x52, 0x00, 0.50))
                                                : (activeCapture ? (compact ? (darkBackground
                                                                               ? fadedColor(0x8d, 0x0f, 0x0f, 0.66)
                                                                               : fadedColor(0xa0, 0x11, 0x11, 0.58))
                                                                             : fadedColor(0xb7, 0x12, 0x12, 0.50))
                                                             : fadedColor(0x00, 0x00, 0x00, compact ? (darkBackground ? 0.58 : 0.50) : 0.44))
    readonly property color stateBorder: prerollOnly ? fadedColor(0x2b, 0x7f, 0xff, compact ? (darkBackground ? 0.52 : 0.46) : 0.40)
                                         : noMedia ? fadedColor(0xff, 0xd5, 0x4a, compact ? (darkBackground ? 0.52 : 0.46) : 0.40)
                                                  : (activeCapture ? fadedColor(0xff, 0x66, 0x66, compact ? (darkBackground ? 0.52 : 0.46) : 0.40)
                                                                   : fadedColor(0xff, 0xff, 0xff, compact ? (darkBackground ? 0.18 : 0.12) : 0.04))
    readonly property color chipFill: compact && useControlBackground ? controlFill : stateFill
    readonly property color chipBorder: compact && useControlBackground ? controlBorder : stateBorder
    readonly property bool drainOnly: bufferDrain && bufferBarVisible && !recording
    readonly property color dotFill: prerollOnly ? "#2b7fff"
                                              : noMedia ? "#ffd54a"
                                              : (activeCapture ? "#fb2c36" : writing ? "#ffd54a" : "#00c951")
    readonly property string chipLabel: prerollOnly ? "PRE-ROLL"
                                                : noMedia ? "NO MEDIA"
                                                : (timelapse ? "TIMELAPSE" : (recording ? "REC" : writing ? "WRITING" : "READY"))

    width: Math.round((prerollOnly ? 118 : noMedia ? 118 : (timelapse ? 136 : writing && !recording ? 118 : 90)) * chipScale)
    height: Math.round(30 * chipScale)
    radius: height / 2
    color: chipFill
    border.width: 1
    border.color: chipBorder
    layer.enabled: true
    layer.smooth: false

    Behavior on color {
        ColorAnimation { duration: 220 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 220 }
    }

    Behavior on width {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    function fadedColor(r, g, b, baseAlpha) {
        return Qt.rgba(r / 255.0,
                       g / 255.0,
                       b / 255.0,
                       Math.max(0.0, Math.min(1.0, baseAlpha * root.backgroundOpacity)))
    }

    // Frame buffer bar: red fill from the left, behind the dot and text (declared before the Row). A clipped Item of
    // the fill's width holds a copy of the pill's own shape, so the pill's rounded ends crop the bar.
    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: root.border.width
        width: Math.max(0, (root.width - 2 * root.border.width) * root.bufferFill)
        clip: true
        visible: root.bufferBarVisible

        Behavior on width {
            NumberAnimation { duration: 150 }
        }

        Rectangle {
            x: 0
            y: 0
            width: root.width - 2 * root.border.width
            height: root.height - 2 * root.border.width
            radius: Math.max(0, root.radius - root.border.width)
            color: root.drainOnly ? "#00c951" : "#fb2c36"
            opacity: 0.85
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.compact ? 5 : 6
        opacity: root.drainOnly ? 0.0 : 1.0

        Item {
            width: root.dotContainerSize
            height: root.dotContainerSize
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: dotGlow
                anchors.centerIn: parent
                width: root.dotContainerSize
                height: root.dotContainerSize
                radius: width / 2
                color: root.dotFill
                opacity: root.activeCapture && !root.noMedia ? 0.22 : 0.0
                visible: root.activeCapture && !root.noMedia

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: root.dotSize
                height: root.dotSize
                radius: width / 2
                color: root.dotFill

                Behavior on color {
                    ColorAnimation { duration: 180 }
                }
            }
        }

        Text {
            text: root.chipLabel
            color: "white"
            font.family: interBold.font.family
            font.weight: Font.Bold
            font.pixelSize: root.compact ? (root.oversizedCompact ? 18 : (root.extraLargeCompact ? 16 : (root.largeCompact ? 14 : 12))) : 14
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
        }
    }
}
