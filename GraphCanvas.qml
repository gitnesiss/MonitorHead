// GraphCanvas.qml
import QtQuick

Canvas {
    id: canvas
    property var graphData: []
    property var dizzinessData: [] // Теперь содержит интервалы {startTime, endTime}
    property int graphDuration: 30
    property color lineColor: "white"
    property real minValue: -90
    property real maxValue: 90
    property real valueRange: maxValue - minValue

    // Настройки внешнего вида
    property color gridColor: "#333"
    property color textColor: "#666"

    // Улучшенные настройки головокружения
    property color dizzinessColor: "#40FFA000" // Очень прозрачный оранжевый
    property color dizzinessBorderColor: "#80FFA000" // Полупрозрачная граница
    property real dizzinessOpacity: 0.15 // Еще более прозрачный

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

            // Новый порядок: сначала головокружение, потом график
            drawDizzinessIntervals(ctx)
            drawGraphLine(ctx)
            drawCurrentTime(ctx)
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
        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        ctx.fillStyle = textColor
        ctx.font = "10px Arial"

        // Горизонтальные линии
        var horizontalLines = 5
        for (var i = 0; i <= horizontalLines; i++) {
            var y = height - (i * height / horizontalLines)
            var value = minValue + (i * valueRange / horizontalLines)

            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(width, y)
            ctx.stroke()

            ctx.textAlign = "left"
            ctx.fillText(value.toFixed(0) + "°", 5, y - 2)
        }

        // Вертикальные линии
        var verticalLines = 6
        for (var j = 0; j <= verticalLines; j++) {
            var x = j * width / verticalLines
            var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

            ctx.beginPath()
            ctx.moveTo(x, 0)
            ctx.lineTo(x, height)
            ctx.stroke()

            ctx.textAlign = "center"
            ctx.fillText("t-" + secondsAgo.toFixed(0) + "с", x, height - 5)
        }

        ctx.textAlign = "center"
        ctx.fillText("t, с", width / 2, height - 5)
    }

    function drawDizzinessIntervals(ctx) {
        if (!dizzinessData || dizzinessData.length === 0) return

        var currentTime = new Date().getTime()
        var minTime = currentTime - graphDuration * 1000

        ctx.fillStyle = dizzinessColor
        ctx.globalAlpha = dizzinessOpacity

        // Рисуем интервалы как сплошные зоны
        for (var i = 0; i < dizzinessData.length; i++) {
            var interval = dizzinessData[i]
            if (!interval || !interval.startTime || !interval.endTime) continue

            var startTime = interval.startTime
            var endTime = interval.endTime

            // Вычисляем координаты начала и конца интервала
            var xStart = width - (currentTime - startTime) / (graphDuration * 1000) * width
            var xEnd = width - (currentTime - endTime) / (graphDuration * 1000) * width

            // Ограничиваем координаты видимой областью
            xStart = Math.max(0, xStart)
            xEnd = Math.min(width, xEnd)

            // Рисуем только если интервал видим
            if (xEnd > xStart && xStart < width && xEnd > 0) {
                // Основная заливка интервала
                ctx.fillRect(xStart, 0, xEnd - xStart, height)

                // Легкая граница для лучшего визуального разделения
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
                var x = width - (currentTime - point.time) / (graphDuration * 1000) * width
                var y = height - ((point.value - minValue) / valueRange) * height

                x = Math.max(0, Math.min(width, x))
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
                var lastX = width - (currentTime - lastPoint.time) / (graphDuration * 1000) * width
                var lastY = height - ((lastPoint.value - minValue) / valueRange) * height

                lastX = Math.max(3, Math.min(width - 3, lastX))
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

    function drawCurrentTime(ctx) {
        ctx.strokeStyle = "rgba(136, 136, 136, 0.7)"
        ctx.lineWidth = 1
        ctx.setLineDash([5, 5])
        ctx.beginPath()
        ctx.moveTo(width, 0)
        ctx.lineTo(width, height)
        ctx.stroke()
        ctx.setLineDash([])
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
