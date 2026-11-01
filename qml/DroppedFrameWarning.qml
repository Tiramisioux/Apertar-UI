import QtQuick

Rectangle {
    id: root
    // The take's dropped frames; 0 (an older Core sends no count) shows "!".
    property int count: 0
    width: Math.max(height, Math.ceil(label.implicitWidth + height * 0.6))
    height: 30
    radius: height / 2
    color: "#e63b2a13"
    border.width: 1
    border.color: "#bfaa7937"

    Accessible.role: Accessible.StaticText
    Accessible.name: count > 0 ? count + " dropped frames" : "Dropped frames detected"

    FontLoader { id: interBold; source: "qrc:/qml/fonts/Inter/Inter-Bold.ttf" }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.count > 0 ? String(root.count) : "!"
        color: "#ffd27a"
        font.family: interBold.font.family
        font.weight: Font.Bold
        font.pixelSize: Math.round(root.height * (root.count > 0 ? 0.56 : 0.68))
        renderType: Text.NativeRendering
    }
}
