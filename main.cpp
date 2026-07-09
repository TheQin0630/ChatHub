#include <QGuiApplication>
#include <QFont>
#include <QFontDatabase>
#include <QIcon>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QPixmap>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QSurfaceFormat>

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

class StaticImageProvider : public QQuickImageProvider
{
public:
    explicit StaticImageProvider(const QImage &image)
        : QQuickImageProvider(QQuickImageProvider::Image)
        , image_(image)
    {
        if (image_.isNull()) {
            image_ = QImage(QSize(128, 128), QImage::Format_ARGB32_Premultiplied);
            image_.fill(Qt::transparent);
        }
    }

    QImage requestImage(const QString &, QSize *size, const QSize &requestedSize) override
    {
        if (size) {
            *size = image_.size();
        }
        if (requestedSize.isValid()) {
            return image_.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
        return image_;
    }

private:
    QImage image_;
};

QImage loadLogoImage()
{
    QImage image(QStringLiteral(":/icons/my_icon_light_ui.png"));
    if (!image.isNull()) {
        return image;
    }
    return QIcon(QStringLiteral(":/icons/my_icon_light.ico")).pixmap(QSize(128, 128)).toImage();
}
}

int main(int argc, char *argv[])
{
    QSurfaceFormat format;
    format.setSamples(4);
    QSurfaceFormat::setDefaultFormat(format);
    QQuickWindow::setTextRenderType(QQuickWindow::CurveTextRendering);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ChatHub"));
    app.setApplicationDisplayName(QStringLiteral("ChatHub"));
    const QString uiFontFamily = chooseUiFontFamily();
    QFont appFont(uiFontFamily);
    appFont.setStyleStrategy(static_cast<QFont::StyleStrategy>(QFont::PreferAntialias | QFont::PreferQuality));
    appFont.setHintingPreference(QFont::PreferVerticalHinting);
    app.setFont(appFont);
    app.setWindowIcon(QIcon(":/icons/my_icon_light.ico"));

    ChatController chatController;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("chatController", &chatController);
    engine.addImageProvider(QStringLiteral("appicons"), new StaticImageProvider(loadLogoImage()));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("ChatHub", "Main");

    return QGuiApplication::exec();
}
