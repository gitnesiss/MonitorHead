import QtQuick

Canvas {
    id: canvas
    property var graphData: []
    property var dizzinessData: []
    property int graphDuration: 30
    property color lineColor: "white"
    property real minValue: -120
    property real maxValue: 120
    property real valueRange: maxValue - minValue

    // Настройки внешнего вида
    property color gridColor: "#333"
    property color textColor: "#888"
    property color axisColor: "white"

    // Настройки головокружения
    property color dizzinessColor: "#40FFA000"        // основной цвет заливки (полупрозрачный оранжевый)
    property color dizzinessBorderColor: "#80FFA000"  // цвет границы интервалов головокружения
    property real dizzinessOpacity: 0.50              // прозрачность заливки (0.15 = 15%)

    onPaint: {
        try {
            var ctx = getContext("2d")
            if (!ctx) return

            ctx.clearRect(0, 0, width, height)

            drawGrid(ctx)

            if (graphData.length === 0) {
                drawNoData(ctx)
                return
            }

            drawDizzinessIntervals(ctx)
            drawGraphLine(ctx)
        } catch (error) {
            console.error("Canvas paint error:", error)
        }
    }

    function drawNoData(ctx) {
        ctx.fillStyle = textColor
        ctx.font = "14px Arial"
        ctx.textAlign = "center"
        ctx.fillText("нет данных", width / 2, height / 2)
    }

    function drawGrid(ctx) {
        // Рисуем основную сетку
        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        ctx.fillStyle = textColor
        ctx.font = "10px Arial"

        // Вычисляем положение нулевой линии (посередине)
        var zeroY = height - ((0 - minValue) / valueRange) * height

        // Определяем отступ для вертикальной оси (справа)
        var verticalAxisMargin = 40
        var verticalAxisX = width - verticalAxisMargin

        // Горизонтальные линии и подписи углов
        var horizontalValues = [-90, -45, 0, 45, 90]
        for (var i = 0; i < horizontalValues.length; i++) {
            var value = horizontalValues[i]
            var y = height - ((value - minValue) / valueRange) * height

            // Линия сетки
            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(width, y)
            ctx.stroke()

            // Подпись угла справа (с отступом от правого края)
            ctx.textAlign = "right"
            ctx.fillText(value.toFixed(0) + "°", width - 5, y - 2)
        }

        // Вертикальные линии и подписи времени
        var verticalLines = 6
        for (var j = 0; j <= verticalLines; j++) {
            var x = j * (verticalAxisX) / verticalLines  // Учитываем отступ для оси
            var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

            // Линия сетки
            ctx.beginPath()
            ctx.moveTo(x, 0)
            ctx.lineTo(x, height)
            ctx.stroke()

            // Подпись времени (без "t-", нулевую не показываем)
            if (secondsAgo > 0) {
                ctx.textAlign = "center"
                // Смещаем подписи времени вниз (ниже оси)
                var textX = x
                // Для самой левой цифры (30) делаем сдвиг вправо
                if (j === 0) {
                    textX = x + 10 // Сдвигаем цифру 30 вправо, чтобы была полностью видна
                }
                ctx.fillText(secondsAgo.toFixed(0), textX, zeroY + 15)
            }
        }

        // Подпись оси времени слева сверху
        ctx.textAlign = "left"
        ctx.fillText("t, с", 5, zeroY - 5)

        // Подпись оси углов сверху справа
        ctx.textAlign = "right"
        ctx.fillText("угол, °", width - 5, 8)

        // Рисуем яркие белые оси
        ctx.strokeStyle = axisColor
        ctx.lineWidth = 2

        // Горизонтальная ось (посередине - на уровне нулевого градуса)
        ctx.beginPath()
        ctx.moveTo(0, zeroY)
        ctx.lineTo(width, zeroY)
        ctx.stroke()

        // Вертикальная ось (справа с небольшим отступом)
        ctx.beginPath()
        ctx.moveTo(verticalAxisX, 0)
        ctx.lineTo(verticalAxisX, height)
        ctx.stroke()
    }

    function drawDizzinessIntervals(ctx) {
        if (!dizzinessData || dizzinessData.length === 0) return

        var currentTime = new Date().getTime()
        var minTime = currentTime - graphDuration * 1000

        // Определяем отступ для вертикальной оси (справа)
        var verticalAxisMargin = 40
        var verticalAxisX = width - verticalAxisMargin

        ctx.fillStyle = dizzinessColor
        ctx.globalAlpha = dizzinessOpacity

        for (var i = 0; i < dizzinessData.length; i++) {
            var interval = dizzinessData[i]
            if (!interval || !interval.startTime || !interval.endTime) continue

            var startTime = interval.startTime
            var endTime = interval.endTime

            // Учитываем отступ для вертикальной оси при расчете координат
            var availableWidth = verticalAxisX
            var xStart = availableWidth - (currentTime - startTime) / (graphDuration * 1000) * availableWidth
            var xEnd = availableWidth - (currentTime - endTime) / (graphDuration * 1000) * availableWidth

            xStart = Math.max(0, xStart)
            xEnd = Math.min(availableWidth, xEnd)

            if (xEnd > xStart && xStart < availableWidth && xEnd > 0) {
                ctx.fillRect(xStart, 0, xEnd - xStart, height)

                ctx.strokeStyle = dizzinessBorderColor
                ctx.lineWidth = 1
                ctx.globalAlpha = 0.3
                ctx.strokeRect(xStart, 0, xEnd - xStart, height)
                ctx.globalAlpha = dizzinessOpacity
            }
        }

        ctx.globalAlpha = 1.0
    }

    function drawGraphLine(ctx) {
        if (!graphData || graphData.length < 2) return

        var currentTime = new Date().getTime()
        var minTime = currentTime - graphDuration * 1000

        // Определяем отступ для вертикальной оси (справа)
        var verticalAxisMargin = 40
        var verticalAxisX = width - verticalAxisMargin
        var availableWidth = verticalAxisX

        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.beginPath()

        var pointsDrawn = 0
        var maxPointsToDraw = 100
        var step = Math.max(1, Math.floor(graphData.length / maxPointsToDraw))

        for (var i = 0; i < graphData.length; i += step) {
            var point = graphData[i]
            if (!point || typeof point.time !== 'number' || typeof point.value !== 'number') {
                continue
            }

            if (point.time >= minTime) {
                // Учитываем отступ для вертикальной оси при расчете координат
                var x = availableWidth - (currentTime - point.time) / (graphDuration * 1000) * availableWidth
                var y = height - ((point.value - minValue) / valueRange) * height

                x = Math.max(0, Math.min(availableWidth, x))
                y = Math.max(0, Math.min(height, y))

                if (pointsDrawn === 0) {
                    ctx.moveTo(x, y)
                } else {
                    ctx.lineTo(x, y)
                }
                pointsDrawn++
            }
        }

        if (pointsDrawn > 0) {
            ctx.stroke()
        }

        // Текущая точка
        if (graphData.length > 0) {
            var lastPoint = graphData[graphData.length - 1]
            if (lastPoint && typeof lastPoint.time === 'number' && typeof lastPoint.value === 'number') {
                var lastX = availableWidth - (currentTime - lastPoint.time) / (graphDuration * 1000) * availableWidth
                var lastY = height - ((lastPoint.value - minValue) / valueRange) * height

                lastX = Math.max(3, Math.min(availableWidth - 3, lastX))
                lastY = Math.max(3, Math.min(height - 3, lastY))

                // Тень для объемности
                ctx.shadowColor = "rgba(0, 0, 0, 0.3)"
                ctx.shadowBlur = 3
                ctx.shadowOffsetX = 1
                ctx.shadowOffsetY = 1

                ctx.fillStyle = lineColor
                ctx.beginPath()
                ctx.arc(lastX, lastY, 4, 0, Math.PI * 2)
                ctx.fill()

                // Сбрасываем тень
                ctx.shadowColor = "transparent"
                ctx.shadowBlur = 0
                ctx.shadowOffsetX = 0
                ctx.shadowOffsetY = 0

                // Белая обводка
                ctx.strokeStyle = "white"
                ctx.lineWidth = 1
                ctx.stroke()
            }
        }
    }

    Timer {
        id: updateTimer
        interval: 1000 / (controller.updateFrequency || 10)
        running: canvas.visible && (controller.connected || controller.logPlaying)
        repeat: true
        onTriggered: {
            if (controller.headModel.hasData) {
                canvas.requestPaint()
            }
        }
    }

    Connections {
        target: controller
        function onGraphDataChanged() {
            if (canvas.visible) canvas.requestPaint()
        }
        function onGraphDurationChanged() {
            if (canvas.visible) canvas.requestPaint()
        }
        function onUpdateFrequencyChanged() {
            updateTimer.interval = 1000 / (controller.updateFrequency || 10)
        }
    }
}
