project ("cmdd" VERSION "1.0.0")

find_package (sdbus-c++ REQUIRED)

set (HEADER_FILES "")
set (SOURCE_FILES  "src/cmdd.cpp")
set (SOURCES "${HEADER_FILES}" "${SOURCE_FILES}")

set (LIBS "SDBusCpp::sdbus-c++")

add_application ("${PROJECT_NAME}" "${SOURCES}" "" "${LIBS}")

add_config ("../configs/cmdd.service.in" "${PROJECT_NAME}.service" "lib/systemd/system")
add_config ("../configs/handler.sh.in" "handler.sh" "share/${PROJECT_NAME}")
add_config ("config.hpp.in" "config.hpp")

install(DIRECTORY "${CMAKE_SOURCE_DIR}/configs/conf.d/"
    DESTINATION "../etc/${PROJECT_NAME}.conf.d/" USE_SOURCE_PERMISSIONS)
