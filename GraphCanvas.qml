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

    // Цвета для текста сетки
    property color gridTextColor: "#AAAAAA"  // Более яркий цвет для текста
    property color gridLineColor: "#444444"  // Цвет линий сетки
    property color axisLineColor: "#777777"  // Цвет основных осей

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

        // ВСЕГДА рисуем сетку, даже если нет данных
        drawGrid(ctx)

        if (graphData.length === 0) {
            drawNoData(ctx)
            return
        }

        drawDizzinessIntervals(ctx)
        drawGraphLine(ctx)
    }


    function drawNoData(ctx) {
        ctx.fillStyle = "#888"
        ctx.font = "14px Arial"
        ctx.textAlign = "center"
        // Сдвигаем надпись "нет данных" на 1/4 от верха (25% высоты)
        var textY = height * 0.25;
        ctx.fillText("нет данных", width / 2, textY)
    }

    // function drawNoData(ctx) {
    //     ctx.fillStyle = "#888"
    //     ctx.font = "14px Arial"
    //     ctx.textAlign = "center"
    //     ctx.fillText("нет данных", width / 2, height / 2)
    // }

    function drawGrid(ctx) {
        ctx.strokeStyle = gridLineColor
        ctx.lineWidth = 1
        ctx.fillStyle = gridTextColor  // Используем вынесенный цвет текста
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

            // Сдвигаем крайние надписи для лучшей видимости
            var textX = x;
            if (j === 0) {
                // Для самой левой метки сдвигаем вправо, чтобы было видно цифру
                textX = x + 15;
            } else if (j === verticalLines) {
                // Для самой правой метки сдвигаем влево
                textX = x - 15;
            }

            ctx.textAlign = "center"
            ctx.fillText(secondsAgo.toFixed(0) + "с", textX, _zeroY + 15)
        }

        // Оси - используем вынесенный цвет
        ctx.strokeStyle = axisLineColor
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

    // Принудительная отрисовка при создании компонента
    Component.onCompleted: {
        canvas.requestPaint()
    }
}



















// import QtQuick

// Canvas {
//     id: canvas
//     property var graphData: []
//     property var dizzinessPatientData: []
//     property var dizzinessDoctorData: []
//     property int graphDuration: 30
//     property color lineColor: "white"
//     property real minValue: -120
//     property real maxValue: 120

//     property color dizzinessPatientColor: "#40FFA000"
//     property color dizzinessDoctorColor: "#406060FF"

//     // Кэшируемые вычисления
//     property real _valueRange: maxValue - minValue
//     property real _zeroY: height - ((0 - minValue) / _valueRange) * height
//     property real _availableWidth: width - 40

//     onWidthChanged: updateCachedValues()
//     onHeightChanged: updateCachedValues()
//     onGraphDurationChanged: updateCachedValues()

//     function updateCachedValues() {
//         _valueRange = maxValue - minValue
//         _zeroY = height - ((0 - minValue) / _valueRange) * height
//         _availableWidth = width - 40
//     }

//     onPaint: {
//         var ctx = getContext("2d")
//         ctx.clearRect(0, 0, width, height)

//         // ВСЕГДА рисуем сетку, даже если нет данных
//         drawGrid(ctx)

//         if (graphData.length === 0) {
//             drawNoData(ctx)
//             return
//         }

//         drawDizzinessIntervals(ctx)
//         drawGraphLine(ctx)
//     }

//     function drawNoData(ctx) {
//         ctx.fillStyle = "#888"
//         ctx.font = "14px Arial"
//         ctx.textAlign = "center"
//         ctx.fillText("нет данных", width / 2, height / 2)
//     }


//     function drawGrid(ctx) {
//         // Увеличиваем контрастность сетки
//         ctx.strokeStyle = "#444" // Более светлый цвет для сетки
//         ctx.lineWidth = 1
//         ctx.fillStyle = "#666" // Более светлый цвет для текста
//         ctx.font = "10px Arial"

//         // Горизонтальные линии и подписи значений
//         var horizontalValues = [-90, -45, 0, 45, 90]
//         for (var i = 0; i < horizontalValues.length; i++) {
//             var value = horizontalValues[i]
//             var y = height - ((value - minValue) / _valueRange) * height

//             // Делаем линию нуля более заметной
//             if (value === 0) {
//                 ctx.strokeStyle = "#666"
//                 ctx.lineWidth = 2
//             } else {
//                 ctx.strokeStyle = "#444"
//                 ctx.lineWidth = 1
//             }

