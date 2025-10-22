cmake_minimum_required(VERSION 3.16)

project(MonitorHead VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick SerialPort)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appMonitorHead
    main.cpp
)

# Создаем QML модуль
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
)

set_target_properties(appMonitorHead PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appMonitorHead
    PRIVATE Qt6::Quick Qt6::SerialPort
)

include(GNUInstallDirs)
install(TARGETS appMonitorHead
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
