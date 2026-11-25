// Qt and Quickshell build in the background between the frames of Qt's animation clock,
// and only while it runs. With that clock replaced (FrameDriver) they see it stopped and
// build everything in one go: a list of asynchronous rows held the window for a tenth of
// a second. Here each frame that ends gives a third of its screen's beat to the building,
// and a timer keeps it going while no window draws.
#include "frameincubator.h"

#include "framedriver.h"

#include <QQmlEngine>

QList<FrameIncubator*> FrameIncubator::sIncubators;

// The engine's own controller (Quickshell's) is set before any QML loads, so this one,
// set as the module is imported, replaces it. It goes with the engine on a reload.
void FrameIncubator::attach(QQmlEngine* engine) {
    if (engine->incubationController() && dynamic_cast<FrameIncubator*>(engine->incubationController()))
        return;
    engine->setIncubationController(new FrameIncubator(engine));
}

FrameIncubator::FrameIncubator(QQmlEngine* engine)
    : QObject(engine) {
    mFallback.setSingleShot(true);
    mFallback.setTimerType(Qt::PreciseTimer);
    QObject::connect(&mFallback, &QTimer::timeout, &mFallback, [this] { step(FrameDriver::fastestInterval()); });
    sIncubators.append(this);
}

FrameIncubator::~FrameIncubator() {
    sIncubators.removeAll(this);
}

// Right after a frame, the next one is a whole beat away
void FrameIncubator::frameEnded(qint64 interval) {
    for (FrameIncubator* incubator : std::as_const(sIncubators))
        incubator->step(interval);
}

// Called from inside QML's building: it only starts the timer, the first slice comes with
// the next frame or the timer
void FrameIncubator::incubatingObjectCountChanged(int count) {
    if (count > 0 && !mFallback.isActive())
        mFallback.start(int(FrameDriver::fastestInterval() / FrameDriver::Millisecond));
}

void FrameIncubator::step(qint64 interval) {
    if (incubatingObjectCount() == 0)
        return;
    incubateFor(qMax(1, int(interval / 3 / FrameDriver::Millisecond)));
    if (incubatingObjectCount() > 0)
        mFallback.start(int(interval / FrameDriver::Millisecond) + 1);
}
