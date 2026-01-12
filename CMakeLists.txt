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
    Network
)

qt_standard_project_setup(REQUIRES 6.8)

# ИЗМЕНЕНО: переименовано с appMonitorHead на MonitorHead
qt_add_executable(MonitorHead
    main.cpp
    headmodel.cpp
    tiltcontroller.cpp
)

# ПРОСТОЙ МЕТОД: Добавляем иконку для Windows
if(WIN32)
    set(APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/images/logo.ico")
    if(EXISTS "${APP_ICON}")
        # Используем RC_ICONS для установки иконки
        set_target_properties(MonitorHead PROPERTIES
            WIN32_EXECUTABLE TRUE
            RC_ICONS "${APP_ICON}"
        )
        message(STATUS "Иконка добавлена: ${APP_ICON}")
    else()
        message(WARNING "Иконка не найдена: ${APP_ICON}")
    endif()
endif()

# Остальной код остается без изменений...

# Создаем папку research если не существует
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/research")
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/research")
endif()

# Создаем папку info если не существует
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/info")
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/info")
endif()

# Ресурсы изображений
qt_add_resources(MonitorHead "images"
    PREFIX "/"
    FILES
        images/front_view.png
        images/back_view.png
        images/left_view.png
        images/right_view.png
        images/top_view.png
)

qt_add_resources(MonitorHead "models_and_textures"
    PREFIX "/"
    FILES
        # Модели
        models/suzanne_mesh.mesh
        models/Inner_ear.mesh
        # Текстуры
        models/textures/Monkey_base_color.png
        models/textures/Inner_ear_texture.png
)

# QML модуль
qt_add_qml_module(MonitorHead
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
        AxisPanel.qml
        Formatters.js
)

target_link_libraries(MonitorHead
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::SerialPort
    Qt6::Quick3D
    Qt6::Network
)

set_target_properties(MonitorHead PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    # Устанавливаем имя выходного файла в Windows
    OUTPUT_NAME "MonitorHead"
    # Для версий релиза/дебага можно указать отдельно
    RUNTIME_OUTPUT_NAME_RELEASE "MonitorHead"
    RUNTIME_OUTPUT_NAME_DEBUG "MonitorHead_debug"
)

include(GNUInstallDirs)
install(TARGETS MonitorHead
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Копируем images директорию с иконкой
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/images")
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/images"
        "$<TARGET_FILE_DIR:MonitorHead>/images"
        COMMENT "Copying images directory to build directory"
    )
endif()

# Копируем models директорию для внешних моделей и текстур
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/models")
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/models"
        "$<TARGET_FILE_DIR:MonitorHead>/models"
        COMMENT "Copying models directory to build directory"
    )
endif()

# Копируем research директорию
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/research")
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/research"
        "$<TARGET_FILE_DIR:MonitorHead>/research"
        COMMENT "Copying research directory to build directory"
    )
endif()

# Копируем info директорию с HTML-файлом справки
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/info")
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/info"
        "$<TARGET_FILE_DIR:MonitorHead>/info"
        COMMENT "Copying info directory to build directory"
    )
endif()

# Копируем licenses директорию
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/licenses")
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/licenses"
        "$<TARGET_FILE_DIR:MonitorHead>/licenses"
        COMMENT "Copying info directory to build directory"
    )
endif()

# Копируем README.txt в корень билд директории
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/README.txt")
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        "${CMAKE_CURRENT_SOURCE_DIR}/README.txt"
        "$<TARGET_FILE_DIR:MonitorHead>/README.txt"
        COMMENT "Copying README.txt to build directory"
    )
endif()

# Создаем research директорию в билд директории на случай если ее нет
add_custom_command(TARGET MonitorHead POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:MonitorHead>/research"
    COMMENT "Creating research directory in build directory"
)

# Создаем info директорию в билд директории на случай если ее нет
add_custom_command(TARGET MonitorHead POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:MonitorHead>/info"
    COMMENT "Creating info directory in build directory"
)

# Для QML приложений: добавляем цель развертывания (deploy)
if(WIN32)
    add_custom_command(TARGET MonitorHead POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "Для развертывания выполните:"
        COMMAND ${CMAKE_COMMAND} -E echo "windeployqt --release $<TARGET_FILE:MonitorHead>"
        COMMENT "Deployment instructions for Windows"
    )
endif()
