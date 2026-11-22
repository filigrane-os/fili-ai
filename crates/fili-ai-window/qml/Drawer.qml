// The drawer of Lia (window of Main.qml): header, conversation, input. A layer-shell surface on the right edge (org.kde.layershell, package
// layer-shell-qt) whose exclusive zone makes the windows shrink beside it, as the drawer of the shell did.
// `--window`: a normal window (the layer-shell variable is then not set, see main.rs).
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import Fili.Ai

Window {
    id: win
    readonly property int viewWidth: Chat.viewWidth
    width: viewWidth
    height: 900
    visible: Chat.open
    color: "transparent"
    title: "Lia"

    LayerShell.Window.scope: "fili-ai"
    LayerShell.Window.layer: Chat.mode === "dock" ? LayerShell.Window.LayerTop : LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
    // The same gap as between two niri windows (`gaps` of the niri config): margins on the three anchored edges, and the
    // exclusive zone counts the right one so that the windows keep that gap beside the drawer
    readonly property int gap: 16
    LayerShell.Window.margins: ({ left: 0, top: gap, right: gap, bottom: gap })
    LayerShell.Window.exclusionZone: Chat.mode === "dock" ? viewWidth + gap : 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    FontLoader { source: "qrc:/qt/qml/Fili/Ai/fonts/Jost-Variable.ttf" }
    FontLoader { source: "qrc:/qt/qml/Fili/Ai/fonts/JetBrainsMono-Variable.ttf" }
    FontLoader { source: "qrc:/qt/qml/Fili/Ai/fonts/FiliIcons.ttf" }
    Connections {
        target: Chat
        function onFocusInput() { input.forceActiveFocus(); }
    }
    onActiveChanged: Chat.focused = active

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Chat.confirmId ? Chat.confirmArchive(false) : Chat.allOpen ? Chat.allOpen = false : Chat.renaming ? Chat.renaming = false : Chat.hide()
        Keys.onPressed: e => {
            if (e.key === Qt.Key_F2) {
                Chat.startRename();
                e.accepted = true;
                return;
            }
            if (!(e.modifiers & Qt.ControlModifier))
                return;
            if (e.key === Qt.Key_N && (e.modifiers & Qt.ShiftModifier))
                Chat.act("new-here");
            else if (e.key === Qt.Key_N)
                Chat.newSession();
            else if (e.key === Qt.Key_L)
                Chat.tabsOpen = !Chat.tabsOpen;
            else if (e.key === Qt.Key_V && Chat.paste())
                e.accepted = true;
            else if (e.key === Qt.Key_Period)
                Chat.stop();
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && Chat.confirmId)
                Chat.confirmArchive(true);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                Chat.answer(Chat.log.find(i => i.kind === "ask" && i.status === "pending")?.rid ?? "", true);
            else
                return;
            e.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            radius: 8
            border { width: Theme.borderWidth; color: Theme.border }
            clip: true

            // Files dragged from an application: attached to the next message
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: d => { if (d.hasUrls) Chat.attachUrls(d.urls.map(u => u.toString())); }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header 44: title of the session, state, new session
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.headerHeight
                    color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: Theme.space3; rightMargin: Theme.space3 }
                        spacing: Theme.space2
                        Text {
                            Layout.fillWidth: true
                            visible: !Chat.renaming
                            text: Chat.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.font; pixelSize: Theme.size; weight: Theme.weightAccent }
                            MouseArea { anchors.fill: parent; onDoubleClicked: Chat.startRename() }
                        }
                        // Rename (F2 or double click): Enter keeps, Escape cancels
                        TextInput {
                            id: renameField
                            Layout.fillWidth: true
                            visible: Chat.renaming
                            text: Chat.title
                            color: Theme.text
                            selectionColor: Theme.surfaceHover
                            selectedTextColor: Theme.text
                            font { family: Theme.font; pixelSize: Theme.size; weight: Theme.weightAccent }
                            clip: true
                            onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
                            Keys.onReturnPressed: Chat.commitRename(text)
                            Keys.onEnterPressed: Chat.commitRename(text)
                            Keys.onEscapePressed: Chat.renaming = false
                        }
                        Text {
                            visible: Chat.working
                            text: Chat.waiting ? qsTr("waiting for you") : qsTr("working")
                            color: Chat.waiting ? Theme.warning : Theme.textSecondary
                            font { family: Theme.font; pixelSize: Theme.sizeSmall }
                        }
                        IconButton { glyph: "≡"; tip: qsTr("Sessions"); on: Chat.tabsOpen; onClicked: Chat.tabsOpen = !Chat.tabsOpen }
                        IconButton { glyph: "+"; tip: qsTr("New session"); onClicked: Chat.newSession() }
                        IconButton { glyph: "×"; tip: qsTr("Close"); onClicked: Chat.hide() }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.border }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Session rail (52 px): the icon of the application the session is linked to, else the glyph of its topic,
                    // else a speech bubble. Dot: waiting (danger), working (blue), finished and unread (green). Hover: the
                    // title and the application, and an × to archive.
                    Rectangle {
                        id: rail
                        visible: Chat.tabsOpen
                        Layout.fillHeight: true
                        Layout.preferredWidth: 52
                        color: Theme.backgroundDeep
                        HoverHandler { id: railHover }
                        property string tipText: ""
                        property real tipY: 0
                        ListView {
                            id: sessions
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: foot.top; rightMargin: Theme.borderWidth }
                            topMargin: Theme.space2
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: Chat.tabSessions
                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                readonly property bool sel: modelData.id === Chat.current
                                readonly property string st: Chat.states[modelData.id] ?? "idle"
                                readonly property string appKey: (modelData.link ?? "").split("\n")[0]
                                readonly property string appIcon: appKey === "" ? "" : Link.iconPath(appKey)
                                readonly property int topic: modelData.icon ?? 0
                                width: sessions.width
                                height: 48
                                color: sel || rowHover.hovered ? Theme.surfaceHover : "transparent"
                                HoverHandler {
                                    id: rowHover
                                    onHoveredChanged: {
                                        if (hovered) {
                                            rail.tipText = (row.modelData.title || qsTr("New session")) + (row.appKey !== "" ? "\n" + row.appKey : "");
                                            rail.tipY = row.mapToItem(rail, 0, 0).y;
                                        }
                                    }
                                }
                                Image {
                                    anchors.centerIn: parent
                                    width: 28; height: 28
                                    visible: row.topic === 0 && row.appIcon !== ""
                                    source: row.appIcon !== "" ? "file://" + row.appIcon : ""
                                    sourceSize: Qt.size(56, 56)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: row.topic !== 0 || row.appIcon === ""
                                    text: String.fromCodePoint(row.topic !== 0 ? row.topic : 0xF05A3)
                                    color: row.sel ? Theme.text : Theme.textSecondary
                                    font { family: Theme.icons; pixelSize: 24 }
                                }
                                Rectangle {
                                    anchors { right: parent.right; rightMargin: Theme.space2; top: parent.top; topMargin: Theme.space2 }
                                    width: 10; height: 10; radius: 5
                                    visible: color.a > 0
                                    color: row.st === "waiting" ? Theme.danger : row.st !== "idle" ? Theme.working : Chat.unread[row.modelData.id] ? Theme.success : "transparent"
                                    border { width: 2; color: Theme.backgroundDeep }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Chat.openSession(row.modelData.id) }
                                Text {
                                    anchors { left: parent.left; leftMargin: Theme.space1 + 2; top: parent.top }
                                    visible: rowHover.hovered
                                    text: "×"
                                    color: archiveHit.containsMouse ? Theme.danger : Theme.textSecondary
                                    font { family: Theme.font; pixelSize: 16 }
                                    MouseArea {
                                        id: archiveHit
                                        anchors { fill: parent; margins: -6 }
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Chat.askArchive(row.modelData.id)
                                    }
                                }
                            }
                        }
                        // Footer of the rail: all the sessions (archived included) and the settings
                        Column {
                            id: foot
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: Theme.borderWidth }
                            Rectangle { width: parent.width; height: Theme.borderWidth; color: Theme.border }
                            Repeater {
                                model: [{ glyph: 0xF2F00, tip: qsTr("All sessions"), act: "all" }, { glyph: 0xF2F01, tip: qsTr("Settings…"), act: "settings" }]
                                Rectangle {
                                    id: fbtn
                                    required property var modelData
                                    width: foot.width
                                    height: 40
                                    color: fHover.hovered || (modelData.act === "all" && Chat.allOpen) ? Theme.surfaceHover : "transparent"
                                    HoverHandler {
                                        id: fHover
                                        onHoveredChanged: if (hovered) { rail.tipText = fbtn.modelData.tip; rail.tipY = fbtn.mapToItem(rail, 0, 0).y; }
                                    }
                                    Text { anchors.centerIn: parent; text: String.fromCodePoint(fbtn.modelData.glyph); color: Theme.textSecondary; font { family: Theme.icons; pixelSize: 22 } }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: fbtn.modelData.act === "all" ? (Chat.confirmId = "", Chat.allOpen = !Chat.allOpen) : Chat.openSettings()
                                    }
                                }
                            }
                        }
                        Rectangle { anchors.right: parent.right; width: Theme.borderWidth; height: parent.height; color: Theme.border }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: Chat.log
                        spacing: 0
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Bubble {}
                        footer: Item {
                            width: list.width
                            height: live.visible ? live.height + Theme.space3 : 0
                            Text {
                                id: live
                                visible: Chat.live !== ""
                                x: Theme.space3; width: parent.width - Theme.space4
                                text: Chat.live
                                wrapMode: Text.Wrap
                                color: Theme.text
                                font { family: Theme.font; pixelSize: Theme.size }
                            }
                        }
                        onCountChanged: Qt.callLater(() => positionViewAtEnd())
                        // All the sessions (a click restores an archived one)
                        Rectangle {
                            anchors.fill: parent
                            visible: Chat.allOpen
                            color: Theme.background
                            ListView {
                                anchors.fill: parent
                                clip: true
                                model: Chat.allSessions
                                delegate: Rectangle {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: 36
                                    color: aHover.hovered ? Theme.surfaceHover : "transparent"
                                    HoverHandler { id: aHover }
                                    Text {
                                        anchors { fill: parent; leftMargin: Theme.space3; rightMargin: Theme.space3 }
                                        verticalAlignment: Text.AlignVCenter
                                        text: (modelData.archived ? "⌫ " : "") + (modelData.title || qsTr("New session"))
                                        elide: Text.ElideRight
                                        color: modelData.archived ? Theme.muted : Theme.text
                                        font { family: Theme.font; pixelSize: Theme.sizeList }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: Chat.pickSession(modelData.id) }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !Chat.agentOk || (Chat.log.length === 0 && Chat.live === "")
                            text: !Chat.linked ? qsTr("Connecting…") : !Chat.agentOk ? qsTr("No agent installed (fili-ai install)") : qsTr("Ask Lia")
                            color: Theme.muted
                            font { family: Theme.font; pixelSize: Theme.size }
                        }
                    }

                    // Archive confirmation (Enter archives, Escape cancels)
                    Rectangle {
                        visible: Chat.confirmId !== ""
                        Layout.fillWidth: true
                        Layout.margins: Theme.space2
                        Layout.bottomMargin: 0
                        implicitHeight: 40
                        radius: Theme.radiusControl
                        color: Theme.surface
                        border { width: Theme.borderWidth; color: Theme.danger }
                        RowLayout {
                            anchors { fill: parent; leftMargin: Theme.space3; rightMargin: Theme.space2 }
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Archive this session?")
                                elide: Text.ElideRight
                                color: Theme.text
                                font { family: Theme.font; pixelSize: Theme.sizeList }
                            }
                            Repeater {
                                model: [{ t: qsTr("Archive"), v: true }, { t: qsTr("Cancel"), v: false }]
                                Rectangle {
                                    required property var modelData
                                    implicitWidth: lbl.implicitWidth + Theme.space4
                                    implicitHeight: 26
                                    radius: Theme.radiusControl
                                    color: hit.containsMouse ? Theme.surfaceHover : Theme.background
                                    border { width: Theme.borderWidth; color: Theme.border }
                                    Text { id: lbl; anchors.centerIn: parent; text: parent.modelData.t; color: Theme.text; font { family: Theme.font; pixelSize: Theme.sizeList } }
                                    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: Chat.confirmArchive(parent.modelData.v) }
                                }
                            }
                        }
                    }

                    // Chips: the application noted (attached to the next message) and the files attached
                    Flow {
                        visible: Chat.ctxOn || Chat.attached.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space2
                        Layout.rightMargin: Theme.space2
                        spacing: Theme.space1
                        Repeater {
                            model: (Chat.ctxOn ? [{ label: Chat.ctxLabel, ctx: true }] : []).concat(Chat.attached.map(p => ({ label: p.split("/").pop(), path: p })))
                            Rectangle {
                                required property var modelData
                                width: Math.min(chipText.implicitWidth + 28, 300)
                                height: 24
                                radius: Theme.radiusControl
                                color: Theme.surface
                                border { width: Theme.borderWidth; color: Theme.border }
                                Text {
                                    id: chipText
                                    anchors { left: parent.left; leftMargin: Theme.space2; right: x1.left; verticalCenter: parent.verticalCenter }
                                    text: modelData.label
                                    elide: Text.ElideRight
                                    color: Theme.textSecondary
                                    font { family: Theme.font; pixelSize: Theme.sizeSmall }
                                }
                                Text {
                                    id: x1
                                    anchors { right: parent.right; rightMargin: Theme.space1 + 2; verticalCenter: parent.verticalCenter }
                                    text: "×"
                                    color: Theme.muted
                                    font { family: Theme.font; pixelSize: 14 }
                                    MouseArea { anchors { fill: parent; margins: -4 } onClicked: modelData.ctx ? Chat.ctxOn = false : Chat.detach(modelData.path) }
                                }
                            }
                        }
                    }

                    // Input: Enter sends, Shift+Enter new line
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.margins: Theme.space2
                        Layout.preferredHeight: Math.min(160, Math.max(40, input.contentHeight + Theme.space3))
                        radius: Theme.radiusControl
                        color: Theme.surface
                        border { width: Theme.borderWidth; color: input.activeFocus ? Theme.accent : Theme.border }
                        TextEdit {
                            id: input
                            anchors { fill: parent; margins: Theme.space2 }
                            wrapMode: TextEdit.Wrap
                            color: Theme.text
                            selectionColor: Theme.muted
                            font { family: Theme.font; pixelSize: Theme.size }
                            focus: true
                            Keys.onPressed: e => {
                                if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) {
                                    Chat.send(text);
                                    text = "";
                                    e.accepted = true;
                                }
                            }
                        }
                    }
                    }
                }
            }

            // Tooltip of a session of the rail (title and linked application), beside the rail
            Rectangle {
                visible: rail.visible && rail.tipText !== "" && railHover.hovered
                x: 52 + Theme.space1
                y: Math.max(Theme.space1, Math.min(parent.height - height - Theme.space1, rail.tipY))
                width: Math.min(tipLabel.implicitWidth + 2 * Theme.space2, parent.width - 52 - 2 * Theme.space1)
                height: tipLabel.implicitHeight + 2 * Theme.space1
                radius: Theme.radiusControl
                color: Theme.surfaceHover
                border { color: Theme.border; width: Theme.borderWidth }
                Text {
                    id: tipLabel
                    anchors { fill: parent; margins: Theme.space1; leftMargin: Theme.space2; rightMargin: Theme.space2 }
                    text: rail.tipText
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font { family: Theme.font; pixelSize: Theme.sizeList }
                }
            }
        }

        // Resize handle on the left edge: the right edge stays put, the width follows the pointer (double click: 440)
        MouseArea {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Theme.space1 + 4
            cursorShape: Qt.SizeHorCursor
            property real pressX: 0
            onPressed: m => pressX = m.x
            onPositionChanged: m => {
                if (pressed)
                    Chat.viewWidth = Chat.clampWidth(Chat.viewWidth - (m.x - pressX));
            }
            onReleased: Chat.saveView()
            onDoubleClicked: { Chat.viewWidth = 440; Chat.saveView(); }
        }
    }
}
