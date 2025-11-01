#include <QtGui/QGuiApplication>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlContext>
#include <QtCore/QDebug>
#include <QtCore/QDir>
#include "tiltcontroller.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    app.setApplicationName("Head Tilt Monitor");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("YourCompany");

    // Явно регистрируем модули Qt 3D для поддержки Advanced3DHead
    qmlRegisterModule("QtQuick3D", 6, 0);
    qmlRegisterModule("QtQuick3D.Helpers", 6, 0);

    // Регистрируем тип в QML системе
    qmlRegisterType<TiltController>("MonitorHead", 1, 0, "TiltController");

    QQmlApplicationEngine engine;

    // Получаем путь к директории с исполняемым файлом для загрузки внешних моделей
    QString applicationDirPath = QDir::currentPath();
    engine.rootContext()->setContextProperty("applicationDirPath", applicationDirPath);

    // Создаем и регистрируем контроллер
    TiltController* controller = new TiltController(&app);
    engine.rootContext()->setContextProperty("controller", controller);

    // Загружаем основной QML файл
    engine.loadFromModule("MonitorHead", "Main");

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML!";
        return -1;
    }

    qDebug() << "✅ Main application started successfully";

    return app.exec();
}
