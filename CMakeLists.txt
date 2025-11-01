cmake_minimum_required(VERSION 3.16)

project(MonitorHead VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    SerialPort
    Quick3D
)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appMonitorHead
    main.cpp
    headmodel.cpp
    tiltcontroller.cpp
)

# Ресурсы изображений
qt_add_resources(appMonitorHead "images"
    PREFIX "/"
    FILES
        images/front_view.png
        images/back_view.png
        images/left_view.png
        images/right_view.png
        images/top_view.png
)

# Ресурсы 3D моделей - только существующие файлы
qt_add_resources(appMonitorHead "models"
    PREFIX "/"
    FILES
        models/suzanne_mesh.mesh
)

# QML модуль
qt_add_qml_module(appMonitorHead
    URI MonitorHead
    VERSION 1.0
    SOURCES
        headmodel.cpp
        headmodel.h
        tiltcontroller.cpp
        tiltcontroller.h
    QML_FILES
        Main.qml
        GraphCanvas.qml
        Advanced3DHead.qml
)

target_link_libraries(appMonitorHead
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::SerialPort
    Qt6::Quick3D
)

set_target_properties(appMonitorHead PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS appMonitorHead
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Копируем models директорию для внешних моделей и текстур
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/models")
    add_custom_command(TARGET appMonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/models"
        "$<TARGET_FILE_DIR:appMonitorHead>/models"
        COMMENT "Copying models directory to build directory"
    )
endif()



















# cmake_minimum_required(VERSION 3.16)

# project(MonitorHead VERSION 0.1 LANGUAGES CXX)

# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# # Находим только основные модули Qt6
# find_package(Qt6 REQUIRED COMPONENTS
#     Core
#     Gui
#     Qml
#     Quick
#     SerialPort
#     Quick3D
# )

# qt_standard_project_setup(REQUIRES 6.8)

# qt_add_executable(appMonitorHead
#     main.cpp
#     headmodel.cpp
#     tiltcontroller.cpp
# )

# # Ресурсы изображений
# qt_add_resources(appMonitorHead "images"
#     PREFIX "/"
#     FILES
#         images/front_view.png
#         images/back_view.png
#         images/left_view.png
#         images/right_view.png
#         images/top_view.png
# )

# # Ресурсы 3D моделей
# qt_add_resources(appMonitorHead "models"
#     PREFIX "/"
#     FILES
#         models/suzanne_mesh.mesh
#         models/suzanne_mesh.mesh
#         models/suzanne_mesh.mesh
# )

# # QML модуль
# qt_add_qml_module(appMonitorHead
#     URI MonitorHead
#     VERSION 1.0
#     SOURCES
#         headmodel.cpp
#         headmodel.h
#         tiltcontroller.cpp
#         tiltcontroller.h
#     QML_FILES
#         Main.qml
#         GraphCanvas.qml
#         Advanced3DHead.qml
# )

# target_link_libraries(appMonitorHead
#     PRIVATE
#     Qt6::Core
#     Qt6::Gui
#     Qt6::Qml
#     Qt6::Quick
#     Qt6::SerialPort
#     Qt6::Quick3D
# )

# set_target_properties(appMonitorHead PROPERTIES
#     MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
#     MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
#     MACOSX_BUNDLE TRUE
#     WIN32_EXECUTABLE TRUE
# )

# include(GNUInstallDirs)
# install(TARGETS appMonitorHead
#     BUNDLE DESTINATION .
#     LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
#     RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
# )

# # Копируем models директорию для внешних моделей
# if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/models")
#     add_custom_command(TARGET appMonitorHead POST_BUILD
#         COMMAND ${CMAKE_COMMAND} -E copy_directory
#         "${CMAKE_CURRENT_SOURCE_DIR}/models"
#         "$<TARGET_FILE_DIR:appMonitorHead>/models"
#         COMMENT "Copying models directory to build directory"
#     )
# endif()

















# cmake_minimum_required(VERSION 3.16)
# project(MonitorHead VERSION 0.1 LANGUAGES CXX)

# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# find_package(Qt6 REQUIRED COMPONENTS
#     Quick
#     SerialPort
#     Quick3D
# )

# qt_standard_project_setup(REQUIRES 6.8)

# qt_add_executable(appMonitorHead
#     main.cpp
#     headmodel.cpp
#     tiltcontroller.cpp
# )

# # Ресурсы изображений
# qt_add_resources(appMonitorHead "images"
#     PREFIX "/"
#     FILES
#         images/front_view.png
#         images/back_view.png
#         images/left_view.png
#         images/right_view.png
#         images/top_view.png
# )

# # Ресурсы 3D моделей
# qt_add_resources(appMonitorHead "models"
#     PREFIX "/"
#     FILES
#         models/head_model.obj
#         models/inner_ear.obj
#         models/teddy.obj
#         models/cube.obj
#         models/Pyramid.obj
#         models/simple_cube.obj
# )

# # QML модуль
# qt_add_qml_module(appMonitorHead
#     URI MonitorHead
#     VERSION 1.0
#     SOURCES
#         headmodel.cpp
#         headmodel.h
#         tiltcontroller.cpp
#         tiltcontroller.h
#     QML_FILES
#         Main.qml
#         GraphCanvas.qml
#         Advanced3DHead.qml
# )



















# cmake_minimum_required(VERSION 3.16)

# project(MonitorHead VERSION 0.1 LANGUAGES CXX)

# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# find_package(Qt6 REQUIRED COMPONENTS
#     Quick
#     SerialPort
#     Quick3D
# )

# qt_standard_project_setup(REQUIRES 6.8)

# qt_add_executable(appMonitorHead
#     main.cpp
# )

# # Добавляем ресурсы с правильными префиксами
# qt_add_resources(appMonitorHead "images"
#     PREFIX "/"
#     FILES
#         images/front_view.png
#         images/back_view.png
#         images/left_view.png
#         images/right_view.png
#         images/top_view.png
# )

# qt_add_resources(appMonitorHead "models"
#     PREFIX "/"
#     FILES
#         models/teddy.obj
#         models/cube.obj
#         models/head_model.obj
#         models/inner_ear.obj
#         models/inner_ear.mtl
#         models/Pyramid.obj
#         models/simple_cube.obj
#         models/test_cube.gltf
#         models/100+_half.stl
# )

# # Создаем QML модуль (БЕЗ ресурсов здесь)
# qt_add_qml_module(appMonitorHead
#     URI MonitorHead
#     VERSION 1.0
#     SOURCES
#         headmodel.cpp
#         headmodel.h
#         tiltcontroller.cpp
#         tiltcontroller.h
#     QML_FILES
#         Main.qml
#         GraphCanvas.qml
#         Head3DCanvas.qml
#         # Test3DModel.qml
#         # Test3DWindow.qml
#         Simple3DHead.qml
#         # ModelTest.qml
# )

# set_target_properties(appMonitorHead PROPERTIES
#     MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
#     MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
#     MACOSX_BUNDLE TRUE
#     WIN32_EXECUTABLE TRUE
# )

# target_link_libraries(appMonitorHead
#     PRIVATE
#     Qt6::Quick
#     Qt6::SerialPort
#     Qt6::Quick3D
# )

# include(GNUInstallDirs)
# install(TARGETS appMonitorHead
#     BUNDLE DESTINATION .
#     LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
#     RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
# )
