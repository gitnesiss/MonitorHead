import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Dialogs
import Qt3D.Core 2.15
import Qt3D.Render 2.15
import Qt3D.Input 2.15
import Qt3D.Extras 2.15

ApplicationWindow {
    id: mainWindow
    width: 1400
    height: 900
    minimumWidth: 1280
    minimumHeight: 720
    visible: true
    title: "Монитор положения головы"
    color: "#1e1e1e"

    // Убираем проблемные свойства фокуса и добавляем Shortcut
    Shortcut {
        sequence: "Space"
        onActivated: handleSpaceKey()
    }

    // Свойства для управления 3D видом
    property bool innerEarVisible: true
    property bool innerHeadVisible: true

    // Новые свойства для исследования
    property string researchNumber: controller.researchNumber
    property bool recording: controller.recording

    // Функция для обработки клавиши пробела
    function handleSpaceKey() {
        // Работает только в режиме COM-порта при подключении
        if (controller.connected && !controller.logMode) {
            if (!recording) {
                // Начинаем запись
                if (researchField.text.length === 6) {
                    controller.startResearchRecording(researchField.text);
                    showNotification("Запись исследования начата (ПРОБЕЛ)", false);
                } else {
                    showNotification("Номер исследования должен состоять из 6 цифр", true);
                }
            } else {
                // Останавливаем запись
                controller.stopResearchRecording();
                showNotification("Запись исследования остановлена (ПРОБЕЛ)", false);
            }
        }
    }

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

    // Функция для форматирования номера кадра в формат времени
    function formatResearchTime(frameNumber, totalFrames) {
        // console.log("Formatting frame:", frameNumber, "Total frames:", totalFrames);
        if (!controller.logLoaded || frameNumber === undefined) {
            return "00:00:00:00";
        }

        // Округляем номер кадра до целого
        var roundedFrame = Math.round(frameNumber);

        // Предполагаем частоту 60 кадров в секунду
        var framesPerSecond = 60;

        // Вычисляем общее количество секунд из номера кадра
        var totalSeconds = roundedFrame / framesPerSecond;

        // Вычисляем компоненты времени
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = Math.floor(totalSeconds % 60);
        var frames = roundedFrame % framesPerSecond;

        // Форматируем с ведущими нулями
        var hoursStr = hours.toString().padStart(2, '0');
        var minutesStr = minutes.toString().padStart(2, '0');
        var secondsStr = seconds.toString().padStart(2, '0');
        var framesStr = frames.toString().padStart(2, '0');

        return hoursStr + ":" + minutesStr + ":" + secondsStr + ":" + framesStr;
    }

    // Функция для форматирования информации об исследовании
    function formatStudyInfo(studyInfo) {
        if (!studyInfo) return "Исследование не загружено";

        // Убираем решетки и лишние пробелы
        var cleaned = studyInfo.replace(/#+/g, '').trim();

        // Разделяем на части
        var parts = cleaned.split('|').map(function(part) {
            return part.trim();
        }).filter(function(part) {
            return part.length > 0;
        });

        // Ищем части с номером исследования и датой
        var researchNumber = "";
        var researchDate = "";

        for (var i = 0; i < parts.length; i++) {
            var part = parts[i];
            if (part.includes("Исследование №")) {
                researchNumber = part;
            } else if (part.match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)) {
                researchDate = part;
            }
        }

        // Форматируем результат
        if (researchNumber && researchDate) {
            return researchNumber + " [" + researchDate + "]";
        } else if (researchNumber) {
            return researchNumber;
        } else if (researchDate) {
            return "Исследование [" + researchDate + "]";
        } else {
            return cleaned || "Исследование не загружено";
        }
    }

    // Функция для диагностики графиков
    function debugGraphs() {
        console.log("=== GRAPH DEBUG ===")
        console.log("COM Port connected:", controller.connected)
        console.log("Log mode:", controller.logMode)
        console.log("Log loaded:", controller.logLoaded)
        console.log("Log playing:", controller.logPlaying)
        console.log("Has data:", controller.headModel.hasData)
        console.log("Pitch graph points:", controller.pitchGraphData.length)
        console.log("Roll graph points:", controller.rollGraphData.length)
        console.log("Yaw graph points:", controller.yawGraphData.length)
        console.log("Dizziness intervals:", controller.dizzinessData.length)
        console.log("Graph duration:", controller.graphDuration)
        console.log("Current time:", controller.currentTime)
        console.log("Total time:", controller.totalTime)

        // Детальная информация о данных графиков
        if (controller.pitchGraphData.length > 0) {
            var firstPoint = controller.pitchGraphData[0]
            var lastPoint = controller.pitchGraphData[controller.pitchGraphData.length - 1]
            console.log("First pitch point - time:", firstPoint.time, "value:", firstPoint.value)
            console.log("Last pitch point - time:", lastPoint.time, "value:", lastPoint.value)

            // Проверяем преобразование координат
            var canvasWidth = pitchGraph.width
            var canvasHeight = pitchGraph.height
            var availableWidth = canvasWidth - 40 // учитываем отступ
            var xFirst = availableWidth - firstPoint.time / (controller.graphDuration * 1000) * availableWidth
            var yFirst = canvasHeight - ((firstPoint.value - (-120)) / 240) * canvasHeight
            console.log("First point coords - x:", xFirst, "y:", yFirst, "canvas:", canvasWidth + "x" + canvasHeight)
        }
        console.log("====================")

        // Принудительно обновляем графики
        pitchGraph.requestPaint()
        rollGraph.requestPaint()
        yawGraph.requestPaint()
    }

    // === ДИАЛОГОВОЕ ОКНО ДЛЯ ЗАГРУЗКИ ФАЙЛА ИССЛЕДОВАНИЯ ===
    FileDialog {
        id: loadResearchDialog
        title: "Выберите файл исследования"
        currentFolder: "file:///" + applicationDirPath + "/research"
        nameFilters: ["Текстовые файлы (*.txt)", "Все файлы (*)"]
        onAccepted: {
            console.log("Selected file:", selectedFile)
            controller.loadLogFile(selectedFile)
        }
        onRejected: {
            console.log("File selection canceled")
        }
    }

    // === ОСНОВНОЙ ИНТЕРФЕЙС ===
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

                        Rectangle {
                            id: connectButton
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignBottom
                            radius: 4

                            // Цвета для разных состояний
                            property color normalColor: controller.connected ? "#e44a2a" : "#2a7be4"
                            property color hoverColor: controller.connected ? "#f55a3a" : "#3a8bff"
                            property color pressedColor: controller.connected ? "#c43a1a" : "#1a6bc4"

                            color: {
                                if (mouseArea.pressed) {
                                    return pressedColor
                                } else if (mouseArea.containsMouse) {
                                    return hoverColor
                                } else {
                                    return normalColor
                                }
                            }

                            // Плавная анимация изменения цвета
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            // Текст кнопки
                            Text {
                                anchors.centerIn: parent
                                text: controller.connected ? "Отключить" : "Подключить"
                                color: "white"
                                font.bold: true
                            }

                            // Обработка кликов
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (controller.connected) {
                                        controller.disconnectDevice()
                                    } else {
                                        controller.connectDevice()
                                    }
                                }
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

                // Левая часть - исследование и кнопки
                RowLayout {
                    spacing: 15
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                    // Поле исследования с центрированной надписью
                    Column {
                        spacing: 5
                        Layout.alignment: Qt.AlignVCenter
                        width: 120 // Фиксированная ширина для центрирования

                        Text {
                            text: "Исследование:"
                            color: "#aaa"
                            font.pixelSize: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        TextField {
                            id: researchField
                            width: 120
                            placeholderText: "000000"
                            maximumLength: 6
                            validator: RegularExpressionValidator { regularExpression: /[0-9]{6}/ }
                            text: researchNumber
                            onTextChanged: {
                                if (text.length === 6) researchNumber = text
                            }
                            background: Rectangle {
                                color: "#3c3c3c"
                                radius: 4
                                border.color: researchField.activeFocus ? "#4caf50" : "#555"
                                border.width: 1
                            }
                            color: "white"
                            font.pixelSize: 14
                            horizontalAlignment: TextInput.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // Подсказка про пробел
                        Text {
                            text: "ПРОБЕЛ - запись"
                            color: "#666"
                            font.pixelSize: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: controller.connected && !controller.logMode
                        }
                    }

                    // Кнопка записи исследования
                    Rectangle {
                        id: researchButton
                        width: 100
                        height: 50
                        radius: 6
                        enabled: controller.connected

                        property color normalColor: recording ? "#e44a2a" : (enabled ? "#2a7be4" : "#555")
                        property color hoverColor: recording ? "#f55a3a" : (enabled ? "#3a8bff" : "#666")
                        property color pressedColor: recording ? "#c43a1a" : (enabled ? "#1a6bc4" : "#444")

                        color: {
                            if (!enabled) return normalColor;
                            if (researchMouseArea.pressed) {
                                return pressedColor
                            } else if (researchMouseArea.containsMouse) {
                                return hoverColor
                            } else {
                                return normalColor
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: recording ? "Остановить\nисследование" : "Записать\nисследование"
                            color: enabled ? "white" : "#888"
                            font.pixelSize: 12
                            font.bold: enabled
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: researchMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (enabled) {
                                    if (!recording) {
                                        controller.startResearchRecording(researchField.text)
                                        recording = true
                                    } else {
                                        controller.stopResearchRecording()
                                        recording = false
                                    }
                                } else {
                                    showNotification("Для записи необходимо подключение к COM-порту", true)
                                }
                            }
                        }
                    }

                    // Кнопка калибровки
                    Rectangle {
                        id: calibrationButton
                        width: 100
                        height: 50
                        radius: 6

                        property color normalColor: "#9c27b0"
                        property color hoverColor: "#ac37c0"
                        property color pressedColor: "#7c3a5c"

                        color: {
                            if (calibrationMouseArea.pressed) {
                                return pressedColor
                            } else if (calibrationMouseArea.containsMouse) {
                                return hoverColor
                            } else {
                                return normalColor
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Калибровка"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: calibrationMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Действие для калибровки
                            }
                        }
                    }

                    // Кнопка загрузки исследования (блокируется во время записи)
                    Rectangle {
                        id: loadResearchButton
                        width: 100
                        height: 50
                        radius: 6
                        enabled: !recording // Блокируем во время записи

                        property color normalColor: enabled ? "#4caf50" : "#555"
                        property color hoverColor: enabled ? "#5cbf62" : "#666"
                        property color pressedColor: enabled ? "#3a5c42" : "#444"

                        color: {
                            if (loadResearchMouseArea.pressed) {
                                return pressedColor
                            } else if (loadResearchMouseArea.containsMouse) {
                                return hoverColor
                            } else {
                                return normalColor
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Загрузить\nисследование"
                            color: enabled ? "white" : "#888"
                            font.pixelSize: 12
                            font.bold: enabled
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: loadResearchMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (enabled) {
                                    loadResearchDialog.open()
                                } else {
                                    showNotification("Невозможно загрузить исследование во время записи", true)
                                }
                            }
                        }
                    }

                    Button {
                        text: "Debug"
                        onClicked: debugGraphs()
                        background: Rectangle {
                            color: "#444"
                            radius: 4
                        }
                    }

                    Button {
                        text: "Debug Graphs"
                        onClicked: {
                            console.log("=== GRAPH DEBUG ===")
                            console.log("Pitch data points:", controller.pitchGraphData.length)
                            console.log("Roll data points:", controller.rollGraphData.length)
                            console.log("Yaw data points:", controller.yawGraphData.length)
                            console.log("Patient dizziness intervals:", controller.dizzinessPatientData.length)
                            console.log("Doctor dizziness intervals:", controller.dizzinessDoctorData.length)

                            if (controller.pitchGraphData.length > 0) {
                                var first = controller.pitchGraphData[0]
                                var last = controller.pitchGraphData[controller.pitchGraphData.length - 1]
                                console.log("First pitch point - time:", first.time, "value:", first.value)
                                console.log("Last pitch point - time:", last.time, "value:", last.value)
                            }
                            console.log("=== GRAPH DEBUG ===")
                        }
                    }
                }

                Item { Layout.fillWidth: true } // Распорка

                // Правая часть - информация о режиме
                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
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
                        text: controller.logMode ? formatStudyInfo(controller.studyInfo) : "Режим реального времени"
                        color: "#aaa"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.maximumWidth: 400
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
                    Layout.fillHeight: true
                    Layout.preferredHeight: 200
                    Layout.minimumHeight: 200
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
                                source: pitchContainer.isLeftView ? "qrc:/images/left_view.png" : "qrc:/images/right_view.png"
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
                                    dizzinessPatientData: controller.dizzinessPatientData
                                    dizzinessDoctorData: controller.dizzinessDoctorData
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
                    Layout.fillHeight: true
                    Layout.preferredHeight: 200
                    Layout.minimumHeight: 200
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
                                source: rollContainer.isFrontView ? "qrc:/images/front_view.png" : "qrc:/images/back_view.png"
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
                                    // dizzinessData: controller.dizzinessData
                                    dizzinessPatientData: controller.dizzinessPatientData
                                    dizzinessDoctorData: controller.dizzinessDoctorData
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
                    Layout.fillHeight: true
                    Layout.preferredHeight: 200
                    Layout.minimumHeight: 200
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
                                source: "qrc:/images/top_view.png"
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
                                    // dizzinessData: controller.dizzinessData
                                    dizzinessPatientData: controller.dizzinessPatientData
                                    dizzinessDoctorData: controller.dizzinessDoctorData
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#252525"
                    radius: 8
                    border.color: "#444"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        // Заголовок - по центру
                        Text {
                            text: "3D визуализация положения головы"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // 3D сцена
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#1a1a1a"
                            radius: 6

                            Advanced3DHead {
                                id: advanced3DHead
                                anchors.fill: parent
                                headPitch: controller.headModel.pitch
                                headRoll: controller.headModel.roll
                                headYaw: controller.headModel.yaw
                                showHead: innerHeadVisible
                                hasData: controller.headModel.hasData
                            }

                            // Кнопка управления головой в правом верхнем углу
                            Button {
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 10
                                }
                                width: 120
                                height: 40
                                text: innerHeadVisible ? "Скрыть голову" : "Показать голову"
                                onClicked: innerHeadVisible = !innerHeadVisible
                                ToolTip.text: innerHeadVisible ? "Скрыть модель головы" : "Показать модель головы"
                                ToolTip.visible: containsMouse
                                background: Rectangle {
                                    color: parent.down ? "#5a3c3c" : (innerHeadVisible ? "#7c3a3a" : "#3a5c3a")
                                    radius: 4
                                    border.color: "#666"
                                    border.width: 1
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            // Панель управления камерой в верхнем центре
                            Row {
                                anchors {
                                    top: parent.top
                                    horizontalCenter: parent.horizontalCenter
                                    topMargin: 10
                                }
                                spacing: 15 // Отступ между группами кнопок

                                // Первая группа - изометрический вид
                                Button {
                                    width: 40
                                    height: 40
                                    text: "🎯"
                                    onClicked: advanced3DHead.setCameraView("isometric")
                                    ToolTip.text: "Изометрический вид"
                                    ToolTip.visible: containsMouse
                                    background: Rectangle {
                                        color: parent.down ? "#5a5a5a" : "#3c3c3c"
                                        radius: 4
                                        border.color: "#666"
                                    }
                                }

                                // Вторая группа - остальные виды
                                Row {
                                    spacing: 5 // Отступ между кнопками в группе

                                    Button {
                                        id: frontBackButton
                                        width: 40
                                        height: 40
                                        text: "👁️"
                                        onClicked: advanced3DHead.toggleFrontBack()
                                        ToolTip.text: advanced3DHead.currentView === "front" ?
                                            "Переключить на вид сзади" : "Переключить на вид спереди"
                                        ToolTip.visible: containsMouse
                                        background: Rectangle {
                                            color: parent.down ? "#5a5a5a" : "#3c3c3c"
                                            radius: 4
                                            border.color: "#666"
                                        }
                                    }

                                    Button {
                                        id: leftRightButton
                                        width: 40
                                        height: 40
                                        text: "👈"
                                        onClicked: advanced3DHead.toggleLeftRight()
                                        ToolTip.text: advanced3DHead.currentView === "left" ?
                                            "Переключить на вид справа" : "Переключить на вид слева"
                                        ToolTip.visible: containsMouse
                                        background: Rectangle {
                                            color: parent.down ? "#5a5a5a" : "#3c3c3c"
                                            radius: 4
                                            border.color: "#666"
                                        }
                                    }

                                    Button {
                                        id: topBottomButton
                                        width: 40
                                        height: 40
                                        text: "⬇️"
                                        onClicked: advanced3DHead.toggleTopBottom()
                                        ToolTip.text: advanced3DHead.currentView === "top" ?
                                            "Переключить на вид снизу" : "Переключить на вид сверху"
                                        ToolTip.visible: containsMouse
                                        background: Rectangle {
                                            color: parent.down ? "#5a5a5a" : "#3c3c3c"
                                            radius: 4
                                            border.color: "#666"
                                        }
                                    }
                                }
                            }

                            // Надпись положения камеры в левом верхнем углу
                            Rectangle {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: 10
                                }
                                width: cameraPositionText.contentWidth + 20
                                height: cameraPositionText.contentHeight + 10
                                color: "#80000000"
                                radius: 5
                                border.color: "#444"
                                border.width: 1

                                Text {
                                    id: cameraPositionText
                                    anchors.centerIn: parent
                                    text: advanced3DHead.viewText
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            // Подсказка управления
                            Rectangle {
                                anchors {
                                    bottom: parent.bottom
                                    left: parent.left
                                    margins: 10
                                }
                                width: childrenRect.width + 10
                                height: childrenRect.height + 10
                                color: "#80000000"
                                radius: 4

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: "ЛКМ: вращать камеру"
                                        color: "#aaa"
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: "Колесо: zoom"
                                        color: "#aaa"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }





        // === ВОСПРОИЗВЕДЕНИЕ ИССЛЕДОВАНИЯ ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            color: controller.logControlsEnabled ? "#2d2d2d" : "#3d3d2d"
            radius: 8
            border.color: controller.logControlsEnabled ? "#555" : "#444"
            border.width: 1
            opacity: controller.logControlsEnabled ? 1.0 : 0.7

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8

                // ВЕРХНЯЯ СТРОКА: информация слева + кнопки по абсолютному центру
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    // ЛЕВАЯ ЧАСТЬ - информация об исследовании
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        width: Math.min(parent.width * 0.4, 400) // Ограничиваем ширину

                        Text {
                            text: "Воспроизведение исследования"
                            color: controller.logControlsEnabled ? "white" : "#888"
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: controller.logMode ? formatStudyInfo(controller.studyInfo) : "Исследование не загружено"
                            color: controller.logControlsEnabled ? "#ccc" : "#888"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        // Text {
                        //     text: controller.logMode ? controller.studyInfo : "Исследование не загружено"
                        //     color: controller.logControlsEnabled ? "#ccc" : "#888"
                        //     font.pixelSize: 12
                        //     elide: Text.ElideRight
                        //     maximumLineCount: 2
                        //     wrapMode: Text.Wrap
                        // }
                    }

                    // ЦЕНТРАЛЬНАЯ ЧАСТЬ - кнопки управления (абсолютный центр)
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Button {
                            text: "⏮️"
                            Layout.preferredWidth: 50
                            onClicked: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                    controller.seekLog(0)
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            ToolTip.text: "В начало"
                            background: Rectangle {
                                color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                                radius: 4
                            }
                        }

                        Button {
                            text: "⏪"
                            Layout.preferredWidth: 50
                            onClicked: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                    controller.seekLog(Math.max(0, controller.currentTime - 5))
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            ToolTip.text: "Назад на 5с"
                            background: Rectangle {
                                color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                                radius: 4
                            }
                        }

                        Button {
                            id: playPauseBtn
                            text: controller.logPlaying ? "⏸️" : "▶️"
                            Layout.preferredWidth: 80
                            onClicked: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                    controller.logPlaying ? controller.pauseLog() : controller.playLog()
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded
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
                            onClicked: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                    controller.seekLog(Math.min(controller.totalTime, controller.currentTime + 5))
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            ToolTip.text: "Вперед на 5с"
                            background: Rectangle {
                                color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                                radius: 4
                            }
                        }

                        Button {
                            text: "⏭️"
                            Layout.preferredWidth: 50
                            onClicked: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                    controller.seekLog(controller.totalTime)
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            ToolTip.text: "В конец"
                            background: Rectangle {
                                color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                                radius: 4
                            }
                        }

                        Button {
                            text: "⏹️"
                            Layout.preferredWidth: 50
                            onClicked: {
                                if (controller.logControlsEnabled) {
                                    controller.stopLog()
                                }
                            }
                            enabled: controller.logControlsEnabled
                            ToolTip.text: "Стоп"
                            background: Rectangle {
                                color: parent.down ? "#7c3a3a" : (parent.enabled ? "#f44336" : "#7c3a3a")
                                radius: 4
                            }
                        }
                    }
                }

                // Временная шкала с метками
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    // Метки времени над ползунком
                    RowLayout {
                        Layout.fillWidth: true

                        // Начальное время
                        Text {
                            text: formatResearchTime(0, controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true } // Распорка

                        // Среднее время
                        Text {
                            text: formatResearchTime(Math.round(controller.totalTime / 2), controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 10
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true } // Распорка

                        // Конечное время
                        Text {
                            text: formatResearchTime(controller.totalTime, controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 10
                            font.bold: true
                            Layout.alignment: Qt.AlignRight
                        }
                    }

                    // Контейнер для ползунка с дополнительной областью для клика
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40  // Увеличиваем высоту для удобства клика

                        // Ползунок времени
                        Slider {
                            id: timeSlider
                            anchors.fill: parent
                            from: 0
                            to: controller.totalTime
                            value: controller.currentTime
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            live: true  // Включаем обновление в реальном времени при перемещении

                            // Автоматическое обновление значения из контроллера
                            Binding {
                                target: timeSlider
                                property: "value"
                                value: controller.currentTime
                                when: !timeSlider.pressed
                            }

                            background: Rectangle {
                                color: controller.logControlsEnabled ? "#3c3c3c" : "#2c2c2c"
                                radius: 3
                                height: 6
                                anchors.verticalCenter: parent.verticalCenter

                                // Прогресс воспроизведения
                                Rectangle {
                                    width: timeSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: controller.logControlsEnabled ? "#2196f3" : "#666"
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: timeSlider.visualPosition * (timeSlider.availableWidth - width)
                                y: (timeSlider.availableHeight - height) / 2
                                width: 20  // Увеличиваем размер бегунка
                                height: 20
                                radius: 10
                                color: timeSlider.pressed ? "#1976d2" : (controller.logControlsEnabled ? "#2196f3" : "#666")
                                border.color: controller.logControlsEnabled ? "#1976d2" : "#555"
                                border.width: 2

                                // Эффект при наведении
                                scale: timeSlider.hovered ? 1.2 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 150 }
                                }
                            }

                            // Обработка перемещения ползунка
                            onMoved: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                    controller.seekLog(value)
                                }
                            }

                            // Обработка нажатия/отпускания
                            onPressedChanged: {
                                if (pressed && controller.logControlsEnabled && controller.logLoaded) {
                                    // Начали перемещение
                                } else if (!pressed && controller.logControlsEnabled && controller.logLoaded) {
                                    // Закончили перемещение - значение уже обновлено в onMoved
                                }
                            }

                            // Показываем текущее время при наведении (время в формате, кадр целым числом)
                            ToolTip {
                                parent: timeSlider.handle
                                visible: timeSlider.hovered && controller.logLoaded
                                text: formatResearchTime(Math.round(timeSlider.value), controller.totalTime) + " (" + Math.round(timeSlider.value) + " кадр)"
                                delay: 500
                            }
                        }

                        // Дополнительная MouseArea для клика в любом месте таймлайна
                        MouseArea {
                            anchors.fill: parent
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            cursorShape: Qt.PointingHandCursor

                            onClicked: function(mouse) {
                                if (!controller.logControlsEnabled || !controller.logLoaded) {
                                    return;
                                }

                                // Вычисляем позицию клика относительно ширины слайдера
                                var clickPosition = mouse.x / width;
                                var targetTime = Math.round(clickPosition * controller.totalTime); // Округляем до целого

                                // Переходим к вычисленному времени
                                controller.seekLog(targetTime);

                                // Обновляем значение слайдера
                                timeSlider.value = targetTime;
                            }

                            // Обработка перетаскивания для плавного следования бегунка за мышью
                            onPositionChanged: function(mouse) {
                                if (pressed && controller.logControlsEnabled && controller.logLoaded) {
                                    var clickPosition = mouse.x / width;
                                    var targetTime = Math.round(clickPosition * controller.totalTime);
                                    targetTime = Math.max(0, Math.min(controller.totalTime, targetTime));

                                    controller.seekLog(targetTime);
                                    timeSlider.value = targetTime;
                                }
                            }
                        }
                    }
                }

                // Дополнительная информация
                RowLayout {
                    Layout.fillWidth: true
                    visible: controller.logLoaded

                    Text {
                        text: "Скорость: " + (controller.logPlaying ? "▶ Воспроизведение" : "⏸ Пауза")
                        color: controller.logControlsEnabled ? "#4caf50" : "#666"
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Длительность: " + formatResearchTime(controller.totalTime, controller.totalTime)
                        color: controller.logControlsEnabled ? "#aaa" : "#666"
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Частота: " + controller.updateFrequency + " Гц"
                        color: controller.logControlsEnabled ? "#aaa" : "#666"
                        font.pixelSize: 11
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

        function onRecordingChanged(isRecording) {
            recording = isRecording
        }

        function onResearchNumberChanged(number) {
            researchNumber = number
            researchField.text = number
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

    Connections {
        target: controller.headModel
        function onDizzinessChanged() {
            advanced3DHead.setDizzinessEffect(controller.headModel.dizziness)
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

        // Инициализация номера исследования
        controller.initializeResearchNumber()
    }

    Timer {
        id: timer
        interval: 1000
        onTriggered: {
            showNotification("Система готова к работе", false)
        }
    }
}
