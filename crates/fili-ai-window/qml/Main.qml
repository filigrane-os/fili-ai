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
    LayerShell.Window.exclusionZone: viewWidth
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
            anchors { fill: parent; margins: Theme.space1 }
            color: Theme.background
            radius: Theme.radiusWindow
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
                        Text {
                            text: "+"
                            color: Theme.textSecondary
                            font { family: Theme.font; pixelSize: Theme.sizeTitle }
                            MouseArea { anchors { fill: parent; margins: -Theme.space1 } onClicked: Chat.newSession() }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.border }
                }

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