//             ctx.beginPath()
//             ctx.moveTo(0, y)
//             ctx.lineTo(width, y)
//             ctx.stroke()

//             // Подписи значений
//             ctx.textAlign = "right"
//             ctx.fillText(value.toFixed(0) + "°", width - 5, y - 2)
//         }


//         // Вертикальные линии
//         var verticalLines = 6
//         for (var j = 0; j <= verticalLines; j++) {
//             var x = j * (_availableWidth) / verticalLines
//             var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//             ctx.beginPath()
//             ctx.moveTo(x, 0)
//             ctx.lineTo(x, height)
//             ctx.stroke()

//             // Сдвигаем надпись "30 с" вправо, добавляя отступ
//             var textX = x;
//             if (j === 0) {
//                 // Для самой левой метки сдвигаем вправо, чтобы было видно цифру
//                 textX = x + 15;
//             }

//             ctx.textAlign = "center"
//             ctx.fillText(secondsAgo.toFixed(0) + "с", textX, _zeroY + 15)
//         }

//         // Основные оси делаем более заметными
//         ctx.strokeStyle = "#777" // Более светлый цвет для осей
//         ctx.lineWidth = 2

//         // Ось X (горизонтальная линия нуля)
//         ctx.beginPath()
//         ctx.moveTo(0, _zeroY)
//         ctx.lineTo(width, _zeroY)
//         ctx.stroke()

//         // Ось Y (вертикальная линия текущего времени)
//         ctx.beginPath()
//         ctx.moveTo(_availableWidth, 0)
//         ctx.lineTo(_availableWidth, height)
//         ctx.stroke()

//         // Рамка вокруг всего графика
//         ctx.strokeStyle = "#555"
//         ctx.lineWidth = 1
//         ctx.strokeRect(0, 0, width, height)
//     }


//     // function drawGrid(ctx) {
//     //     ctx.strokeStyle = "#333"
//     //     ctx.lineWidth = 1
//     //     ctx.fillStyle = "#888"
//     //     ctx.font = "10px Arial"

//     //     // Горизонтальные линии
//     //     var horizontalValues = [-90, -45, 0, 45, 90]
//     //     for (var i = 0; i < horizontalValues.length; i++) {
//     //         var value = horizontalValues[i]
//     //         var y = height - ((value - minValue) / _valueRange) * height

//     //         ctx.beginPath()
//     //         ctx.moveTo(0, y)
//     //         ctx.lineTo(width, y)
//     //         ctx.stroke()

//     //         ctx.textAlign = "right"
//     //         ctx.fillText(value.toFixed(0) + "°", width - 5, y - 2)
//     //     }

//     //     // Вертикальные линии
//     //     var verticalLines = 6
//     //     for (var j = 0; j <= verticalLines; j++) {
//     //         var x = j * (_availableWidth) / verticalLines
//     //         var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//     //         ctx.beginPath()
//     //         ctx.moveTo(x, 0)
//     //         ctx.lineTo(x, height)
//     //         ctx.stroke()

//     //         ctx.textAlign = "center"
//     //         ctx.fillText(secondsAgo.toFixed(0) + "с", x, _zeroY + 15)
//     //     }

//     //     // Оси
//     //     ctx.strokeStyle = "white"
//     //     ctx.lineWidth = 2
//     //     ctx.beginPath()
//     //     ctx.moveTo(0, _zeroY)
//     //     ctx.lineTo(width, _zeroY)
//     //     ctx.stroke()

//     //     ctx.beginPath()
//     //     ctx.moveTo(_availableWidth, 0)
//     //     ctx.lineTo(_availableWidth, height)
//     //     ctx.stroke()
//     // }

//     function drawDizzinessIntervals(ctx) {
//         drawDizzinessType(ctx, dizzinessPatientData, dizzinessPatientColor)
//         drawDizzinessType(ctx, dizzinessDoctorData, dizzinessDoctorColor)
//     }

//     function drawDizzinessType(ctx, intervals, color) {
//         if (!intervals || intervals.length === 0) return

//         ctx.fillStyle = color

//         for (var i = 0; i < intervals.length; i++) {
//             var interval = intervals[i]
//             if (!interval || interval.startTime === undefined || interval.endTime === undefined) continue

//             var startTime = interval.startTime
//             var endTime = interval.endTime

