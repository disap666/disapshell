import QtQuick

// Glossy selection: lit top edge, soft body, faint rim: reads as raised glass.
Rectangle {
    id: pill
    radius: 11
    gradient: Gradient {
        GradientStop { position: 0; color: Tokens.alpha("#ffffff", .24) }
        GradientStop { position: .5; color: Tokens.alpha("#ffffff", .12) }
        GradientStop { position: 1; color: Tokens.alpha("#ffffff", .08) }
    }
    border.width: 1
    border.color: Tokens.alpha("#ffffff", .22)
    Rectangle { x: pill.radius; width: pill.width - 2 * pill.radius; height: 1; y: 1; color: Tokens.alpha("#ffffff", .45) }
}
