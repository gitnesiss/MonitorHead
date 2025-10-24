import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

ApplicationWindow {
    id: mainWindow
    width: 1400
    height: 900
    minimumWidth: 1200
    minimumHeight: 700
    visible: true
    title: "Монитор положения головы"
    color: "#1e1e1e"

    // Функция для показа уведомлений
    function showNotification(message, isError) {
        if (notificationTimer.running) {
            return
        }
        notificationText.text = message
        notificationBackground.color = isError ? "#f44336" : "#4CAF50"
        notificationLayout.height = 40
        notificationTimer.restart()
    }

    // Функция для форматирования значений
    function formatValue(value, hasData) {
        return hasData ? value.toFixed(1) + "°" : "нет данных"
    }

    function formatSpeed(value, hasData) {
        return hasData ? value.toFixed(1) + "°/с" : "нет данных"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // === ВЕРХНЯЯ ПАНЕЛЬ: УВЕДОМЛЕНИЯ + НАСТРОЙКИ ПОРТА ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // === ЛЕВАЯ ЧАСТЬ - УВЕДОМЛЕНИЯ ===
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: notificationLayout.height
                color: "transparent"
                clip: true

                Rectangle {
                    id: notificationLayout
                    width: parent.width
                    height: 0
                    color: "transparent"
                    clip: true
                    radius: 6

                    Behavior on height {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        id: notificationBackground
                        anchors.fill: parent
                        color: "#4CAF50"
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                id: notificationIcon
                                text: "💡"
                                font.pixelSize: 16
                                color: "white"
                            }

                            Text {
                                id: notificationText
                                text: ""
                                color: "white"
                                font.pixelSize: 14
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }

                            Button {
                                text: "✕"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                onClicked: {
                                    notificationLayout.height = 0
                                    notificationTimer.stop()
                                }
                                background: Rectangle {
                                    color: "transparent"
                                    border.color: "white"
                                    border.width: 1
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    Timer {
                        id: notificationTimer
                        interval: 5000
                        onTriggered: {
                            notificationLayout.height = 0
                        }
                    }
                }
            }

            // === ПРАВАЯ ЧАСТЬ - НАСТРОЙКИ ПОРТА И СТАТУС ===
            RowLayout {
                spacing: 15

                // Блок настроек COM-порта
                Rectangle {
                    Layout.preferredWidth: 350
                    Layout.preferredHeight: 80
                    color: "#2d2d2d"
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "COM порт"
                                color: "#aaa"
                                font.pixelSize: 12
                            }

                            ComboBox {
                                id: comPortCombo
                                Layout.fillWidth: true
                                model: controller.availablePorts
                                onActivated: controller.selectedPort = currentText
                                background: Rectangle {
                                    color: "#3c3c3c"
                                    radius: 4
                                }
                            }
                        }

                        Button {
                            text: controller.connected ? "Отключить" : "Подключить"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignBottom
                            onClicked: {
                                if (controller.connected) {
                                    controller.disconnectDevice()
                                } else {
                                    controller.connectDevice()
                                }
                            }
                            background: Rectangle {
                                color: parent.down ?
                                    (controller.connected ? "#c43a1a" : "#1a6bc4") :
                                    (controller.connected ? "#e44a2a" : "#2a7be4")
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // Статус подключения
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 30
                    color: "#333"
                    radius: 15
                    border.color: "#555"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: controller.connected ? "#4CAF50" : "#f44336"
                        }

                        Text {
                            text: controller.connected ? "Подключено" : "Не подключено"
                            color: controller.connected ? "#4CAF50" : "#f44336"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // === ПАНЕЛЬ УПРАВЛЕНИЯ ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#2d2d2d"
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 15

                // Левая часть - информация о режиме и исследовании
                ColumnLayout {
                    spacing: 5

                    Text {
                        text: controller.logMode ?
                              "📁 Режим лог-файла" :
                              (controller.connected ? "🔌 Режим COM-порта" : "⏳ Ожидание подключения")
                        color: controller.logMode ? "#4caf50" : (controller.connected ? "#2196f3" : "#ff9800")
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: controller.logMode ? controller.studyInfo : "Режим реального времени"
                        color: "#aaa"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.maximumWidth: 400
                    }
                }

                Item { Layout.fillWidth: true } // Распорка

                // Правая часть - кнопки загрузки данных и калибровка
                RowLayout {
                    spacing: 10

                    Button {
                        text: "📁 Загрузить лог-файл"
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 40
                        onClicked: {
                            showNotification("Используйте поле ввода для загрузки файла", false)
                        }
                        background: Rectangle {
                            color: parent.down ? "#3a5c42" : "#4caf50"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "🔌 Перейти к COM-порту"
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 40
                        onClicked: controller.switchToCOMPortMode()
                        visible: controller.logMode
                        background: Rectangle {
                            color: parent.down ? "#1a4b6b" : "#2196f3"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "🎯 Калибровка"
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        background: Rectangle {
                            color: parent.down ? "#7c3a5c" : "#9c27b0"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // === ОТЛАДОЧНЫЙ БЛОК ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            color: "#2d2d2d"
            radius: 8
            border.color: "#555"
            visible: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Text {
                    text: "ОТЛАДКА - ИНТЕРВАЛЫ ГОЛОВОКРУЖЕНИЯ"
                    color: "#FF9800"
                    font.pixelSize: 12
                    font.bold: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 5

                    Text { text: "Активное головокружение:"; color: "#aaa"; font.pixelSize: 10 }
                    Text {
                        text: controller.headModel.dizziness ? "ДА 🔴" : "НЕТ 🟢"
                        color: controller.headModel.dizziness ? "#FFA000" : "#4CAF50"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Text { text: "Интервалов головокружения:"; color: "#aaa"; font.pixelSize: 10 }
                    Text {
                        text: controller.dizzinessData.length
                        color: controller.dizzinessData.length > 0 ? "#40FFA000" : "#aaa"
                        font.pixelSize: 10
                        font.bold: controller.dizzinessData.length > 0
                    }

                    Text { text: "Текущий интервал:"; color: "#aaa"; font.pixelSize: 10 }
                    Text {
                        text: {
                            if (controller.headModel.dizziness) {
                                return "АКТИВЕН ⏱️"
                            } else if (controller.dizzinessData.length > 0) {
                                return "ЗАВЕРШЕН ✅"
                            } else {
                                return "ОТСУТСТВУЕТ ❌"
                            }
                        }
                        color: controller.headModel.dizziness ? "#FFA000" :
                               (controller.dizzinessData.length > 0 ? "#4CAF50" : "#aaa")
                        font.pixelSize: 10
                    }

                    Text { text: "Данные Pitch:"; color: "#aaa"; font.pixelSize: 10 }
                    Text {
                        text: controller.pitchGraphData.length + " точек"
                        color: controller.pitchGraphData.length > 0 ? "#BB86FC" : "#f44336"
                        font.pixelSize: 10
                    }

                    Text { text: "Частота обновления:"; color: "#aaa"; font.pixelSize: 10 }
                    Text {
                        text: controller.updateFrequency + " Гц"
                        color: "#2196f3"
                        font.pixelSize: 10
                    }

                    Text { text: "Режим:"; color: "#aaa"; font.pixelSize: 10 }
                    Text {
                        text: controller.connected ? "COM-порт" : (controller.logLoaded ? "Лог-файл" : "Ожидание")
                        color: controller.connected ? "#4CAF50" : (controller.logLoaded ? "#2196F3" : "#FF9800")
                        font.pixelSize: 10
                    }
                }

                // Информация о последнем интервале
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    color: "transparent"
                    visible: controller.dizzinessData.length > 0

                    Text {
                        text: {
                            if (controller.dizzinessData.length > 0) {
                                var lastInterval = controller.dizzinessData[controller.dizzinessData.length - 1]
                                var duration = (lastInterval.endTime - lastInterval.startTime) / 1000
                                return "Последний интервал: " + duration.toFixed(1) + " сек"
                            }
                            return ""
                        }
                        color: "#40FFA000"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }
        }

        // === ОСНОВНАЯ ЧАСТЬ ЭКРАНА - РАЗДЕЛЕНА НА 2 СТОЛБЦА ===
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15

            // === ЛЕВАЯ ЧАСТЬ - 2D ВИЗУАЛИЗАЦИЯ (60% ширины) ===
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.6
                spacing: 10

                // === PITCH (тангаж) - ПЕРВАЯ СТРОКА ===
                Rectangle {
                    id: pitchContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    // Свойство для отслеживания текущего вида
                    property bool isLeftView: true

                    // Вычисляемое свойство для правильного вращения
                    property real displayPitch: isLeftView ? controller.headModel.pitch : -controller.headModel.pitch

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Вид слева/справа (PITCH) - квадратная область с возможностью переключения
                        Rectangle {
                            id: pitchViewContainer
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 180
                            Layout.alignment: Qt.AlignCenter
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"

                            // Область клика для переключения вида
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pitchContainer.isLeftView = !pitchContainer.isLeftView
                                }
                                ToolTip.visible: containsMouse
                                ToolTip.text: "Нажмите для переключения между видом слева и справа"
                                ToolTip.delay: 1000
                                hoverEnabled: true
                            }

                            // Изображение головы (вид слева или справа)
                            Image {
                                id: headImagePitch
                                anchors.fill: parent
                                anchors.margins: 15
                                source: pitchContainer.isLeftView ? "images/left_view.png" : "images/right_view.png"
                                fillMode: Image.PreserveAspectFit
                                rotation: pitchContainer.displayPitch  // Используем вычисляемое свойство
                                transformOrigin: Item.Center
                                smooth: true
                                opacity: controller.headModel.hasData ? 1.0 : 0.5

                                // Точка вращения (центр) - визуальный маркер
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFA000"
                                    anchors.centerIn: parent
                                    visible: controller.headModel.hasData
                                }
                            }

                            // Индикатор горизонта
                            Rectangle {
                                width: parent.width - 30
                                height: 1
                                color: controller.headModel.hasData ? "#FFA000" : "#666"
                                opacity: 0.5
                                anchors.centerIn: parent
                            }

                            // Индикатор текущего вида с пояснением направления
                            Column {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: 5
                                }
                                spacing: 2

                                Text {
                                    text: pitchContainer.isLeftView ? "СЛЕВА" : "СПРАВА"
                                    color: "#BB86FC"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            // Иконка переключения в углу
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: "#333"
                                border.color: "#666"
                                border.width: 1
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 5
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: pitchContainer.isLeftView ? "↺" : "↻"
                                    color: pitchContainer.isLeftView ? "white" : "#FFA000"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            // Текст с текущим углом
                            Text {
                                anchors {
                                    bottom: parent.bottom
                                    horizontalCenter: parent.horizontalCenter
                                    bottomMargin: 5
                                }
                                text: controller.headModel.hasData ? controller.headModel.pitch.toFixed(1) + "°" : ""
                                color: "#FFA000"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        // Блоки данных PITCH (остаются без изменений, показывают реальные значения с датчика)
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 100
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 40
                                color: "#252525"
                                radius: 6

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "ТАНГАЖ / PITCH"
                                        color: "#BB86FC"
                                        font.pixelSize: 16
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 60
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#BB86FC"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "ТЕКУЩИЙ УГОЛ"
                                        color: "#BB86FC"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: formatValue(controller.headModel.pitch, controller.headModel.hasData)
                                        color: controller.headModel.hasData ? "white" : "#888"
                                        font.pixelSize: controller.headModel.hasData ? 18 : 14
                                        font.bold: controller.headModel.hasData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 60
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#BB86FC"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "УГЛОВАЯ СКОРОСТЬ"
                                        color: "#BB86FC"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: {
                                            if (controller.connected && controller.headModel.hasData) {
                                                return formatSpeed(controller.headModel.speedPitch, true)
                                            } else if (controller.logLoaded && controller.headModel.hasData) {
                                                return formatSpeed(controller.headModel.speedPitch, true)
                                            } else {
                                                return "нет данных"
                                            }
                                        }
                                        color: (controller.connected || controller.logLoaded) && controller.headModel.hasData ? "white" : "#888"
                                        font.pixelSize: ((controller.connected || controller.logLoaded) && controller.headModel.hasData) ? 16 : 14
                                        font.bold: (controller.connected || controller.logLoaded) && controller.headModel.hasData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // // Индикатор текущего вида
                            // Rectangle {
                            //     Layout.preferredWidth: 120
                            //     Layout.preferredHeight: 25
                            //     color: "transparent"
                            //     border.color: "#03DAC6"
                            //     border.width: 1
                            //     radius: 4

                            //     Text {
                            //         anchors.centerIn: parent
                            //         text: pitchContainer.isLeftView ? "СЛЕВА" : "СПРАВА"
                            //         // text: rollContainer.isFrontView ? "ВИД СПЕРЕДИ" : "ВИД СЗАДИ"
                            //         color: "#03DAC6"
                            //         font.pixelSize: 9
                            //         font.bold: true
                            //     }
                            // }
                        }

                        // График PITCH (без изменений - показывает реальные данные)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#252525"
                            radius: 8
                            border.color: "#444"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 2

                                Text {
                                    text: "График PITCH (" + controller.graphDuration + " сек)"
                                    color: "#666"
                                    font.pixelSize: 12
                                    Layout.topMargin: 5
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                GraphCanvas {
                                    id: pitchGraph
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    graphData: controller.pitchGraphData
                                    dizzinessData: controller.dizzinessData
                                    graphDuration: controller.graphDuration
                                    lineColor: "#BB86FC"
                                    minValue: -120
                                    maxValue: 120
                                }
                            }
                        }
                    }
                }

                // === ROLL (крен) - ВТОРАЯ СТРОКА ===
                Rectangle {
                    id: rollContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    // Свойство для отслеживания текущего вида
                    property bool isFrontView: true

                    // Вычисляемое свойство для правильного вращения
                    property real displayRoll: isFrontView ? -controller.headModel.roll : controller.headModel.roll

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Вид спереди/сзади (ROLL) - квадратная область с возможностью переключения
                        Rectangle {
                            id: rollViewContainer
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 180
                            Layout.alignment: Qt.AlignCenter
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"

                            // Область клика для переключения вида
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rollContainer.isFrontView = !rollContainer.isFrontView
                                }
                                ToolTip.visible: containsMouse
                                ToolTip.text: "Нажмите для переключения между видом спереди и сзади"
                                ToolTip.delay: 1000
                                hoverEnabled: true
                            }

                            // Изображение головы (вид спереди или сзади)
                            Image {
                                id: headImageRoll
                                anchors.fill: parent
                                anchors.margins: 15
                                source: rollContainer.isFrontView ? "images/front_view.png" : "images/back_view.png"
                                fillMode: Image.PreserveAspectFit
                                rotation: rollContainer.displayRoll  // Используем вычисляемое свойство
                                transformOrigin: Item.Center
                                smooth: true
                                opacity: controller.headModel.hasData ? 1.0 : 0.5

                                // Точка вращения (центр) - визуальный маркер
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFA000"
                                    anchors.centerIn: parent
                                    visible: controller.headModel.hasData
                                }
                            }

                            // Индикатор горизонта
                            Rectangle {
                                width: 1
                                height: parent.height - 30
                                color: controller.headModel.hasData ? "#FFA000" : "#666"
                                opacity: 0.5
                                anchors.centerIn: parent
                            }

                            // Индикатор текущего вида с пояснением направления
                            Column {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: 5
                                }
                                spacing: 2

                                Text {
                                    text: rollContainer.isFrontView ? "СПЕРЕДИ" : "СЗАДИ"
                                    color: "#03DAC6"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            // Иконка переключения в углу
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: "#333"
                                border.color: "#666"
                                border.width: 1
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 5
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: rollContainer.isFrontView ? "↺" : "↻"
                                    color: rollContainer.isFrontView ? "white" : "#FFA000"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            // Текст с текущим углом (опционально)
                            Text {
                                anchors {
                                    bottom: parent.bottom
                                    horizontalCenter: parent.horizontalCenter
                                    bottomMargin: 5
                                }
                                text: controller.headModel.hasData ? controller.headModel.roll.toFixed(1) + "°" : ""
                                color: "#FFA000"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        // Блоки данных ROLL (остаются без изменений, показывают реальные значения с датчика)
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 100
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 40
                                color: "#252525"
                                radius: 6

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "КРЕН / ROLL"
                                        color: "#03DAC6"
                                        font.pixelSize: 16
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 60
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#03DAC6"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "ТЕКУЩИЙ УГОЛ"
                                        color: "#03DAC6"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: formatValue(controller.headModel.roll, controller.headModel.hasData)
                                        color: controller.headModel.hasData ? "white" : "#888"
                                        font.pixelSize: controller.headModel.hasData ? 18 : 14
                                        font.bold: controller.headModel.hasData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 60
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#03DAC6"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "УГЛОВАЯ СКОРОСТЬ"
                                        color: "#03DAC6"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: {
                                            if (controller.connected && controller.headModel.hasData) {
                                                return formatSpeed(controller.headModel.speedRoll, true)
                                            } else if (controller.logLoaded && controller.headModel.hasData) {
                                                return formatSpeed(controller.headModel.speedRoll, true)
                                            } else {
                                                return "нет данных"
                                            }
                                        }
                                        color: (controller.connected || controller.logLoaded) && controller.headModel.hasData ? "white" : "#888"
                                        font.pixelSize: ((controller.connected || controller.logLoaded) && controller.headModel.hasData) ? 16 : 14
                                        font.bold: (controller.connected || controller.logLoaded) && controller.headModel.hasData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // // Индикатор текущего вида
                            // Rectangle {
                            //     Layout.preferredWidth: 120
                            //     Layout.preferredHeight: 25
                            //     color: "transparent"
                            //     border.color: "#03DAC6"
                            //     border.width: 1
                            //     radius: 4

                            //     Text {
                            //         anchors.centerIn: parent
                            //         text: rollContainer.isFrontView ? "ВИД СПЕРЕДИ" : "ВИД СЗАДИ"
                            //         color: "#03DAC6"
                            //         font.pixelSize: 9
                            //         font.bold: true
                            //     }
                            // }
                        }

                        // График ROLL (без изменений - показывает реальные данные)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#252525"
                            radius: 8
                            border.color: "#444"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Text {
                                    text: "График ROLL (" + controller.graphDuration + " сек)"
                                    color: "#666"
                                    font.pixelSize: 12
                                    Layout.topMargin: 5
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                GraphCanvas {
                                    id: rollGraph
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    graphData: controller.rollGraphData
                                    dizzinessData: controller.dizzinessData
                                    graphDuration: controller.graphDuration
                                    lineColor: "#03DAC6"
                                    minValue: -120
                                    maxValue: 120
                                }
                            }
                        }
                    }
                }

                // === YAW (рыскание) - ТРЕТЬЯ СТРОКА ===
                Rectangle {
                    id: yawContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    // Свойство для отслеживания переворота изображения
                    property bool isFlipped: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Вид сверху (YAW) - квадратная область с возможностью переворота
                        Rectangle {
                            id: yawViewContainer
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 180
                            Layout.alignment: Qt.AlignCenter
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"

                            // Область клика для переворота
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    yawContainer.isFlipped = !yawContainer.isFlipped
                                }
                                ToolTip.visible: containsMouse
                                ToolTip.text: "Нажмите для переворота изображения"
                                ToolTip.delay: 1000
                                hoverEnabled: true
                            }

                            // Изображение головы (вид сверху)
                            Image {
                                id: headImageYaw
                                anchors.fill: parent
                                anchors.margins: 15
                                source: "images/top_view.png"
                                fillMode: Image.PreserveAspectFit
                                rotation: yawContainer.isFlipped ? (180 + controller.headModel.yaw) : controller.headModel.yaw
                                transformOrigin: Item.Center
                                smooth: true
                                opacity: controller.headModel.hasData ? 1.0 : 0.5

                                // Анимации
                                Behavior on rotation {
                                    PropertyAnimation { duration: 300 }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 200 }
                                }

                                // Точка вращения (центр) - визуальный маркер
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#FFA000"
                                    anchors.centerIn: parent
                                    visible: controller.headModel.hasData
                                }
                            }

                            // Индикатор горизонта
                            Rectangle {
                                width: 1
                                height: parent.height - 30
                                color: controller.headModel.hasData ? "#FFA000" : "#666"
                                opacity: 0.5
                                anchors.centerIn: parent
                            }

                            // Индикатор вида (всегда "СВЕРХУ")
                            Column {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: 5
                                }
                                spacing: 2

                                Text {
                                    text: "СВЕРХУ"
                                    color: "#CF6679"
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                // Text {
                                //     text: "⊕ по ч.с.\n⊖ против ч.с."
                                //     color: "#888"
                                //     font.pixelSize: 8
                                // }
                            }

                            // Индикатор состояния переворота (Иконка переключения в углу)
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: "#333"
                                border.color: "#666"
                                border.width: 1
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 5
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: yawContainer.isFlipped ? "↻" : "↺"
                                    color: yawContainer.isFlipped ? "#FFA000" : "white"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            // Текст с текущим углом
                            Text {
                                anchors {
                                    bottom: parent.bottom
                                    horizontalCenter: parent.horizontalCenter
                                    bottomMargin: 5
                                }
                                text: controller.headModel.hasData ? controller.headModel.yaw.toFixed(1) + "°" : ""
                                color: "#FFA000"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        // Блоки данных YAW (остаются без изменений, показывают реальные значения с датчика)
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 100
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 40
                                color: "#252525"
                                radius: 6

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "РЫСКАНЬЕ / YAW"
                                        color: "#CF6679"
                                        font.pixelSize: 16
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 60
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#CF6679"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "YAW"
                                        color: "#CF6679"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: formatValue(controller.headModel.yaw, controller.headModel.hasData)
                                        color: controller.headModel.hasData ? "white" : "#888"
                                        font.pixelSize: controller.headModel.hasData ? 18 : 14
                                        font.bold: controller.headModel.hasData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    // // Дополнительная подпись с направлением
                                    // Text {
                                    //     text: {
                                    //         if (!controller.headModel.hasData) return ""
                                    //         return controller.headModel.yaw > 0 ?
                                    //             "по ч.с." :
                                    //             (controller.headModel.yaw < 0 ? "против ч.с." : "прямо")
                                    //     }
                                    //     color: "#CF6679"
                                    //     font.pixelSize: 9
                                    //     anchors.horizontalCenter: parent.horizontalCenter
                                    // }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 60
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#CF6679"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "УГЛОВАЯ СКОРОСТЬ"
                                        color: "#CF6679"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: {
                                            if (controller.connected && controller.headModel.hasData) {
                                                return formatSpeed(controller.headModel.speedYaw, true)
                                            } else if (controller.logLoaded && controller.headModel.hasData) {
                                                return formatSpeed(controller.headModel.speedYaw, true)
                                            } else {
                                                return "нет данных"
                                            }
                                        }
                                        color: (controller.connected || controller.logLoaded) && controller.headModel.hasData ? "white" : "#888"
                                        font.pixelSize: ((controller.connected || controller.logLoaded) && controller.headModel.hasData) ? 16 : 14
                                        font.bold: (controller.connected || controller.logLoaded) && controller.headModel.hasData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }

                        // График YAW (без изменений - показывает реальные данные)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#252525"
                            radius: 8
                            border.color: "#444"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Text {
                                    text: "График YAW (" + controller.graphDuration + " сек)"
                                    color: "#666"
                                    font.pixelSize: 12
                                    Layout.topMargin: 5
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                GraphCanvas {
                                    id: yawGraph
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    graphData: controller.yawGraphData
                                    dizzinessData: controller.dizzinessData
                                    graphDuration: controller.graphDuration
                                    lineColor: "#CF6679"
                                    minValue: -120
                                    maxValue: 120
                                }
                            }
                        }
                    }
                }
            }

            // === ПРАВАЯ ЧАСТЬ - 3D ВИЗУАЛИЗАЦИЯ (40% ширины) ===
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.4
                spacing: 10

                // 3D визуализация головы
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Text {
                            text: "3D визуализация положения головы"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // Заглушка для OpenGL 3D визуализации
                        Rectangle {
                            id: visualizationContainer
                            width: parent.width
                            height: parent.height - 100
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"
                            border.width: 1

                            // Простая 3D-сетка для демонстрации
                            Canvas {
                                id: threeDCanvas
                                anchors.fill: parent
                                anchors.margins: 5

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    // 3D сетка
                                    ctx.strokeStyle = "#333"
                                    ctx.lineWidth = 1

                                    // Перспективные линии
                                    for (var i = 0; i <= 4; i++) {
                                        var pos = i * width/4
                                        ctx.beginPath()
                                        ctx.moveTo(pos, 0)
                                        ctx.lineTo(width/2, height/2)
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.moveTo(pos, height)
                                        ctx.lineTo(width/2, height/2)
                                        ctx.stroke()
                                    }

                                    if (controller.headModel.hasData) {
                                        // Упрощенная голова (куб в изометрии)
                                        ctx.strokeStyle = "#4CAF50"
                                        ctx.lineWidth = 2
                                        ctx.beginPath()
                                        // Передняя грань
                                        ctx.moveTo(width/2 - 40, height/2 - 30)
                                        ctx.lineTo(width/2 + 40, height/2 - 30)
                                        ctx.lineTo(width/2 + 40, height/2 + 50)
                                        ctx.lineTo(width/2 - 40, height/2 + 50)
                                        ctx.closePath()
                                        ctx.stroke()

                                        // Задняя грань
                                        ctx.beginPath()
                                        ctx.moveTo(width/2 - 20, height/2 - 50)
                                        ctx.lineTo(width/2 + 60, height/2 - 50)
                                        ctx.lineTo(width/2 + 60, height/2 + 30)
                                        ctx.lineTo(width/2 - 20, height/2 + 30)
                                        ctx.closePath()
                                        ctx.stroke()

                                        // Соединительные линии
                                        ctx.beginPath()
                                        ctx.moveTo(width/2 - 40, height/2 - 30)
                                        ctx.lineTo(width/2 - 20, height/2 - 50)
                                        ctx.moveTo(width/2 + 40, height/2 - 30)
                                        ctx.lineTo(width/2 + 60, height/2 - 50)
                                        ctx.moveTo(width/2 + 40, height/2 + 50)
                                        ctx.lineTo(width/2 + 60, height/2 + 30)
                                        ctx.moveTo(width/2 - 40, height/2 + 50)
                                        ctx.lineTo(width/2 - 20, height/2 + 30)
                                        ctx.stroke()

                                        // Индикатор головокружения - круговой градиент с правильными радиусами
                                        if (controller.headModel.dizziness) {
                                            // Вычисляем размеры области
                                            var a = width;   // ширина области 3D
                                            var b = height;  // высота области 3D

                                            // Находим меньший размер
                                            var minSize = Math.min(a, b);

                                            // Начальный радиус (90% от половины меньшего размера)
                                            var startRadius = minSize * 0.9 / 2;

                                            // Конечный радиус (больший размер, умноженный на 2)
                                            var endRadius = Math.max(a, b) * 0.9;

                                            // Центр области
                                            var centerX = a / 2;
                                            var centerY = b / 2;

                                            // Создаем круговой градиент
                                            var gradient = ctx.createRadialGradient(
                                                centerX, centerY, startRadius,  // центр и начальный радиус
                                                centerX, centerY, endRadius     // центр и конечный радиус
                                            );

                                            // Настраиваем градиент
                                            gradient.addColorStop(0, 'rgba(255, 160, 0, 0)');      // Прозрачно на начальном радиусе
                                            gradient.addColorStop(0.5, 'rgba(255, 160, 0, 0.2)');  // Полупрозрачно на середине
                                            gradient.addColorStop(1, 'rgba(255, 160, 0, 0.4)');    // Интенсивно на конечном радиусе

                                            // Применяем градиент ко всей области
                                            ctx.fillStyle = gradient;
                                            ctx.fillRect(0, 0, width, height);

                                            // Текст предупреждения
                                            ctx.fillStyle = "#FFA000";
                                            ctx.font = "bold 20px Arial";
                                            ctx.textAlign = "center";
                                            ctx.fillText("ГОЛОВОКРУЖЕНИЕ", width/2, 30);
                                        }
                                    } else {
                                        // Текст "нет данных"
                                        ctx.fillStyle = "#666";
                                        ctx.font = "16px Arial";
                                        ctx.textAlign = "center";
                                        ctx.fillText("нет данных", width/2, height/2);
                                    }
                                }
                            }

                            // Таймер для периодической перерисовки
                            Timer {
                                id: refreshTimer
                                interval: 100
                                running: true
                                repeat: true
                                onTriggered: {
                                    threeDCanvas.requestPaint();
                                }
                            }
                        }

                        // Текст с углами внизу
                        Rectangle {
                            width: parent.width
                            height: 60
                            color: "#2d2d2d"
                            radius: 6

                            Column {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "Текущие углы:"
                                    color: "#aaa"
                                    font.pixelSize: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: controller.headModel.hasData ?
                                          "Pitch: " + controller.headModel.pitch.toFixed(1) + "° | " +
                                          "Roll: " + controller.headModel.roll.toFixed(1) + "° | " +
                                          "Yaw: " + controller.headModel.yaw.toFixed(1) + "°" :
                                          "нет данных"
                                    color: controller.headModel.hasData ? "white" : "#888"
                                    font.pixelSize: 14
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    // Перерисовка при изменении состояния головокружения
                    Connections {
                        target: controller.headModel
                        function onDizzinessChanged() {
                            threeDCanvas.requestPaint();
                        }
                        function onPitchChanged() {
                            threeDCanvas.requestPaint();
                        }
                        function onRollChanged() {
                            threeDCanvas.requestPaint();
                        }
                        function onYawChanged() {
                            threeDCanvas.requestPaint();
                        }
                    }
                }
            }
        }

        // === УПРАВЛЕНИЕ ЛОГ-ФАЙЛОМ ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            color: controller.logControlsEnabled ? "#2d2d2d" : "#3d3d3d"
            radius: 8
            border.color: controller.logControlsEnabled ? "#555" : "#444"
            border.width: 1
            opacity: controller.logControlsEnabled ? 1.0 : 0.7

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "Управление воспроизведением лог-файла"
                    color: controller.logControlsEnabled ? "white" : "#888"
                    font.pixelSize: 16
                    font.bold: true
                }

                // Поле для ввода пути к файлу
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: filePathField
                        Layout.fillWidth: true
                        placeholderText: "Введите путь к лог-файлу"
                        selectByMouse: true
                        color: controller.logControlsEnabled ? "white" : "#888"
                        enabled: !controller.connected
                        background: Rectangle {
                            color: controller.logControlsEnabled ? "#3c3c3c" : "#2c2c2c"
                            radius: 4
                        }
                    }

                    Button {
                        text: "Загрузить"
                        onClicked: {
                            if (filePathField.text !== "") {
                                controller.loadLogFile(filePathField.text)
                            }
                        }
                        enabled: !controller.connected
                        background: Rectangle {
                            color: parent.down ? "#3a5c42" : (parent.enabled ? "#4caf50" : "#3a5c42")
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Кнопки управления
                    Button {
                        text: "⏮️"
                        Layout.preferredWidth: 50
                        onClicked: controller.seekLog(0)
                        enabled: controller.logControlsEnabled
                        ToolTip.text: "В начало"
                        background: Rectangle {
                            color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                            radius: 4
                        }
                    }

                    Button {
                        text: "⏪"
                        Layout.preferredWidth: 50
                        onClicked: controller.seekLog(Math.max(0, controller.currentTime - 10))
                        enabled: controller.logControlsEnabled
                        ToolTip.text: "Назад на 10с"
                        background: Rectangle {
                            color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                            radius: 4
                        }
                    }

                    Button {
                        id: playPauseBtn
                        text: controller.logPlaying ? "⏸️" : "▶️"
                        Layout.preferredWidth: 80
                        onClicked: controller.logPlaying ? controller.pauseLog() : controller.playLog()
                        enabled: controller.logControlsEnabled
                        ToolTip.text: controller.logPlaying ? "Пауза" : "Продолжить"
                        background: Rectangle {
                            color: parent.down ? "#3a5c42" : (parent.enabled ? "#4caf50" : "#3a5c42")
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "⏩"
                        Layout.preferredWidth: 50
                        onClicked: controller.seekLog(Math.min(controller.totalTime, controller.currentTime + 10))
                        enabled: controller.logControlsEnabled
                        ToolTip.text: "Вперед на 10с"
                        background: Rectangle {
                            color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                            radius: 4
                        }
                    }

                    Button {
                        text: "⏭️"
                        Layout.preferredWidth: 50
                        onClicked: controller.seekLog(controller.totalTime)
                        enabled: controller.logControlsEnabled
                        ToolTip.text: "В конец"
                        background: Rectangle {
                            color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                            radius: 4
                        }
                    }

                    Button {
                        text: "⏹️"
                        Layout.preferredWidth: 50
                        onClicked: controller.stopLog()
                        enabled: controller.logControlsEnabled
                        ToolTip.text: "Стоп"
                        background: Rectangle {
                            color: parent.down ? "#7c3a3a" : (parent.enabled ? "#f44336" : "#7c3a3a")
                            radius: 4
                        }
                    }

                    Item { Layout.fillWidth: true } // Распорка

                    Text {
                        text: {
                            var currentMinutes = Math.floor(controller.currentTime / 60)
                            var currentSeconds = Math.floor(controller.currentTime % 60)
                            var totalMinutes = Math.floor(controller.totalTime / 60)
                            var totalSeconds = Math.floor(controller.totalTime % 60)
                            return (currentMinutes < 10 ? "0" : "") + currentMinutes + ":" +
                                   (currentSeconds < 10 ? "0" : "") + currentSeconds + " / " +
                                   (totalMinutes < 10 ? "0" : "") + totalMinutes + ":" +
                                   (totalSeconds < 10 ? "0" : "") + totalSeconds
                        }
                        color: controller.logControlsEnabled ? "#ccc" : "#888"
                        font.pixelSize: 14
                    }
                }

                // Ползунок времени
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: controller.totalTime
                    value: controller.currentTime
                    onMoved: controller.seekLog(value)
                    enabled: controller.logControlsEnabled && !controller.logPlaying
                    background: Rectangle {
                        color: controller.logControlsEnabled ? "#3c3c3c" : "#2c2c2c"
                        radius: 2
                        height: 4
                    }
                    handle: Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: controller.logControlsEnabled ? "#2196f3" : "#666"
                        border.color: controller.logControlsEnabled ? "#1976d2" : "#555"
                        border.width: 2
                    }
                }
            }
        }
    }

    // Обработчики сигналов из C++
    Connections {
        target: controller
        function onNotificationChanged(message) {
            showNotification(message, false)
        }

        function onConnectedChanged(connected) {
            if (connected) {
                showNotification("Успешное подключение к " + controller.selectedPort, false)
            } else {
                showNotification("Отключено от COM-порта", false)
            }
        }

        function onLogLoadedChanged(loaded) {
            if (loaded) {
                showNotification("Лог-файл успешно загружен", false)
            }
        }

        function onLogModeChanged(logMode) {
            if (logMode) {
                showNotification("Переключено в режим лог-файла", false)
            }
        }
    }

    // Защита от сбоев COM-порта
    Connections {
        target: controller
        function onConnectedChanged(connected) {
            if (!connected) {
                cleanupTimer.restart()
            }
        }
    }

    Timer {
        id: cleanupTimer
        interval: 100
        onTriggered: {
            if (controller && controller.headModel) {
                // Ничего не делаем - просто даем время системе стабилизироваться
            }
        }
    }

    // Обработка критических ошибок
    function handleCriticalError(message) {
        console.error("Critical error:", message)
        showNotification("Критическая ошибка: " + message, true)
    }

    // Тестовое уведомление при запуске
    Component.onCompleted: {
        timer.start()
        console.log("Application started, headModel.hasData:", controller.headModel.hasData)
        console.log("Initial roll value:", controller.headModel.roll)
    }

    Timer {
        id: timer
        interval: 1000
        onTriggered: {
            showNotification("Система готова к работе", false)
        }
    }
}
