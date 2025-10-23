// GraphCanvas.qml
import QtQuick

Canvas {
    id: canvas
    property var graphData: []
    property var dizzinessData: []
    property int graphDuration: 30
    property color lineColor: "white"
    property real minValue: -90
    property real maxValue: 90
    property real valueRange: maxValue - minValue

    // Настройки внешнего вида
    property color gridColor: "#333"
    property color textColor: "#666"

    // Упрощаем настройки головокружения для стабильности
    property color dizzinessColor: "#60FFB300"
    property real dizzinessOpacity: 0.25
    property real dizzinessWidth: 6

    onPaint: {
        try {
            var ctx = getContext("2d")
            if (!ctx) {
                console.error("Cannot get canvas context")
                return
            }

            ctx.clearRect(0, 0, width, height)

            drawGrid(ctx)

            if (graphData.length === 0) {
                drawNoData(ctx)
                return
            }

            // УБИРАЕМ ГРАДИЕНТ И СЛОЖНЫЕ ФУНКЦИИ - используем простую отрисовку
            drawDizzinessZones(ctx)
            drawGraphLine(ctx)
            drawCurrentTime(ctx)
        } catch (error) {
            console.error("Error in canvas paint:", error)
        }
    }

    function drawNoData(ctx) {
        try {
            ctx.fillStyle = textColor
            ctx.font = "14px Arial"
            ctx.textAlign = "center"
            ctx.fillText("нет данных", width / 2, height / 2)
        } catch (error) {
            console.error("Error in drawNoData:", error)
        }
    }

    function drawGrid(ctx) {
        try {
            ctx.strokeStyle = gridColor
            ctx.lineWidth = 1
            ctx.fillStyle = textColor
            ctx.font = "10px Arial"

            // Горизонтальные линии и подписи значений
            var horizontalLines = 5
            for (var i = 0; i <= horizontalLines; i++) {
                var y = height - (i * height / horizontalLines)
                var value = minValue + (i * valueRange / horizontalLines)

                // Линия
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()

                // Подпись значения
                ctx.textAlign = "left"
                ctx.fillText(value.toFixed(0) + "°", 5, y - 2)
            }

            // Вертикальные линии (временные метки)
            var verticalLines = 6
            for (var j = 0; j <= verticalLines; j++) {
                var x = j * width / verticalLines
                var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

                // Линия
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()

                // Подпись времени
                ctx.textAlign = "center"
                ctx.fillText("t-" + secondsAgo.toFixed(0) + "с", x, height - 5)
            }

            // Подпись оси времени в центре снизу
            ctx.textAlign = "center"
            ctx.fillText("t, с", width / 2, height - 5)
        } catch (error) {
            console.error("Error in drawGrid:", error)
        }
    }

    function drawDizzinessZones(ctx) {
        try {
            if (!dizzinessData || dizzinessData.length === 0) {
                return
            }

            var currentTime = new Date().getTime()
            var minTime = currentTime - graphDuration * 1000

            // УПРОЩАЕМ: используем простой цвет без градиента
            ctx.fillStyle = dizzinessColor
            ctx.globalAlpha = dizzinessOpacity

            for (var i = 0; i < dizzinessData.length; i++) {
                var dizzinessTime = dizzinessData[i]
                // Проверяем что dizzinessTime - валидное число
                if (typeof dizzinessTime !== 'number' || isNaN(dizzinessTime)) {
                    continue
                }

                if (dizzinessTime >= minTime) {
                    var x = width - (currentTime - dizzinessTime) / (graphDuration * 1000) * width

                    // Используем настраиваемую ширину
                    var zoneWidth = Math.max(dizzinessWidth, width / (graphDuration * 5))

                    // Ограничиваем позицию
                    var drawX = Math.max(zoneWidth / 2, Math.min(width - zoneWidth / 2, x))

                    // ПРОСТОЙ прямоугольник - убираем roundRect который может не поддерживаться
                    ctx.fillRect(drawX - zoneWidth / 2, 0, zoneWidth, height)
                }
            }

            ctx.globalAlpha = 1.0
        } catch (error) {
            console.error("Error in drawDizzinessZones:", error)
        }
    }

    function drawGraphLine(ctx) {
        try {
            if (!graphData || graphData.length < 2) return

            var currentTime = new Date().getTime()
            var minTime = currentTime - graphDuration * 1000

            ctx.strokeStyle = lineColor
            ctx.lineWidth = 2
            ctx.beginPath()

            var pointsDrawn = 0

            // Ограничиваем количество точек для отрисовки
            var maxPointsToDraw = 100
            var step = Math.max(1, Math.floor(graphData.length / maxPointsToDraw))

            for (var i = 0; i < graphData.length; i += step) {
                var point = graphData[i]
                // Проверяем валидность точки
                if (!point || typeof point.time !== 'number' || typeof point.value !== 'number') {
                    continue
                }

                if (point.time >= minTime) {
                    var x = width - (currentTime - point.time) / (graphDuration * 1000) * width
                    var y = height - ((point.value - minValue) / valueRange) * height

                    // Ограничиваем координаты
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

            // Рисуем текущую точку (последнюю)
            if (graphData.length > 0) {
                var lastPoint = graphData[graphData.length - 1]
                if (lastPoint && typeof lastPoint.time === 'number' && typeof lastPoint.value === 'number') {
                    var lastX = width - (currentTime - lastPoint.time) / (graphDuration * 1000) * width
                    var lastY = height - ((lastPoint.value - minValue) / valueRange) * height

                    // Ограничиваем координаты
                    lastX = Math.max(3, Math.min(width - 3, lastX))
                    lastY = Math.max(3, Math.min(height - 3, lastY))

                    ctx.fillStyle = lineColor
                    ctx.beginPath()
                    ctx.arc(lastX, lastY, 4, 0, Math.PI * 2)
                    ctx.fill()

                    // Белая обводка для лучшей видимости
                    ctx.strokeStyle = "white"
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }
        } catch (error) {
            console.error("Error in drawGraphLine:", error)
        }
    }

    function drawCurrentTime(ctx) {
        try {
            // Вертикальная линия текущего времени (правая граница)
            ctx.strokeStyle = "#888"
            ctx.lineWidth = 1
            ctx.setLineDash([5, 5])
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(width, height)
            ctx.stroke()
            ctx.setLineDash([])
        } catch (error) {
            console.error("Error in drawCurrentTime:", error)
        }
    }

    // Таймер для обновления графика
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

    // Обновляем при изменении данных
    Connections {
        target: controller
        function onGraphDataChanged() {
            if (canvas.visible) {
                canvas.requestPaint()
            }
        }
        function onGraphDurationChanged() {
            if (canvas.visible) {
                canvas.requestPaint()
            }
        }
        function onUpdateFrequencyChanged() {
            updateTimer.interval = 1000 / (controller.updateFrequency || 10)
        }
    }

    // Восстановление после ошибок
    function safeRepaint() {
        try {
            requestPaint()
        } catch (error) {
            console.error("Safe repaint failed, resetting canvas...")
            // Пытаемся восстановить контекст
            var ctx = getContext("2d")
            if (ctx) {
                ctx.clearRect(0, 0, width, height)
                drawNoData(ctx)
            }
        }
    }
}




// // GraphCanvas.qml
// import QtQuick

// Canvas {
//     id: canvas
//     property var graphData: []
//     property var dizzinessData: []
//     property int graphDuration: 30
//     property color lineColor: "white"
//     property real minValue: -90
//     property real maxValue: 90
//     property real valueRange: maxValue - minValue

//     // Настройки внешнего вида
//     property color gridColor: "#333"
//     property color textColor: "#666"
//     property color dizzinessColor: "#FFA000" // Более насыщенный оранжево-желтый
//     property real dizzinessOpacity: 0.6      // Увеличиваем непрозрачность

//     onPaint: {
//         var ctx = getContext("2d")
//         ctx.clearRect(0, 0, width, height)

//         drawGrid(ctx)

//         if (graphData.length === 0) {
//             drawNoData(ctx)
//             return
//         }

//         // ИЗМЕНЯЕМ ПОРЯДОК: сначала головокружение, потом график
//         drawDizzinessZones(ctx)
//         drawGraphLine(ctx)
//         drawCurrentTime(ctx)
//     }

//     function drawNoData(ctx) {
//         ctx.fillStyle = textColor
//         ctx.font = "14px Arial"
//         ctx.textAlign = "center"
//         ctx.fillText("нет данных", width / 2, height / 2)
//     }

//     function drawGrid(ctx) {
//         ctx.strokeStyle = gridColor
//         ctx.lineWidth = 1
//         ctx.fillStyle = textColor
//         ctx.font = "10px Arial"

//         // Горизонтальные линии и подписи значений
//         var horizontalLines = 5
//         for (var i = 0; i <= horizontalLines; i++) {
//             var y = height - (i * height / horizontalLines)
//             var value = minValue + (i * valueRange / horizontalLines)

//             // Линия
//             ctx.beginPath()
//             ctx.moveTo(0, y)
//             ctx.lineTo(width, y)
//             ctx.stroke()

//             // Подпись значения
//             ctx.textAlign = "left"
//             ctx.fillText(value.toFixed(0) + "°", 5, y - 2)
//         }

//         // Вертикальные линии (временные метки)
//         var verticalLines = 6
//         for (var j = 0; j <= verticalLines; j++) {
//             var x = j * width / verticalLines
//             var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//             // Линия
//             ctx.beginPath()
//             ctx.moveTo(x, 0)
//             ctx.lineTo(x, height)
//             ctx.stroke()

//             // Подпись времени
//             ctx.textAlign = "center"
//             ctx.fillText("t-" + secondsAgo.toFixed(0) + "с", x, height - 5)
//         }

//         // Подпись оси времени в центре снизу
//         ctx.textAlign = "center"
//         ctx.fillText("t, с", width / 2, height - 5)
//     }

//     function drawDizzinessZones(ctx) {
//         if (dizzinessData.length === 0) {
//             // console.log("No dizziness data to display")
//             return
//         }

//         var currentTime = new Date().getTime()
//         var minTime = currentTime - graphDuration * 1000

//         ctx.fillStyle = dizzinessColor
//         ctx.globalAlpha = dizzinessOpacity

//         var zonesDrawn = 0

//         for (var i = 0; i < dizzinessData.length; i++) {
//             var dizzinessTime = dizzinessData[i]
//             if (dizzinessTime >= minTime) {
//                 var x = width - (currentTime - dizzinessTime) / (graphDuration * 1000) * width

//                 // УВЕЛИЧИВАЕМ ШИРИНУ ЗОНЫ для лучшей видимости
//                 var zoneWidth = Math.max(8, width / (graphDuration * 3)) // Шире и заметнее

//                 // Ограничиваем позицию чтобы не выходила за границы
//                 var drawX = Math.max(zoneWidth / 2, Math.min(width - zoneWidth / 2, x))

//                 ctx.fillRect(drawX - zoneWidth / 2, 0, zoneWidth, height)
//                 zonesDrawn++
//             }
//         }

//         ctx.globalAlpha = 1.0

//         // Отладочная информация
//         if (zonesDrawn > 0) {
//             // console.log("Drawn dizziness zones:", zonesDrawn, "at time:", currentTime)
//         }
//     }

//     function drawGraphLine(ctx) {
//         if (graphData.length < 2) return

//         var currentTime = new Date().getTime()
//         var minTime = currentTime - graphDuration * 1000

//         ctx.strokeStyle = lineColor
//         ctx.lineWidth = 2
//         ctx.beginPath()

//         var pointsDrawn = 0

//         // Ограничиваем количество точек для отрисовки
//         var maxPointsToDraw = 100
//         var step = Math.max(1, Math.floor(graphData.length / maxPointsToDraw))

//         for (var i = 0; i < graphData.length; i += step) {
//             var point = graphData[i]
//             if (point.time >= minTime) {
//                 var x = width - (currentTime - point.time) / (graphDuration * 1000) * width
//                 var y = height - ((point.value - minValue) / valueRange) * height

//                 // Ограничиваем координаты
//                 x = Math.max(0, Math.min(width, x))
//                 y = Math.max(0, Math.min(height, y))

//                 if (pointsDrawn === 0) {
//                     ctx.moveTo(x, y)
//                 } else {
//                     ctx.lineTo(x, y)
//                 }
//                 pointsDrawn++
//             }
//         }

//         ctx.stroke()

//         // Рисуем текущую точку (последнюю)
//         if (graphData.length > 0) {
//             var lastPoint = graphData[graphData.length - 1]
//             var lastX = width - (currentTime - lastPoint.time) / (graphDuration * 1000) * width
//             var lastY = height - ((lastPoint.value - minValue) / valueRange) * height

//             // Ограничиваем координаты
//             lastX = Math.max(3, Math.min(width - 3, lastX))
//             lastY = Math.max(3, Math.min(height - 3, lastY))

//             ctx.fillStyle = lineColor
//             ctx.beginPath()
//             ctx.arc(lastX, lastY, 4, 0, Math.PI * 2)
//             ctx.fill()

//             // Белая обводка для лучшей видимости
//             ctx.strokeStyle = "white"
//             ctx.lineWidth = 1
//             ctx.stroke()
//         }
//     }

//     function drawCurrentTime(ctx) {
//         // Вертикальная линия текущего времени (правая граница)
//         ctx.strokeStyle = "#888"
//         ctx.lineWidth = 1
//         ctx.setLineDash([5, 5])
//         ctx.beginPath()
//         ctx.moveTo(width, 0)
//         ctx.lineTo(width, height)
//         ctx.stroke()
//         ctx.setLineDash([])
//     }

//     // Таймер для обновления графика
//     Timer {
//         interval: 200
//         running: canvas.visible && (controller.connected || controller.logPlaying)
//         repeat: true
//         onTriggered: {
//             if (controller.headModel.hasData) {
//                 canvas.requestPaint()
//             }
//         }
//     }

//     // Обновляем при изменении данных
//     Connections {
//         target: controller
//         function onGraphDataChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//         function onGraphDurationChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//     }

//     // Дополнительная отладочная информация
//     Component.onCompleted: {
//         console.log("GraphCanvas loaded for", lineColor)
//     }
// }








// // GraphCanvas.qml
// import QtQuick

// Canvas {
//     id: canvas
//     property var graphData: []
//     property var dizzinessData: []
//     property int graphDuration: 30
//     property color lineColor: "white"
//     property real minValue: -90
//     property real maxValue: 90
//     property real valueRange: maxValue - minValue

//     // Настройки внешнего вида
//     property color gridColor: "#333"
//     property color textColor: "#666"
//     property color dizzinessColor: "#FFEB3B"
//     property real dizzinessOpacity: 0.3

//     onPaint: {
//         var ctx = getContext("2d")
//         ctx.clearRect(0, 0, width, height)

//         if (graphData.length === 0) {
//             drawNoData(ctx)
//             return
//         }

//         drawGrid(ctx)
//         drawDizzinessZones(ctx)
//         drawGraphLine(ctx)
//         drawCurrentTime(ctx)
//     }

//     function drawNoData(ctx) {
//         ctx.fillStyle = textColor
//         ctx.font = "14px Arial"
//         ctx.textAlign = "center"
//         ctx.fillText("нет данных", width / 2, height / 2)
//     }

//     function drawGrid(ctx) {
//         ctx.strokeStyle = gridColor
//         ctx.lineWidth = 1
//         ctx.fillStyle = textColor
//         ctx.font = "10px Arial"

//         // Горизонтальные линии и подписи значений
//         var horizontalLines = 5
//         for (var i = 0; i <= horizontalLines; i++) {
//             var y = height - (i * height / horizontalLines)
//             var value = minValue + (i * valueRange / horizontalLines)

//             // Линия
//             ctx.beginPath()
//             ctx.moveTo(0, y)
//             ctx.lineTo(width, y)
//             ctx.stroke()

//             // Подпись значения
//             ctx.textAlign = "left"
//             ctx.fillText(value.toFixed(0) + "°", 5, y - 2)
//         }

//         // Вертикальные линии (временные метки)
//         var verticalLines = 6
//         for (var j = 0; j <= verticalLines; j++) {
//             var x = j * width / verticalLines
//             var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//             // Линия
//             ctx.beginPath()
//             ctx.moveTo(x, 0)
//             ctx.lineTo(x, height)
//             ctx.stroke()

//             // Подпись времени
//             ctx.textAlign = "center"
//             ctx.fillText("t-" + secondsAgo.toFixed(0) + "с", x, height - 5)
//         }

//         // Подпись оси времени в центре снизу
//         ctx.textAlign = "center"
//         ctx.fillText("t, с", width / 2, height - 5)
//     }

//     function drawDizzinessZones(ctx) {
//         if (dizzinessData.length === 0) return

//         var currentTime = new Date().getTime()
//         var minTime = currentTime - graphDuration * 1000

//         ctx.fillStyle = dizzinessColor
//         ctx.globalAlpha = dizzinessOpacity

//         for (var i = 0; i < dizzinessData.length; i++) {
//             var dizzinessTime = dizzinessData[i]
//             if (dizzinessTime >= minTime) {
//                 var x = width - (currentTime - dizzinessTime) / (graphDuration * 1000) * width
//                 var zoneWidth = Math.max(2, width / (graphDuration * 10))

//                 ctx.fillRect(x - zoneWidth / 2, 0, zoneWidth, height)
//             }
//         }

//         ctx.globalAlpha = 1.0
//     }

//     function drawGraphLine(ctx) {
//         if (graphData.length < 2) return

//         var currentTime = new Date().getTime()
//         var minTime = currentTime - graphDuration * 1000

//         ctx.strokeStyle = lineColor
//         ctx.lineWidth = 2
//         ctx.beginPath()

//         var pointsDrawn = 0

//         // Ограничиваем количество точек для отрисовки
//         var maxPointsToDraw = 100
//         var step = Math.max(1, Math.floor(graphData.length / maxPointsToDraw))

//         for (var i = 0; i < graphData.length; i += step) {
//             var point = graphData[i]
//             if (point.time >= minTime) {
//                 var x = width - (currentTime - point.time) / (graphDuration * 1000) * width
//                 var y = height - ((point.value - minValue) / valueRange) * height

//                 // Ограничиваем координаты
//                 x = Math.max(0, Math.min(width, x))
//                 y = Math.max(0, Math.min(height, y))

//                 if (pointsDrawn === 0) {
//                     ctx.moveTo(x, y)
//                 } else {
//                     ctx.lineTo(x, y)
//                 }
//                 pointsDrawn++
//             }
//         }

//         ctx.stroke()

//         // Рисуем текущую точку (последнюю)
//         if (graphData.length > 0) {
//             var lastPoint = graphData[graphData.length - 1]
//             var lastX = width - (currentTime - lastPoint.time) / (graphDuration * 1000) * width
//             var lastY = height - ((lastPoint.value - minValue) / valueRange) * height

//             ctx.fillStyle = lineColor
//             ctx.beginPath()
//             ctx.arc(lastX, lastY, 3, 0, Math.PI * 2)
//             ctx.fill()
//         }
//     }

//     function drawCurrentTime(ctx) {
//         // Вертикальная линия текущего времени (правая граница)
//         ctx.strokeStyle = "#888"
//         ctx.lineWidth = 1
//         ctx.setLineDash([5, 5])
//         ctx.beginPath()
//         ctx.moveTo(width, 0)
//         ctx.lineTo(width, height)
//         ctx.stroke()
//         ctx.setLineDash([])
//     }

//     // Увеличиваем интервал обновления до 200ms (5 FPS)
//     Timer {
//         interval: 200
//         running: canvas.visible && (controller.connected || controller.logPlaying)
//         repeat: true
//         onTriggered: {
//             if (controller.headModel.hasData) {
//                 canvas.requestPaint()
//             }
//         }
//     }

//     // Обновляем при изменении данных
//     Connections {
//         target: controller
//         function onGraphDataChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//         function onGraphDurationChanged() {
//             if (canvas.visible) {
//                 canvas.requestPaint()
//             }
//         }
//     }
// }







// // GraphCanvas.qml
// import QtQuick

// Canvas {
//     id: canvas
//     property var graphData: []
//     property var dizzinessData: []
//     property int graphDuration: 30
//     property color lineColor: "white"
//     property real minValue: -90
//     property real maxValue: 90
//     property real valueRange: maxValue - minValue

//     // Настройки внешнего вида
//     property color gridColor: "#333"
//     property color textColor: "#666"
//     property color dizzinessColor: "#FFEB3B"
//     property real dizzinessOpacity: 0.3

//     onPaint: {
//         var ctx = getContext("2d")
//         ctx.clearRect(0, 0, width, height)

//         if (graphData.length === 0) {
//             drawNoData(ctx)
//             return
//         }

//         drawGrid(ctx)
//         drawDizzinessZones(ctx)
//         drawGraphLine(ctx)
//         drawCurrentTime(ctx)
//     }

//     function drawNoData(ctx) {
//         ctx.fillStyle = textColor
//         ctx.font = "14px Arial"
//         ctx.textAlign = "center"
//         ctx.fillText("нет данных", width / 2, height / 2)
//     }

//     function drawGrid(ctx) {
//         ctx.strokeStyle = gridColor
//         ctx.lineWidth = 1
//         ctx.fillStyle = textColor
//         ctx.font = "10px Arial"

//         // Горизонтальные линии и подписи значений
//         var horizontalLines = 5
//         for (var i = 0; i <= horizontalLines; i++) {
//             var y = height - (i * height / horizontalLines)
//             var value = minValue + (i * valueRange / horizontalLines)

//             // Линия
//             ctx.beginPath()
//             ctx.moveTo(0, y)
//             ctx.lineTo(width, y)
//             ctx.stroke()

//             // Подпись значения
//             ctx.textAlign = "left"
//             ctx.fillText(value.toFixed(0) + "°", 5, y - 2)
//         }

//         // Вертикальные линии (временные метки)
//         var verticalLines = 6
//         var currentTime = new Date().getTime()
//         for (var j = 0; j <= verticalLines; j++) {
//             var x = j * width / verticalLines
//             var secondsAgo = (verticalLines - j) * graphDuration / verticalLines

//             // Линия
//             ctx.beginPath()
//             ctx.moveTo(x, 0)
//             ctx.lineTo(x, height)
//             ctx.stroke()

//             // Подпись времени
//             ctx.textAlign = "center"
//             ctx.fillText("t-" + secondsAgo.toFixed(0) + "с", x, height - 5)
//         }

//         // Подпись оси времени в центре снизу
//         ctx.textAlign = "center"
//         ctx.fillText("t, с", width / 2, height - 5)
//     }

//     function drawDizzinessZones(ctx) {
//         if (dizzinessData.length === 0) return

//         var currentTime = new Date().getTime()
//         var minTime = currentTime - graphDuration * 1000

//         ctx.fillStyle = dizzinessColor
//         ctx.globalAlpha = dizzinessOpacity

//         for (var i = 0; i < dizzinessData.length; i++) {
//             var dizzinessTime = dizzinessData[i]
//             if (dizzinessTime >= minTime) {
//                 var x = width - (currentTime - dizzinessTime) / (graphDuration * 1000) * width
//                 var zoneWidth = Math.max(2, width / (graphDuration * 10)) // Минимальная ширина 2px

//                 ctx.fillRect(x - zoneWidth / 2, 0, zoneWidth, height)
//             }
//         }

//         ctx.globalAlpha = 1.0
//     }

//     function drawGraphLine(ctx) {
//         if (graphData.length < 2) return

//         var currentTime = new Date().getTime()
//         var minTime = currentTime - graphDuration * 1000

//         ctx.strokeStyle = lineColor
//         ctx.lineWidth = 2
//         ctx.beginPath()

//         var pointsDrawn = 0
//         for (var i = 0; i < graphData.length; i++) {
//             var point = graphData[i]
//             if (point.time >= minTime) {
//                 var x = width - (currentTime - point.time) / (graphDuration * 1000) * width
//                 var y = height - ((point.value - minValue) / valueRange) * height

//                 // Ограничиваем координаты
//                 x = Math.max(0, Math.min(width, x))
//                 y = Math.max(0, Math.min(height, y))

//                 if (pointsDrawn === 0) {
//                     ctx.moveTo(x, y)
//                 } else {
//                     ctx.lineTo(x, y)
//                 }
//                 pointsDrawn++
//             }
//         }

//         ctx.stroke()

//         // Рисуем текущую точку (последнюю)
//         if (pointsDrawn > 0) {
//             var lastPoint = graphData[graphData.length - 1]
//             var lastX = width - (currentTime - lastPoint.time) / (graphDuration * 1000) * width
//             var lastY = height - ((lastPoint.value - minValue) / valueRange) * height

//             ctx.fillStyle = lineColor
//             ctx.beginPath()
//             ctx.arc(lastX, lastY, 4, 0, Math.PI * 2)
//             ctx.fill()
//         }
//     }

//     function drawCurrentTime(ctx) {
//         // Вертикальная линия текущего времени (правая граница)
//         ctx.strokeStyle = "#888"
//         ctx.lineWidth = 1
//         ctx.setLineDash([5, 5])
//         ctx.beginPath()
//         ctx.moveTo(width, 0)
//         ctx.lineTo(width, height)
//         ctx.stroke()
//         ctx.setLineDash([])
//     }

//     // Таймер для обновления графика
//     Timer {
//         interval: 50 // 20 FPS
//         running: true
//         repeat: true
//         onTriggered: canvas.requestPaint()
//     }

//     // Обновляем при изменении данных
//     Connections {
//         target: controller
//         function onGraphDataChanged() {
//             canvas.requestPaint()
//         }
//     }

//     Connections {
//         target: controller
//         function onGraphDurationChanged() {
//             canvas.requestPaint()
//         }
//     }
// }