//             var xStart = (startTime / (graphDuration * 1000)) * _availableWidth
//             var xEnd = (endTime / (graphDuration * 1000)) * _availableWidth

//             xStart = Math.max(0, Math.min(_availableWidth, xStart))
//             xEnd = Math.max(0, Math.min(_availableWidth, xEnd))

//             if (xEnd > xStart) {
//                 ctx.fillRect(xStart, 0, xEnd - xStart, height)
//             }
//         }
//     }

//     function drawGraphLine(ctx) {
//         if (graphData.length < 2) return

//         ctx.strokeStyle = lineColor
//         ctx.lineWidth = 2
//         ctx.beginPath()

//         var firstPoint = true

//         for (var i = 0; i < graphData.length; i++) {
//             var point = graphData[i]
//             if (!point || point.time === undefined || point.value === undefined) continue

//             var x = (point.time / (graphDuration * 1000)) * _availableWidth
//             var y = height - ((point.value - minValue) / _valueRange) * height

//             x = Math.max(0, Math.min(_availableWidth, x))
//             y = Math.max(0, Math.min(height, y))

//             if (firstPoint) {
//                 ctx.moveTo(x, y)
//                 firstPoint = false
//             } else {
//                 ctx.lineTo(x, y)
//             }
//         }

//         ctx.stroke()

//         // Рисуем последнюю точку
//         if (graphData.length > 0) {
//             var lastPoint = graphData[graphData.length - 1]
//             if (lastPoint && lastPoint.time !== undefined && lastPoint.value !== undefined) {
//                 var lastX = (lastPoint.time / (graphDuration * 1000)) * _availableWidth
//                 var lastY = height - ((lastPoint.value - minValue) / _valueRange) * height

//                 lastX = Math.max(3, Math.min(_availableWidth - 3, lastX))
//                 lastY = Math.max(3, Math.min(height - 3, lastY))

//                 ctx.fillStyle = lineColor
//                 ctx.beginPath()
//                 ctx.arc(lastX, lastY, 3, 0, Math.PI * 2)
//                 ctx.fill()
//             }
//         }
//     }

//     Timer {
//         interval: 100
//         running: canvas.visible && (controller.connected || controller.logPlaying)
//         repeat: true
//         onTriggered: canvas.requestPaint()
//     }

//     Connections {
//         target: controller
//         function onGraphDataChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//     }

//     // Принудительная отрисовка при создании компонента
//     Component.onCompleted: {
//         canvas.requestPaint()
//     }
// }



















// import QtQuick

// Canvas {
//     id: canvas
//     property var graphData: []
//     property var dizzinessPatientData: []
//     property var dizzinessDoctorData: []
//     property int graphDuration: 30
//     property color lineColor: "white"
//     property real minValue: -120
//     property real maxValue: 120

//     property color dizzinessPatientColor: "#40FFA000"
//     property color dizzinessDoctorColor: "#406060FF"

//     // Кэшируемые вычисления для оптимизации
//     property real _valueRange: maxValue - minValue
//     property real _zeroY: height - ((0 - minValue) / _valueRange) * height
//     property real _availableWidth: width - 40
//     property real _timeScale: _availableWidth / (graphDuration * 1000)

//     // Кэш для отрисованных данных
//     property var _cachedGraphData: []
//     property var _cachedDizzinessPatient: []
//     property var _cachedDizzinessDoctor: []
//     property bool _cacheValid: false

//     // Флаг для отображения сетки при отсутствии данных
//     property bool _hasData: graphData && graphData.length > 0

//     onWidthChanged: {
//         updateCachedValues()
//         canvas.requestPaint() // Принудительная перерисовка при изменении размера
//     }
//     onHeightChanged: {
//         updateCachedValues()
//         canvas.requestPaint()
//     }
//     onGraphDurationChanged: {
//         updateCachedValues()
//         canvas.requestPaint()
//     }
//     onGraphDataChanged: {
//         _hasData = graphData && graphData.length > 0
//         invalidateCache()
//     }
//     onDizzinessPatientDataChanged: invalidateCache()
//     onDizzinessDoctorDataChanged: invalidateCache()

//     function updateCachedValues() {
//         _valueRange = maxValue - minValue
//         _zeroY = height - ((0 - minValue) / _valueRange) * height
//         _availableWidth = width - 40
//         _timeScale = _availableWidth / (graphDuration * 1000)
//         invalidateCache()
//     }

//     function invalidateCache() {
//         _cacheValid = false
//         canvas.requestPaint()
//     }

