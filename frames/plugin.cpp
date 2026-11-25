// The HyprPunk.Frames QML module: importing it puts the frame driver in charge of the
// process's animations (framedriver.cpp), and of what each engine builds in the
// background between frames (frameincubator.cpp). It has no types of its own.
#include "framedriver.h"
#include "frameincubator.h"

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
    // Every reload makes a new engine, with its own incubator; the driver stays the same
    void initializeEngine(QQmlEngine* engine, const char*) override {
        FrameDriver::installOnce();
        FrameIncubator::attach(engine);
    }
};

#include "plugin.moc"
