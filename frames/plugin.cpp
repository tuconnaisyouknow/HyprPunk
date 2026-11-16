// The HyprPunk.Frames QML module: importing it puts the frame driver in charge of the
// process's animations (framedriver.cpp). It has no types of its own.
#include "framedriver.h"

#include <QQmlEngineExtensionPlugin>
#include <QQmlModuleRegistration>
#include <qqml.h>

// A module without a version doesn't count as installed, even with its plugin loaded
static const QQmlModuleRegistration registration("HyprPunk.Frames",
                                                 [] { qmlRegisterModule("HyprPunk.Frames", 1, 0); });

class FramesPlugin : public QQmlEngineExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    // Every reload makes a new engine; the driver stays the same
    void initializeEngine(QQmlEngine*, const char*) override { FrameDriver::installOnce(); }
};

#include "plugin.moc"
