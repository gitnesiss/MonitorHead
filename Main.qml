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
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200  // Фиксированная высота для строки
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Профиль лица (PITCH) - уменьшаем ширину чтобы график поместился
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 150  // Уменьшено с 200
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"

                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.strokeStyle = "#333"
                                    ctx.lineWidth = 1

                                    // Вертикальные линии
                                    for (var x = 0; x <= width; x += 20) {
                                        ctx.beginPath()
                                        ctx.moveTo(x, 0)
                                        ctx.lineTo(x, height)
                                        ctx.stroke()
                                    }

                                    // Горизонтальные линии
                                    for (var y = 0; y <= height; y += 20) {
                                        ctx.beginPath()
                                        ctx.moveTo(0, y)
                                        ctx.lineTo(width, y)
                                        ctx.stroke()
                                    }
                                }
                            }

                            // Линия профиля (упрощенная голова)
                            Shape {
                                anchors.centerIn: parent
                                width: 150
                                height: 150

                                ShapePath {
                                    strokeColor: "#BB86FC"
                                    strokeWidth: 3
                                    fillColor: "transparent"

                                    startX: 0; startY: 75
                                    PathLine { x: 150; y: 75 } // Базовая линия
                                }

                                // Индикатор наклона
                                Rectangle {
                                    width: 120
                                    height: 4
                                    color: controller.headModel.hasData ? "#BB86FC" : "#666"
                                    rotation: controller.headModel.pitch
                                    anchors.centerIn: parent
                                }
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 5
                                text: "Вид сбоку (PITCH)"
                                color: "#888"
                                font.pixelSize: 12
                            }
                        }

                        // Блоки данных PITCH
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 100  // Уменьшено с 120
                            spacing: 10

                            // Угол наклона
                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 70
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#BB86FC"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "PITCH"
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

                            // Скорость поворота
                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 70
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#03DAC6"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "СКОРОСТЬ PITCH"
                                        color: "#03DAC6"
                                        font.pixelSize: 10
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
                        }

                        // График PITCH - теперь занимает больше места
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true  // Заполняем всю доступную высоту
                            color: "#252525"
                            radius: 8
                            border.color: "#444"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

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
                                    minValue: -120  // Изменено с -90
                                    maxValue: 120   // Изменено с 90
                                }
                            }
                        }
                    }
                }

                // === ROLL (крен) - ВТОРАЯ СТРОКА ===
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200  // Фиксированная высота
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Вид сзади (ROLL) - уменьшаем ширину
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 150  // Уменьшено с 200
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"

                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.strokeStyle = "#333"
                                    ctx.lineWidth = 1

                                    for (var x = 0; x <= width; x += 20) {
                                        ctx.beginPath()
                                        ctx.moveTo(x, 0)
                                        ctx.lineTo(x, height)
                                        ctx.stroke()
                                    }

                                    for (var y = 0; y <= height; y += 20) {
                                        ctx.beginPath()
                                        ctx.moveTo(0, y)
                                        ctx.lineTo(width, y)
                                        ctx.stroke()
                                    }
                                }
                            }

                            // Круг для вида сверху/сзади
                            Rectangle {
                                width: 100
                                height: 100
                                radius: 50
                                color: "transparent"
                                border.color: "#03DAC6"
                                border.width: 2
                                anchors.centerIn: parent

                                // Индикатор крена
                                Rectangle {
                                    width: 80
                                    height: 4
                                    color: controller.headModel.hasData ? "#03DAC6" : "#666"
                                    rotation: controller.headModel.roll
                                    anchors.centerIn: parent
                                }
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 5
                                text: "Вид сзади (ROLL)"
                                color: "#888"
                                font.pixelSize: 12
                            }
                        }

                        // Блоки данных ROLL
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 100  // Уменьшено с 120
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 70
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#03DAC6"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "ROLL"
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
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 70
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#BB86FC"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "СКОРОСТЬ ROLL"
                                        color: "#BB86FC"
                                        font.pixelSize: 10
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
                        }

                        // График ROLL
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
                                    minValue: -120  // Изменено с -90
                                    maxValue: 120   // Изменено с 90
                                }
                            }
                        }
                    }
                }

                // === YAW (рыскание) - ТРЕТЬЯ СТРОКА ===
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200  // Фиксированная высота
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Вид сверху (YAW) - уменьшаем ширину
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 150  // Уменьшено с 200
                            color: "#1a1a1a"
                            radius: 6
                            border.color: "#333"

                            // График ROLL
                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.strokeStyle = "#333"
                                    ctx.lineWidth = 1

                                    for (var x = 0; x <= width; x += 20) {
                                        ctx.beginPath()
                                        ctx.moveTo(x, 0)
                                        ctx.lineTo(x, height)
                                        ctx.stroke()
                                    }

                                    for (var y = 0; y <= height; y += 20) {
                                        ctx.beginPath()
                                        ctx.moveTo(0, y)
                                        ctx.lineTo(width, y)
                                        ctx.stroke()
                                    }
                                }
                            }

                            // Стрелка для вида сверху
                            Shape {
                                anchors.centerIn: parent
                                width: 100
                                height: 100

                                ShapePath {
                                    strokeColor: "#CF6679"
                                    strokeWidth: 3
                                    fillColor: "transparent"

                                    startX: 50; startY: 80
                                    PathLine { x: 50; y: 20 }
                                    PathLine { x: 40; y: 40 }
                                    PathMove { x: 50; y: 20 }
                                    PathLine { x: 60; y: 40 }
                                }

                                // Индикатор поворота
                                Rectangle {
                                    width: 4
                                    height: 60
                                    color: controller.headModel.hasData ? "#CF6679" : "#666"
                                    rotation: controller.headModel.yaw
                                    anchors.centerIn: parent
                                }
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 5
                                text: "Вид сверху (YAW)"
                                color: "#888"
                                font.pixelSize: 12
                            }
                        }

                        // Блоки данных YAW
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 100  // Уменьшено с 120
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 70
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
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 70
                                color: "#2d2d2d"
                                radius: 6
                                border.color: "#FF9800"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: "СКОРОСТЬ YAW"
                                        color: "#FF9800"
                                        font.pixelSize: 10
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

                        // График YAW
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
                                    minValue: -120  // Изменено с -180
                                    maxValue: 120   // Изменено с 180
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

                            // Простая 3D-сетка для демонстрации
                            Canvas {
                                anchors.fill: parent
                                anchors.margins: 20

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

                                        // Индикатор головокружения
                                        if (controller.headModel.dizziness) {
                                            ctx.fillStyle = "rgba(255, 160, 0, 0.3)";
                                            ctx.fillRect(0, 0, width, height);

                                            ctx.fillStyle = "#FFA000";
                                            ctx.font = "bold 24px Arial";
                                            ctx.textAlign = "center";
                                            ctx.fillText("ГОЛОВОКРУЖЕНИЕ", width/2, height/2);
                                        }
                                    } else {
                                        // Текст "нет данных"
                                        ctx.fillStyle = "#666"
                                        ctx.font = "16px Arial"
                                        ctx.textAlign = "center"
                                        ctx.fillText("нет данных", width/2, height/2)
                                    }
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
