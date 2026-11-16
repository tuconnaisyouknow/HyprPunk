// The shell's animation clock: every window moves it at its own screen's frames, so each
// screen animates at its own refresh rate. Installed once per process by the plugin.
#pragma once

#include <QAnimationDriver>
#include <QHash>
#include <QTimer>

class QQuickWindow;

class FrameDriver : public QAnimationDriver {
public:
    explicit FrameDriver(QObject* parent = nullptr);

    static void installOnce();

    qint64 elapsed() const override;
    bool eventFilter(QObject* watched, QEvent* event) override;

protected:
    void start() override;
    void stop() override;

private:
    struct WindowState {
        qint64 lastFrame = 0;
        bool drawing = false;
        bool wantsNext = false;
    };

    static bool drawsFrame(QQuickWindow* window);
    static bool hasWork(QQuickWindow* window);
    void windowFrame(QQuickWindow* window, WindowState& state);
    void frameEnded(QQuickWindow* window);
    void tick(qint64 time);
    static qint64 now();
    static qint64 fastestInterval();

    qint64 mStart = 0;
    qint64 mClock = 0;
    QHash<QQuickWindow*, WindowState> mWindows;
    QTimer mFallback;
};
