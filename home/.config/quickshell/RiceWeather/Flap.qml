import QtQuick

// One split-flap tile. When its character changes, the top half folds down.
Item {
    id: flap
    property string ch: " "
    property color ink: "#f4f0e6"
    property int size: 22
    property string shown: " "
    property string coming: " "
    width: size * .78; height: size * 1.32
    onChChanged: if (ch !== shown) { coming = ch; flip.restart(); }
    Component.onCompleted: shown = ch

    component Half: Item {
        property bool upper: true
        property string glyph: " "
        width: flap.width; height: flap.height / 2
        clip: true
        Rectangle {
            width: flap.width; height: flap.height; radius: 3
            y: parent.upper ? 0 : -flap.height / 2
            color: "#1d1d20"
            Text {
                anchors.centerIn: parent
                text: parent.parent.glyph
                font.family: "JetBrains Mono"; font.pixelSize: flap.size; font.weight: Font.Bold
                color: flap.ink
            }
        }
    }
    Half { id: topBack; upper: true; glyph: flap.coming }          // next char waiting behind
    Half { id: bottomFront; upper: false; y: flap.height / 2; glyph: flap.shown }
    Half {
        id: topFront; upper: true; glyph: flap.shown
        transform: Rotation { id: fold; origin.y: flap.height / 2; axis { x: 1; y: 0; z: 0 } angle: 0 }
    }
    Rectangle { y: flap.height / 2 - .5; width: flap.width; height: 1; color: "#000000"; opacity: .7 }   // the split
    SequentialAnimation {
        id: flip
        NumberAnimation { target: fold; property: "angle"; from: 0; to: -90; duration: 110; easing.type: Easing.InQuad }
        ScriptAction { script: { flap.shown = flap.coming; fold.angle = 0; } }
    }
}
