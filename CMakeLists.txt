cmake_minimum_required(VERSION 3.16)

project(ChatHub VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network)

qt_standard_project_setup(REQUIRES 6.10)

if(WIN32)
    enable_language(RC)
    set(APP_ICON_RESOURCE_WINDOWS resources/app_icon.rc)
endif()

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(ChatHub
    main.cpp
    ${APP_ICON_RESOURCE_WINDOWS}
    src/controller/ChatController.h
    src/controller/ChatController.cpp
    src/network/NetworkClient.h
    src/network/NetworkClient.cpp
    src/protocol/ProtocolAdapter.h
    src/protocol/ProtocolAdapter.cpp
)

qt_add_resources(ChatHub "app_icons"
    PREFIX "/icons"
    BASE "resources"
    FILES
        resources/my_icon_light.ico
        resources/my_icon_light_ui.png
)

qt_add_qml_module(ChatHub
    URI ChatHub
    NO_CACHEGEN
    QML_FILES
        Main.qml
        qml/components/AppButton.qml
        qml/components/AppLogo.qml
        qml/components/Field.qml
        qml/components/ReadonlyLogText.qml
        qml/components/SectionTitle.qml
        qml/components/StyledCheckBox.qml
        qml/components/StyledComboBox.qml
        qml/components/StyledTabButton.qml
        qml/components/ThemeSwitch.qml
        qml/panels/ChannelsPanel.qml
        qml/panels/ChatPanel.qml
        qml/panels/TopBar.qml
        qml/panels/WorkspacePanel.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(ChatHub PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.ChatHub
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(ChatHub
    PRIVATE Qt6::Quick Qt6::Network
)

install(TARGETS ChatHub
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

enable_testing()

qt_add_executable(protocol_tests
    tests/protocol_tests.cpp
    src/protocol/ProtocolAdapter.h
    src/protocol/ProtocolAdapter.cpp
)

target_link_libraries(protocol_tests
    PRIVATE Qt6::Core
)

add_test(NAME protocol_tests COMMAND protocol_tests)
get_filename_component(MINGW_RUNTIME_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
set_tests_properties(protocol_tests PROPERTIES
    ENVIRONMENT "PATH=${CMAKE_PREFIX_PATH}/bin;${MINGW_RUNTIME_DIR};$ENV{PATH}"
)

qt_add_executable(network_client_tests
    tests/network_client_tests.cpp
    src/network/NetworkClient.h
    src/network/NetworkClient.cpp
    src/protocol/ProtocolAdapter.h
    src/protocol/ProtocolAdapter.cpp
)

target_link_libraries(network_client_tests
    PRIVATE Qt6::Core Qt6::Network
)

add_test(NAME network_client_tests COMMAND network_client_tests)
set_tests_properties(network_client_tests PROPERTIES
    ENVIRONMENT "PATH=${CMAKE_PREFIX_PATH}/bin;${MINGW_RUNTIME_DIR};$ENV{PATH}"
)

qt_add_executable(controller_tests
    tests/controller_tests.cpp
    src/controller/ChatController.h
    src/controller/ChatController.cpp
    src/network/NetworkClient.h
    src/network/NetworkClient.cpp
    src/protocol/ProtocolAdapter.h
    src/protocol/ProtocolAdapter.cpp
)

target_link_libraries(controller_tests
    PRIVATE Qt6::Core Qt6::Network
)

add_test(NAME controller_tests COMMAND controller_tests)
set_tests_properties(controller_tests PROPERTIES
    ENVIRONMENT "PATH=${CMAKE_PREFIX_PATH}/bin;${MINGW_RUNTIME_DIR};$ENV{PATH}"
)
