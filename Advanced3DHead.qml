import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick.Controls

Item {
    id: advanced3DHead
    property real headPitch: 0
    property real headRoll: 0
    property real headYaw: 0
    property bool showInnerEar: false
    // property string currentModelPathHeadMonkey: "qrc:/models/suzanne_mesh.mesh" // Голова обезъяны
    property string currentModelPathHead: "qrc:/models/Head_poligon.mesh" // Голова полигональная
    property string currentModelPathEarLeft: "qrc:/models/Inner_ear_left.mesh"
    property real headScale: 50 // Масштаб головы: для полигональной - 15, для обезъяны - 5
    property real earScale: 28 // Масштаб ушей относительно головы

    property bool patientDizziness: false
    property bool doctorDizziness: false
    property bool hasData: false
    property bool showHead: true

    // Свойства для управления видимостью сетки и стрелок осей
    property bool showGrid: true
    property bool showAxisArrows: true

    property string currentView: "free"
    property string viewText: {
        switch(currentView) {
            case "front": return "СПЕРЕДИ";
            case "back": return "СЗАДИ";
            case "left": return "СЛЕВА";
            case "right": return "СПРАВА";
            case "top": return "СВЕРХУ";
            case "bottom": return "СНИЗУ";
            default: return "СВОБОДНЫЙ";
        }
    }

    // ЦВЕТА ДЛЯ ЭФФЕКТОВ ГОЛОВОКРУЖЕНИЯ
    property color patientDizzinessColor: "#40FFA000"  // Оранжевый
    property color doctorDizzinessColor: "#406060FF"   // Синий
    property color combinedDizzinessColor: "#40FF4040" // Красный

    // ТЕКСТЫ ДЛЯ ГОЛОВОКРУЖЕНИЯ
    property string patientDizzinessText: "ГОЛОВОКРУЖЕНИЕ"
    property string doctorDizzinessText: "НИСТАГМ"
    property string combinedPatientText: "ГОЛОВОКРУЖЕНИЕ"
    property string combinedDoctorText: "НИСТАГМ"

    // ЦВЕТА ТЕКСТОВ (более яркие для лучшей видимости)
    property color patientTextColor: "#FFFFA000"  // Яркий оранжевый
    property color doctorTextColor: "#FF6060FF"   // Яркий синий
    property color combinedTextColor: "#FFFF4040" // Яркий красный

    // ПАРАМЕТРЫ АНИМАЦИИ
    property real dizzinessOpacityMin: 0.6
    property real dizzinessOpacityMax: 0.9
    property int dizzinessPulseDuration: 1000

    // ПАРАМЕТРЫ ТЕКСТА
    property int textFontSize: 24
    property bool textBold: true
    property real textPositionRatio: 0.33  // Позиция текста (1/3 от края)

    // Свойства для управления камерой
    property real cameraDistance: 50
    property real cameraYaw: 45
    property real cameraPitch: 30

    // ПАРАМЕТРЫ ОСВЕЩЕНИЯ
    property real mainLightBrightness: 2.0
    property real secondaryLightBrightness: 0.8
    property real backLightBrightness: 0.7  // 35% от основного (2.0 * 0.35 = 0.7)

    // ПРОЗРАЧНОСТЬ ГОЛОВЫ (при запуске программы)
    property real headOpacity: 0.15  // Прозрачность головы (0.0 - полностью прозрачная, 1.0 - полностью непрозрачная)

    View3D {
        id: view3D
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#2b2b2b"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        Node {
            id: scene

            // ОСНОВНОЙ ИСТОЧНИК СВЕТА (спереди-сверху-слева)
            DirectionalLight {
                id: mainLight
                eulerRotation.x: -30
                eulerRotation.y: 45
                brightness: mainLightBrightness
                ambientColor: Qt.rgba(0.3, 0.3, 0.3, 1.0)
            }

            // ВТОРОСТЕПЕННЫЙ ИСТОЧНИК СВЕТА (спереди-снизу-справа)
            DirectionalLight {
                eulerRotation.x: -10
                eulerRotation.y: -60
                brightness: secondaryLightBrightness
            }

            // ДОПОЛНИТЕЛЬНЫЙ ИСТОЧНИК СВЕТА (сзади-снизу)
            DirectionalLight {
                id: backLight
                eulerRotation.x: 20    // Немного снизу
                eulerRotation.y: 160   // Сзади (180 - небольшое смещение)
                brightness: backLightBrightness
                ambientColor: Qt.rgba(0.2, 0.2, 0.2, 1.0)
            }

            PerspectiveCamera {
                id: camera
                position: Qt.vector3d(0, 0, cameraDistance)
                clipNear: 0.01
                clipFar: 10000
                fieldOfView: 60
            }

            // Фоновая плоскость сетки (плоскость XZ)
            Model {
                id: gridPlane
                source: "#Rectangle"
                eulerRotation.x: -90
                scale: Qt.vector3d(2, 2, 2)
                materials: PrincipledMaterial {
                    baseColor: "#333333"
                    roughness: 0.9
                    metalness: 0.0
                    opacity: 0.01
                    alphaMode: PrincipledMaterial.Blend
                }
                visible: showGrid
            }

            // Линии сетки вдоль оси X (вертикальные линии в плоскости XZ)
            Repeater3D {
                model: 41
                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d((index - 20) * 5, 0.01, 0)
                    eulerRotation.x: 90
                    scale: Qt.vector3d(0.0005, 2, 0.0005)
                    materials: PrincipledMaterial {
                        baseColor: "#666666"
                        roughness: 0.7
                        metalness: 0.0
                        opacity: 0.7
                        alphaMode: PrincipledMaterial.Blend
                    }
                    visible: showGrid
                }
            }

            // Линии сетки вдоль оси Z (горизонтальные линии в плоскости XZ)
            Repeater3D {
                model: 41
                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d(0, 0.01, (index - 20) * 5)
                    eulerRotation.z: 90
                    scale: Qt.vector3d(0.0005, 2, 0.0005)
                    materials: PrincipledMaterial {
                        baseColor: "#666666"
                        roughness: 0.7
                        metalness: 0.0
                        opacity: 0.7
                        alphaMode: PrincipledMaterial.Blend
                    }
                    visible: showGrid
                }
            }

            // СТАНДАРТНЫЕ ОСИ КООРДИНАТ
            Node {
                id: axesNode

                // Ось X (фиолетовый) - Pitch (тангаж)
                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d(12.5, 0, 0)
                    eulerRotation.z: -90
                    scale: Qt.vector3d(0.001, 25, 0.001)
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#BB86FC" // Фиолетовый
                            roughness: 0.1
                            metalness: 0.0
                            specularAmount: 1.0
                        }
                    ]
                }

                // Стрелка для оси X (фиолетовый)
                Model {
                    source: "#Cone"
                    position: Qt.vector3d(25, 0, 0)
                    eulerRotation.z: -90
                    scale: Qt.vector3d(0.01, 0.01, 0.01)
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#BB86FC" // Фиолетовый
                            roughness: 0.1
                            metalness: 0.0
                            specularAmount: 1.0
                        }
                    ]
                    visible: showAxisArrows
                }

                // Ось Y (коралоывый) - Yaw (рыскание)
                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d(0, 12.5, 0)
                    scale: Qt.vector3d(0.001, 25, 0.001)
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#CF6679" // Коралоывый
                            roughness: 0.1
                            metalness: 0.0
                            specularAmount: 1.0
                        }
                    ]
                }

                // Стрелка для оси Y (коралоывый)
                Model {
                    source: "#Cone"
                    position: Qt.vector3d(0, 25, 0)
                    scale: Qt.vector3d(0.01, 0.01, 0.01)
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#CF6679" // Коралоывый
                            roughness: 0.1
                            metalness: 0.0
                            specularAmount: 1.0
                        }
                    ]
                    visible: showAxisArrows
                }

                // Ось Z (бирюзовый) - Roll (крен)
                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d(0, 0, 12.5)
                    eulerRotation.x: 90
                    scale: Qt.vector3d(0.001, 25, 0.001)
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#03DAC6" // Бирюзовый
                            roughness: 0.1
                            metalness: 0.0
                            specularAmount: 1.0
                        }
                    ]
                }

                // Стрелка для оси Z (бирюзовый)
                Model {
                    source: "#Cone"
                    position: Qt.vector3d(0, 0, 25)
                    eulerRotation.x: 90
                    scale: Qt.vector3d(0.01, 0.01, 0.01)
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#03DAC6" // Бирюзовый
                            roughness: 0.1
                            metalness: 0.0
                            specularAmount: 1.0
                        }
                    ]
                    visible: showAxisArrows
                }
            }

            // // Основная модель Голова обезъяны
            // Node {
            //     id: headModelNode
            //     position: Qt.vector3d(0, 0, 0)
            //     scale: Qt.vector3d(5, 5, 5)
            //     // Правильное соответствие осей и вращений:
            //     // X (фиолетовый) = Pitch (тангаж)
            //     // Y (кораловый) = Yaw (рыскание)
            //     // Z (бирюзовый) = Roll (крен)
            //     eulerRotation: Qt.vector3d(-headPitch, -headYaw, headRoll)

            //     Model {
            //         id: headModel
            //         source: currentModelPathHeadMonkey
            //         // Начальная ориентация: смотрит вперед по оси Z
            //         eulerRotation: Qt.vector3d(-90, 0, 0)
            //         materials: PrincipledMaterial {
            //             id: headMaterial
            //             baseColorMap: Texture {
            //                 source: "qrc:/models/textures/Monkey_base_color.png"
            //             }
            //             metalness: 0.0
            //             roughness: 0.3
            //             specularAmount: 0.8
            //         }
            //         visible: showHead
            //     }
            // }

            // Основная модель Голова полигональная
            Node {
                id: headModelNode
                position: Qt.vector3d(0, 4, 0)

                // Правильное соответствие осей и вращений:
                // X (фиолетовый) = Pitch (тангаж)
                // Y (кораловый) = Yaw (рыскание)
                // Z (бирюзовый) = Roll (крен)
                eulerRotation: Qt.vector3d(-headPitch, -headYaw, headRoll)

                Model {
                    id: headModel
                    source: currentModelPathHead
                    scale: Qt.vector3d(headScale, headScale, headScale)
                    // Начальная ориентация: смотрит вперед по оси Z
                    eulerRotation: Qt.vector3d(0, -90, 0)
                    materials: PrincipledMaterial {
                        id: headMaterial
                        // baseColor: "#03DAC6" // Бирюзовый цвет для ушей
                        // baseColor: "#FFE0BD"  // Очень светлый теплый бежевый
                        // baseColor: "#F5D0A9"  // Светлый бежево-персиковый
                        // baseColor: "#E8C39E"  // Светлый бежевый
                        baseColor: "#D2B48C"  // Классический "tan" (загар)
                        metalness: 0.0
                        roughness: 0.3
                        specularAmount: 0.8
                        opacity: headOpacity  // Используем свойство прозрачности
                        alphaMode: PrincipledMaterial.Blend  // Включаем режим прозрачности
                    }
                    visible: showHead
                }

                // Левое внутреннее ухо
                Node {
                    id: leftEarNode
                    position: Qt.vector3d(2, 3, 0) // Смещение относительно головы
                    scale: Qt.vector3d(earScale, earScale, earScale)
                    // eulerRotation: Qt.vector3d(-headPitch, -headYaw, headRoll)

                    Model {
                        id: leftEarModel
                        source: currentModelPathEarLeft
                        // Начальная ориентация левого уха
                        eulerRotation: Qt.vector3d(270, 0, 0) // Ориентация
                        materials: PrincipledMaterial {
                            baseColorMap: Texture {
                                source: "qrc:/models/textures/Inner_ear_texture.png"
                            }
                            metalness: 0.0
                            roughness: 0.5
                            specularAmount: 0.3
                            opacity: 1.0
                        }
                        visible: showLeftEar && showHead // Видно только если голова видна
                    }
                }

                // Правое внутреннее ухо (зеркальная копия левого)
                Node {
                    id: rightEarNode
                    position: Qt.vector3d(-2, 3, 0) // Симметричная позиция по оси X

                    // ЗЕРКАЛЬНОЕ ОТРАЖЕНИЕ по оси X:
                    scale: Qt.vector3d(-earScale, earScale, earScale) // Отрицательный scale.X = зеркало

                    // eulerRotation: Qt.vector3d(-headPitch, -headYaw, headRoll)

                    // Используем ТУ ЖЕ модель
                    Model {
                        id: rightEarModel
                        source: currentModelPathEarLeft
                        // Начальная ориентация левого уха
                        // Корректировка поворота для зеркальной модели:
                        eulerRotation: Qt.vector3d(270, 0, 0)
                        materials: PrincipledMaterial {
                            baseColorMap: Texture {
                                source: "qrc:/models/textures/Inner_ear_texture.png"
                            }
                            metalness: 0.0
                            roughness: 0.5
                            specularAmount: 0.3
                            opacity: 1.0

                            // cullMode: Material.BackFaceCulling // или NoCulling
                            cullMode: Material.NoCulling // Делает правильную видимость модели правого внутреннего уха, исправляет отображение нормалей.
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            property point lastMousePos: Qt.point(0, 0)

            onWheel: (wheel) => {
                var delta = wheel.angleDelta.y / 120
                cameraDistance = Math.max(10, Math.min(50, cameraDistance - delta * 2))
                updateCameraPosition()
            }

            onPressed: (mouse) => {
                lastMousePos = Qt.point(mouse.x, mouse.y)
            }

            onPositionChanged: (mouse) => {
                if (pressedButtons & Qt.LeftButton) {
                    var dx = mouse.x - lastMousePos.x
                    var dy = mouse.y - lastMousePos.y

                    cameraYaw -= dx * 0.5
                    cameraPitch += dy * 0.5
                    cameraPitch = Math.max(-80, Math.min(80, cameraPitch))

                    updateCameraPosition()
                    lastMousePos = Qt.point(mouse.x, mouse.y)

                    // При вращении камеры мышью устанавливаем вид в "free"
                    currentView = "free"
                    // При свободном вращении показываем сетку и стрелки
                    showGrid = true
                    showAxisArrows = true
                }
            }
        }
    }

    // Мини-компас с 3D проекцией осей в правом нижнем углу
    Rectangle {
        id: axisCompass
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }
        width: 120
        height: 120
        color: "#252b2b2b"  // Очень прозрачный фон
        radius: 8

        Canvas {
            id: compassCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                // Центр виджета
                var centerX = width / 2
                var centerY = height / 2

                // Максимальная длина стрелки (не более половины ширины виджета минус отступ)
                var maxArrowLength = 45

                // Преобразуем углы камеры из градусов в радианы
                var yawRad = advanced3DHead.cameraYaw * Math.PI / 180
                var pitchRad = advanced3DHead.cameraPitch * Math.PI / 180

                // Определяем базовые векторы осей в 3D пространстве
                var axes3D = [
                    {x: -1, y: 0, z: 0, color: "#BB86FC", label: "Y"}, // Ось X (фиолетовый)
                    {x: 0, y: 1, z: 0, color: "#CF6679", label: "Z"}, // Ось Y (коралловый)
                    {x: 0, y: 0, z: 1, color: "#03DAC6", label: "X"}  // Ось Z (бирюзовый)
                ]

                // Создаем матрицу вращения для учета углов камеры
                // Вращение по Yaw (рыскание) - вращение вокруг оси Y
                var cosYaw = Math.cos(yawRad)
                var sinYaw = Math.sin(yawRad)

                // Вращение по Pitch (тангаж) - вращение вокруг оси X
                var cosPitch = Math.cos(pitchRad)
                var sinPitch = Math.sin(pitchRad)

                // Применяем вращение к каждой оси
                for (var i = 0; i < axes3D.length; i++) {
                    var axis = axes3D[i]

                    // Применяем вращение по Yaw (вокруг Y)
                    var x1 = axis.x * cosYaw + axis.z * sinYaw
                    var z1 = -axis.x * sinYaw + axis.z * cosYaw
                    var y1 = axis.y

                    // Применяем вращение по Pitch (вокруг X)
                    var y2 = y1 * cosPitch - z1 * sinPitch
                    var z2 = y1 * sinPitch + z1 * cosPitch
                    var x2 = x1

                    // ЗЕРКАЛЬНОЕ ОТОБРАЖЕНИЕ ОТНОСИТЕЛЬНО ПЛОСКОСТИ XY
                    // Инвертируем горизонтальные компоненты осей Y и X
                    if (axis.label === "Y" || axis.label === "X") {
                        x2 = -x2  // Зеркалим горизонтальную компоненту
                    }

                    // Рассчитываем длину проекции на плоскость XY
                    var projectionLength = Math.sqrt(x2*x2 + y2*y2)

                    // Если проекция слишком короткая (меньше 0.05), не рисуем ось
                    if (projectionLength < 0.05) {
                        continue
                    }

                    // Нормализуем проекцию (приводим к единичному вектору в плоскости XY)
                    var nx = x2 / projectionLength
                    var ny = y2 / projectionLength

                    // Перспективная проекция: уменьшаем длину, если ось направлена от/к камере
                    var perspectiveFactor = 1.0 / (1.0 + Math.abs(z2) * 0.3)

                    // Длина стрелки зависит от проекции и перспективы
                    var arrowLength = projectionLength * maxArrowLength * perspectiveFactor

                    // Координаты конца стрелки
                    var endX = centerX + nx * arrowLength
                    var endY = centerY - ny * arrowLength  // Инвертируем Y для Canvas

                    // Угол стрелки для рисования наконечника
                    var angle = Math.atan2(endY - centerY, endX - centerX)

                    // 1. Рисуем стрелку (БЕЗ свечения)
                    // Убедимся, что свечение отключено
                    ctx.shadowColor = 'transparent'
                    ctx.shadowBlur = 0
                    ctx.shadowOffsetX = 0
                    ctx.shadowOffsetY = 0

                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.lineTo(endX, endY)
                    ctx.strokeStyle = axis.color
                    ctx.lineWidth = 3
                    ctx.stroke()

                    // 2. Рисуем наконечник стрелки (треугольник, БЕЗ свечения)
                    var arrowSize = 6
                    var arrowAngle = Math.PI / 6  // 30 градусов

                    ctx.beginPath()
                    ctx.moveTo(endX, endY)
                    ctx.lineTo(
                        endX - arrowSize * Math.cos(angle - arrowAngle),
                        endY - arrowSize * Math.sin(angle - arrowAngle)
                    )
                    ctx.lineTo(
                        endX - arrowSize * Math.cos(angle + arrowAngle),
                        endY - arrowSize * Math.sin(angle + arrowAngle)
                    )
                    ctx.closePath()
                    ctx.fillStyle = axis.color
                    ctx.fill()

                    // 3. Рассчитываем позицию метки (5px от конца стрелки в том же направлении)
                    var labelDistance = 5
                    var labelX = endX + labelDistance * Math.cos(angle)
                    var labelY = endY + labelDistance * Math.sin(angle)

                    // 4. Рисуем метку С эффектом свечения
                    // Включаем свечение только для текста
                    ctx.shadowColor = axis.color
                    ctx.shadowBlur = 5
                    ctx.shadowOffsetX = 0
                    ctx.shadowOffsetY = 0

                    ctx.fillStyle = axis.color
                    ctx.font = "bold 13px Arial"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText(axis.label, labelX, labelY)

                    // Сбрасываем тень для следующих элементов
                    ctx.shadowBlur = 0
                    ctx.shadowColor = 'transparent'
                }

                // Рисуем центр компаса (точка, БЕЗ свечения)
                ctx.shadowBlur = 0
                ctx.shadowColor = 'transparent'

                ctx.beginPath()
                ctx.arc(centerX, centerY, 2, 0, Math.PI * 2)
                ctx.fillStyle = "#FFFFFF"
                ctx.fill()
            }
        }

        // Таймер для обновления компаса
        Timer {
            id: compassUpdateTimer
            interval: 50  // 20 FPS - достаточно плавно
            running: true
            repeat: true
            onTriggered: {
                compassCanvas.requestPaint()
            }
        }

        // Подсказка при наведении
        ToolTip.visible: tooltipsEnabled && compassMouseArea.containsMouse
        ToolTip.text: "3D мини-компас осей\n" +
                     "Показывает проекцию системы координат на 2D плоскость\n" +
                     "X (бирюзовый) - Roll (крен)\n" +
                     "Y (Фиолетовый) - Pitch (тангаж)\n" +
                     "Z (коралловый) - Yaw (рыскание)"

        // MouseArea для подсказки
        MouseArea {
            id: compassMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                advanced3DHead.setCameraView("isometric")
            }
        }
    }

    // Эффект головокружения пациента
    Item {
        id: patientDizzinessEffect
        anchors.fill: parent
        visible: patientDizziness && !doctorDizziness
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }

        Canvas {
            id: patientDizzinessCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (!patientDizzinessEffect.visible) return;

                var centerX = width / 2;
                var centerY = height / 2;

                var minSize = Math.min(width, height);
                var maxSize = Math.max(width, height);

                var innerRadius = minSize * 0.8 / 2;
                var outerRadius = maxSize * 1.5 / 2;

                var gradient = ctx.createRadialGradient(
                    centerX, centerY, innerRadius,
                    centerX, centerY, outerRadius
                );

                gradient.addColorStop(0, "transparent");
                gradient.addColorStop(1, patientDizzinessColor);

                ctx.beginPath();
                ctx.arc(centerX, centerY, outerRadius, 0, Math.PI * 2);
                ctx.arc(centerX, centerY, innerRadius, 0, Math.PI * 2, true);
                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * textPositionRatio
            text: patientDizzinessText
            color: patientTextColor
            font.pixelSize: textFontSize
            font.bold: textBold
            opacity: parent.visible ? 1.0 : 0
        }
    }

    // Эффект головокружения врача
    Item {
        id: doctorDizzinessEffect
        anchors.fill: parent
        visible: doctorDizziness && !patientDizziness
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }

        Canvas {
            id: doctorDizzinessCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (!doctorDizzinessEffect.visible) return;

                var centerX = width / 2;
                var centerY = height / 2;

                var minSize = Math.min(width, height);
                var maxSize = Math.max(width, height);

                var innerRadius = minSize * 0.8 / 2;
                var outerRadius = maxSize * 1.5 / 2;

                var gradient = ctx.createRadialGradient(
                    centerX, centerY, innerRadius,
                    centerX, centerY, outerRadius
                );

                gradient.addColorStop(0, "transparent");
                gradient.addColorStop(1, doctorDizzinessColor);

                ctx.beginPath();
                ctx.arc(centerX, centerY, outerRadius, 0, Math.PI * 2);
                ctx.arc(centerX, centerY, innerRadius, 0, Math.PI * 2, true);
                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * textPositionRatio
            text: doctorDizzinessText
            color: doctorTextColor
            font.pixelSize: textFontSize
            font.bold: textBold
            opacity: parent.visible ? 1.0 : 0
        }
    }

    // Эффект одновременного головокружения
    Item {
        id: combinedDizzinessEffect
        anchors.fill: parent
        visible: patientDizziness && doctorDizziness
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }

        Canvas {
            id: combinedDizzinessCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (!combinedDizzinessEffect.visible) return;

                var centerX = width / 2;
                var centerY = height / 2;

                var minSize = Math.min(width, height);
                var maxSize = Math.max(width, height);

                var innerRadius = minSize * 0.8 / 2;
                var outerRadius = maxSize * 1.5 / 2;

                var gradient = ctx.createRadialGradient(
                    centerX, centerY, innerRadius,
                    centerX, centerY, outerRadius
                );

                gradient.addColorStop(0, "transparent");
                gradient.addColorStop(1, combinedDizzinessColor);

                ctx.beginPath();
                ctx.arc(centerX, centerY, outerRadius, 0, Math.PI * 2);
                ctx.arc(centerX, centerY, innerRadius, 0, Math.PI * 2, true);
                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * textPositionRatio
            text: combinedPatientText
            color: combinedTextColor
            font.pixelSize: textFontSize
            font.bold: textBold
            opacity: parent.visible ? 1.0 : 0
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * textPositionRatio
            text: combinedDoctorText
            color: combinedTextColor
            font.pixelSize: textFontSize
            font.bold: textBold
            opacity: parent.visible ? 1.0 : 0
        }
    }

    // Анимации для каждого эффекта
    SequentialAnimation {
        id: patientPulseAnimation
        running: patientDizzinessEffect.visible
        loops: Animation.Infinite

        NumberAnimation {
            target: patientDizzinessEffect
            property: "opacity"
            from: dizzinessOpacityMin
            to: dizzinessOpacityMax
            duration: dizzinessPulseDuration
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: patientDizzinessEffect
            property: "opacity"
            from: dizzinessOpacityMax
            to: dizzinessOpacityMin
            duration: dizzinessPulseDuration
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: doctorPulseAnimation
        running: doctorDizzinessEffect.visible
        loops: Animation.Infinite

        NumberAnimation {
            target: doctorDizzinessEffect
            property: "opacity"
            from: dizzinessOpacityMin
            to: dizzinessOpacityMax
            duration: dizzinessPulseDuration
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: doctorDizzinessEffect
            property: "opacity"
            from: dizzinessOpacityMax
            to: dizzinessOpacityMin
            duration: dizzinessPulseDuration
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: combinedPulseAnimation
        running: combinedDizzinessEffect.visible
        loops: Animation.Infinite

        NumberAnimation {
            target: combinedDizzinessEffect
            property: "opacity"
            from: dizzinessOpacityMin
            to: dizzinessOpacityMax
            duration: dizzinessPulseDuration
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: combinedDizzinessEffect
            property: "opacity"
            from: dizzinessOpacityMax
            to: dizzinessOpacityMin
            duration: dizzinessPulseDuration
            easing.type: Easing.InOutQuad
        }
    }

    // Отображение текущих углов в нижней части 3D сцены
    Rectangle {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 10
        }
        width: angleText.contentWidth + 20
        height: angleText.contentHeight + 10
        color: "#80000000"
        radius: 4
        border.color: "#444"
        opacity: hasData ? 0.9 : 0.6

        Text {
            id: angleText
            anchors.centerIn: parent
            text: hasData ?
                  // "Фронт: " + headPitch.toFixed(1) + "° | " +
                  // "Сагит: " + headRoll.toFixed(1) + "° | " +
                  // "Ротац: " + headYaw.toFixed(1) + "°" :
                  // "нет данных"
                "Pitch: " + headPitch.toFixed(1) + "° | " +
                "Roll: " + headRoll.toFixed(1) + "° | " +
                "Yaw: " + headYaw.toFixed(1) + "°" :
                "нет данных"
            color: hasData ? "white" : "#888"
            font.pixelSize: 14
            font.bold: hasData
        }
    }

    // Функция для управления эффектами
    function setDizzinessEffects(patientActive, doctorActive) {
        patientDizziness = patientActive
        doctorDizziness = doctorActive

        if (patientActive && !doctorActive) {
            patientDizzinessEffect.opacity = 0.7
            patientDizzinessCanvas.requestPaint()
            patientPulseAnimation.start()
        } else if (doctorActive && !patientActive) {
            doctorDizzinessEffect.opacity = 0.7
            doctorDizzinessCanvas.requestPaint()
            doctorPulseAnimation.start()
        } else if (patientActive && doctorActive) {
            combinedDizzinessEffect.opacity = 0.7
            combinedDizzinessCanvas.requestPaint()
            combinedPulseAnimation.start()
        } else {
            patientDizzinessEffect.opacity = 0
            doctorDizzinessEffect.opacity = 0
            combinedDizzinessEffect.opacity = 0
            patientPulseAnimation.stop()
            doctorPulseAnimation.stop()
            combinedPulseAnimation.stop()
        }
    }

    // Обработчики изменения размера для перерисовки
    onWidthChanged: {
        if (patientDizzinessEffect.visible) patientDizzinessCanvas.requestPaint()
        if (doctorDizzinessEffect.visible) doctorDizzinessCanvas.requestPaint()
        if (combinedDizzinessEffect.visible) combinedDizzinessCanvas.requestPaint()
    }

    onHeightChanged: {
        if (patientDizzinessEffect.visible) patientDizzinessCanvas.requestPaint()
        if (doctorDizzinessEffect.visible) doctorDizzinessCanvas.requestPaint()
        if (combinedDizzinessEffect.visible) combinedDizzinessCanvas.requestPaint()
    }

    function updateCameraPosition() {
        var radYaw = cameraYaw * Math.PI / 180
        var radPitch = cameraPitch * Math.PI / 180

        var x = cameraDistance * Math.cos(radPitch) * Math.sin(radYaw)
        var y = cameraDistance * Math.sin(radPitch)
        var z = cameraDistance * Math.cos(radPitch) * Math.cos(radYaw)

        camera.position = Qt.vector3d(x, y, z)
        camera.lookAt(Qt.vector3d(0, 0, 0))
    }

    // Обновленная функция setCameraView с управлением видимостью сетки и стрелок
    function setCameraView(viewType) {
        switch(viewType) {
            case "front":
                cameraYaw = 0;
                cameraPitch = 0;
                currentView = "front";
                showGrid = false;
                showAxisArrows = false;
                break;
            case "back":
                cameraYaw = 180;
                cameraPitch = 0;
                currentView = "back";
                showGrid = false;
                showAxisArrows = false;
                break;
            case "left":
                cameraYaw = -90;
                cameraPitch = 0;
                currentView = "left";
                showGrid = false;
                showAxisArrows = false;
                break;
            case "right":
                cameraYaw = 90;
                cameraPitch = 0;
                currentView = "right";
                showGrid = false;
                showAxisArrows = false;
                break;
            case "top":
                cameraYaw = 0;
                cameraPitch = 90;
                currentView = "top";
                showGrid = true;
                showAxisArrows = false;
                break;
            case "bottom":
                cameraYaw = 0;
                cameraPitch = -90;
                currentView = "bottom";
                showGrid = true;
                showAxisArrows = true;
                break;
            case "isometric":
                cameraYaw = 45;
                cameraPitch = 30;
                currentView = "free";
                showGrid = true;
                showAxisArrows = true;
                break;
        }
        updateCameraPosition();
    }

    // Функции переключения видов
    function toggleFrontBack() {
        if (currentView === "front") {
            setCameraView("back");
        } else {
            setCameraView("front");
        }
    }

    function toggleLeftRight() {
        if (currentView === "left") {
            setCameraView("right");
        } else {
            setCameraView("left");
        }
    }

    function toggleTopBottom() {
        if (currentView === "top") {
            setCameraView("bottom");
        } else {
            setCameraView("top");
        }
    }

    Component.onCompleted: {
        updateCameraPosition()
    }
}
