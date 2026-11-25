// What QML builds in the background (an asynchronous Loader), built a slice at a time
// after each frame, so the frames keep their beat. One per engine, set by the plugin.
#pragma once

#include <QList>
#include <QObject>
#include <QQmlIncubationController>
#include <QTimer>

class QQmlEngine;

class FrameIncubator : public QObject, public QQmlIncubationController {
public:
    static void attach(QQmlEngine* engine);
    static void frameEnded(qint64 interval);

protected:
    void incubatingObjectCountChanged(int count) override;

private:
    explicit FrameIncubator(QQmlEngine* engine);
    ~FrameIncubator() override;

    void step(qint64 interval);

    QTimer mFallback;
    static QList<FrameIncubator*> sIncubators;
};
