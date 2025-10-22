import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    width: 800
    height: 600
    visible: true
    title: "Тест подключения контроллера"
    color: "#1e1e1e"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Text {
            text: "Тест подключения контроллера"
            color: "white"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // Тест 1: Проверка доступности контроллера
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: controller ? "#2d2d2d" : "#f44336"
            radius: 8
            border.color: "#555"

            Text {
                anchors.centerIn: parent
                text: controller ? "✅ Контроллер доступен" : "❌ Контроллер НЕ доступен"
                color: "white"
                font.pixelSize: 16
            }
        }

        // Тест 2: Проверка модели головы
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: controller && controller.headModel ? "#2d2d2d" : "#f44336"
            radius: 8
            border.color: "#555"

            Text {
                anchors.centerIn: parent
                text: controller && controller.headModel ? 
                      "✅ HeadModel доступна" : "❌ HeadModel НЕ доступна"
                color: "white"
                font.pixelSize: 16
            }
        }

        // Тест 3: Отображение данных
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#2d2d2d"
            radius: 8
            border.color: "#555"

            Column {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "Данные HeadModel:"
                    color: "white"
                    font.pixelSize: 14
                }

                Text {
                    text: controller && controller.headModel ? 
                          "hasData: " + controller.headModel.hasData + 
                          ", Roll: " + controller.headModel.roll.toFixed(1) :
                          "Нет данных"
                    color: controller && controller.headModel && controller.headModel.hasData ? 
                           "white" : "#888"
                    font.pixelSize: 14
                }
            }
        }

        // Тест 4: COM порты
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#2d2d2d"
            radius: 8
            border.color: "#555"

            Column {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "COM порты:"
                    color: "white"
                    font.pixelSize: 14
                }

                Text {
                    text: controller ? 
                          controller.availablePorts.join(", ") : 
                          "Не доступно"
                    color: "white"
                    font.pixelSize: 12
                }
            }
        }

        // Тест 5: Кнопки для проверки
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "Установить тест данные"
                Layout.fillWidth: true
                onClicked: {
                    if (controller) {
                        controller.setTestData()
                    }
                }
                enabled: controller
                background: Rectangle {
                    color: parent.down ? "#3a5c42" : "#4caf50"
                    radius: 4
                }
            }

            // Button {
            //     text: "Установить тест данные"
            //     Layout.fillWidth: true
            //     onClicked: {
            //         if (controller) {
            //             controller.updateHeadModel(15.5, -8.2, 3.7, 2.1, 1.5, 0.8, false)
            //             console.log("Тестовые данные установлены")
            //         }
            //     }
            //     enabled: controller
            //     background: Rectangle {
            //         color: parent.down ? "#3a5c42" : "#4caf50"
            //         radius: 4
            //     }
            // }

            Button {
                text: "Сбросить данные"
                Layout.fillWidth: true
                onClicked: {
                    if (controller && controller.headModel) {
                        controller.headModel.resetData()
                        console.log("Данные сброшены")
                    }
                }
                enabled: controller && controller.headModel
                background: Rectangle {
                    color: parent.down ? "#7c3a3a" : "#f44336"
                    radius: 4
                }
            }
        }

        Button {
            text: "Подключиться к COM порту"
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            onClicked: {
                if (controller) {
                    controller.connectDevice()
                }
            }
            enabled: controller
            background: Rectangle {
                color: parent.down ? "#1a4b6b" : "#2196f3"
                radius: 4
            }
        }

        // Отладочная информация
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a1a1a"
            radius: 8
            border.color: "#555"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    text: getDebugInfo()
                    color: "#ccc"
                    font.pixelSize: 12
                    font.family: "Courier"
                }
            }
        }
    }

    function getDebugInfo() {
        if (!controller) return "Контроллер не доступен"
        
        let info = "=== ОТЛАДОЧНАЯ ИНФОРМАЦИЯ ===\n"
        info += "Controller: " + (controller ? "доступен" : "не доступен") + "\n"
        info += "HeadModel: " + (controller.headModel ? "доступна" : "не доступна") + "\n"
        
        if (controller.headModel) {
            info += "hasData: " + controller.headModel.hasData + "\n"
            info += "Pitch: " + controller.headModel.pitch + "\n"
            info += "Roll: " + controller.headModel.roll + "\n"
            info += "Yaw: " + controller.headModel.yaw + "\n"
        }
        
        info += "Connected: " + controller.connected + "\n"
        info += "Available Ports: " + controller.availablePorts + "\n"
        info += "Selected Port: " + controller.selectedPort + "\n"
        info += "Log Loaded: " + controller.logLoaded + "\n"
        info += "Log Mode: " + controller.logMode + "\n"
        
        return info
    }

    Component.onCompleted: {
        console.log("Application started")
        console.log("Controller available:", controller !== undefined)
        if (controller) {
            console.log("HeadModel available:", controller.headModel !== undefined)
            console.log("Available ports:", controller.availablePorts)
        }
    }
}
