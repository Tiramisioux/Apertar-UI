import QtQuick

// Content of the "Clip Names" card (Settings > Record): how the clip folder and file names are
// composed. The pattern is a Core template string such as "{format}_{date}_{clip}". It is parsed
// into `partsModel` (one ListModel row per pill: partKind "token", "text" or "sep", plus partValue),
// edited as pills, and serialised back to the string for Core. Edits auto-save after a short pause.
Item {
    id: card

    property var bridge: null
    readonly property bool editable: !!bridge && !bridge.recording

    // Asks the owner to open the text keyboard; `current` is the existing text when editing a pill.
    signal textRequested(string current)

    property bool largeLandscape: typeof displayConfigBridge !== "undefined"
                                  && displayConfigBridge.uiLayout === "landscape_large"
    property bool standardLandscape: typeof displayConfigBridge !== "undefined"
                                     && displayConfigBridge.uiLayout === "landscape"
    readonly property int pillHeight: largeLandscape ? 60 : (standardLandscape ? 46 : 40)
    readonly property int pillFontSize: largeLandscape ? 22 : (standardLandscape ? 16 : 14)

    readonly property var presetList: [
        { label: "Standard", template: "{format}_{date}_{clip}_{tc}" },   // Core clipname::kStandardTemplate
        { label: "Original", template: "{format}_{date}_{clip}" },
        { label: "Time of day, dashes", template: "{format}_{date_}_{tc-}_{clip}" },
        { label: "Time of day, compact", template: "{format}_{date_}_{tc}_{clip}" }
    ]
    readonly property var paletteGroups: [
        { title: "Time", kind: "token", items: ["date", "date_", "yy", "mm", "dd", "time", "time-", "tc", "tc-"] },
        { title: "Camera", kind: "token", items: ["cam", "sensor", "model"] },
        { title: "Format", kind: "token", items: ["format", "clip", "res", "fps", "bits", "comp", "log"] },
        { title: "Text", kind: "text", items: ["Text…"] },
        { title: "Separators", kind: "sep", items: ["_", "-", "."] }
    ]
    readonly property int textMaxLength: 24

    property string currentTemplate: ""     // serialisation of partsModel
    property int selectedIndex: -1
    property bool dragActive: false
    property string dragSource: ""          // "row" or "palette"
    property int dragFrom: -1
    property string dragPartKind: ""
    property string dragPartValue: ""
    property string dragLabel: ""
    property int dropIndex: -1              // insertion slot under the ghost, -1 = outside the row
    property bool dragTravelled: false
    property real dragStartX: 0
    property real dragStartY: 0
    property int textEditIndex: -1          // >= 0: the text pill being edited
    property int textInsertIndex: -1        // >= 0: where a new text pill goes, -1 = at the end

    readonly property bool dirty: !!bridge && currentTemplate !== bridge.clipNameTemplate
    readonly property bool matchesNoPreset: {
        for (var i = 0; i < presetList.length; ++i) {
            if (presetList[i].template === currentTemplate)
                return false
        }
        return true
    }

    implicitHeight: content.implicitHeight
    height: implicitHeight

    ListModel { id: partsModel }

    // ----- template string <-> parts -----

    function isKnownToken(name) {
        for (var g = 0; g < paletteGroups.length; ++g) {
            if (paletteGroups[g].kind === "token" && paletteGroups[g].items.indexOf(name) >= 0)
                return true
        }
        return false
    }

    function parseTemplate(text) {
        var out = []
        var i = 0
        while (i < text.length) {
            var c = text.charAt(i)
            if (c === "{") {
                var end = text.indexOf("}", i)
                if (end < 0)
                    break
                var body = text.substring(i + 1, end)
                if (body.indexOf("text:") === 0) {
                    var t = card.sanitizeText(body.substring(5))
                    if (t.length > 0)
                        out.push({ partKind: "text", partValue: t })
                } else if (card.isKnownToken(body)) {
                    out.push({ partKind: "token", partValue: body })
                }
                i = end + 1
            } else {
                if (c === "_" || c === "-" || c === ".")
                    out.push({ partKind: "sep", partValue: c })
                i += 1
            }
        }
        return out
    }

    function serialize() {
        var s = ""
        for (var i = 0; i < partsModel.count; ++i) {
            var part = partsModel.get(i)
            if (part.partKind === "token")
                s += "{" + part.partValue + "}"
            else if (part.partKind === "text")
                s += "{text:" + part.partValue + "}"
            else
                s += part.partValue
        }
        return s
    }

    function sanitizeText(text) {
        return String(text).replace(/[^A-Za-z0-9._-]/g, "").substring(0, card.textMaxLength)
    }

    function hasClipToken() {
        for (var i = 0; i < partsModel.count; ++i) {
            var part = partsModel.get(i)
            if (part.partKind === "token" && part.partValue === "clip")
                return true
        }
        return false
    }

    function loadFromTemplate(text) {
        var parsed = card.parseTemplate(text || "")
        partsModel.clear()
        for (var i = 0; i < parsed.length; ++i)
            partsModel.append(parsed[i])
        card.selectedIndex = -1
        card.currentTemplate = card.serialize()
    }

    function syncFromBridge(force) {
        if (!card.bridge || card.dragActive)
            return
        if (!force && saveTimer.running)
            return
        if (card.bridge.clipNameTemplate !== card.currentTemplate)
            card.loadFromTemplate(card.bridge.clipNameTemplate)
    }

    // ----- editing -----

    function changed() {
        card.currentTemplate = card.serialize()
        previewTimer.restart()
        saveTimer.restart()
    }

    function saveNow() {
        saveTimer.stop()
        previewTimer.stop()
        if (!card.bridge || !card.editable)
            return
        if (!card.hasClipToken()) {
            // {clip} is required; add it here so the row shows what Core will store.
            if (partsModel.count > 0)
                partsModel.append({ partKind: "sep", partValue: "_" })
            partsModel.append({ partKind: "token", partValue: "clip" })
        }
        card.currentTemplate = card.serialize()
        if (card.currentTemplate !== card.bridge.clipNameTemplate)
            card.bridge.applyClipNameTemplate(card.currentTemplate)
    }

    function applyPreset(text) {
        if (!card.editable)
            return
        card.loadFromTemplate(text)
        card.saveNow()
    }

    function insertPart(index, kind, value) {
        if (kind === "token" && value === "clip" && card.hasClipToken())
            return   // one clip number is enough
        var at = (index < 0 || index > partsModel.count) ? partsModel.count : index
        partsModel.insert(at, { partKind: kind, partValue: value })
        card.selectedIndex = at
        card.changed()
    }

    function removePart(index) {
        if (index < 0 || index >= partsModel.count)
            return
        var part = partsModel.get(index)
        if (part.partKind === "token" && part.partValue === "clip")
            return   // the clip number cannot be removed
        partsModel.remove(index)
        card.selectedIndex = -1
        card.changed()
    }

    function movePart(from, to) {
        if (from < 0 || from >= partsModel.count || to < 0 || to >= partsModel.count || from === to)
            return
        partsModel.move(from, to, 1)
        card.selectedIndex = to
        card.changed()
    }

    function requestText(editIndex, insertIndex) {
        card.textEditIndex = editIndex
        card.textInsertIndex = insertIndex
        card.textRequested(editIndex >= 0 ? partsModel.get(editIndex).partValue : "")
    }

    // Called by the owner with the text the user typed.
    function acceptText(text) {
        var t = card.sanitizeText(text)
        if (t.length === 0)
            return
        if (card.textEditIndex >= 0 && card.textEditIndex < partsModel.count) {
            partsModel.setProperty(card.textEditIndex, "partValue", t)
            card.selectedIndex = card.textEditIndex
            card.changed()
        } else {
            card.insertPart(card.textInsertIndex, "text", t)
        }
        card.textEditIndex = -1
        card.textInsertIndex = -1
    }

    function paletteTapped(kind, value) {
        if (!card.editable)
            return
        if (kind === "text")
            card.requestText(-1, -1)
        else
            card.insertPart(-1, kind, value)
    }

    // ----- drag and drop -----

    // Insertion slot for a point in rowFlow coordinates: before the first pill whose centre is
    // after the point on its line, else after the last pill.
    function indexAt(px, py) {
        var n = partsModel.count
        for (var i = 0; i < n; ++i) {
            var item = rowRepeater.itemAt(i)
            if (!item)
                continue
            if (py < item.y)
                return i
            if (py < item.y + item.height && px < item.x + item.width / 2)
                return i
        }
        return n
    }

    function beginDrag(source, index, pillItem, kind, value, label, mx, my) {
        if (!card.editable)
            return
        card.dragSource = source
        card.dragFrom = index
        card.dragPartKind = kind
        card.dragPartValue = value
        card.dragLabel = label
        ghost.width = pillItem.width
        ghost.height = pillItem.height
        var p = pillItem.mapToItem(card, mx, my)
        card.dragStartX = p.x
        card.dragStartY = p.y
        card.dragTravelled = false
        card.dropIndex = -1
        ghost.x = p.x - ghost.width / 2
        ghost.y = p.y - ghost.height / 2
        card.dragActive = true
    }

    function moveDrag(pillItem, mx, my) {
        if (!card.dragActive)
            return
        var p = pillItem.mapToItem(card, mx, my)
        ghost.x = p.x - ghost.width / 2
        ghost.y = p.y - ghost.height / 2
        if (Math.abs(p.x - card.dragStartX) + Math.abs(p.y - card.dragStartY) > card.pillHeight)
            card.dragTravelled = true
    }

    function endDrag(canceled) {
        if (!card.dragActive)
            return
        var idx = card.dropIndex
        var from = card.dragFrom
        var source = card.dragSource
        var travelled = card.dragTravelled
        var kind = card.dragPartKind
        var value = card.dragPartValue
        card.dragActive = false
        card.dropIndex = -1
        card.dragFrom = -1
        if (canceled)
            return
        if (source === "row") {
            if (idx >= 0) {
                var to = idx > from ? idx - 1 : idx
                card.movePart(from, to)
            } else if (travelled) {
                card.removePart(from)   // dragged out of the row
            }
        } else if (idx >= 0) {
            if (kind === "text")
                card.requestText(-1, idx)
            else
                card.insertPart(idx, kind, value)
        }
    }

    Component.onCompleted: card.loadFromTemplate(card.bridge ? card.bridge.clipNameTemplate : "")

    Connections {
        target: card.bridge
        function onClipNameChanged() { card.syncFromBridge(false) }
        function onRecordingChanged() {
            if (card.bridge && !card.bridge.recording) {
                saveTimer.stop()
                previewTimer.stop()
                card.syncFromBridge(true)
            }
        }
    }

    // Preview first (cheap, no side effects), save a little later.
    Timer {
        id: previewTimer
        interval: 350
        onTriggered: {
            if (card.bridge && card.editable && card.currentTemplate.length > 0)
                card.bridge.requestClipNamePreview(card.currentTemplate)
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: card.saveNow()
    }

    Column {
        id: content
        width: card.width
        spacing: 10

        Text {
            width: parent.width
            text: "Pattern"
            color: "white"
            font.pixelSize: 14
        }

        Flow {
            width: parent.width
            spacing: 12

            Repeater {
                model: card.presetList

                ActionTile {
                    required property var modelData
                    width: (content.width - 12) / 2
                    label: modelData.label
                    tone: card.currentTemplate === modelData.template ? "accent" : "default"
                    actionEnabled: card.editable
                    onClicked: card.applyPreset(modelData.template)
                }
            }
        }

        Text {
            width: parent.width
            text: card.matchesNoPreset ? "Custom pattern" : " "
            color: "#9aa5b1"
            font.pixelSize: 12
        }

        // The pattern row: pills in order, a drop target for dragged pills.
        Rectangle {
            id: rowFrame
            width: parent.width
            height: Math.max(rowFlow.implicitHeight, card.pillHeight) + 16
            radius: 14
            color: "#101010"
            border.width: 1
            border.color: card.dragActive && card.dropIndex >= 0 ? "#3fd0ff" : "#1affffff"

            DropArea {
                id: clipDrop
                anchors.fill: parent
                onPositionChanged: function(drag) {
                    card.dropIndex = card.indexAt(drag.x - rowFlow.x, drag.y - rowFlow.y)
                }
                onEntered: function(drag) {
                    card.dropIndex = card.indexAt(drag.x - rowFlow.x, drag.y - rowFlow.y)
                }
                onExited: card.dropIndex = -1
            }

            Text {
                visible: partsModel.count === 0
                anchors.centerIn: parent
                text: "Tap or drag pills here"
                color: "#66ffffff"
                font.pixelSize: 13
            }

            Flow {
                id: rowFlow
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 8

                Repeater {
                    id: rowRepeater
                    model: partsModel

                    ClipNamePill {
                        id: rowPill
                        required property int index
                        required property string partKind
                        required property string partValue
                        kind: partKind
                        label: partValue
                        pillHeight: card.pillHeight
                        fontSize: card.pillFontSize
                        emphasis: partKind === "token" && partValue === "clip"
                        removable: !emphasis
                        selected: card.selectedIndex === index
                        pillEnabled: card.editable
                        dimmed: card.dragActive && card.dragSource === "row" && card.dragFrom === index
                        onTapped: card.selectedIndex = (card.selectedIndex === index ? -1 : index)
                        onRemoveRequested: card.removePart(index)
                        onDragStarted: function(mx, my) {
                            card.beginDrag("row", index, rowPill, partKind, partValue, partValue, mx, my)
                        }
                        onDragMoved: function(mx, my) { card.moveDrag(rowPill, mx, my) }
                        onDragFinished: function(mx, my, canceled) { card.endDrag(canceled) }
                    }
                }
            }

            // Where a dropped pill would land.
            Rectangle {
                visible: card.dragActive && card.dropIndex >= 0
                width: 3
                radius: 1
                color: "#3fd0ff"
                height: card.pillHeight
                x: {
                    var n = partsModel.count
                    if (n === 0)
                        return rowFlow.x
                    var target = rowRepeater.itemAt(Math.min(card.dropIndex, n - 1))
                    if (!target)
                        return rowFlow.x
                    return rowFlow.x + (card.dropIndex < n ? target.x - 5 : target.x + target.width + 3)
                }
                y: {
                    var n = partsModel.count
                    if (n === 0)
                        return rowFlow.y
                    var target = rowRepeater.itemAt(Math.min(card.dropIndex, n - 1))
                    return rowFlow.y + (target ? target.y : 0)
                }
            }
        }

        // Fallback to dragging: act on the selected pill.
        Flow {
            width: parent.width
            spacing: 12
            visible: card.selectedIndex >= 0 && card.selectedIndex < partsModel.count

            ActionTile {
                width: (content.width - 36) / 4
                label: "◀"
                actionEnabled: card.editable && card.selectedIndex > 0
                onClicked: card.movePart(card.selectedIndex, card.selectedIndex - 1)
            }

            ActionTile {
                width: (content.width - 36) / 4
                label: "▶"
                actionEnabled: card.editable && card.selectedIndex >= 0 && card.selectedIndex < partsModel.count - 1
                onClicked: card.movePart(card.selectedIndex, card.selectedIndex + 1)
            }

            ActionTile {
                width: (content.width - 36) / 4
                label: "Edit text"
                actionEnabled: card.editable && card.selectedIndex >= 0 && card.selectedIndex < partsModel.count
                               && partsModel.get(card.selectedIndex).partKind === "text"
                onClicked: card.requestText(card.selectedIndex, -1)
            }

            ActionTile {
                width: (content.width - 36) / 4
                label: "Remove"
                actionEnabled: card.editable && card.selectedIndex >= 0 && card.selectedIndex < partsModel.count
                               && !(partsModel.get(card.selectedIndex).partKind === "token"
                                    && partsModel.get(card.selectedIndex).partValue === "clip")
                onClicked: card.removePart(card.selectedIndex)
            }
        }

        Text {
            width: parent.width
            text: card.bridge
                  ? "Next clip: " + (card.dirty && card.bridge.clipNamePreview !== ""
                                     ? card.bridge.clipNamePreview : card.bridge.clipNameExample)
                  : ""
            color: "white"
            font.pixelSize: 14
            wrapMode: Text.WrapAnywhere
        }

        Text {
            width: parent.width
            text: card.editable
                  ? "Hold a pill to drag it. Tap a pill below to add it, tap a pill above to select it. The clip number is always kept."
                  : "Locked while recording"
            color: "#9aa5b1"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: card.paletteGroups

            Column {
                id: groupColumn
                required property var modelData
                width: content.width
                spacing: 6
                opacity: card.editable ? 1.0 : 0.45

                Text {
                    text: groupColumn.modelData.title
                    color: "#9aa5b1"
                    font.pixelSize: 12
                }

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: groupColumn.modelData.items

                        ClipNamePill {
                            id: palettePill
                            required property string modelData
                            label: modelData
                            kind: groupColumn.modelData.kind
                            pillHeight: card.pillHeight
                            fontSize: card.pillFontSize
                            emphasis: modelData === "clip"
                            pillEnabled: card.editable
                            onTapped: card.paletteTapped(kind, modelData)
                            onDragStarted: function(mx, my) {
                                card.beginDrag("palette", -1, palettePill, kind, modelData, label, mx, my)
                            }
                            onDragMoved: function(mx, my) { card.moveDrag(palettePill, mx, my) }
                            onDragFinished: function(mx, my, canceled) { card.endDrag(canceled) }
                        }
                    }
                }
            }
        }
    }

    // The pill that follows the finger. Its Drag drives the DropArea of the pattern row.
    Rectangle {
        id: ghost
        visible: card.dragActive
        z: 100
        radius: height / 2
        color: "#123d59"
        border.width: 1
        border.color: "#3fd0ff"
        opacity: 0.9
        Drag.active: card.dragActive
        Drag.dragType: Drag.Internal
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Text {
            anchors.centerIn: parent
            text: card.dragLabel
            color: "#e2f6ff"
            font.pixelSize: card.pillFontSize
            renderType: Text.NativeRendering
        }
    }
}
