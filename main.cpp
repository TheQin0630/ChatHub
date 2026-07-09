#include <QGuiApplication>
#include <QFont>
#include <QFontDatabase>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>

#include "src/controller/ChatController.h"

namespace {
QString chooseUiFontFamily()
{
    const QStringList candidates = {
        QStringLiteral("PingFang SC"),
        QStringLiteral("Microsoft YaHei UI"),
        QStringLiteral("Noto Sans CJK SC"),
        QStringLiteral("Source Han Sans SC"),
        QStringLiteral("Segoe UI")
    };
    const QStringList availableFamilies = QFontDatabase::families();
    for (const QString &candidate : candidates) {
        if (availableFamilies.contains(candidate, Qt::CaseInsensitive)) {
            return candidate;
        }
    }
    return QGuiApplication::font().family();
}
}

int main(int argc, char *argv[])
{
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ChatHub"));
    app.setApplicationDisplayName(QStringLiteral("ChatHub"));
    const QString uiFontFamily = chooseUiFontFamily();
    QFont appFont(uiFontFamily);
    app.setFont(appFont);
    app.setWindowIcon(QIcon(":/icons/my_icon_light.ico"));

    ChatController chatController;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("chatController", &chatController);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("ChatHub", "Main");

    return QGuiApplication::exec();
}
