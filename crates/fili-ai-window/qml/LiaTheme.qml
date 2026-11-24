pragma Singleton
// What Lia adds to the kit's tokens (FiliTheme): the blue of a working agent and the green of an unread answer.
import QtQuick
import Fili.UI

QtObject {
    // Working state: the blue of the "voile" accent
    readonly property color working: FiliTheme.light ? FiliTheme.theme.accents.voile[2] : FiliTheme.theme.accents.voile[0]
    readonly property color success: FiliTheme.m.success
}