//     onPaint: {
//         var ctx = getContext("2d")
//         ctx.clearRect(0, 0, width, height)

//         // ВСЕГДА рисуем сетку и оси, независимо от наличия данных
//         drawGrid(ctx)
//         drawDizzinessIntervals(ctx)

//         // Рисуем график только если есть данные
//         if (_hasData) {
//             drawGraphLine(ctx)
//         } else {
//             drawNoData(ctx)
//         }
//     }

//     function recalculateCache() {
//         if (!_hasData) return;

//         _cachedGraphData = []
//         for (var i = 0; i < graphData.length; i++) {
//             var point = graphData[i]
//             if (!point || point.time === undefined || point.value === undefined) continue

//             var x = point.time * _timeScale
//             var y = height - ((point.value - minValue) / _valueRange) * height

//             x = Math.max(0, Math.min(_availableWidth, x))
//             y = Math.max(0, Math.min(height, y))

//             _cachedGraphData.push({x: x, y: y, value: point.value})
//         }
//         _cacheValid = true
//     }

//     function drawNoData(ctx) {
//         ctx.fillStyle = "#888"
//         ctx.font = "14px Arial"
//         ctx.textAlign = "center"
//         ctx.fillText("нет данных", width / 2, height / 2)
//     }

//     function drawGrid(ctx) {
//         // Увеличиваем контрастность сетки
//         ctx.strokeStyle = "#444" // Более светлый цвет для сетки
//         ctx.lineWidth = 1
//         ctx.fillStyle = "#666" // Более светлый цвет для текста
//         ctx.font = "10px Arial"

//         // Горизонтальные линии и подписи значений
//         var horizontalValues = [-90, -45, 0, 45, 90]
//         for (var i = 0; i < horizontalValues.length; i++) {
//             var value = horizontalValues[i]
//             var y = height - ((value - minValue) / _valueRange) * height

//             // Делаем линию нуля более заметной
//             if (value === 0) {
//                 ctx.strokeStyle = "#666"
//                 ctx.lineWidth = 2
//             } else {
//                 ctx.strokeStyle = "#444"
//                 ctx.lineWidth = 1
//             }

//             ctx.beginPath()
//             ctx.moveTo(0, y)
//             ctx.lineTo(width, y)
//             ctx.stroke()

//             // Подписи значений
//             ctx.textAlign = "right"
//             ctx.fillText(value.toFixed(0) + "°", width - 5, y - 2)
//         }

//         // Вертикальные линии и подписи времени
//         ctx.strokeStyle = "#444"
//         ctx.lineWidth = 1
//         var verticalLines = 6
//         for (var j = 0; j <= verticalLines; j++) {
//             var x = j * (_availableWidth) / verticalLines
//             var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//             ctx.beginPath()
//             ctx.moveTo(x, 0)
//             ctx.lineTo(x, height)
//             ctx.stroke()

//             ctx.textAlign = "center"
//             ctx.fillText(secondsAgo.toFixed(0) + "с", x, _zeroY + 15)
//         }

//         // Основные оси делаем более заметными
//         ctx.strokeStyle = "#777" // Более светлый цвет для осей
//         ctx.lineWidth = 2

//         // Ось X (горизонтальная линия нуля)
//         ctx.beginPath()
//         ctx.moveTo(0, _zeroY)
//         ctx.lineTo(width, _zeroY)
//         ctx.stroke()

//         // Ось Y (вертикальная линия текущего времени)
//         ctx.beginPath()
//         ctx.moveTo(_availableWidth, 0)
//         ctx.lineTo(_availableWidth, height)
//         ctx.stroke()

//         // Рамка вокруг всего графика
//         ctx.strokeStyle = "#555"
//         ctx.lineWidth = 1
//         ctx.strokeRect(0, 0, width, height)
//     }

//     function drawDizzinessIntervals(ctx) {
//         if (!_hasData) return;

//         drawDizzinessType(ctx, dizzinessPatientData, dizzinessPatientColor)
//         drawDizzinessType(ctx, dizzinessDoctorData, dizzinessDoctorColor)
//     }

//     function drawDizzinessType(ctx, intervals, color) {
//         if (!intervals || intervals.length === 0) return

//         ctx.fillStyle = color

//         for (var i = 0; i < intervals.length; i++) {
//             var interval = intervals[i]
//             if (!interval || interval.startTime === undefined || interval.endTime === undefined) continue

