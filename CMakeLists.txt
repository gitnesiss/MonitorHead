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

# Создаем папку research если не существует
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/research")
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/research")
endif()

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
        log_reader.h
        log_reader.cpp
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

# Копируем research директорию
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/research")
    add_custom_command(TARGET appMonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/research"
        "$<TARGET_FILE_DIR:appMonitorHead>/research"
        COMMENT "Copying research directory to build directory"
    )
endif()

# Создаем research директорию в билд директории на случай если ее нет
add_custom_command(TARGET appMonitorHead POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:appMonitorHead>/research"
    COMMENT "Creating research directory in build directory"
)
