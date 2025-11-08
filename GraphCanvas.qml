import QtQuick

Canvas {
    id: canvas
    property var graphData: []
    property var dizzinessPatientData: []
    property var dizzinessDoctorData: []
    property int graphDuration: 30
    property color lineColor: "white"
    property real minValue: -120
    property real maxValue: 120

    property color dizzinessPatientColor: "#40FFA000"
    property color dizzinessDoctorColor: "#406060FF"

    // Кэшируемые вычисления
    property real _valueRange: maxValue - minValue
    property real _zeroY: height - ((0 - minValue) / _valueRange) * height
    property real _availableWidth: width - 40

    onWidthChanged: updateCachedValues()
    onHeightChanged: updateCachedValues()
    onGraphDurationChanged: updateCachedValues()

    function updateCachedValues() {
        _valueRange = maxValue - minValue
        _zeroY = height - ((0 - minValue) / _valueRange) * height
        _availableWidth = width - 40
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (graphData.length === 0) {
            drawNoData(ctx)
            return
        }

        drawGrid(ctx)
        drawDizzinessIntervals(ctx)
        drawGraphLine(ctx)
    }

    function drawNoData(ctx) {
        ctx.fillStyle = "#888"
        ctx.font = "14px Arial"
        ctx.textAlign = "center"
        ctx.fillText("нет данных", width / 2, height / 2)
    }

    function drawGrid(ctx) {
        ctx.strokeStyle = "#333"
        ctx.lineWidth = 1
        ctx.fillStyle = "#888"
        ctx.font = "10px Arial"

        // Горизонтальные линии
        var horizontalValues = [-90, -45, 0, 45, 90]
        for (var i = 0; i < horizontalValues.length; i++) {
            var value = horizontalValues[i]
            var y = height - ((value - minValue) / _valueRange) * height

            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(width, y)
            ctx.stroke()

            ctx.textAlign = "right"
            ctx.fillText(value.toFixed(0) + "°", width - 5, y - 2)
        }

        // Вертикальные линии
        var verticalLines = 6
        for (var j = 0; j <= verticalLines; j++) {
            var x = j * (_availableWidth) / verticalLines
            var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

            ctx.beginPath()
            ctx.moveTo(x, 0)
            ctx.lineTo(x, height)
            ctx.stroke()

            ctx.textAlign = "center"
            ctx.fillText(secondsAgo.toFixed(0) + "с", x, _zeroY + 15)
        }

        // Оси
        ctx.strokeStyle = "white"
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(0, _zeroY)
        ctx.lineTo(width, _zeroY)
        ctx.stroke()

        ctx.beginPath()
        ctx.moveTo(_availableWidth, 0)
        ctx.lineTo(_availableWidth, height)
        ctx.stroke()
    }

    function drawDizzinessIntervals(ctx) {
        drawDizzinessType(ctx, dizzinessPatientData, dizzinessPatientColor)
        drawDizzinessType(ctx, dizzinessDoctorData, dizzinessDoctorColor)
    }

    function drawDizzinessType(ctx, intervals, color) {
        if (!intervals || intervals.length === 0) return

        ctx.fillStyle = color

        for (var i = 0; i < intervals.length; i++) {
            var interval = intervals[i]
            if (!interval || interval.startTime === undefined || interval.endTime === undefined) continue

            var startTime = interval.startTime
            var endTime = interval.endTime

            var xStart = (startTime / (graphDuration * 1000)) * _availableWidth
            var xEnd = (endTime / (graphDuration * 1000)) * _availableWidth

            xStart = Math.max(0, Math.min(_availableWidth, xStart))
            xEnd = Math.max(0, Math.min(_availableWidth, xEnd))

            if (xEnd > xStart) {
                ctx.fillRect(xStart, 0, xEnd - xStart, height)
            }
        }
    }

    function drawGraphLine(ctx) {
        if (graphData.length < 2) return

        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.beginPath()

        var firstPoint = true

        for (var i = 0; i < graphData.length; i++) {
            var point = graphData[i]
            if (!point || point.time === undefined || point.value === undefined) continue

            var x = (point.time / (graphDuration * 1000)) * _availableWidth
            var y = height - ((point.value - minValue) / _valueRange) * height

            x = Math.max(0, Math.min(_availableWidth, x))
            y = Math.max(0, Math.min(height, y))

            if (firstPoint) {
                ctx.moveTo(x, y)
                firstPoint = false
            } else {
                ctx.lineTo(x, y)
            }
        }

        ctx.stroke()

        // Рисуем последнюю точку
        if (graphData.length > 0) {
            var lastPoint = graphData[graphData.length - 1]
            if (lastPoint && lastPoint.time !== undefined && lastPoint.value !== undefined) {
                var lastX = (lastPoint.time / (graphDuration * 1000)) * _availableWidth
                var lastY = height - ((lastPoint.value - minValue) / _valueRange) * height

                lastX = Math.max(3, Math.min(_availableWidth - 3, lastX))
                lastY = Math.max(3, Math.min(height - 3, lastY))

                ctx.fillStyle = lineColor
                ctx.beginPath()
                ctx.arc(lastX, lastY, 3, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    Timer {
        interval: 100
        running: canvas.visible && (controller.connected || controller.logPlaying)
        repeat: true
        onTriggered: canvas.requestPaint()
    }

    Connections {
        target: controller
        function onGraphDataChanged() {
            if (canvas.visible) {
                canvas.requestPaint()
            }
        }
    }
}
