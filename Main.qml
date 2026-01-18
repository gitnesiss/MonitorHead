import QtQuick
import QtCore
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
    minimumHeight: 790
    visible: true
    title: "Монитор положения головы"
    color: "#1e1e1e"

    property string programVersion: "Версия 1.1.0"

    // Минималистичная черно-серая цветовая схема для кнопок
    property color buttonNormal: "#404040"
    property color buttonHover: "#505050"
    property color buttonPressed: "#303030"
    property color buttonDisabled: "#2a2a2a"

    property color buttonText: "#ffffff"
    property color buttonTextDisabled: "#888888"

    // Акцентные цвета (минимальные)
    property color accentSuccess: "#4CAF50"
    property color accentDanger: "#f44336"
    property color accentWarning: "#FF9800"

    // Свойство для управления видимостью бокового меню
    property bool sideMenuOpen: false

    // Свойство для управления подсказками
    property bool tooltipsEnabled: false

    // Свойство для установки начальных положений переключателей в
    // боковом меню 2D изображений
    property bool pitchIsLeftView: true
    property bool rollIsFrontView: true
    property bool yawIsFlipped: true

    // Свойства для управления 3D видом
    property bool innerEarVisible: true
    property bool innerHeadVisible: true

    // Новые свойства для исследования
    property string researchNumber: controller.researchNumber
    property bool recording: controller.recording

    property color graphTextColor: "#CCCCCC"

    // Таймер записи исследования
    property int researchTimerSeconds: 0

    // Функция для получения цветов кнопки в зависимости от состояния
    function getButtonColors(isEnabled, mouseArea, type) {
        if (!isEnabled) {
            return {
                normal: buttonDisabled,
                hover: buttonDisabled,
                pressed: buttonDisabled
            }
        }

        var colors = {}
        switch(type) {
            case "success":
                colors.normal = buttonSuccess
                colors.hover = buttonSuccessHover
                colors.pressed = buttonSuccessPressed
                break
            case "danger":
                colors.normal = buttonDanger
                colors.hover = buttonDangerHover
                colors.pressed = buttonDangerPressed
                break
            case "warning":
                colors.normal = buttonWarning
                colors.hover = buttonWarningHover
                colors.pressed = buttonWarningPressed
                break
            default: // primary
                colors.normal = buttonNormal
                colors.hover = buttonHover
                colors.pressed = buttonPressed
        }

        if (mouseArea.pressed) {
            return { normal: colors.pressed, hover: colors.pressed, pressed: colors.pressed }
        } else if (mouseArea.containsMouse) {
            return { normal: colors.hover, hover: colors.hover, pressed: colors.pressed }
        } else {
            return { normal: colors.normal, hover: colors.hover, pressed: colors.pressed }
        }
    }

    // Убираем проблемные свойства фокуса и добавляем Shortcut
    Shortcut {
        sequence: "Space"
        onActivated: handleSpaceKey()
    }

    // Добавляем shortcut для меню (Esc закрывает меню)
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (sideMenuOpen) {
                sideMenuOpen = false
            }
        }
    }

    // === ДИАЛОГОВОЕ ОКНО ДЛЯ ЗАГРУЗКИ ФАЙЛА ИССЛЕДОВАНИЯ (упрощенная версия) ===
    FileDialog {
        id: loadResearchDialog
        title: "Выберите файл исследования"

        // Просто используем стандартную папку документов + наш подкаталог
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) + "/MonitorHead/research"

        fileMode: FileDialog.OpenFile
        nameFilters: ["Текстовые файлы (*.txt)", "Все файлы (*)"]

        onAccepted: {
            var filePath = selectedFile.toString();
            // Убираем file:/// префикс
            if (filePath.startsWith("file:///")) {
                filePath = filePath.substring(8);
            }
            controller.loadLogFile(filePath);
        }
    }

    // === БОКОВОЕ МЕНЮ ===
    Rectangle {
        id: sideMenu
        width: 300
        height: parent.height
        x: sideMenuOpen ? 0 : -width
        y: 0
        color: "#2d2d2d"
        z: 1000

        Behavior on x {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        // MouseArea для перехвата всех кликов внутри меню
        MouseArea {
            anchors.fill: parent
            // Эта MouseArea перехватывает все клики внутри меню и предотвращает их распространение
            onClicked: {
                // Ничего не делаем, просто перехватываем клик
            }
            onPressed: {
                // Ничего не делаем, просто перехватываем нажатие
            }
            onReleased: {
                // Ничего не делаем, просто перехватываем отпускание
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            // Заголовок меню с кнопкой закрытия
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.bottomMargin: 10

                // Кнопка закрытия меню (гамбургер)
                Rectangle {
                    id: closeMenuButton
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    color: closeMenuMouseArea.pressed ? "#5a5a5a" : (closeMenuMouseArea.containsMouse ? "#3a3a3a" : "transparent")
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "☰"
                        color: "white"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: closeMenuMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sideMenuOpen = false
                    }

                    ToolTip.visible: tooltipsEnabled && closeMenuMouseArea.containsMouse
                    ToolTip.text: "Закрыть меню"
                }

                Text {
                    text: "Меню"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Пустой элемент для симметрии (чтобы текст оставался по центру)
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    color: "transparent"
                    visible: true // Сделаем видимым с прозрачным цветом, чтобы сместить надпись МЕНЮ в центр
                }
            }

            // Раздел: Настройки отображения
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "Настройки отображения"
                    color: "#4CAF50"
                    font.pixelSize: 16
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                }

                // Переключатель отключения подсказок
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: tooltipsToggleMouseArea.pressed ? "#3a3a3a" : (tooltipsToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 5

                        Text {
                            text: "Включить подсказки"
                            color: "white"
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 40
                            height: 20
                            radius: 10
                            color: mainWindow.tooltipsEnabled ? "#4CAF50" : "#666"

                            Rectangle {
                                x: mainWindow.tooltipsEnabled ? parent.width - width - 2 : 2
                                y: 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"

                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }

                    MouseArea {
                        id: tooltipsToggleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mainWindow.tooltipsEnabled = !mainWindow.tooltipsEnabled
                    }
                }

                // Переключатель вида тангажа
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: pitchToggleMouseArea.pressed ? "#3a3a3a" : (pitchToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5

                        Text {
                            text: "Наклон вперёд-назад:\nвид слева"
                            color: "white"
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 40
                            height: 20
                            radius: 10
                            color: pitchIsLeftView ? "#4CAF50" : "#666"

                            Rectangle {
                                x: pitchIsLeftView ? parent.width - width - 2 : 2
                                y: 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }

                    MouseArea {
                        id: pitchToggleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pitchIsLeftView = !pitchIsLeftView
                    }
                }

                // Переключатель вида крена
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: rollToggleMouseArea.pressed ? "#3a3a3a" : (rollToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5

                        Text {
                            text: "Наклон влево-вправо:\nвид спереди"
                            color: "white"
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 40
                            height: 20
                            radius: 10
                            color: rollIsFrontView ? "#4CAF50" : "#666"

                            Rectangle {
                                x: rollIsFrontView ? parent.width - width - 2 : 2
                                y: 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }

                    MouseArea {
                        id: rollToggleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rollIsFrontView = !rollIsFrontView
                    }
                }

                // Переключатель рыскания
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: yawToggleMouseArea.pressed ? "#3a3a3a" : (yawToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5

                        Text {
                            text: "Поворот влево-вправо:\nвзгляд вверх"
                            color: "white"
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 40
                            height: 20
                            radius: 10
                            color: yawIsFlipped ? "#4CAF50" : "#666"

                            Rectangle {
                                x: yawIsFlipped ? parent.width - width - 2 : 2
                                y: 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }

                    MouseArea {
                        id: yawToggleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: yawIsFlipped = !yawIsFlipped
                    }
                }

                // Переключатель модели головы
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: headToggleMouseArea.pressed ? "#3a3a3a" : (headToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 5

                        Text {
                            text: "Показывать модель головы"
                            color: "white"
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 40
                            height: 20
                            radius: 10
                            color: innerHeadVisible ? "#4CAF50" : "#666"

                            Rectangle {
                                x: innerHeadVisible ? parent.width - width - 2 : 2
                                y: 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                                Behavior on x {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }

                    MouseArea {
                        id: headToggleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: innerHeadVisible = !innerHeadVisible
                    }
                }

                // Слайдер прозрачности головы
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color: "transparent"
                    radius: 4

                    // Локальное свойство для хранения значения прозрачности
                    property real localHeadOpacity: advanced3DHead.headOpacity

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "Прозрачность головы"
                                color: "white"
                                font.pixelSize: 14
                                Layout.fillWidth: true
                            }

                            Text {
                                id: headOpacityValueText
                                text: Math.round(advanced3DHead.headOpacity * 100) + "%"
                                color: "#4CAF50"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Контейнер для слайдера прозрачности
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Slider {
                                id: headOpacitySlider
                                anchors.fill: parent
                                from: 0.0
                                to: 1.0
                                stepSize: 0.01
                                value: advanced3DHead.headOpacity
                                snapMode: Slider.SnapAlways
                                live: true

                                onValueChanged: {
                                    // Обновляем только когда пользователь взаимодействует со слайдером
                                    if (pressed) {
                                        advanced3DHead.headOpacity = Math.round(value * 100) / 100
                                        headOpacityValueText.text = Math.round(value * 100) + "%"
                                    }
                                }

                                onMoved: {
                                    // Дополнительная обработка для перемещения
                                    advanced3DHead.headOpacity = Math.round(value * 100) / 100
                                    headOpacityValueText.text = Math.round(value * 100) + "%"
                                }

                                background: Rectangle {
                                    color: "#3c3c3c"
                                    radius: 2
                                    height: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Rectangle {
                                        width: headOpacitySlider.visualPosition * parent.width
                                        height: parent.height
                                        // color: "#FFA500" // Оранжевый для прозрачности
                                        color: "#4CAF50"  // Зеленый цвет трека (было: "#FFA500" - оранжевый)
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: headOpacitySlider.visualPosition * (headOpacitySlider.availableWidth - width)
                                    y: headOpacitySlider.availableHeight / 2 - height / 2
                                    width: 20
                                    height: 20
                                    radius: 10
                                    // color: headOpacitySlider.pressed ? "#e69500" : "#FFA500"
                                    color: headOpacitySlider.pressed ? "#45a049" : "#4CAF50"  // Темно-зеленый при нажатии, зеленый обычно (было: "#e69500" и "#FFA500")
                                    border.color: "#ffffff"
                                    border.width: 2

                                    scale: headOpacitySlider.hovered ? 1.2 : 1.0
                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }
                        }
                    }

                    // Связь для обновления слайдера при изменении headOpacity извне
                    Connections {
                        target: advanced3DHead
                        function onHeadOpacityChanged() {
                            // Обновляем значение слайдера только если пользователь не взаимодействует с ним
                            if (!headOpacitySlider.pressed) {
                                headOpacitySlider.value = advanced3DHead.headOpacity
                                headOpacityValueText.text = Math.round(advanced3DHead.headOpacity * 100) + "%"
                            }
                        }
                    }

                    ToolTip.visible: tooltipsEnabled && headOpacitySlider.hovered
                    ToolTip.text: "Прозрачность модели головы: " + Math.round(advanced3DHead.headOpacity * 100) + "%\n" +
                                 "0% - полностью прозрачная\n" +
                                 "100% - полностью непрозрачная"
                }
            }

            // Раздел: Настройки ⚙️
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "Настройки️"
                    color: "#4CAF50"
                    font.pixelSize: 16
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 70
                    color: tooltipsToggleMouseArea.pressed ? "#3a3a3a" : (tooltipsToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    // Настройки для режима реального времени (COM)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 5

                        Text {
                            text: "Режим реального времени:"
                            color: "#4CAF50"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        // Строка для частоты обновления COM
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "Частота обновления угловой скорости"
                                color: "#cccccc"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(menuComFrequencySlider.value) + " Гц"
                                color: controller.connected && !controller.logMode ? "#2196F3" : "#888"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Контейнер для слайдера с увеличенной высотой
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Slider {
                                id: menuComFrequencySlider
                                anchors.fill: parent
                                from: 1
                                to: 30
                                stepSize: 1
                                value: controller.angularSpeedUpdateFrequencyCOM
                                enabled: controller.connected && !controller.logMode
                                snapMode: Slider.SnapAlways

                                onMoved: {
                                    controller.angularSpeedUpdateFrequencyCOM = Math.round(value)
                                }

                                background: Rectangle {
                                    color: "#3c3c3c"
                                    radius: 2
                                    height: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Rectangle {
                                        width: menuComFrequencySlider.visualPosition * parent.width
                                        height: parent.height
                                        color: controller.connected && !controller.logMode ? "#2196F3" : "#666"
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: menuComFrequencySlider.visualPosition * (menuComFrequencySlider.availableWidth - width)
                                    y: menuComFrequencySlider.availableHeight / 2 - height / 2
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: menuComFrequencySlider.pressed ? "#1976d2" : (controller.connected && !controller.logMode ? "#2196F3" : "#666")
                                    border.color: "#ffffff"
                                    border.width: 2

                                    scale: menuComFrequencySlider.hovered ? 1.2 : 1.0
                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && hovered
                                ToolTip.text: "Частота обновления данных с COM-порта: " + Math.round(value) + " Гц\n" +
                                             "Доступно только при подключении к устройству"
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                    Layout.topMargin: 5
                    Layout.bottomMargin: 5
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 140
                    color: tooltipsToggleMouseArea.pressed ? "#3a3a3a" : (tooltipsToggleMouseArea.containsMouse ? "#2a2a2a" : "transparent")
                    radius: 4

                    // Настройки для режима воспроизведения (лог)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 2

                        Text {
                            text: "Режим воспроизведения:"
                            color: "#4CAF50"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        // Строка для сглаживания
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "Окно сглаживания по времени"
                                color: "#cccccc"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(menuSmoothingSlider.value * 10) / 10 + " сек"
                                color: "#4CAF50"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Контейнер для слайдера сглаживания
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Slider {
                                id: menuSmoothingSlider
                                anchors.fill: parent
                                from: 0.1
                                to: 2.0
                                stepSize: 0.1
                                value: controller.angularSpeedSmoothingLog
                                snapMode: Slider.SnapAlways

                                onMoved: {
                                    controller.angularSpeedSmoothingLog = Math.round(value * 10) / 10
                                }

                                background: Rectangle {
                                    color: "#3c3c3c"
                                    radius: 2
                                    height: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Rectangle {
                                        width: menuSmoothingSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#4CAF50"
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: menuSmoothingSlider.visualPosition * (menuSmoothingSlider.availableWidth - width)
                                    y: menuSmoothingSlider.availableHeight / 2 - height / 2
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: menuSmoothingSlider.pressed ? "#45a049" : "#4CAF50"
                                    border.color: "#ffffff"
                                    border.width: 2

                                    scale: menuSmoothingSlider.hovered ? 1.2 : 1.0
                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && hovered
                                ToolTip.text: "Окно сглаживания: " + Math.round(value * 10) / 10 + " сек\n" +
                                             "Регулирует плавность отображения угловой скорости.\n" +
                                             "Больше значение = более плавные, но запаздывающие значения\n" +
                                             "Меньше значение = более резкие, но быстрые реакции"
                            }
                        }

                        // Строка для обновления
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "Частота обновления угловой скорости"
                                color: "#cccccc"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(menuUpdateRateSlider.value) + " Гц"
                                color: "#2196F3"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Контейнер для слайдера обновления
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Slider {
                                id: menuUpdateRateSlider
                                anchors.fill: parent
                                from: 1
                                to: 30
                                stepSize: 1
                                value: controller.angularSpeedDisplayRateLog
                                snapMode: Slider.SnapAlways

                                onMoved: {
                                    controller.angularSpeedDisplayRateLog = Math.round(value)
                                }

                                background: Rectangle {
                                    color: "#3c3c3c"
                                    radius: 2
                                    height: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Rectangle {
                                        width: menuUpdateRateSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#2196F3"
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: menuUpdateRateSlider.visualPosition * (menuUpdateRateSlider.availableWidth - width)
                                    y: menuUpdateRateSlider.availableHeight / 2 - height / 2
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: menuUpdateRateSlider.pressed ? "#1976d2" : "#2196F3"
                                    border.color: "#ffffff"
                                    border.width: 2

                                    scale: menuUpdateRateSlider.hovered ? 1.2 : 1.0
                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && hovered
                                ToolTip.text: "Частота обновления отображения: " + Math.round(value) + " Гц\n" +
                                             "Регулирует, как часто обновляются цифры угловой скорости на экране.\n" +
                                             "Больше = плавнее анимация цифр, Меньше = меньше мелькания"
                            }
                        }
                    }
                }
            }

            // Раздел: Система
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "Система"
                    color: "#4CAF50"
                    font.pixelSize: 16
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Кнопка справки
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: getButtonColors(true, helpButtonMouseArea, "primary").normal
                        radius: 4

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "Справка"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: helpButtonMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                openHelpInBrowser();
                                sideMenuOpen = false;
                            }
                        }
                    }

                    // Кнопка о программе
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: getButtonColors(true, aboutButtonMouseArea, "primary").normal
                        radius: 4

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "О программе"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: aboutButtonMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showAboutDialog()
                                sideMenuOpen = false
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Нижняя часть меню
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                }

                Text {
                    text: programVersion
                    color: "#888"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }

                // Кнопка выхода
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: exitButtonMouseArea.pressed ? "#7c3a3a" : (exitButtonMouseArea.containsMouse ? "#bf5c5c" : "#f44336")
                    radius: 4

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "Выход"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: exitButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }
        }
    }

    // Затемнение основного контента при открытом меню
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: "black"
        opacity: sideMenuOpen ? 0.5 : 0
        visible: opacity > 0
        z: 999

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        // MouseArea которая закрывает меню только при клике вне меню
        MouseArea {
            id: overlayMouseArea
            anchors.fill: parent
            enabled: sideMenuOpen
            onClicked: {
                // Проверяем, был ли клик вне области меню
                var clickPos = mapToItem(sideMenu, mouse.x, mouse.y);
                if (clickPos.x < 0 || clickPos.x > sideMenu.width ||
                    clickPos.y < 0 || clickPos.y > sideMenu.height) {
                    sideMenuOpen = false;
                }
            }
        }
    }

    // ДИАЛОГ "О ПРОГРАММЕ"
    Popup {
        id: aboutDialog
        width: 500
        height: 320
        modal: true
        focus: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#2d2d2d"
            radius: 8
            border.color: "#444"
            border.width: 2

            // Заголовок диалога
            Rectangle {
                id: aboutHeader
                width: parent.width
                height: 50
                color: "#3d3d3d"
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: "О программе"
                    color: "#4CAF50"
                    font.pixelSize: 16
                    font.bold: true
                }

                // Кнопка закрытия
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: closeAboutMouseArea.pressed ? "#7c3a3a" : (closeAboutMouseArea.containsMouse ? "#bf5c5c" : "transparent")
                    anchors {
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        id: closeAboutMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aboutDialog.close()
                    }
                }
            }
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 15

            ColumnLayout {
                Layout.topMargin: 55
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Монитор положения головы"
                    color: "#4CAF50"
                    font.pixelSize: 20
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: programVersion
                    color: "#aaa"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                }

                Text {
                    text: "Программа для мониторинга и анализа ориентации головы"
                    color: "white"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Разработано для медицинских исследований\nи диагностики вестибулярных нарушений"
                    color: "#aaa"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#555"
                }

                Text {
                    text: "Программа использует библиотеку Qt (https://www.qt.io) под лицензией GNU LGPL v3.\nCopyright (C) The Qt Company."
                    color: "#aaa"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Кнопка OK внизу
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 10
                radius: 4
                color: okAboutMouseArea.pressed ? "#45a049" : (okAboutMouseArea.containsMouse ? "#5cbf62" : "#4CAF50")

                Text {
                    anchors.centerIn: parent
                    text: "OK"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: okAboutMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: aboutDialog.close()
                }
            }
        }
    }

    // === ОСНОВНОЙ ИНТЕРФЕЙС ===
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        enabled: !sideMenuOpen

        // === ВЕРХНЯЯ ПАНЕЛЬ: КНОПКА МЕНЮ + УВЕДОМЛЕНИЯ ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // === ЛЕВАЯ ЧАСТЬ - ТОЛЬКО КНОПКА МЕНЮ ===
            Rectangle {
                id: menuButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                color: menuMouseArea.pressed ? "#5a5a5a" : (menuMouseArea.containsMouse ? "#3a3a3a" : "transparent")
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: "☰"
                    color: "white"
                    font.pixelSize: 18
                }

                MouseArea {
                    id: menuMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sideMenuOpen = !sideMenuOpen
                }

                ToolTip.visible: tooltipsEnabled && menuMouseArea.containsMouse
                ToolTip.text: "Открыть меню"
            }

            // === ЦЕНТРАЛЬНАЯ ЧАСТЬ - УВЕДОМЛЕНИЯ ===
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
                        color: "#666"
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                id: notificationIcon
                                text: "💡"
                                font.pixelSize: 16
                                color: "white"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                id: notificationText
                                text: ""
                                color: "white"
                                font.pixelSize: 14
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Button {
                                text: "✕"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter
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
                        interval: 10000
                        onTriggered: {
                            notificationLayout.height = 0
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

            // Используем Row вместо RowLayout для более точного позиционирования
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 15

                // === ЛЕВАЯ ЧАСТЬ - ИССЛЕДОВАНИЕ И КНОПКИ ===
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    // Блок исследования
                    Column {
                        spacing: 5
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "Исследование"
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
                            text: controller.logMode ? controller.loadedResearchNumber : controller.researchNumber
                            enabled: !controller.logMode
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

                            ToolTip.visible: tooltipsEnabled && hovered
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
                                    return "#4CAF50"
                                } else {
                                    return "#888"
                                }
                            }
                            font.pixelSize: 14
                            font.bold: controller.recording && controller.connected && !controller.logMode
                        }
                    }

                    // Кнопка записи исследования
                    Rectangle {
                        id: researchButton
                        width: 110
                        height: 50
                        radius: 6
                        enabled: controller.connected && !controller.logMode
                        anchors.verticalCenter: parent.verticalCenter

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
                            font.pixelSize: 14
                            font.bold: enabled
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: researchMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            ToolTip.visible: tooltipsEnabled && containsMouse
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
                        width: 110
                        height: 50
                        radius: 6
                        enabled: controller.connected && !controller.logMode && !controller.recording
                        anchors.verticalCenter: parent.verticalCenter

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

                            ToolTip.visible: tooltipsEnabled && containsMouse
                            ToolTip.delay: 500
                            ToolTip.text: {
                                if (!controller.connected) {
                                    return "Калибровка недоступна: нет подключения"
                                } else if (controller.logMode) {
                                    return "Калибровка недоступна в режиме воспроизведения"
                                } else if (controller.recording) {
                                    return "Калибровка недоступна во время записи"
                                } else {
                                    return "Выполнить калибровку устройства\n" +
                                           "Текущие смещения:\n" +
                                           "Pitch: " + controller.calibrationPitch.toFixed(1) + "°\n" +
                                           "Roll: " + controller.calibrationRoll.toFixed(1) + "°\n" +
                                           "Yaw: " + controller.calibrationYaw.toFixed(1) + "°"
                                }
                            }

                            onClicked: {
                                if (enabled) {
                                    controller.calibrateDevice()
                                }
                            }
                        }
                    }

                    // Кнопка загрузки исследования
                    Rectangle {
                        id: loadResearchButton
                        width: 110
                        height: 50
                        radius: 6
                        enabled: !recording
                        anchors.verticalCenter: parent.verticalCenter

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
                            font.pixelSize: 14
                            font.bold: enabled
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // ИСПРАВЛЕННЫЙ MouseArea:
                        MouseArea {
                            id: loadResearchMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            ToolTip.visible: tooltipsEnabled && containsMouse
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
                                    // Открываем диалог выбора файла вместо показа папки
                                    loadResearchDialog.open();
                                } else {
                                    showNotification("Невозможно загрузить исследование во время записи", true)
                                }
                            }
                        }
                    }

                    // Кнопка открытия папки исследований (ОТДЕЛЬНАЯ от кнопки загрузки файла)
                    Rectangle {
                        width: 50
                        height: 50
                        radius: 6
                        enabled: true
                        anchors.verticalCenter: parent.verticalCenter

                        property color normalColor: enabled ? "#9C27B0" : "#555"
                        property color hoverColor: enabled ? "#BA68C8" : "#666"
                        property color pressedColor: enabled ? "#7B1FA2" : "#444"

                        color: {
                            if (openFolderMouseArea.pressed) {
                                return pressedColor
                            } else if (openFolderMouseArea.containsMouse) {
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
                            text: "📁"
                            color: "white"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: openFolderMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            ToolTip.visible: tooltipsEnabled && containsMouse
                            ToolTip.delay: 500
                            ToolTip.text: "Открыть папку с исследованиями"

                            onClicked: {
                                controller.openResearchFolder()  // Открывает папку в проводнике
                            }
                        }
                    }
                }

                // === ЦЕНТРАЛЬНАЯ ЧАСТЬ - ИНФОРМАЦИЯ О РЕЖИМЕ (АБСОЛЮТНО ПО ЦЕНТРУ) ===
                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: controller.logMode ?
                              "Режим воспроизведения" :
                              (controller.connected ? "Режим реального времени" : "Ожидание подключения")
                        color: controller.logMode ? "#4caf50" : (controller.connected ? "#2196f3" : "#ff9800")
                        font.pixelSize: 14
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: controller.logMode ? "Чтение данных из файла" : "Ожидание действий пользователя"
                        color: "#aaa"
                        font.pixelSize: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // === ПРАВАЯ ЧАСТЬ - БЛОК ПОДКЛЮЧЕНИЯ (2 КОЛОНКИ) ===
                Rectangle {
                    width: 380
                    height: 80
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    color: "#282828"
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // ЛЕВАЯ КОЛОНКА - Источник (фиксированная ширина)
                        ColumnLayout {
                            Layout.preferredWidth: 80
                            Layout.minimumWidth: 80
                            Layout.maximumWidth: 80
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 5

                            Text {
                                text: "Источник"
                                color: "#aaa"
                                font.pixelSize: 11
                                font.bold: true
                                Layout.alignment: Qt.AlignLeft
                            }

                            ComboBox {
                                id: connectionTypeCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 25
                                model: ["WiFi", "COM-порт"]
                                currentIndex: controller.connectionType === "WiFi" ? 0 : 1
                                onActivated: {
                                    var type = currentIndex === 0 ? "WiFi" : "COM"
                                    controller.connectionType = type
                                    // Принудительно обновляем видимость панелей после смены
                                    Qt.callLater(function() {
                                        comPortSettings.visible = (type === "COM")
                                        wifiSettings.visible = (type === "WiFi")
                                    })
                                }

                                Layout.minimumWidth: 80
                                Layout.maximumWidth: 80
                                Layout.preferredWidth: 80

                                background: Rectangle {
                                    color: "#3c3c3c"
                                    radius: 4
                                    border.color: connectionTypeCombo.activeFocus ? "#4caf50" : "#555"
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: connectionTypeCombo.displayText
                                    color: "white"
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 8
                                    elide: Text.ElideRight
                                }

                                popup: Popup {
                                    y: connectionTypeCombo.height
                                    width: Math.max(connectionTypeCombo.width, 80)
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: connectionTypeCombo.popup.visible ? connectionTypeCombo.delegateModel : null
                                        currentIndex: connectionTypeCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }

                                    background: Rectangle {
                                        color: "#3c3c3c"
                                        border.color: "#555"
                                        radius: 4
                                    }
                                }

                                Component.onCompleted: {
                                    // Принудительно устанавливаем видимость панелей при запуске
                                    var type = controller.connectionType === "WiFi" ? "WiFi" : "COM"
                                    comPortSettings.visible = (type === "COM")
                                    wifiSettings.visible = (type === "WiFi")
                                }
                            }
                        }

                        // ПРАВАЯ КОЛОНКА - Объединенные настройки и управление
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#202020"  // Более темный фон
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 10

                                // НАСТРОЙКИ ПОДКЛЮЧЕНИЯ (растягивается)
                                ColumnLayout {
                                    id: connectionSettingsColumn
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 5

                                    // COM-порт настройки
                                    ColumnLayout {
                                        id: comPortSettings
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2
                                        visible: false  // ИЗМЕНЕНО: по умолчанию скрыто

                                        Text {
                                            text: "COM-порт"
                                            color: "#aaa"
                                            font.pixelSize: 12
                                            font.bold: true
                                            Layout.alignment: Qt.AlignLeft
                                        }

                                        ComboBox {
                                            id: comPortCombo
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 25
                                            model: [] // Начально пустой массив
                                            currentIndex: -1
                                            enabled: !controller.connected
                                            editable: false

                                            // Обновляем список при отображении (onVisibleChanged)
                                            onVisibleChanged: {
                                                if (visible) {
                                                    updatePortsList();
                                                }
                                            }

                                            // Обновляем список при активации выпадающего списка
                                            onActivated: {
                                                // Обновляем список перед показом вариантов
                                                updatePortsList();

                                                // Устанавливаем выбранный порт
                                                if (currentIndex >= 0 && currentIndex < model.length) {
                                                    var port = model[currentIndex];
                                                    if (port !== controller.selectedPort) {
                                                        controller.selectedPort = port;
                                                        showNotification("Выбран порт: " + port, false);
                                                    }
                                                }
                                            }

                                            // Функция для обновления списка портов
                                            function updatePortsList() {
                                                var currentPort = controller.selectedPort;
                                                var ports = controller.availablePorts;

                                                // Устанавливаем модель
                                                comPortCombo.model = ports;

                                                // Устанавливаем текущий индекс
                                                var index = ports.indexOf(currentPort);
                                                if (index >= 0) {
                                                    comPortCombo.currentIndex = index;
                                                } else if (ports.length > 0) {
                                                    // Если выбранный порт не найден, выбираем первый
                                                    comPortCombo.currentIndex = 0;
                                                    controller.selectedPort = ports[0];
                                                } else {
                                                    comPortCombo.currentIndex = -1;
                                                }

                                                // Логируем обновление
                                                console.log("Ports list updated:", ports, "Selected:", currentPort, "Index:", comPortCombo.currentIndex);
                                            }

                                            // Обновляем список при наведении мыши
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    if (!controller.connected) {
                                                        comPortCombo.updatePortsList();
                                                    }
                                                }
                                                onClicked: {
                                                    // Открываем список программно
                                                    if (!controller.connected) {
                                                        comPortCombo.popup.open();
                                                    }
                                                }
                                            }

                                            // Делегат для элементов списка
                                            delegate: ItemDelegate {
                                                width: comPortCombo.width
                                                height: 30
                                                padding: 5

                                                contentItem: Text {
                                                    text: modelData
                                                    color: "white"
                                                    font.pixelSize: 12
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                }

                                                background: Rectangle {
                                                    color: highlighted ? "#4caf50" : (hovered ? "#3a3a3a" : "transparent")
                                                    radius: 2
                                                }

                                                ToolTip.visible: tooltipsEnabled && hovered
                                                ToolTip.text: "Нажмите для выбора порта " + modelData
                                                ToolTip.delay: 500

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        controller.selectedPort = modelData;
                                                        comPortCombo.popup.close();
                                                        showNotification("Выбран порт: " + modelData, false);
                                                    }
                                                }
                                            }

                                            popup: Popup {
                                                id: portPopup
                                                y: comPortCombo.height + 2
                                                width: Math.max(comPortCombo.width, 150)
                                                implicitHeight: contentItem.implicitHeight + 30 // Учитываем заголовок
                                                padding: 0 // Убираем внутренние отступы
                                                modal: true
                                                focus: true
                                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                                // Фон для всего Popup
                                                background: Rectangle {
                                                    color: "#3c3c3c"
                                                    border.color: "#555"
                                                    radius: 4

                                                    // Заголовок Popup
                                                    Rectangle {
                                                        id: popupHeader
                                                        width: parent.width
                                                        height: 30
                                                        color: "#3a3a3a"
                                                        radius: 4

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 5
                                                            spacing: 10

                                                            Text {
                                                                text: "COM-порты"
                                                                color: "white"
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                                Layout.fillWidth: true
                                                            }

                                                            // Кнопка обновления
                                                            Rectangle {
                                                                Layout.preferredWidth: 24
                                                                Layout.preferredHeight: 24
                                                                radius: 12
                                                                color: refreshPortsMouseArea.pressed ? "#45a049" :
                                                                       (refreshPortsMouseArea.containsMouse ? "#4caf50" : "#666")

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: "🔄"
                                                                    color: "white"
                                                                    font.pixelSize: 12
                                                                }

                                                                MouseArea {
                                                                    id: refreshPortsMouseArea
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: {
                                                                        comPortCombo.updatePortsList();
                                                                    }
                                                                }

                                                                ToolTip.visible: tooltipsEnabled && refreshPortsMouseArea.containsMouse
                                                                ToolTip.text: "Обновить список портов"
                                                                ToolTip.delay: 500
                                                            }
                                                        }
                                                    }
                                                }

                                                contentItem: Column {
                                                    width: parent.width

                                                    // Пустой элемент для смещения контента под заголовок
                                                    Item {
                                                        width: parent.width
                                                        height: 30
                                                    }

                                                    // Список портов
                                                    ListView {
                                                        id: portListView
                                                        width: parent.width
                                                        height: Math.min(model.length * 30, 300) // Максимальная высота 300px
                                                        clip: true
                                                        model: comPortCombo.model
                                                        currentIndex: comPortCombo.highlightedIndex
                                                        boundsBehavior: Flickable.StopAtBounds

                                                        ScrollIndicator.vertical: ScrollIndicator {
                                                            active: true
                                                        }

                                                        // Обновляем список при открытии
                                                        Component.onCompleted: {
                                                            if (portPopup.visible) {
                                                                comPortCombo.updatePortsList();
                                                            }
                                                        }

                                                        // Обновляем при появлении
                                                        onVisibleChanged: {
                                                            if (visible) {
                                                                comPortCombo.updatePortsList();
                                                            }
                                                        }

                                                        // Делегат для элементов списка
                                                        delegate: ItemDelegate {
                                                            width: portListView.width
                                                            height: 30
                                                            padding: 5

                                                            contentItem: Text {
                                                                text: modelData
                                                                color: "white"
                                                                font.pixelSize: 12
                                                                verticalAlignment: Text.AlignVCenter
                                                                elide: Text.ElideRight
                                                            }

                                                            background: Rectangle {
                                                                color: highlighted ? "#4caf50" : (hovered ? "#3a3a3a" : "transparent")
                                                                radius: 2
                                                            }

                                                            ToolTip.visible: tooltipsEnabled && hovered
                                                            ToolTip.text: "Нажмите для выбора порта " + modelData
                                                            ToolTip.delay: 500

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    controller.selectedPort = modelData;
                                                                    comPortCombo.popup.close();
                                                                    showNotification("Выбран порт: " + modelData, false);
                                                                    comPortCombo.currentIndex = index;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // Автоматическое обновление при открытии
                                                onOpened: {
                                                    comPortCombo.updatePortsList();
                                                }
                                            }

                                            background: Rectangle {
                                                color: "#202020"
                                                radius: 4
                                                border.color: comPortCombo.activeFocus ? "#4caf50" :
                                                             (comPortCombo.hovered ? "#666" : "#555")
                                                border.width: 1

                                                // Индикатор активности
                                                Rectangle {
                                                    visible: comPortCombo.enabled
                                                    anchors {
                                                        right: parent.right
                                                        rightMargin: 8
                                                        verticalCenter: parent.verticalCenter
                                                    }
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    color: "#4caf50"
                                                    opacity: comPortCombo.hovered ? 1.0 : 0.7

                                                    SequentialAnimation on opacity {
                                                        running: comPortCombo.enabled && comPortCombo.hovered
                                                        loops: Animation.Infinite
                                                        NumberAnimation { from: 0.3; to: 1.0; duration: 1000 }
                                                        NumberAnimation { from: 1.0; to: 0.3; duration: 1000 }
                                                    }
                                                }
                                            }

                                            contentItem: Text {
                                                text: {
                                                    if (comPortCombo.currentIndex >= 0 && comPortCombo.currentIndex < comPortCombo.model.length) {
                                                        return comPortCombo.model[comPortCombo.currentIndex];
                                                    } else if (controller.selectedPort) {
                                                        return controller.selectedPort;
                                                    } else {
                                                        return "Выберите порт";
                                                    }
                                                }
                                                color: comPortCombo.enabled ? "white" : "#888"
                                                font.pixelSize: 12
                                                verticalAlignment: Text.AlignVCenter
                                                leftPadding: 8
                                                elide: Text.ElideRight
                                            }

                                            ToolTip.visible: tooltipsEnabled && hovered
                                            ToolTip.text: {
                                                if (controller.connected) {
                                                    return "Порт подключен: " + controller.selectedPort + "\n" +
                                                           "Для смены порта отключитесь от устройства";
                                                } else {
                                                    var count = comPortCombo.model ? comPortCombo.model.length : 0;
                                                    var hint = count > 0 ?
                                                        "Доступно портов: " + count + "\n" +
                                                        "Нажмите для выбора или наведите для обновления списка" :
                                                        "Порты не обнаружены\nНажмите для обновления списка";
                                                    return hint;
                                                }
                                            }
                                            ToolTip.delay: 500
                                        }
                                    }

                                    // WiFi настройки
                                    ColumnLayout {
                                        id: wifiSettings
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 5
                                        visible: true  // ИЗМЕНЕНО: по умолчанию видно

                                        // Строка IP-адреса
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                text: "IP-адрес"
                                                color: "#aaa"
                                                font.pixelSize: 12
                                                font.bold: true
                                                Layout.preferredWidth: 60
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            TextField {
                                                id: wifiAddressField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 25
                                                text: controller.wifiAddress
                                                placeholderText: "192.168.4.1"
                                                onEditingFinished: controller.wifiAddress = text
                                                Layout.alignment: Qt.AlignVCenter

                                                background: Rectangle {
                                                    color: "#202020"
                                                    radius: 4
                                                    border.color: wifiAddressField.activeFocus ? "#4caf50" : "#555"
                                                    border.width: 1
                                                }
                                                color: "white"
                                                font.pixelSize: 12
                                                horizontalAlignment: TextInput.AlignLeft
                                                leftPadding: 8

                                                validator: RegularExpressionValidator {
                                                    regularExpression: /^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
                                                }

                                                ToolTip.visible: tooltipsEnabled && hovered
                                                ToolTip.text: "IP адрес WiFi устройства (например: 192.168.4.1)"
                                            }
                                        }

                                        // Строка порта
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                text: "Порт"
                                                color: "#aaa"
                                                font.pixelSize: 12
                                                font.bold: true
                                                Layout.preferredWidth: 60
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            TextField {
                                                id: wifiPortField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 25
                                                text: controller.wifiPort
                                                placeholderText: "8080"
                                                validator: IntValidator { bottom: 1; top: 65535 }
                                                onEditingFinished: controller.wifiPort = parseInt(text)
                                                Layout.alignment: Qt.AlignVCenter

                                                background: Rectangle {
                                                    color: "#202020"
                                                    radius: 4
                                                    border.color: wifiPortField.activeFocus ? "#4caf50" : "#555"
                                                    border.width: 1
                                                }
                                                color: "white"
                                                font.pixelSize: 12
                                                horizontalAlignment: TextInput.AlignLeft
                                                leftPadding: 8

                                                ToolTip.visible: tooltipsEnabled && hovered
                                                ToolTip.text: "Порт WiFi устройства (обычно 8080)"
                                            }
                                        }
                                    }
                                }

                                // УПРАВЛЕНИЕ ПОДКЛЮЧЕНИЕМ (фиксированная ширина)
                                ColumnLayout {
                                    Layout.preferredWidth: 100
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 5

                                    // Статус подключения
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                        Text {
                                            text: controller.connected ? "Подключен" : "Отключен"
                                            color: controller.connected ? "#4CAF50" : "#f44336"
                                            font.pixelSize: 12
                                            font.bold: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Индикатор статуса
                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: controller.connected ? "#4CAF50" : "#f44336"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Кнопка подключения/отключения
                                    Rectangle {
                                        id: connectButton
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 25
                                        radius: 4
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

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

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: controller.connected ? "Отключить" : "Подключить"
                                            color: "white"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

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

                                            ToolTip.visible: tooltipsEnabled && containsMouse
                                            ToolTip.text: controller.connected ?
                                                "Отключиться от устройства" :
                                                "Подключиться к устройству"
                                        }
                                    }
                                }
                            }
                        }
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
                Layout.preferredWidth: parent.width * 0.5
                spacing: 10

                // === PITCH (тангаж) - ПЕРВАЯ СТРОКА ===
                AxisPanel {
                    // axisName: "ТАНГАЖ / PITCH"
                    // axisName: "ФРОНТАЛЬНАЯ ОСЬ"
                    axisName: "Наклон\nВПЕРЁД / НАЗАД"
                    axisNameGraph: "ТАНГАЖ (PITCH)   "
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
                    // axisName: "КРЕН / ROLL"
                    // axisName: "САГИТТАЛЬНАЯ ОСЬ"
                    axisName: "Наклон\nВЛЕВО / ВПРАВО"
                    axisNameGraph: "КРЕН (ROLL)   "
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
                    // axisName: "РЫСКАНЬЕ / YAW"
                    // axisName: "РОТАЦИОННАЯ ОСЬ"
                    axisName: "Вращение\nВЛЕВО / ВПРАВО"
                    axisNameGraph: "РЫСКАНЬЕ (YAW)   "
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

                            // Кнопка управления головой в правом верхнем углу 3D сцены
                            Rectangle {
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 10
                                }
                                width: 140
                                height: 40
                                radius: 6

                                // Цвета в зависимости от состояния
                                property color normalColor: innerHeadVisible ? "#3a5c3a" : "#7c3a3a"
                                property color hoverColor: "#5a5a5a"
                                property color pressedColor: "#4a4a4a"

                                color: {
                                    if (headToggleMouseArea.pressed) return pressedColor
                                    else if (headToggleMouseArea.containsMouse) return hoverColor
                                    else return normalColor
                                }

                                border.color: "#666"
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: innerHeadVisible ? "Скрыть голову" : "Показать голову"
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    id: headToggleMouseAreaButton
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: innerHeadVisible = !innerHeadVisible

                                    ToolTip.visible: tooltipsEnabled && containsMouse
                                    ToolTip.text: innerHeadVisible ? "Скрыть модель головы" : "Показать модель головы"
                                    ToolTip.delay: 500
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
                                    // text: "🎯"
                                    text: "🌐"
                                    onClicked: advanced3DHead.setCameraView("isometric")
                                    ToolTip.text: "Изометрический вид"
                                    ToolTip.visible: tooltipsEnabled && containsMouse
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
                                        // text: "👁️"
                                        text: {
                                            switch(advanced3DHead.currentView) {
                                                case "front": return "⬆️"
                                                case "back": return "⬇️"
                                                default: return "↕️"
                                            }
                                        }
                                        onClicked: advanced3DHead.toggleFrontBack()
                                        ToolTip.text: advanced3DHead.currentView === "front" ?
                                            "Переключить на вид сзади" : "Переключить на вид спереди"
                                        ToolTip.visible: tooltipsEnabled && containsMouse
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
                                        // text: "👈"
                                        text: {
                                            switch(advanced3DHead.currentView) {
                                                case "left": return "⬅️"
                                                case "right": return "➡️"
                                                default: return "↔️"
                                            }
                                        }
                                        onClicked: advanced3DHead.toggleLeftRight()
                                        ToolTip.text: advanced3DHead.currentView === "left" ?
                                            "Переключить на вид справа" : "Переключить на вид слева"
                                        ToolTip.visible: tooltipsEnabled && containsMouse
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
                                        // text: "⬇️"
                                        text: {
                                            switch(advanced3DHead.currentView) {
                                                case "top": return "⏫"
                                                case "bottom": return "⏬"
                                                default: return "↕️"
                                            }
                                        }
                                        onClicked: advanced3DHead.toggleTopBottom()
                                        ToolTip.text: advanced3DHead.currentView === "top" ?
                                            "Переключить на вид снизу" : "Переключить на вид сверху"
                                        ToolTip.visible: tooltipsEnabled && containsMouse
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

                        // Кнопка "В начало"
                        Rectangle {
                            id: toStartButton
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 40
                            radius: 4
                            enabled: controller.logControlsEnabled && controller.logLoaded

                            property color normalColor: enabled ? "#2196F3" : "#555"
                            property color hoverColor: enabled ? "#42A5F5" : "#666"
                            property color pressedColor: enabled ? "#1976D2" : "#444"

                            color: {
                                if (!enabled) return normalColor;
                                if (toStartMouseArea.pressed) {
                                    return pressedColor
                                } else if (toStartMouseArea.containsMouse) {
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
                                text: "⏮️"
                                color: enabled ? "white" : "#888"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: toStartMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (enabled) {
                                        controller.seekLog(0)
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: "Перейти в начало записи"
                            }
                        }

                        // Кнопка "Назад на 5с"
                        Rectangle {
                            id: rewindButton
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 40
                            radius: 4
                            enabled: controller.logControlsEnabled && controller.logLoaded

                            property color normalColor: enabled ? "#2196F3" : "#555"
                            property color hoverColor: enabled ? "#42A5F5" : "#666"
                            property color pressedColor: enabled ? "#1976D2" : "#444"

                            color: {
                                if (!enabled) return normalColor;
                                if (rewindMouseArea.pressed) {
                                    return pressedColor
                                } else if (rewindMouseArea.containsMouse) {
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
                                text: "⏪"
                                color: enabled ? "white" : "#888"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: rewindMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (enabled) {
                                        var newTime = Math.max(0, controller.currentTime - 5000);
                                        controller.seekLog(newTime);
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: "Перемотать назад на 5 секунд"
                            }
                        }

                        // Кнопка Play/Pause (уже в правильном стиле) - оставляем как есть
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

                                ToolTip.visible: tooltipsEnabled && containsMouse
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

                        // Кнопка "Вперед на 5с"
                        Rectangle {
                            id: forwardButton
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 40
                            radius: 4
                            enabled: controller.logControlsEnabled && controller.logLoaded

                            property color normalColor: enabled ? "#2196F3" : "#555"
                            property color hoverColor: enabled ? "#42A5F5" : "#666"
                            property color pressedColor: enabled ? "#1976D2" : "#444"

                            color: {
                                if (!enabled) return normalColor;
                                if (forwardMouseArea.pressed) {
                                    return pressedColor
                                } else if (forwardMouseArea.containsMouse) {
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
                                text: "⏩"
                                color: enabled ? "white" : "#888"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: forwardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (enabled) {
                                        var newTime = Math.min(controller.totalTime, controller.currentTime + 5000);
                                        controller.seekLog(newTime);
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: "Перемотать вперед на 5 секунд"
                            }
                        }

                        // Кнопка "В конец"
                        Rectangle {
                            id: toEndButton
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 40
                            radius: 4
                            enabled: controller.logControlsEnabled && controller.logLoaded

                            property color normalColor: enabled ? "#2196F3" : "#555"
                            property color hoverColor: enabled ? "#42A5F5" : "#666"
                            property color pressedColor: enabled ? "#1976D2" : "#444"

                            color: {
                                if (!enabled) return normalColor;
                                if (toEndMouseArea.pressed) {
                                    return pressedColor
                                } else if (toEndMouseArea.containsMouse) {
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
                                text: "⏭️"
                                color: enabled ? "white" : "#888"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: toEndMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (enabled) {
                                        controller.seekLog(controller.totalTime)
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: "Перейти в конец записи"
                            }
                        }

                        // Кнопка "Стоп"
                        Rectangle {
                            id: stopButton
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 40
                            radius: 4
                            enabled: controller.logControlsEnabled

                            property color normalColor: enabled ? "#f44336" : "#555"
                            property color hoverColor: enabled ? "#ff5555" : "#666"
                            property color pressedColor: enabled ? "#c43a1a" : "#444"

                            color: {
                                if (!enabled) return normalColor;
                                if (stopMouseArea.pressed) {
                                    return pressedColor
                                } else if (stopMouseArea.containsMouse) {
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
                                text: "⏹️"
                                color: enabled ? "white" : "#888"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: stopMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (enabled) {
                                        controller.stopLog()
                                    }
                                }

                                ToolTip.visible: tooltipsEnabled && containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: "Остановить воспроизведение и вернуться в начало"
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
                // ИЗМЕНЕНО: Единое сообщение для обоих типов подключения
                var message = controller.connectionType === "COM" ?
                    "Успешное подключение к COM-порту: " + controller.selectedPort :
                    "Успешное подключение к WiFi: " + controller.wifiAddress + ":" + controller.wifiPort;
                showNotification(message, false)
            } else {
                var disconnectMsg = controller.connectionType === "COM" ?
                    "Отключено от COM-порта" :
                    "Отключено от WiFi";
                showNotification(disconnectMsg, false)
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
            menuSmoothingSlider.value = smoothing;
        }

        function onAngularSpeedDisplayRateLogChanged(rate) {
            menuUpdateRateSlider.value = rate;
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

    Connections {
        target: controller

        function onWifiConnectedChanged(connected) {
            // Обновляем статус в реальном времени
            if (connected) {
                showNotification("Успешное подключение к WiFi", false)
            }
        }
    }

    // Обновляем существующий Connections для уведомлений
    Connections {
        target: controller
        function onConnectedChanged(connected) {
            if (connected) {
                var message = controller.connectionType === "COM" ?
                    "Успешное подключение к " + controller.selectedPort :
                    "Успешное подключение к WiFi";
                showNotification(message, false)
            } else {
                showNotification("Отключено от устройства", false)
            }
        }
    }

    Connections {
        target: controller
        function onConnectionTypeChanged(type) {
            console.log("Тип подключения изменен на:", type)

            // Автоматически показываем соответствующие настройки
            if (type === "WiFi") {
                showNotification("Режим WiFi активирован. Укажите IP-адрес и порт.", false)
            } else {
                showNotification("Режим COM-порта активирован. Выберите порт.", false)
            }

            // Если было подключение, переподключаемся
            if (controller.connected) {
                controller.disconnectDevice();
                reconnectTimer.start();
            }
        }

        function onWifiAddressChanged(address) {
            wifiAddressField.text = address
        }

        function onWifiPortChanged(port) {
            wifiPortField.text = port
        }

        function onConnectedChanged(connected) {
            if (connected) {
                var message = controller.connectionType === "COM" ?
                    "Успешное подключение к " + controller.selectedPort :
                    "Успешное подключение к WiFi";
                showNotification(message, false)
            } else {
                showNotification("Отключено от устройства", false)
            }
        }

        function onAvailablePortsChanged() {
            // Принудительно обновляем список портов в UI
            if (comPortCombo && comPortSettings.visible) {
                Qt.callLater(function() {
                    comPortCombo.updatePortsList();
                });
            }
        }
    }

    Connections {
        target: controller
        function onWifiConnectedChanged(connected) {
            if (connected) {
                // Принудительно обновляем графики при подключении WiFi
                Qt.callLater(function() {
                    pitchGraph.requestPaint();
                    rollGraph.requestPaint();
                    yawGraph.requestPaint();
                });
            }
        }
    }

    // Добавьте этот Connections блок в существующие Connections (где-то после других Connections)
    Connections {
        target: controller
        function onConnectionTypeChanged(type) {
            console.log("Тип подключения изменен на:", type)

            // Обновляем видимость панелей настроек
            comPortSettings.visible = (type === "COM")
            wifiSettings.visible = (type === "WiFi")

            // Если переключились на COM-порт, обновляем список портов
            if (type === "COM" && comPortSettings.visible) {
                Qt.callLater(function() {
                    if (comPortCombo) {
                        comPortCombo.updatePortsList();
                    }
                });
            }

            // Автоматически показываем соответствующие настройки
            if (type === "WiFi") {
                showNotification("Режим WiFi активирован. Укажите IP-адрес и порт.", false)
            } else {
                showNotification("Режим COM-порта активирован. Выберите порт.", false)
            }

            // // Если было подключение, переподключаемся
            // if (controller.connected) {
            //     controller.disconnectDevice();
            //     reconnectTimer.start();
            // }
        }
    }

    // // Таймер для автоматического переподключения при смене типа
    // Timer {
    //     id: reconnectTimer
    //     interval: 500
    //     onTriggered: {
    //         if (!controller.connected && !controller.logMode) {
    //             controller.connectDevice();
    //         }
    //     }
    // }

    // Обработка критических ошибок
    function handleCriticalError(message) {
        console.error("Critical error:", message)
        showNotification("Критическая ошибка: " + message, true)
    }

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
        if (notificationTimer.running || sideMenuOpen) {
            return
        }
        notificationText.text = message
        notificationBackground.color = isError ? "#f44336" : "#4CAF50"
        notificationLayout.height = 40
        notificationTimer.restart()
    }

    function showAboutDialog() {
        aboutDialog.open()
    }

    function openHelpInBrowser() {
        var helpFilePath = "file:///" + applicationDirPath + "/info/help.html";
        Qt.openUrlExternally(helpFilePath);
    }

    // Тестовое уведомление при запуске
    Component.onCompleted: {
        timer.start()
        console.log("Application started, headModel.hasData:", controller.headModel.hasData)
        console.log("Initial roll value:", controller.headModel.roll)
        console.log("Default connection type:", controller.connectionType)

        // Принудительно обновляем видимость панелей при запуске
        var type = controller.connectionType
        comPortSettings.visible = (type === "COM")
        wifiSettings.visible = (type === "WiFi")

        // Показываем информацию о режиме по умолчанию
        if (type === "WiFi") {
            showNotification("Режим подключения по WiFi установлен по умолчанию", false)
        } else {
            showNotification("Режим подключения по COM-порту", false)
        }

        // Инициализация номера исследования
        controller.initializeResearchNumber()
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

    Timer {
        id: timer
        interval: 1000
        onTriggered: {
            showNotification("Система готова к работе", false)
        }
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
}