//             var startTime = interval.startTime
//             var endTime = interval.endTime

//             var xStart = startTime * _timeScale
//             var xEnd = endTime * _timeScale

//             xStart = Math.max(0, Math.min(_availableWidth, xStart))
//             xEnd = Math.max(0, Math.min(_availableWidth, xEnd))

//             if (xEnd > xStart) {
//                 ctx.fillRect(xStart, 0, xEnd - xStart, height)
//             }
//         }
//     }

//     function drawGraphLine(ctx) {
//         if (!_cacheValid) {
//             recalculateCache()
//         }

//         if (_cachedGraphData.length < 2) return

//         ctx.strokeStyle = lineColor
//         ctx.lineWidth = 2
//         ctx.beginPath()

//         var firstPoint = true

//         for (var i = 0; i < _cachedGraphData.length; i++) {
//             var point = _cachedGraphData[i]

//             if (firstPoint) {
//                 ctx.moveTo(point.x, point.y)
//                 firstPoint = false
//             } else {
//                 ctx.lineTo(point.x, point.y)
//             }
//         }

//         ctx.stroke()

//         // Рисуем последнюю точку
//         if (_cachedGraphData.length > 0) {
//             var lastPoint = _cachedGraphData[_cachedGraphData.length - 1]

//             ctx.fillStyle = lineColor
//             ctx.beginPath()
//             ctx.arc(lastPoint.x, lastPoint.y, 3, 0, Math.PI * 2)
//             ctx.fill()
//         }
//     }

//     // ОПТИМИЗАЦИЯ: Перерисовываем при изменении видимости или данных
//     Connections {
//         target: controller
//         function onGraphDataChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//     }

//     // Принудительная отрисовка при создании компонента
//     Component.onCompleted: {
//         canvas.requestPaint()
//     }

//     // Таймер для периодической перерисовки (на случай если данные не меняются, но нужно обновить отображение)
//     Timer {
//         interval: 1000
//         running: canvas.visible
//         repeat: true
//         onTriggered: {
//             if (!_hasData) {
//                 canvas.requestPaint()
//             }
//         }
//     }
// }



















// import QtQuick

// Canvas {
//     id: canvas
//     property var graphData: []
//     property var dizzinessPatientData: []
//     property var dizzinessDoctorData: []
//     property int graphDuration: 30
//     property color lineColor: "white"
//     property real minValue: -120
//     property real maxValue: 120

//     property color dizzinessPatientColor: "#40FFA000"
//     property color dizzinessDoctorColor: "#406060FF"

//     // Кэшируемые вычисления для оптимизации
//     property real _valueRange: maxValue - minValue
//     property real _zeroY: height - ((0 - minValue) / _valueRange) * height
//     property real _availableWidth: width - 40
//     property real _timeScale: _availableWidth / (graphDuration * 1000)

//     // Кэш для отрисованных данных
//     property var _cachedGraphData: []
//     property var _cachedDizzinessPatient: []
//     property var _cachedDizzinessDoctor: []
//     property bool _cacheValid: false

//     onWidthChanged: updateCachedValues()
//     onHeightChanged: updateCachedValues()
//     onGraphDurationChanged: updateCachedValues()
//     onGraphDataChanged: invalidateCache()
//     onDizzinessPatientDataChanged: invalidateCache()
//     onDizzinessDoctorDataChanged: invalidateCache()

//     function updateCachedValues() {
//         _valueRange = maxValue - minValue
//         _zeroY = height - ((0 - minValue) / _valueRange) * height
//         _availableWidth = width - 40
//         _timeScale = _availableWidth / (graphDuration * 1000)
//         invalidateCache()
//     }

//     function invalidateCache() {
//         _cacheValid = false
//         canvas.requestPaint()
//     }

//     onPaint: {
//         var ctx = getContext("2d")
//         ctx.clearRect(0, 0, width, height)

//         if (graphData.length === 0) {
//             drawNoData(ctx)
//             return
//         }

//         // Используем кэшированные вычисления если они валидны
//         if (!_cacheValid) {
//             recalculateCache()
//         }

//         drawGrid(ctx)
//         drawDizzinessIntervals(ctx)
//         drawGraphLine(ctx)
//     }

//     function recalculateCache() {
//         // Предварительные вычисления для оптимизации отрисовки
//         _cachedGraphData = []
//         for (var i = 0; i < graphData.length; i++) {
//             var point = graphData[i]
//             if (!point || point.time === undefined || point.value === undefined) continue

