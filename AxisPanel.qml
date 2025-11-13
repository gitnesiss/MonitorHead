import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Formatters.js" as Formatters

Rectangle {
    id: axisPanel
    
    // Основные свойства
    required property string axisName
    required property color axisColor
    required property var graphData
    required property color lineColor
    required property real currentAngle
    required property real currentSpeed
    required property bool hasData
    required property int graphDuration
    
    // Свойства для визуализации
    property string viewType: "pitch" // "pitch", "roll", "yaw"
    property bool isLeftView: true    // Для pitch
    property bool isFrontView: true   // Для roll  
    property bool isFlipped: false    // Для yaw
    
    // Форматированные значения (вычисляются в родителе)
    property string formattedAngle: "нет данных"
    property string formattedSpeed: "нет данных"
    
    // Сигналы
    signal imageClicked()
    signal viewToggled()
    
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 200
    Layout.minimumHeight: 200
    color: "#252525"
    radius: 8
    border.color: "#444"
    border.width: 1

    // Вычисляемые свойства для отображения
    property real displayAngle: {
        if (viewType === "pitch") {
            return isLeftView ? currentAngle : -currentAngle
        } else if (viewType === "roll") {
            return isFrontView ? -currentAngle : currentAngle
        } else { // yaw
            return isFlipped ? (180 + currentAngle) : currentAngle
        }
    }
    
    property string viewText: {
        if (viewType === "pitch") {
            return isLeftView ? "СЛЕВА" : "СПРАВА"
        } else if (viewType === "roll") {
            return isFrontView ? "СПЕРЕДИ" : "СЗАДИ"
        } else {
            return "СВЕРХУ"
        }
    }
    
    property string imageSource: {
        if (viewType === "pitch") {
            return isLeftView ? "qrc:/images/left_view.png" : "qrc:/images/right_view.png"
        } else if (viewType === "roll") {
            return isFrontView ? "qrc:/images/front_view.png" : "qrc:/images/back_view.png"
        } else {
            return "qrc:/images/top_view.png"
        }
    }
    
    property string flipIcon: {
        if (viewType === "pitch") {
            return isLeftView ? "↺" : "↻"
        } else if (viewType === "roll") {
            return isFrontView ? "↺" : "↻"
        } else {
            return isFlipped ? "↻" : "↺"
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Блок с изображением головы
        Rectangle {
            id: viewContainer
            Layout.preferredWidth: 180
            Layout.preferredHeight: 180
            Layout.alignment: Qt.AlignCenter
            color: "#1a1a1a"
            radius: 6
            border.color: "#333"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: axisPanel.viewToggled()
                ToolTip.visible: tooltipsEnabled && containsMouse
                ToolTip.text: getTooltipText()
                ToolTip.delay: 1000
                hoverEnabled: true
                
                function getTooltipText() {
                    if (viewType === "pitch") {
                        return "Нажмите для переключения между видом слева и справа"
                    } else if (viewType === "roll") {
                        return "Нажмите для переключения между видом спереди и сзади"
                    } else {
                        return "Нажмите для переворота изображения"
                    }
                }
            }

            Image {
                id: headImage
                anchors.fill: parent
                anchors.margins: 15
                source: axisPanel.imageSource
                fillMode: Image.PreserveAspectFit
                rotation: axisPanel.displayAngle
                transformOrigin: Item.Center
                smooth: true
                opacity: hasData ? 1.0 : 0.5

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#FFA000"
                    anchors.centerIn: parent
                    visible: hasData
                }
            }

            // Центральная линия
            Rectangle {
                id: centerLine
                color: hasData ? "#FFA000" : "#666"
                opacity: 0.5
                anchors.centerIn: parent

                // Разные типы линий для разных осей
                width: {
                    switch(viewType) {
                        case "pitch": return parent.width - 30  // Горизонтальная линия
                        case "roll": return 1                   // Вертикальная линия
                        case "yaw": return 1                    // Вертикальная линия для YAW
                        default: return 1
                    }
                }

                height: {
                    switch(viewType) {
                        case "pitch": return 1                  // Горизонтальная линия
                        case "roll": return parent.height - 30  // Вертикальная линия
                        case "yaw": return parent.height - 30   // Вертикальная линия для YAW
                        default: return 1
                    }
                }

                // Убираем rotation для YAW - оставляем вертикальную линию
                rotation: 0
            }

            // Текст вида
            Column {
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 5
                }
                spacing: 2

                Text {
                    text: axisPanel.viewText
                    color: axisColor
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            // Иконка переключения
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
                    text: axisPanel.flipIcon
                    color: (viewType === "pitch" && !isLeftView) || 
                           (viewType === "roll" && !isFrontView) || 
                           (viewType === "yaw" && isFlipped) ? "#FFA000" : "white"
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            // Текущий угол
            Text {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 5
                }
                text: hasData ? currentAngle.toFixed(1) + "°" : ""
                color: "#FFA000"
                font.pixelSize: 12
                font.bold: true
            }
        }

        // Блок с информацией
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 100
            spacing: 10

            // Заголовок оси
            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 40
                color: "#252525"
                radius: 6

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: axisName
                        color: axisColor
                        font.pixelSize: 16
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Текущий угол
            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 60
                color: "#2d2d2d"
                radius: 6
                border.color: axisColor
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "ТЕКУЩИЙ УГОЛ"
                        color: axisColor
                        font.pixelSize: 12
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: formattedAngle
                        color: hasData ? "white" : "#888"
                        font.pixelSize: hasData ? 18 : 14
                        font.bold: hasData
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Угловая скорость
            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 60
                color: "#2d2d2d"
                radius: 6
                border.color: axisColor
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "УГЛОВАЯ СКОРОСТЬ"
                        color: axisColor
                        font.pixelSize: 12
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: formattedSpeed
                        color: hasData ? "white" : "#888"
                        font.pixelSize: hasData ? 16 : 14
                        font.bold: hasData
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // График
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
                    text: "График " + axisName.split(" / ")[1] + " (" + graphDuration + " сек)"
                    color: graphTextColor
                    font.pixelSize: 12
                    Layout.topMargin: 5
                    Layout.alignment: Qt.AlignHCenter
                }

                GraphCanvas {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    graphData: axisPanel.graphData
                    dizzinessPatientData: controller.dizzinessPatientData
                    dizzinessDoctorData: controller.dizzinessDoctorData
                    graphDuration: axisPanel.graphDuration
                    lineColor: axisPanel.lineColor
                    minValue: -120
                    maxValue: 120
                }
            }
        }
    }
}
