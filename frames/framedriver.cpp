// Qt has one animation clock per process, and with more than one window it moves it on a
// 16 ms timer that ignores the screens: steps get skipped or repeated, and a 120 Hz screen
// only sees 60 states a second. Here each window sets the clock to the time of the frame
// it's about to prepare, so every screen shows the animations at its own frames, and a
// window where nothing moves never draws. Each window draws one frame at a time, at its
// screen's beat, and nothing waits for the screens anywhere else. A timer only takes over
// while no window draws.
//   QT_LOGGING_RULES=hyprpunk.frames.debug=true   logs each frame: screen, real time,
//                                                 frame time, clock (µs), window size
#include "framedriver.h"

#include <chrono>

#include <QEvent>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QQuickWindow>
#include <QScreen>
#include <QSurfaceFormat>
#include <private/qquickwindow_p.h>
#include <private/qsgrenderloop_p.h>

Q_LOGGING_CATEGORY(lcFrames, "hyprpunk.frames", QtWarningMsg)

namespace {
constexpr qint64 Second = 1'000'000'000;
constexpr qint64 Millisecond = 1'000'000;

qint64 intervalOf(const QScreen* screen) {
    const qreal rate = screen ? screen->refreshRate() : 0;
    return rate > 1 ? qint64(Second / rate) : Second / 60;
}
} // namespace

FrameDriver::FrameDriver(QObject* parent)
    : QAnimationDriver(parent) {
    mFallback.setSingleShot(true);
    mFallback.setTimerType(Qt::PreciseTimer);
    QObject::connect(&mFallback, &QTimer::timeout, this, [this] {
        tick(now());
        mFallback.start(int(fastestInterval() / Millisecond));
    });
}

// Qt's render loop installs its own driver before any QML loads, so it has to go first.
// That takes Qt's private API, which can change with any Qt release: a plugin built for
// another Qt leaves the clock alone rather than risk a crash.
void FrameDriver::installOnce() {
    static FrameDriver* driver = nullptr;
    if (driver)
        return;
    if (qstrcmp(qVersion(), QT_VERSION_STR) != 0) {
        qWarning().nospace() << "HyprPunk.Frames was built for Qt " << QT_VERSION_STR << ", not " << qVersion()
                             << ": run install.sh apply to rebuild it. Animations keep Qt's own clock until then.";
        return;
    }
    QSGRenderLoop::instance()->animationDriver()->uninstall();

    // Each frame already waits for its screen's beat (the compositor's frame callback, see
    // eventFilter). Waiting for it again in the swap would hold the shell's thread on the
    // render thread for a whole beat of a 60 Hz screen, while a 120 Hz one waits for its
    // frames. Windows take this format as they're made (Quickshell's ProxyWindow).
    QSurfaceFormat format = QSurfaceFormat::defaultFormat();
    format.setSwapInterval(0);
    QSurfaceFormat::setDefaultFormat(format);

    driver = new FrameDriver(qApp);
    driver->install();
    qApp->installEventFilter(driver);
}

qint64 FrameDriver::now() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

qint64 FrameDriver::fastestInterval() {
    qint64 interval = Second / 60;
    for (const QScreen* screen : QGuiApplication::screens())
        interval = qMin(interval, intervalOf(screen));
    return interval;
}

qint64 FrameDriver::elapsed() const {
    return (mClock - mStart) / Millisecond;
}

// An animation that starts changes nothing yet, so no window asks for a frame: the timer
// gives it its first step, one frame of the fastest screen later.
void FrameDriver::start() {
    mStart = mClock = now();
    mFallback.start(int(fastestInterval() / Millisecond));
    QAnimationDriver::start();
}

void FrameDriver::stop() {
    mFallback.stop();
    QAnimationDriver::stop();
}

// A window's update request comes before it polishes and syncs, so what moves now is in
// this very frame, layouts included.
// One frame at a time per window: a request that comes while the last one is still on its
// way (another screen's step, a live layer whose source changed during the sync) would go
// out at once, right behind it: Qt holds a request until the compositor's frame callback,
// and there's none before the frame is sent. It's asked again once that frame ends, and
// then waits for the screen's next beat.
bool FrameDriver::eventFilter(QObject* watched, QEvent* event) {
    if (event->type() != QEvent::UpdateRequest)
        return false;
    auto* window = qobject_cast<QQuickWindow*>(watched);
    if (!window)
        return false;

    auto state = mWindows.find(window);
    if (state == mWindows.end()) {
        state = mWindows.insert(window, {});
        QObject::connect(window, &QObject::destroyed, this, [this, window] { mWindows.remove(window); });
        QObject::connect(window, &QQuickWindow::afterFrameEnd, this, [this, window] { frameEnded(window); },
                         Qt::QueuedConnection);
    }
    if (state->drawing) {
        state->wantsNext = true;
        return true;
    }
    state->drawing = drawsFrame(window);
    windowFrame(window, *state);
    return false;
}

// Qt skips the frame of a hidden, empty or frozen window, and no frame end would come to
// let the next one through
bool FrameDriver::drawsFrame(QQuickWindow* window) {
    return window->isExposed() && !window->size().isEmpty() && QQuickWindowPrivate::get(window)->updatesEnabled;
}

void FrameDriver::windowFrame(QQuickWindow* window, WindowState& state) {
    if (!isRunning())
        return;

    const qint64 time = now();
    const qint64 interval = intervalOf(window->screen());

    // Requests come a little late now and then: one close behind the screen's beat lands
    // on it, so steps stay even. Never ahead of the real time, though: the clock is the
    // same for every screen, and one running ahead would leave the others nothing to move.
    const qint64 expected = state.lastFrame + interval;
    const qint64 frame = time >= expected && time - expected < interval / 4 ? expected : time;
    state.lastFrame = frame;

    qCDebug(lcFrames).noquote() << "frame" << (window->screen() ? window->screen()->name() : QString())
                                << time / 1000 << frame / 1000 << qMax(mClock, frame) / 1000
                                << QStringLiteral("%1x%2").arg(window->width()).arg(window->height());

    // While a window draws, the timer waits: it only steps in once frames stop coming
    // (a hidden window, an animation with nothing to show)
    mFallback.start(int(interval * 3 / 2 / Millisecond) + 1);

    tick(frame);

    // A window with something new to draw wants its next frame, so it keeps its own
    // screen's pace while anything in it moves, and stops one frame after.
    state.wantsNext = hasWork(window);
}

// Something in it waits to be laid out or drawn
bool FrameDriver::hasWork(QQuickWindow* window) {
    const auto* d = QQuickWindowPrivate::get(window);
    return d->dirtyItemList || !d->itemsToPolish.isEmpty();
}

// Every frame ends with this, shown or not. Asked from here, the next frame waits for the
// screen's next beat.
// Qt drops the request of anything that changes while a window lays itself out, whichever
// window it's in: what this frame changed in another window (the blur behind a pill that
// zooms) would wait there for good. So every window left with something to draw is asked.
void FrameDriver::frameEnded(QQuickWindow* window) {
    auto ended = mWindows.find(window);
    if (ended == mWindows.end())
        return;
    ended->drawing = false;

    for (auto state = mWindows.begin(); state != mWindows.end(); ++state) {
        if (state->drawing || !(state->wantsNext || (drawsFrame(state.key()) && hasWork(state.key()))))
            continue;
        state->wantsNext = false;
        state.key()->requestUpdate();
    }
}

// The clock never goes back: another screen may already have moved it a little further
void FrameDriver::tick(qint64 time) {
    if (time <= mClock)
        return;
    mClock = time;
    advance();
}