//             var x = point.time * _timeScale
//             var y = height - ((point.value - minValue) / _valueRange) * height

//             x = Math.max(0, Math.min(_availableWidth, x))
//             y = Math.max(0, Math.min(height, y))

//             _cachedGraphData.push({x: x, y: y, value: point.value})
//         }
//         _cacheValid = true
//     }

//     function drawNoData(ctx) {
//         ctx.fillStyle = "#888"
//         ctx.font = "14px Arial"
//         ctx.textAlign = "center"
//         ctx.fillText("нет данных", width / 2, height / 2)
//     }

//     function drawGrid(ctx) {
//         ctx.strokeStyle = "#333"
//         ctx.lineWidth = 1
//         ctx.fillStyle = "#888"
//         ctx.font = "10px Arial"

//         // Горизонтальные линии
//         var horizontalValues = [-90, -45, 0, 45, 90]
//         for (var i = 0; i < horizontalValues.length; i++) {
//             var value = horizontalValues[i]
//             var y = height - ((value - minValue) / _valueRange) * height

//             ctx.beginPath()
//             ctx.moveTo(0, y)
//             ctx.lineTo(width, y)
//             ctx.stroke()

//             ctx.textAlign = "right"
//             ctx.fillText(value.toFixed(0) + "°", width - 5, y - 2)
//         }

//         // Вертикальные линии
//         var verticalLines = 6
//         for (var j = 0; j <= verticalLines; j++) {
//             var x = j * (_availableWidth) / verticalLines
//             var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//             ctx.beginPath()
//             ctx.moveTo(x, 0)
//             ctx.lineTo(x, height)
//             ctx.stroke()

//             ctx.textAlign = "center"
//             ctx.fillText(secondsAgo.toFixed(0) + "с", x, _zeroY + 15)
//         }

//         // Оси
//         ctx.strokeStyle = "white"
//         ctx.lineWidth = 2
//         ctx.beginPath()
//         ctx.moveTo(0, _zeroY)
//         ctx.lineTo(width, _zeroY)
//         ctx.stroke()

//         ctx.beginPath()
//         ctx.moveTo(_availableWidth, 0)
//         ctx.lineTo(_availableWidth, height)
//         ctx.stroke()
//     }

//     function drawDizzinessIntervals(ctx) {
//         drawDizzinessType(ctx, dizzinessPatientData, dizzinessPatientColor)
//         drawDizzinessType(ctx, dizzinessDoctorData, dizzinessDoctorColor)
//     }

//     function drawDizzinessType(ctx, intervals, color) {
//         if (!intervals || intervals.length === 0) return

//         ctx.fillStyle = color

//         for (var i = 0; i < intervals.length; i++) {
//             var interval = intervals[i]
//             if (!interval || interval.startTime === undefined || interval.endTime === undefined) continue

//             var startTime = interval.startTime
//             var endTime = interval.endTime

//             var xStart = startTime * _timeScale
//             var xEnd = endTime * _timeScale

//             xStart = Math.max(0, Math.min(_availableWidth, xStart))
//             xEnd = Math.max(0, Math.min(_availableWidth, xEnd))

//             if (xEnd > xStart) {
//                 ctx.fillRect(xStart, 0, xEnd - xStart, height)
//             }
//         }
//     }

//     function drawGraphLine(ctx) {
//         if (_cachedGraphData.length < 2) return

//         ctx.strokeStyle = lineColor
//         ctx.lineWidth = 2
//         ctx.beginPath()

//         var firstPoint = true

//         for (var i = 0; i < _cachedGraphData.length; i++) {
//             var point = _cachedGraphData[i]

//             if (firstPoint) {
//                 ctx.moveTo(point.x, point.y)
//                 firstPoint = false
//             } else {
//                 ctx.lineTo(point.x, point.y)
//             }
//         }

//         ctx.stroke()

//         // Рисуем последнюю точку
//         if (_cachedGraphData.length > 0) {
//             var lastPoint = _cachedGraphData[_cachedGraphData.length - 1]

//             ctx.fillStyle = lineColor
//             ctx.beginPath()
//             ctx.arc(lastPoint.x, lastPoint.y, 3, 0, Math.PI * 2)
//             ctx.fill()
//         }
//     }

//     // ОПТИМИЗАЦИЯ: Перерисовываем только при реальном изменении данных
//     Connections {
//         target: controller
//         function onGraphDataChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//     }
// }
