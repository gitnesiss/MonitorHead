#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QException>
#include "tiltcontroller.h"

void myMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QByteArray localMsg = msg.toLocal8Bit();
    const char *file = context.file ? context.file : "";
    const char *function = context.function ? context.function : "";

    switch (type) {
    case QtDebugMsg:
        fprintf(stderr, "Debug: %s (%s:%u, %s)\n", localMsg.constData(), file, context.line, function);
        break;
    case QtInfoMsg:
        fprintf(stderr, "Info: %s (%s:%u, %s)\n", localMsg.constData(), file, context.line, function);
        break;
    case QtWarningMsg:
        fprintf(stderr, "Warning: %s (%s:%u, %s)\n", localMsg.constData(), file, context.line, function);
        break;
    case QtCriticalMsg:
        fprintf(stderr, "Critical: %s (%s:%u, %s)\n", localMsg.constData(), file, context.line, function);
        break;
    case QtFatalMsg:
        fprintf(stderr, "Fatal: %s (%s:%u, %s)\n", localMsg.constData(), file, context.line, function);
        break;
    }
}

int main(int argc, char *argv[])
{
    // Устанавливаем обработчик сообщений
    qInstallMessageHandler(myMessageHandler);

    QGuiApplication app(argc, argv);

    app.setApplicationName("Head Tilt Monitor");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("YourCompany");

    try {
        // Регистрируем тип в QML системе
        qmlRegisterType<TiltController>("MonitorHead", 1, 0, "TiltController");

        QQmlApplicationEngine engine;

        // СОЗДАЕМ И РЕГИСТРИРУЕМ КОНТРОЛЛЕР В КОНТЕКСТЕ QML
        TiltController* controller = new TiltController(&app);
        engine.rootContext()->setContextProperty("controller", controller);

        qDebug() << "Starting application...";

        QObject::connect(
            &engine,
            &QQmlApplicationEngine::objectCreationFailed,
            &app,
            []() {
                qCritical() << "QML object creation failed!";
                QCoreApplication::exit(-1);
            },
            Qt::QueuedConnection);

        engine.loadFromModule("MonitorHead", "Main");

        if (engine.rootObjects().isEmpty()) {
            qCritical() << "Failed to load QML!";
            return -1;
        }

        qDebug() << "QML loaded successfully!";
        qDebug() << "Controller registered:" << (controller != nullptr);

        return app.exec();

    } catch (const std::exception& e) {
        qCritical() << "Exception in main:" << e.what();
        return -1;
    } catch (...) {
        qCritical() << "Unknown exception in main!";
        return -1;
    }
}
