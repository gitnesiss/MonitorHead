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
    property string currentModelPath: "qrc:/models/suzanne_mesh.mesh"

    property bool dizziness: false

    // Свойства для управления камерой
    property real cameraDistance: 50
    property real cameraYaw: 45
    property real cameraPitch: 30

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

            DirectionalLight {
                id: mainLight
                eulerRotation.x: -30
                eulerRotation.y: 45
                brightness: 2.0
                ambientColor: Qt.rgba(0.3, 0.3, 0.3, 1.0)
            }

            DirectionalLight {
                eulerRotation.x: -10
                eulerRotation.y: -60
                brightness: 0.8
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
                }
            }

            // Основная модель головы
            Node {
                id: headModelNode
                position: Qt.vector3d(0, 0, 0)
                scale: Qt.vector3d(5, 5, 5)
                // Правильное соответствие осей и вращений:
                // X (фиолетовый) = Pitch (тангаж)
                // Y (кораловый) = Yaw (рыскание)
                // Z (бирюзовый) = Roll (крен)
                eulerRotation: Qt.vector3d(-headPitch, -headYaw, headRoll)

                Model {
                    id: headModel
                    source: currentModelPath
                    // Начальная ориентация: смотрит вперед по оси Z
                    eulerRotation: Qt.vector3d(-90, 0, 0)
                    materials: PrincipledMaterial {
                        id: headMaterial
                        baseColorMap: Texture {
                            source: "file:///C:/Users/pomai/programming/code/projects/qt_qml/MonitorHead/models/textures/Monkey_base_color.png"
                        }
                        metalness: 0.0
                        roughness: 0.3
                        specularAmount: 0.8
                    }
                }
            }
        }

        // Управление камерой мышью
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
                }
            }
        }
    }

    // Эффект головокружения - одно кольцо с градиентом
    Item {
        id: dizzinessEffect
        anchors.fill: parent
        visible: false
        opacity: 0

        // Анимация появления
        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }

        // Канвас для рисования кольца
        Canvas {
            id: dizzinessCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (!dizzinessEffect.visible) return;

                var centerX = width / 2;
                var centerY = height / 2;

                // Минимальный размер сцены
                var minSize = Math.min(width, height);

                // Максимальный размер сцены
                var maxSize = Math.max(width, height);

                // Радиусы для кольца (с градиентом)
                var innerRadius = minSize * 0.8 / 2;  // Начало градиента
                var outerRadius = maxSize * 1.5 / 2;  // Конец градиента

                // Создаем градиент
                var gradient = ctx.createRadialGradient(
                    centerX, centerY, innerRadius,
                    centerX, centerY, outerRadius
                );

                // Градиент: от прозрачного (внутри) к непрозрачному (снаружи)
                gradient.addColorStop(0, "transparent");
                gradient.addColorStop(1, "#40FFA000");

                // Рисуем кольцо
                ctx.beginPath();
                ctx.arc(centerX, centerY, outerRadius, 0, Math.PI * 2); // Внешний круг
                ctx.arc(centerX, centerY, innerRadius, 0, Math.PI * 2, true); // Вырезаем внутреннюю часть
                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }

        // // Текст "ГОЛОВОКРУЖЕНИЕ" в центре
        // Text {
        //     id: dizzinessText
        //     anchors.centerIn: parent
        //     text: "ГОЛОВОКРУЖЕНИЕ"
        //     color: "#66FFA000"
        //     font.pixelSize: 24
        //     font.bold: true
        //     opacity: parent.visible ? 1.0 : 0
        // }

        // Текст "ГОЛОВОКРУЖЕНИЕ" в верхней трети экрана
        Text {
            id: dizzinessText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height / 3
            text: "ГОЛОВОКРУЖЕНИЕ"
            color: "#40FFA000"
            font.pixelSize: 24
            font.bold: true
            opacity: parent.visible ? 1.0 : 0
        }
    }

    // Анимация пульсации
    SequentialAnimation {
        id: pulseAnimation
        running: dizzinessEffect.visible
        loops: Animation.Infinite

        NumberAnimation {
            target: dizzinessEffect
            property: "opacity"
            from: 0.6
            to: 0.9
            duration: 1000
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: dizzinessEffect
            property: "opacity"
            from: 0.9
            to: 0.6
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }

    // Функция для управления эффектом
    function setDizzinessEffect(active) {
        dizzinessEffect.visible = active
        if (active) {
            dizzinessEffect.opacity = 0.7
            dizzinessCanvas.requestPaint()
            pulseAnimation.start()
        } else {
            dizzinessEffect.opacity = 0
            pulseAnimation.stop()
        }
    }

    // Обработчики изменения размера для перерисовки
    onWidthChanged: {
        if (dizzinessEffect.visible) {
            dizzinessCanvas.requestPaint()
        }
    }

    onHeightChanged: {
        if (dizzinessEffect.visible) {
            dizzinessCanvas.requestPaint()
        }
    }

    // Обработчик изменения свойства dizziness
    onDizzinessChanged: {
        setDizzinessEffect(dizziness)
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

    function setCameraView(viewType) {
        switch(viewType) {
            case "isometric":
                cameraYaw = 45
                cameraPitch = 30
                cameraDistance = 50
                break
            case "front":
                cameraYaw = 0
                cameraPitch = 0
                cameraDistance = 50
                break
            case "back":
                cameraYaw = 180
                cameraPitch = 0
                cameraDistance = 50
                break
            case "left":
                cameraYaw = -90
                cameraPitch = 0
                cameraDistance = 50
                break
            case "right":
                cameraYaw = 90
                cameraPitch = 0
                cameraDistance = 50
                break
            case "top":
                cameraYaw = 0
                cameraPitch = 90
                cameraDistance = 50
                break
        }
        updateCameraPosition()
    }

    Component.onCompleted: {
        updateCameraPosition()
    }
}
