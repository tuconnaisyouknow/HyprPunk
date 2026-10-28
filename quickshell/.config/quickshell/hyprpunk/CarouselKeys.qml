import QtQuick

// The keys of the carousel panels (wallpaper, SDDM theme): arrows, Tab or the Vim
// keys turn the carousel, Enter picks the one in the middle. Give it to the panel's
// keyTargets.
Item {
    id: keys

    required property IslandPanel panel
    required property ImageCarousel carousel

    signal picked()

    Keys.onPressed: (event) => {
        const direction = keys.panel.horizontalKey(event);
        if (direction !== 0) {
            keys.carousel.step(direction);
            event.accepted = true;
        }
    }
    Keys.onLeftPressed: carousel.step(-1)
    Keys.onRightPressed: carousel.step(1)
    Keys.onTabPressed: carousel.step(1)
    Keys.onBacktabPressed: carousel.step(-1)
    Keys.onReturnPressed: picked()
    Keys.onEnterPressed: picked()
}
