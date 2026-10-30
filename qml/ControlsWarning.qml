import QtQuick

// T45: a chip on the camera page when Core's check of ~/apertar-hardware.conf finds errors. The fix is in the
// WebUI (Settings > Controls or Config); this only says so.
Rectangle {
    id: root
    property int errors: 0
    height: 30
    width: label.implicitWidth + height
    radius: height / 2
    color: "#e63b2a13"
    border.width: 1
    border.color: "#bfaa7937"

    Accessible.role: Accessible.StaticText
    Accessible.name: label.text

    FontLoader { id: interBold; source: "qrc:/qml/fonts/Inter/Inter-Bold.ttf" }

    Text {
        id: label
        anchors.centerIn: parent
        text: "Controls: " + root.errors + (root.errors === 1 ? " error" : " errors")
        color: "#ffd27a"
        font.family: interBold.font.family
        font.weight: Font.Bold
        font.pixelSize: Math.round(root.height * 0.45)
        renderType: Text.NativeRendering
    }
}
