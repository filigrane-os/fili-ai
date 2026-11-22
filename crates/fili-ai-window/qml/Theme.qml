pragma Singleton
// Tokens of the fili-shell, dark defaults of theme.toml (names as in the shell). The merged theme (theme.toml and
// fili-ai.toml layers, light mode) comes with the settings; until then the defaults are fixed.
import QtQuick

QtObject {
    readonly property color background: "#1c222b"
    readonly property color backgroundDeep: "#181d25"
    readonly property color surface: "#232b36"
    readonly property color surfaceHover: "#2d3744"
    readonly property color surfaceActive: "#3c4858"
    readonly property color border: "#3c4858"
    readonly property color muted: "#5f7894"
    readonly property color textSecondary: "#a9b8c8"
    readonly property color text: "#dbe7f4"
    readonly property color warning: "#d2bf92"
    readonly property color danger: "#c98f93"
    readonly property color success: "#a3bfa8"
    readonly property color accent: "#d2bf92"
    readonly property color working: "#9dbbd6"

    readonly property string font: "Jost"
    readonly property string mono: "JetBrains Mono"
    readonly property string icons: "Fili Icons"
    readonly property int size: 14
    readonly property int sizeList: 13
    readonly property int sizeSmall: 12
    readonly property int sizeTitle: 18
    readonly property int weightAccent: 600
    readonly property int radiusControl: 6
    readonly property int radiusWindow: 10
    readonly property int borderWidth: 1
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int headerHeight: 44
    readonly property int footerHeight: 28
    readonly property int sidebarWidth: 200
}
