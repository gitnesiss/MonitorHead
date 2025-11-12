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
import "Formatters.js" as Formatters

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

    property bool pitchIsLeftView: true
    property bool rollIsFrontView: true
    property bool yawIsFlipped: false

    // Свойства для управления 3D видом
    property bool innerEarVisible: true
    property bool innerHeadVisible: true

    // Новые свойства для исследования
    property string researchNumber: controller.researchNumber
    property bool recording: controller.recording

    property color graphTextColor: "#CCCCCC"  // Более яркий цвет для текста

    // Таймер записи исследования
    property int researchTimerSeconds: 0

    function startResearchTimer() {
        researchTimerSeconds = 0
        researchTimer.start()
        updateResearchTimerDisplay()
    }

    function stopResearchTimer() {
        researchTimer.stop()
        researchTimerSeconds = 0
        updateResearchTimerDisplay()
    }

    function updateResearchTimerDisplay() {
        var seconds = researchTimerSeconds % 60
        var minutes = Math.floor(researchTimerSeconds / 60) % 60
        var hours = Math.floor(researchTimerSeconds / 3600)

        researchTimerText.text =
            (hours < 10 ? "0" + hours : hours) + ":" +
            (minutes < 10 ? "0" + minutes : minutes) + ":" +
            (seconds < 10 ? "0" + seconds : seconds)
    }

    Timer {
        id: researchTimer
        interval: 1000
        repeat: true
        onTriggered: {
            researchTimerSeconds++
            updateResearchTimerDisplay()
        }
    }

    // Функция для обработки клавиши пробела
    function handleSpaceKey() {
        // РЕЖИМ ВОСПРОИЗВЕДЕНИЯ: пробел работает как плей/пауза
        if (controller.logMode && controller.logLoaded) {
            if (controller.logPlaying) {
                controller.pauseLog()
                showNotification("Воспроизведение приостановлено (ПРОБЕЛ)", false)
            } else {
                controller.playLog()
                showNotification("Воспроизведение продолжено (ПРОБЕЛ)", false)
            }
        }
        // РЕЖИМ РЕАЛЬНОГО ВРЕМЕНИ: пробел работает как запись/остановка записи
        else if (controller.connected && !controller.logMode) {
            if (!recording) {
                // Начинаем запись
                if (researchField.text.length === 6) {
                    controller.startResearchRecording(researchField.text)
                    showNotification("Запись исследования начата (ПРОБЕЛ)", false)
                } else {
                    showNotification("Номер исследования должен состоять из 6 цифр", true)
                }
            } else {
                // Останавливаем запись
                controller.stopResearchRecording()
                showNotification("Запись исследования остановлена (ПРОБЕЛ)", false)
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
            Layout.preferredHeight: 90
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

                    // Заменяем существующий блок исследования на:
                    Column {
                        spacing: 5
                        Layout.alignment: Qt.AlignVCenter
                        width: 120 // Фиксированная ширина для центрирования


                        Text {
                            text: "Исследование"  // Всегда одинаковая надпись в обоих режимах
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
                            // ОТОБРАЖАЕМ РАЗНЫЕ НОМЕРА В ЗАВИСИМОСТИ ОТ РЕЖИМА
                            text: controller.logMode ? controller.loadedResearchNumber : controller.researchNumber
                            enabled: !controller.logMode // Разрешаем редактирование только в режиме COM-порта
                            onTextChanged: {
                                if (!controller.logMode && text.length === 6) {
                                    controller.researchNumber = text
                                }
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

                            // Подсказка при наведении
                            ToolTip.visible: hovered
                            ToolTip.text: controller.logMode ?
                                "Номер загруженного исследования (только просмотр)" :
                                "Номер следующего исследования для записи"
                        }

                        // Таймер записи исследования
                        Text {
                            id: researchTimerText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "00:00:00"
                            color: {
                                if (controller.recording && controller.connected && !controller.logMode) {
                                    return "#4CAF50"  // Зеленый при активной записи
                                } else {
                                    return "#888"   // Серый в остальных случаях
                                }
                            }
                            font.pixelSize: 14
                            font.bold: controller.recording && controller.connected && !controller.logMode
                        }
                    }

                    // Кнопка записи исследования
                    Rectangle {
                        id: researchButton
                        width: 100
                        height: 50
                        radius: 6
                        enabled: controller.connected && !controller.logMode

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

                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                            ToolTip.text: {
                                if (!controller.connected) {
                                    return "Запись недоступна: нет подключения к COM-порту"
                                } else if (controller.logMode) {
                                    return "Запись недоступна в режиме воспроизведения"
                                } else if (recording) {
                                    return "Остановить запись текущего исследования\n(ПРОБЕЛ - остановка записи)"
                                } else {
                                    return "Начать запись нового исследования\n(ПРОБЕЛ - начало записи)"
                                }
                            }

                            onClicked: {
                                if (enabled) {
                                    if (!recording) {
                                        if (researchField.text.length === 6) {
                                            controller.startResearchRecording(researchField.text)
                                            recording = true
                                        } else {
                                            showNotification("Номер исследования должен состоять из 6 цифр", true)
                                        }
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
                        enabled: controller.connected && !controller.logMode && !controller.recording

                        property color normalColor: enabled ? "#9c27b0" : "#555"
                        property color hoverColor: enabled ? "#ac37c0" : "#666"
                        property color pressedColor: enabled ? "#7c3a5c" : "#444"

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
                            color: enabled ? "white" : "#888"
                            font.pixelSize: 14
                            font.bold: enabled
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: calibrationMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                            ToolTip.text: {
                                if (!controller.connected) {
                                    return "Калибровка недоступна: нет подключения"
                                } else if (controller.logMode) {
                                    return "Калибровка недоступна в режиме воспроизведения"
                                } else if (controller.recording) {
                                    return "Калибровка недоступна во время записи"
                                } else {
                                    return "Выполнить калибровку устройства"
                                }
                            }

                            onClicked: {
                                if (enabled) {
                                    // Действие для калибровки
                                    showNotification("Запущена калибровка устройства", false)
                                }
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

                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                            ToolTip.text: {
                                if (!enabled) {
                                    return "Невозможно загрузить исследование во время записи"
                                } else {
                                    return "Загрузить файл исследования для воспроизведения"
                                }
                            }

                            onClicked: {
                                if (enabled) {
                                    loadResearchDialog.open()
                                } else {
                                    showNotification("Невозможно загрузить исследование во время записи", true)
                                }
                            }
                        }
                    }

                    // НОВЫЙ БЛОК: УПРАВЛЕНИЕ ЧАСТОТОЙ ОБНОВЛЕНИЯ СКОРОСТИ ДЛЯ COM-ПОРТА (вертикальная компоновка)
                    ColumnLayout {
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 60
                        Layout.alignment: Qt.AlignVCenter
                        visible: controller.connected && !controller.logMode
                        spacing: 5

                        // Надпись сверху
                        Text {
                            id: comFrequencyLabel
                            text: "Частота обновления угловой скорости"
                            color: controller.connected ? "#aaa" : "#666"
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Комбобокс снизу
                        ComboBox {
                            id: comFrequencyCombo
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignHCenter
                            model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
                            currentIndex: controller.angularSpeedUpdateFrequencyCOM - 1
                            enabled: controller.connected && !controller.logMode

                            onActivated: {
                                var selectedFrequency = model[currentIndex];
                                controller.angularSpeedUpdateFrequencyCOM = selectedFrequency;
                            }

                            background: Rectangle {
                                color: controller.connected && !controller.logMode ? "#3c3c3c" : "#2c2c2c"
                                radius: 4
                                border.color: comFrequencyCombo.activeFocus ? "#2196F3" : "#555"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: comFrequencyCombo.displayText + " Гц"
                                color: controller.connected && !controller.logMode ? "white" : "#888"
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }

                            popup: Popup {
                                y: comFrequencyCombo.height
                                width: comFrequencyCombo.width
                                implicitHeight: contentItem.implicitHeight
                                padding: 1

                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: comFrequencyCombo.popup.visible ? comFrequencyCombo.delegateModel : null
                                    currentIndex: comFrequencyCombo.highlightedIndex

                                    ScrollIndicator.vertical: ScrollIndicator { }
                                }

                                background: Rectangle {
                                    color: "#3c3c3c"
                                    border.color: "#555"
                                    radius: 4
                                }
                            }

                            delegate: ItemDelegate {
                                width: comFrequencyCombo.width
                                height: 30
                                highlighted: comFrequencyCombo.highlightedIndex === index

                                contentItem: Text {
                                    text: modelData + " Гц"
                                    color: highlighted ? "#2196F3" : "white"
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                background: Rectangle {
                                    color: highlighted ? "#2c2c2c" : "transparent"
                                }
                            }
                        }
                    }

                    // НАСТРОЙКИ ДЛЯ ЛОГ-ФАЙЛА (компактный двухколоночный вид)
                    RowLayout {
                        Layout.preferredWidth: 320  // Фиксированная ширина для компактности
                        Layout.preferredHeight: 60
                        Layout.alignment: Qt.AlignVCenter
                        visible: controller.logLoaded && controller.logMode // ДОБАВЬТЕ controller.logMode
                        spacing: 15

                        // Первый столбец - Сглаживание
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5

                            // Надпись "Сглаживание" - выровнена по центру
                            Text {
                                text: "Сглаживание"
                                color: controller.logControlsEnabled ? "#aaa" : "#666"
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Комбобокс сглаживания
                            ComboBox {
                                id: smoothingCombo
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 30
                                model: {
                                    var values = [];
                                    // Первый диапазон: 0.1с до 1.5с с шагом 0.1с
                                    for (var i = 1; i <= 15; i++) {
                                        values.push((i * 0.1).toFixed(1) + "с");
                                    }
                                    // Второй диапазон: 2с до 10с с шагом 1с
                                    for (var j = 2; j <= 10; j++) {
                                        values.push(j + "с");
                                    }
                                    return values;
                                }

                                // Устанавливаем текущее значение из контроллера
                                Component.onCompleted: {
                                    var currentValue = controller.angularSpeedSmoothingLog.toFixed(1) + "с";
                                    var index = find(currentValue);
                                    if (index !== -1) {
                                        currentIndex = index;
                                    } else {
                                        // Если точного значения нет, находим ближайшее
                                        for (var i = 0; i < model.length; i++) {
                                            var val = parseFloat(model[i]);
                                            if (val >= controller.angularSpeedSmoothingLog) {
                                                currentIndex = i;
                                                break;
                                            }
                                        }
                                    }
                                }

                                onActivated: {
                                    var textValue = model[currentIndex];
                                    var numericValue = parseFloat(textValue);
                                    controller.angularSpeedSmoothingLog = numericValue;
                                }

                                ToolTip.text: {
                                    var currentValue = parseFloat(model[currentIndex]);
                                    return "Окно сглаживания: " + currentValue + " сек\n" +
                                           "Регулирует плавность отображения угловой скорости.\n" +
                                           "Больше значение = более плавные, но запаздывающие значения\n" +
                                           "Меньше значение = более резкие, но быстрые реакции"
                                }
                                ToolTip.visible: hovered
                                ToolTip.delay: 500

                                background: Rectangle {
                                    color: controller.logControlsEnabled ? "#3c3c3c" : "#2c2c2c"
                                    radius: 4
                                    border.color: smoothingCombo.activeFocus ? "#4CAF50" : "#555"
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: smoothingCombo.displayText
                                    color: controller.logControlsEnabled ? "white" : "#888"
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                popup: Popup {
                                    y: smoothingCombo.height
                                    width: smoothingCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: smoothingCombo.popup.visible ? smoothingCombo.delegateModel : null
                                        currentIndex: smoothingCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }

                                    background: Rectangle {
                                        color: "#3c3c3c"
                                        border.color: "#555"
                                        radius: 4
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: smoothingCombo.width
                                    height: 30
                                    highlighted: smoothingCombo.highlightedIndex === index

                                    contentItem: Text {
                                        text: modelData
                                        color: highlighted ? "#4CAF50" : "white"
                                        font.pixelSize: 11
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    background: Rectangle {
                                        color: highlighted ? "#2c2c2c" : "transparent"
                                    }
                                }
                            }
                        }

                        // Второй столбец - Обновление
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5

                            // Надпись "Обновление" - выровнена по центру
                            Text {
                                text: "Обновление"
                                color: controller.logControlsEnabled ? "#aaa" : "#666"
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Комбобокс обновления
                            ComboBox {
                                id: updateRateCombo
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 30
                                model: {
                                    var rates = [];
                                    for (var i = 1; i <= 30; i++) {
                                        rates.push(i + " Гц");
                                    }
                                    return rates;
                                }

                                // Устанавливаем текущее значение из контроллера
                                Component.onCompleted: {
                                    var currentValue = Math.round(controller.angularSpeedDisplayRateLog) + " Гц";
                                    currentIndex = find(currentValue);
                                }

                                onActivated: {
                                    var textValue = model[currentIndex];
                                    var numericValue = parseInt(textValue);
                                    controller.angularSpeedDisplayRateLog = numericValue;
                                }

                                ToolTip.text: {
                                    var currentValue = parseInt(model[currentIndex]);
                                    return "Частота обновления отображения: " + currentValue + " Гц\n" +
                                           "Регулирует, как часто обновляются цифры угловой скорости на экране.\n" +
                                           "Больше = плавнее анимация цифр, Меньше = меньше мелькания"
                                }
                                ToolTip.visible: hovered
                                ToolTip.delay: 500

                                background: Rectangle {
                                    color: controller.logControlsEnabled ? "#3c3c3c" : "#2c2c2c"
                                    radius: 4
                                    border.color: updateRateCombo.activeFocus ? "#2196F3" : "#555"
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: updateRateCombo.displayText
                                    color: controller.logControlsEnabled ? "white" : "#888"
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                popup: Popup {
                                    y: updateRateCombo.height
                                    width: updateRateCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: updateRateCombo.popup.visible ? updateRateCombo.delegateModel : null
                                        currentIndex: updateRateCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }

                                    background: Rectangle {
                                        color: "#3c3c3c"
                                        border.color: "#555"
                                        radius: 4
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: updateRateCombo.width
                                    height: 30
                                    highlighted: updateRateCombo.highlightedIndex === index

                                    contentItem: Text {
                                        text: modelData
                                        color: highlighted ? "#2196F3" : "white"
                                        font.pixelSize: 11
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    background: Rectangle {
                                        color: highlighted ? "#2c2c2c" : "transparent"
                                    }
                                }
                            }
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
                              "📁 Режим воспроизведения" :  // Было: "Режим лог-файла"
                              (controller.connected ? "🔌 Режим реального времени" : "⏳ Ожидание подключения")  // Было: "Режим COM-порта"
                        color: controller.logMode ? "#4caf50" : (controller.connected ? "#2196f3" : "#ff9800")
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: controller.logMode ?
                              Formatters.formatStudyInfo(controller.studyInfo) :
                              "Получение данных с датчика"
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
                AxisPanel {
                    axisName: "ТАНГАЖ / PITCH"
                    axisColor: "#BB86FC"
                    graphData: controller.pitchGraphData
                    lineColor: "#BB86FC"
                    currentAngle: controller.headModel.pitch
                    currentSpeed: controller.headModel.speedPitch
                    hasData: controller.headModel.hasData
                    graphDuration: controller.graphDuration
                    viewType: "pitch"
                    isLeftView: pitchIsLeftView

                    formattedAngle: Formatters.formatValue(controller.headModel.pitch, controller.headModel.hasData)
                    formattedSpeed: Formatters.getFormattedSpeed(
                        controller.headModel.speedPitch,
                        controller.connected,
                        controller.logMode,
                        controller.logLoaded,
                        controller.headModel.hasData
                    )

                    onViewToggled: pitchIsLeftView = !pitchIsLeftView
                }

                // === ROLL (крен) - ВТОРАЯ СТРОКА ===
                AxisPanel {
                    axisName: "КРЕН / ROLL"
                    axisColor: "#03DAC6"
                    graphData: controller.rollGraphData
                    lineColor: "#03DAC6"
                    currentAngle: controller.headModel.roll
                    currentSpeed: controller.headModel.speedRoll
                    hasData: controller.headModel.hasData
                    graphDuration: controller.graphDuration
                    viewType: "roll"
                    isFrontView: rollIsFrontView

                    formattedAngle: Formatters.formatValue(controller.headModel.roll, controller.headModel.hasData)
                    formattedSpeed: Formatters.getFormattedSpeed(
                        controller.headModel.speedRoll,
                        controller.connected,
                        controller.logMode,
                        controller.logLoaded,
                        controller.headModel.hasData
                    )

                    onViewToggled: rollIsFrontView = !rollIsFrontView
                }

                // === YAW (рыскание) - ТРЕТЬЯ СТРОКА ===
                AxisPanel {
                    axisName: "РЫСКАНЬЕ / YAW"
                    axisColor: "#CF6679"
                    graphData: controller.yawGraphData
                    lineColor: "#CF6679"
                    currentAngle: controller.headModel.yaw
                    currentSpeed: controller.headModel.speedYaw
                    hasData: controller.headModel.hasData
                    graphDuration: controller.graphDuration
                    viewType: "yaw"
                    isFlipped: yawIsFlipped

                    formattedAngle: Formatters.formatValue(controller.headModel.yaw, controller.headModel.hasData)
                    formattedSpeed: Formatters.getFormattedSpeed(
                        controller.headModel.speedYaw,
                        controller.connected,
                        controller.logMode,
                        controller.logLoaded,
                        controller.headModel.hasData
                    )

                    onViewToggled: yawIsFlipped = !yawIsFlipped
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
                            text: controller.logMode ?
                                  Formatters.formatStudyInfo(controller.studyInfo) :
                                  "Исследование не загружено"
                            color: controller.logControlsEnabled ? "#ccc" : "#888"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
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
                                            var newTime = Math.max(0, controller.currentTime - 5000); // Назад на 5 секунд
                                            controller.seekLog(newTime);
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded
                            ToolTip.text: "Назад на 5с"
                            background: Rectangle {
                                color: parent.down ? "#5a5a5a" : (parent.enabled ? "#3c3c3c" : "#2c2c2c")
                                radius: 4
                            }
                        }




                        Rectangle {
                            id: playPauseBtn
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 40
                            radius: 4
                            color: {
                                if (!controller.logControlsEnabled || !controller.logLoaded) {
                                    return "#3a5c42"
                                } else if (playPauseMouseArea.pressed) {
                                    return "#3a5c42"
                                } else if (playPauseMouseArea.containsMouse) {
                                    return "#5cbf62"
                                } else {
                                    return "#4caf50"
                                }
                            }
                            enabled: controller.logControlsEnabled && controller.logLoaded

                            Text {
                                anchors.centerIn: parent
                                text: controller.logPlaying ? "⏸️" : "▶️"
                                color: "white"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: playPauseMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (parent.enabled) {
                                        controller.logPlaying ? controller.pauseLog() : controller.playLog()
                                    }
                                }

                                ToolTip.visible: containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: {
                                    if (!parent.enabled) {
                                        return "Воспроизведение недоступно"
                                    } else if (controller.logPlaying) {
                                        return "Приостановить воспроизведение\n[ ПРОБЕЛ ]"
                                    } else {
                                        return "Начать воспроизведение\n[ ПРОБЕЛ ]"
                                    }
                                }
                            }
                        }

                        Button {
                            text: "⏩"
                            Layout.preferredWidth: 50
                            onClicked: {
                                if (controller.logControlsEnabled && controller.logLoaded) {
                                            var newTime = Math.min(controller.totalTime, controller.currentTime + 5000); // Вперед на 5 секунд
                                            controller.seekLog(newTime);
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
                            text: Formatters.formatTimeWithoutMs(0, controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true } // Распорка

                        // 25%
                        Text {
                            text: Formatters.formatTimeWithoutMs(controller.totalTime * 0.25, controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true } // Распорка

                        // Среднее время (50%)
                        Text {
                            text: Formatters.formatTimeWithoutMs(Math.round(controller.totalTime / 2), controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true } // Распорка

                        // 75%
                        Text {
                            text: Formatters.formatTimeWithoutMs(controller.totalTime * 0.75, controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true } // Распорка

                        // Конечное время - теперь в формате "текущее / общее"
                        Text {
                            id: currentTimeLabel
                            text: Formatters.formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)
                            color: controller.logControlsEnabled ? "#aaa" : "#666"
                            font.pixelSize: 12
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
                                    // ОБНОВЛЯЕМ ВРЕМЯ ПРИ ПЕРЕМЕЩЕНИИ
                                    currentTimeLabel.text = formatCurrentAndTotalTime(value, controller.totalTime)
                                }
                            }

                            // Обработка нажатия/отпускания - ИСПРАВЛЕННАЯ ВЕРСИЯ
                            onPressedChanged: {
                                if (!pressed && controller.logControlsEnabled && controller.logLoaded) {
                                    // Когда отпускаем слайдер, обновляем отображение времени
                                    currentTimeLabel.text = formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)
                                }
                            }

                            // Показываем текущее время при наведении (только время, без номера кадра)
                            ToolTip {
                                parent: timeSlider.handle
                                visible: timeSlider.hovered && controller.logLoaded
                                text: Formatters.formatResearchTime(Math.round(timeSlider.value), controller.totalTime)
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

                                // НЕМЕДЛЕННО ОБНОВЛЯЕМ ОТОБРАЖЕНИЕ ВРЕМЕНИ
                                currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(targetTime, controller.totalTime);
                            }

                            // Обработка перетаскивания для плавного следования бегунка за мышью
                            onPositionChanged: function(mouse) {
                                if (pressed && controller.logControlsEnabled && controller.logLoaded) {
                                    var clickPosition = mouse.x / width;
                                    var targetTime = Math.round(clickPosition * controller.totalTime);
                                    targetTime = Math.max(0, Math.min(controller.totalTime, targetTime));

                                    controller.seekLog(targetTime);
                                    timeSlider.value = targetTime;

                                    // ОБНОВЛЯЕМ ОТОБРАЖЕНИЕ ВРЕМЕНИ ПРИ ПЕРЕТАСКИВАНИИ
                                    currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(targetTime, controller.totalTime);
                                }
                            }

                            // ОБРАБОТКА ОТПУСКАНИЯ МЫШИ - ДОБАВЛЯЕМ ЭТОТ БЛОК
                            onReleased: {
                                // При отпускании мыши обновляем отображение времени
                                currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)
                            }
                        }
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
            if (loaded && controller.logMode) {
                showNotification("Лог-файл успешно загружен.\nПРОБЕЛ - управление воспроизведением", false)
            }
        }

        function onLoadedResearchNumberChanged() {
            if (controller.logMode) {
                researchField.text = controller.loadedResearchNumber
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

    Connections {
        target: controller

        function onAngularSpeedSmoothingLogChanged(smoothing) {
            // Обновляем комбобокс сглаживания при изменении значения из C++
            var valueToFind = smoothing.toFixed(1) + "с";
            var index = smoothingCombo.find(valueToFind);
            if (index !== -1 && smoothingCombo.currentIndex !== index) {
                smoothingCombo.currentIndex = index;
            }
        }

        function onAngularSpeedDisplayRateLogChanged(rate) {
            // Обновляем комбобокс частоты обновления при изменении значения из C++
            var valueToFind = Math.round(rate) + " Гц";
            var index = updateRateCombo.find(valueToFind);
            if (index !== -1 && updateRateCombo.currentIndex !== index) {
                updateRateCombo.currentIndex = index;
            }
        }

        function onRecordingChanged(isRecording) {
            recording = isRecording
            if (isRecording && controller.connected && !controller.logMode) {
                startResearchTimer()
            } else {
                stopResearchTimer()
            }
        }

        function onConnectedChanged(connected) {
            if (!connected) {
                stopResearchTimer()
            }
        }

        function onLogModeChanged() {
            // При переключении в режим воспроизведения останавливаем и сбрасываем таймер
            stopResearchTimer()

            // Принудительно обновляем текст поля при смене режима
            researchField.text = controller.logMode ?
                controller.loadedResearchNumber :
                controller.researchNumber

            // Принудительно обновляем интерфейс при смене режима
            if (controller.logMode) {
                console.log("Переключено в режим воспроизведения - блокируем калибровку и запись")
            } else {
                console.log("Переключено в режим реального времени - разблокируем калибровку")
            }

            // При переключении в режим воспроизведения показываем подсказку про пробел
            if (controller.logMode && controller.logLoaded) {
                showNotification("ПРОБЕЛ - управление воспроизведением", false)
            }
        }
    }

    // Обработчики для обновления комбобоксов частот
    Connections {
        target: controller
        function onAngularSpeedUpdateFrequencyCOMChanged(frequency) {
            // Обновляем COM комбобокс при изменении значения из C++
            comFrequencyCombo.currentIndex = frequency - 1;
        }

        function onAngularSpeedUpdateFrequencyLogChanged(frequency) {
            // Обновляем Log комбобокс при изменении значения из C++
            if (frequency <= 0.8) logFrequencyCombo.currentIndex = 0;
            else if (frequency <= 0.9) logFrequencyCombo.currentIndex = 1;
            else if (frequency <= 1.0) logFrequencyCombo.currentIndex = 2;
            else if (frequency <= 1.1) logFrequencyCombo.currentIndex = 3;
            else if (frequency <= 1.2) logFrequencyCombo.currentIndex = 4;
            else if (frequency <= 1.3) logFrequencyCombo.currentIndex = 5;
            else if (frequency <= 1.4) logFrequencyCombo.currentIndex = 6;
            else logFrequencyCombo.currentIndex = 7;
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
        target: controller
        function onPatientDizzinessChanged() {
            advanced3DHead.setDizzinessEffects(controller.patientDizziness, controller.doctorDizziness)
        }
        function onDoctorDizzinessChanged() {
            advanced3DHead.setDizzinessEffects(controller.patientDizziness, controller.doctorDizziness)
        }
    }

    Connections {
        target: controller
        function onConnectedChanged(connected) {
            if (!connected && !controller.logMode) {
                // Принудительно обновляем графики при отключении в режиме COM-порта
                pitchGraph.requestPaint()
                rollGraph.requestPaint()
                yawGraph.requestPaint()

                // Обновляем 3D вид
                advanced3DHead.setDizzinessEffects(false, false)
            }
        }
    }

    // Обработчик для обновления времени при любом изменении currentTime
    Connections {
        target: controller
        function onCurrentTimeChanged() {
            // Всегда обновляем отображение времени при изменении currentTime
            currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)
        }
    }

    // Обработчик для обновления времени при изменении состояния воспроизведения
    Connections {
        target: controller
        function onLogPlayingChanged() {
            // Обновляем время при запуске/остановке воспроизведения
            currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)
        }
    }

    Connections {
        target: controller
        function onCurrentTimeChanged() {
            // Всегда обновляем отображение времени при изменении currentTime
            currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)

            // Также обновляем значение слайдера, если он не нажат
            if (!timeSlider.pressed) {
                timeSlider.value = controller.currentTime
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

    // Таймер для обновления текущего времени на метке
    Timer {
        id: currentTimeUpdateTimer
        interval: 100 // Обновляем 10 раз в секунду для плавности
        running: controller.logPlaying // Работает только при воспроизведении лога
        repeat: true
        onTriggered: {
            // Принудительно обновляем текст метки текущего времени
            currentTimeLabel.text = Formatters.formatCurrentAndTotalTime(controller.currentTime, controller.totalTime)
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
