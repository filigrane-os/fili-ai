// The drawer of Lia (window of Main.qml): header, conversation, input. A layer-shell surface on the right edge (org.kde.layershell, package
// layer-shell-qt) whose exclusive zone makes the windows shrink beside it, as the drawer of the shell did.
// `--window`: a normal window (the layer-shell variable is then not set, see main.rs).
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import Fili.Ai
import Fili.UI

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
    // Stuck to the right edge of the screen; the same gap as between two niri windows (`gaps` of the niri config) above and below.
    // The compositor adds the margin of the anchored edge to the exclusive zone: with no margin on the right, the zone is the width
    // of the drawer, and the windows stop one `gaps` before it (the gap between two windows).
    readonly property int gap: 16
    LayerShell.Window.margins: ({ left: 0, top: gap, right: 0, bottom: gap })
    LayerShell.Window.exclusionZone: Chat.mode === "dock" ? viewWidth : 0
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
            else if (e.key === Qt.Key_L && (e.modifiers & Qt.ShiftModifier))
                Chat.debugOpen = !Chat.debugOpen;
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
            color: FiliTheme.background
            radius: 8
            border { width: FiliTheme.borderWidth; color: FiliTheme.border }
            clip: true

            // Files dragged from an application: attached to the next message
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: d => { if (d.hasUrls) Chat.attachUrls(d.urls.map(u => u.toString())); }
            }

            ColumnLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; bottomMargin: debug.height }
                spacing: 0

                // Header 44: title of the session, state, new session
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: FiliTheme.toolbarHeight
                    color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: FiliTheme.space3; rightMargin: FiliTheme.space3 }
                        spacing: FiliTheme.space2
                        Text {
                            Layout.fillWidth: true
                            visible: !Chat.renaming
                            text: Chat.title
                            elide: Text.ElideRight
                            color: FiliTheme.text
                            font { family: FiliTheme.font; pixelSize: FiliTheme.size; weight: FiliTheme.weightAccent }
                            MouseArea { anchors.fill: parent; onDoubleClicked: Chat.startRename() }
                        }
                        // Rename (F2 or double click): Enter keeps, Escape cancels
                        TextInput {
                            id: renameField
                            Layout.fillWidth: true
                            visible: Chat.renaming
                            text: Chat.title
                            color: FiliTheme.text
                            selectionColor: FiliTheme.surfaceHover
                            selectedTextColor: FiliTheme.text
                            font { family: FiliTheme.font; pixelSize: FiliTheme.size; weight: FiliTheme.weightAccent }
                            clip: true
                            onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
                            Keys.onReturnPressed: Chat.commitRename(text)
                            Keys.onEnterPressed: Chat.commitRename(text)
                            Keys.onEscapePressed: Chat.renaming = false
                        }
                        Text {
                            visible: Chat.working
                            text: Chat.waiting ? Link.tr("waiting for you") : Link.tr("working")
                            color: Chat.waiting ? FiliTheme.warning : FiliTheme.textSecondary
                            font { family: FiliTheme.font; pixelSize: FiliTheme.sizeSmall }
                        }
                        FiliIconButton { glyph: "≡"; size: FiliTheme.sizeTitle; implicitHeight: 28; tip: Link.tr("Sessions"); toggled: Chat.tabsOpen; onClicked: Chat.tabsOpen = !Chat.tabsOpen }
                        FiliIconButton { glyph: "+"; size: FiliTheme.sizeTitle; implicitHeight: 28; tip: Link.tr("New session"); onClicked: Chat.newSession() }
                        FiliIconButton { glyph: "×"; size: FiliTheme.sizeTitle; implicitHeight: 28; tip: Link.tr("Close"); onClicked: Chat.hide() }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: FiliTheme.borderWidth; color: FiliTheme.border }
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
                        color: FiliTheme.backgroundDeep
                        // The bottom left corner follows the rounded corner of the drawer (a Rectangle does not clip to a rounded
                        // parent): the rail is rounded, and two plain strips give back the square top and right edges
                        radius: 8
                        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 20; color: parent.color }
                        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 12; color: parent.color }
                        HoverHandler { id: railHover }
                        property string tipText: ""
                        property real tipY: 0
                        ListView {
                            id: sessions
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: foot.top; rightMargin: FiliTheme.borderWidth }
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
                                color: sel || rowHover.hovered ? FiliTheme.surfaceHover : "transparent"
                                HoverHandler {
                                    id: rowHover
                                    onHoveredChanged: {
                                        if (hovered) {
                                            rail.tipText = (row.modelData.title || Link.tr("New session")) + (row.appKey !== "" ? "\n" + row.appKey : "");
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
                                    color: row.sel ? FiliTheme.text : FiliTheme.textSecondary
                                    font { family: FiliTheme.icons; pixelSize: 24 }
                                }
                                Rectangle {
                                    anchors { right: parent.right; rightMargin: FiliTheme.space2; top: parent.top; topMargin: FiliTheme.space2 }
                                    width: 10; height: 10; radius: 5
                                    visible: color.a > 0
                                    color: row.st === "waiting" ? FiliTheme.danger : row.st !== "idle" ? LiaTheme.working : Chat.unread[row.modelData.id] ? LiaTheme.success : "transparent"
                                    border { width: 2; color: FiliTheme.backgroundDeep }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Chat.openSession(row.modelData.id) }
                                Text {
                                    anchors { left: parent.left; leftMargin: FiliTheme.space1 + 2; top: parent.top }
                                    visible: rowHover.hovered
                                    text: "×"
                                    color: archiveHit.containsMouse ? FiliTheme.danger : FiliTheme.textSecondary
                                    font { family: FiliTheme.font; pixelSize: 16 }
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
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: FiliTheme.borderWidth }
                            Rectangle { width: parent.width; height: FiliTheme.borderWidth; color: FiliTheme.border }
                            Repeater {
                                model: [{ glyph: 0xF2F00, tip: Link.tr("All sessions"), act: "all" }, { glyph: 0xF2F01, tip: Link.tr("Settings…"), act: "settings" }]
                                Rectangle {
                                    id: fbtn
                                    required property var modelData
                                    width: foot.width
                                    height: 40
                                    color: fHover.hovered || (modelData.act === "all" && Chat.allOpen) ? FiliTheme.surfaceHover : "transparent"
                                    HoverHandler {
                                        id: fHover
                                        onHoveredChanged: if (hovered) { rail.tipText = fbtn.modelData.tip; rail.tipY = fbtn.mapToItem(rail, 0, 0).y; }
                                    }
                                    Text { anchors.centerIn: parent; text: String.fromCodePoint(fbtn.modelData.glyph); color: FiliTheme.textSecondary; font { family: FiliTheme.icons; pixelSize: 22 } }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: fbtn.modelData.act === "all" ? (Chat.confirmId = "", Chat.allOpen = !Chat.allOpen) : Chat.openSettings()
                                    }
                                }
                            }
                        }
                        Rectangle { anchors.right: parent.right; width: FiliTheme.borderWidth; height: parent.height; color: FiliTheme.border }
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
                        KineticScroll {}
                        footer: Item {
                            width: list.width
                            height: live.visible ? live.height + FiliTheme.space3 : 0
                            TextEdit {
                                id: live
                                visible: Chat.live !== ""
                                x: FiliTheme.space3; width: parent.width - FiliTheme.space4
                                readOnly: true
                                selectByMouse: true
                                activeFocusOnPress: false
                                selectionColor: FiliTheme.accentColor
                                selectedTextColor: FiliTheme.background
                                onSelectedTextChanged: if (selectedText !== "") Chat.picked = selectedText
                                text: Chat.live
                                textFormat: TextEdit.PlainText
                                wrapMode: TextEdit.Wrap
                                color: FiliTheme.text
                                font { family: FiliTheme.font; pixelSize: FiliTheme.size }
                            }
                        }
                        FiliScrollBar { flick: list; anchors { top: parent.top; bottom: parent.bottom; right: parent.right } }
                        onCountChanged: Qt.callLater(() => positionViewAtEnd())
                        // All the sessions (a click restores an archived one)
                        Rectangle {
                            anchors.fill: parent
                            visible: Chat.allOpen
                            color: FiliTheme.background
                            ListView {
                                anchors.fill: parent
                                clip: true
                                model: Chat.allSessions
                                delegate: Rectangle {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: 36
                                    color: aHover.hovered ? FiliTheme.surfaceHover : "transparent"
                                    HoverHandler { id: aHover }
                                    Text {
                                        anchors { fill: parent; leftMargin: FiliTheme.space3; rightMargin: FiliTheme.space3 }
                                        verticalAlignment: Text.AlignVCenter
                                        text: (modelData.archived ? "⌫ " : "") + (modelData.title || Link.tr("New session"))
                                        elide: Text.ElideRight
                                        color: modelData.archived ? FiliTheme.muted : FiliTheme.text
                                        font { family: FiliTheme.font; pixelSize: FiliTheme.sizeList }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: Chat.pickSession(modelData.id) }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !Chat.agentOk || (Chat.log.length === 0 && Chat.live === "")
                            text: !Chat.linked ? Link.tr("Connecting…") : !Chat.agentOk ? Link.tr("No agent installed (fili-ai install)") : Link.tr("Ask Lia")
                            color: FiliTheme.muted
                            font { family: FiliTheme.font; pixelSize: FiliTheme.size }
                        }
                    }

                    // Archive confirmation (Enter archives, Escape cancels)
                    Rectangle {
                        visible: Chat.confirmId !== ""
                        Layout.fillWidth: true
                        Layout.margins: FiliTheme.space2
                        Layout.bottomMargin: 0
                        implicitHeight: 40
                        radius: FiliTheme.radiusControl
                        color: FiliTheme.surface
                        border { width: FiliTheme.borderWidth; color: FiliTheme.danger }
                        RowLayout {
                            anchors { fill: parent; leftMargin: FiliTheme.space3; rightMargin: FiliTheme.space2 }
                            Text {
                                Layout.fillWidth: true
                                text: Link.tr("Archive this session?")
                                elide: Text.ElideRight
                                color: FiliTheme.text
                                font { family: FiliTheme.font; pixelSize: FiliTheme.sizeList }
                            }
                            Repeater {
                                model: [{ t: Link.tr("Archive"), v: true }, { t: Link.tr("Cancel"), v: false }]
                                Rectangle {
                                    required property var modelData
                                    implicitWidth: lbl.implicitWidth + FiliTheme.space4
                                    implicitHeight: 26
                                    radius: FiliTheme.radiusControl
                                    color: hit.containsMouse ? FiliTheme.surfaceHover : FiliTheme.background
                                    border { width: FiliTheme.borderWidth; color: FiliTheme.border }
                                    Text { id: lbl; anchors.centerIn: parent; text: parent.modelData.t; color: FiliTheme.text; font { family: FiliTheme.font; pixelSize: FiliTheme.sizeList } }
                                    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: Chat.confirmArchive(parent.modelData.v) }
                                }
                            }
                        }
                    }

                    // Chips: the application noted (attached to the next message) and the files attached
                    Flow {
                        visible: Chat.ctxOn || Chat.attached.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: FiliTheme.space2
                        Layout.rightMargin: FiliTheme.space2
                        spacing: FiliTheme.space1
                        Repeater {
                            model: (Chat.ctxOn ? [{ label: Chat.ctxLabel, ctx: true }] : []).concat(Chat.attached.map(p => ({ label: p.split("/").pop(), path: p })))
                            Rectangle {
                                required property var modelData
                                width: Math.min(chipText.implicitWidth + 28, 300)
                                height: 24
                                radius: FiliTheme.radiusControl
                                color: FiliTheme.surface
                                border { width: FiliTheme.borderWidth; color: FiliTheme.border }
                                Text {
                                    id: chipText
                                    anchors { left: parent.left; leftMargin: FiliTheme.space2; right: x1.left; verticalCenter: parent.verticalCenter }
                                    text: modelData.label
                                    elide: Text.ElideRight
                                    color: FiliTheme.textSecondary
                                    font { family: FiliTheme.font; pixelSize: FiliTheme.sizeSmall }
                                }
                                Text {
                                    id: x1
                                    anchors { right: parent.right; rightMargin: FiliTheme.space1 + 2; verticalCenter: parent.verticalCenter }
                                    text: "×"
                                    color: FiliTheme.muted
                                    font { family: FiliTheme.font; pixelSize: 14 }
                                    MouseArea { anchors { fill: parent; margins: -4 } onClicked: modelData.ctx ? Chat.ctxOn = false : Chat.detach(modelData.path) }
                                }
                            }
                        }
                    }

                    // Input: Enter makes a new line, Shift+Enter (or Ctrl+Enter) sends, as in every message composer of Filigrane
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.margins: FiliTheme.space2
                        Layout.preferredHeight: Math.min(160, Math.max(40, input.contentHeight + FiliTheme.space3))
                        radius: FiliTheme.radiusControl
                        color: FiliTheme.surface
                        border { width: FiliTheme.borderWidth; color: input.activeFocus ? FiliTheme.accentColor : FiliTheme.border }
                        TextEdit {
                            id: input
                            anchors { fill: parent; margins: FiliTheme.space2 }
                            wrapMode: TextEdit.Wrap
                            color: FiliTheme.text
                            selectionColor: FiliTheme.muted
                            font { family: FiliTheme.font; pixelSize: FiliTheme.size }
                            focus: true
                            Keys.onPressed: e => {
                                // Ctrl+C copies what was selected in the conversation when the field has no selection of its own
                                // (a Shortcut would never fire: an editable text keeps the copy keys for itself)
                                if (e.matches(StandardKey.Copy) && input.selectedText === "" && Chat.picked !== "") {
                                    Link.copyText(Chat.picked);
                                    e.accepted = true;
                                    return;
                                }
                                if (Chat.sendsMessage(e.key, e.modifiers)) {
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

            // Debug panel (View > Debug Logs, Ctrl+Shift+L): the log of the window, above the bottom edge
            FiliDebugPanel {
                id: debug
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                open: Chat.debugOpen
            }

            // Tooltip of a session of the rail (title and linked application), beside the rail
            Rectangle {
                visible: rail.visible && rail.tipText !== "" && railHover.hovered
                x: 52 + FiliTheme.space1
                y: Math.max(FiliTheme.space1, Math.min(parent.height - height - FiliTheme.space1, rail.tipY))
                width: Math.min(tipLabel.implicitWidth + 2 * FiliTheme.space2, parent.width - 52 - 2 * FiliTheme.space1)
                height: tipLabel.implicitHeight + 2 * FiliTheme.space1
                radius: FiliTheme.radiusControl
                color: FiliTheme.surfaceHover
                border { color: FiliTheme.border; width: FiliTheme.borderWidth }
                Text {
                    id: tipLabel
                    anchors { fill: parent; margins: FiliTheme.space1; leftMargin: FiliTheme.space2; rightMargin: FiliTheme.space2 }
                    text: rail.tipText
                    wrapMode: Text.Wrap
                    color: FiliTheme.text
                    font { family: FiliTheme.font; pixelSize: FiliTheme.sizeList }
                }
            }
        }

        // Resize handle on the left edge: the right edge stays put, the width follows the pointer (double click: 440)
        MouseArea {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: FiliTheme.space1 + 4
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
