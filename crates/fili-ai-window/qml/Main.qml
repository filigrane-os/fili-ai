// The drawer of Lia: header, conversation, input. A layer-shell surface on the right edge (org.kde.layershell, package
// layer-shell-qt) whose exclusive zone makes the windows shrink beside it, as the drawer of the shell did.
// `--window`: a normal window (the layer-shell variable is then not set, see main.rs).
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import Fili.Ai

Window {
    id: win
    readonly property int viewWidth: 440
    width: viewWidth
    height: 900
    visible: true
    color: "transparent"
    title: "Lia"

    LayerShell.Window.scope: "fili-ai"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
    // The same gap as between two niri windows (`gaps` of the niri config): margins on the three anchored edges, and the
    // exclusive zone counts the right one so that the windows keep that gap beside the drawer
    readonly property int gap: 16
    LayerShell.Window.margins: ({ left: 0, top: gap, right: gap, bottom: gap })
    LayerShell.Window.exclusionZone: viewWidth + gap
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    Component.onCompleted: Chat.connectNow()

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Qt.quit()
        Keys.onPressed: e => {
            if (!(e.modifiers & Qt.ControlModifier))
                return;
            if (e.key === Qt.Key_N)
                Chat.newSession();
            else if (e.key === Qt.Key_Period)
                Chat.stop();
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
                            text: Chat.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.font; pixelSize: Theme.size; weight: Theme.weightAccent }
                        }
                        Text {
                            visible: Chat.working
                            text: Chat.waiting ? qsTr("waiting for you") : qsTr("working")
                            color: Chat.waiting ? Theme.warning : Theme.textSecondary
                            font { family: Theme.font; pixelSize: Theme.sizeSmall }
                        }
                        IconButton { glyph: "≡"; tip: qsTr("Sessions"); on: Chat.tabsOpen; onClicked: Chat.tabsOpen = !Chat.tabsOpen }
                        IconButton { glyph: "+"; tip: qsTr("New session"); onClicked: Chat.newSession() }
                        IconButton { glyph: "×"; tip: qsTr("Close"); onClicked: Qt.quit() }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.border }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Sessions: the 20 most recent; dot = waiting (sand) or finished and unread (green)
                    Rectangle {
                        visible: Chat.tabsOpen
                        Layout.fillHeight: true
                        Layout.preferredWidth: 140
                        color: Theme.backgroundDeep
                        ListView {
                            anchors.fill: parent
                            clip: true
                            model: Chat.sessions.slice(0, 20)
                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                readonly property bool sel: modelData.id === Chat.current
                                readonly property string st: Chat.states[modelData.id] ?? "idle"
                                width: ListView.view.width
                                height: 32
                                color: sel ? Theme.surfaceHover : rowHover.hovered ? Theme.surface : "transparent"
                                HoverHandler { id: rowHover }
                                Rectangle {
                                    id: dot
                                    x: Theme.space2; anchors.verticalCenter: parent.verticalCenter
                                    width: 8; height: 8; radius: 4
                                    visible: row.st === "waiting" || Chat.unread[row.modelData.id] === true || row.st !== "idle"
                                    color: row.st === "waiting" ? Theme.warning : Chat.unread[row.modelData.id] ? Theme.success : Theme.muted
                                }
                                Text {
                                    anchors { left: parent.left; leftMargin: Theme.space2 + 14; right: parent.right; rightMargin: archive.visible ? 26 : Theme.space2; verticalCenter: parent.verticalCenter }
                                    text: row.modelData.title || qsTr("New session")
                                    elide: Text.ElideRight
                                    color: row.sel ? Theme.text : Theme.textSecondary
                                    font { family: Theme.font; pixelSize: Theme.sizeList }
                                }
                                MouseArea { anchors.fill: parent; onClicked: Chat.openSession(row.modelData.id) }
                                IconButton {
                                    id: archive
                                    visible: rowHover.hovered
                                    anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                                    implicitWidth: 22; implicitHeight: 22
                                    glyph: "×"; tip: qsTr("Archive")
                                    onClicked: Chat.archive(row.modelData.id)
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
                        Text {
                            anchors.centerIn: parent
                            visible: !Chat.agentOk || (Chat.log.length === 0 && Chat.live === "")
                            text: !Chat.linked ? qsTr("Connecting…") : !Chat.agentOk ? qsTr("No agent installed (fili-ai install)") : qsTr("Ask Lia")
                            color: Theme.muted
                            font { family: Theme.font; pixelSize: Theme.size }
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
        }
    }
}
