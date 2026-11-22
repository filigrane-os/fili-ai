pragma Singleton
// Tokens of the fili-shell, same names. Merged theme (defaults of theme.toml, ~/.config/filigrane/theme.toml,
// ~/.config/filigrane/fili-ai.toml) read from Rust, light mode and accent followed live (Link.light, Link.accent).
import QtQuick
import Fili.Ai

QtObject {
    readonly property bool light: Link.light
    // Re-read when a settings file changes (Link.settingsRev)
    readonly property var theme: { const rev = Link.settingsRev; return JSON.parse(Link.themeJson()); }
    readonly property var m: light ? theme.light : theme.dark
    readonly property var tone: theme.accents[Link.accent] || theme.accents.default

    readonly property color background: m.background
    readonly property color backgroundDeep: m.background_deep
    readonly property color surface: m.surface
    readonly property color surfaceHover: m.surface_hover
    readonly property color surfaceActive: m.surface_active
    readonly property color border: m.border
    readonly property color muted: m.muted
    readonly property color textSecondary: m.text_secondary
    readonly property color text: m.text
    readonly property color warning: m.warning
    readonly property color danger: m.danger
    readonly property color success: m.success
    readonly property color accent: m.accent || (light ? tone[2] : tone[0])
    // Working state: the blue of the "voile" accent
    readonly property color working: light ? theme.accents.voile[2] : theme.accents.voile[0]

    readonly property string font: m.font
    readonly property string mono: m.mono
    readonly property string icons: m.icons
    readonly property int size: m.size
    readonly property int sizeList: m.size_list
    readonly property int sizeSmall: m.size_small
    readonly property int sizeTitle: m.size_title
    readonly property int weightAccent: m.weight_accent
    readonly property int radiusControl: m.radius_control
    readonly property int radiusWindow: m.radius_window
    readonly property int borderWidth: m.border_width
    readonly property int space1: m.space_1
    readonly property int space2: m.space_2
    readonly property int space3: m.space_3
    readonly property int space4: m.space_4
    readonly property int headerHeight: m.toolbar_height
    readonly property int footerHeight: m.status_height
    readonly property int sidebarWidth: m.sidebar_width
}
