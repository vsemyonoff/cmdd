############ Cmake version

cmake_minimum_required (VERSION 3.5 FATAL_ERROR)

############ Global variables

# Name, description, URL
set (PROJECT_NAME "")
set (DESCRIPTION  "No project description")
set (HOMEPAGE     "http://www.example.com")

# Version
set (VERSION_MAJOR 0)
set (VERSION_MINOR 0)
set (VERSION_PATCH 1)

# C++ standard version
set (REQUIRED_CXX_STANDARD 11)

# Boost and components
set (REQUIRED_BOOST_VERSION "")
set (REQUIRED_BOOST_LIBS    "")
# set more Boost options here...

# 3rd party libs, sources, examples and tests folders
set (SOURCES_DIR  "sources")
set (EXTLIBS_DIR  "extlibs")
set (EXAMPLES_DIR "examples")
set (TESTS_DIR    "tests")

############ Project settings

# Load config
if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/config.cmake")
    message (FATAL_ERROR "Error: 'config.cmake' not found")
endif ()
include ("${CMAKE_CURRENT_SOURCE_DIR}/config.cmake")

############ Project setup

# Declare project
if (NOT PROJECT_NAME)
    message (FATAL_ERROR "Error: project name not set, please edit 'config.cmake'.")
endif ()

project ("${PROJECT_NAME}"
    VERSION      "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
    DESCRIPTION  "${DESCRIPTION}"
    HOMEPAGE_URL "${HOMEPAGE}"
    LANGUAGES    C CXX)

############ Declare package

set (PACKAGE_NAME "${PROJECT_NAME}")

############ C++ standard version setup

set (CMAKE_CXX_STANDARD          ${REQUIRED_CXX_STANDARD})
set (CMAKE_CXX_STANDARD_REQUIRED ON                      )
set (CMAKE_CXX_EXTENSIONS        OFF                     )

############ Custom Cmake modules

# Cmake custom modules
list (APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/.cmake")
include ("CustomUtils")

############ Misc

set (default_build_type "Release")

if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message (STATUS "Setting build type to '${default_build_type}' as none was specified")
    set (CMAKE_BUILD_TYPE "${default_build_type}" CACHE
        STRING "Choose the type of build." FORCE)
    set_property (CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
        "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif ()

## Allow per-target folders (for IDEs)
#set_property (GLOBAL PROPERTY USE_FOLDERS     ON)

# Add source/build folders to headers search path
set (CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE ON)
set (CMAKE_INCLUDE_CURRENT_DIR_IN_INTERFACE   ON)
set (CMAKE_INCLUDE_CURRENT_DIR                ON)

############ Custom options

option (DISABLE_SHARED   "Disable shared libraries building. Default: OFF"         OFF)
option (DISABLE_STATIC   "Disable static libraries building. Default: OFF"         OFF)
option (STATIC_LINKAGE   "Link executables with static libraries. Default: OFF"    OFF)
option (BUILD_EXAMPLES   "Build '${PACKAGE_NAME}' examples. Default: OFF"          OFF)

if (BUILD_EXAMPLES)
    option (INSTALL_EXAMPLES "Install '${PACKAGE_NAME}' examples. Default: OFF"    OFF)
endif ()

if (BUILD_TESTING)
    option (AUTORUN_TESTS "Run all tests after project build. Default: ON"         ON )
    option (ENABLE_FAKEIT "Setup 'FakeIt' mocking library for Boost. Default: OFF" OFF)
endif ()

# Use somelib::${LIB_TYPE} to link targets
set (LIB_TYPE "")
if (STATIC_LINKAGE AND NOT DISABLE_STATIC)
    set (LIB_TYPE "static")
elseif (NOT STATIC_LINKAGE AND NOT DISABLE_SHARED)
    set (LIB_TYPE "shared")
endif ()

############ Git and submodules

if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
    find_package (Git QUIET)
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.gitmodules")
        if (NOT GIT_FOUND)
            message(FATAL_ERROR "Error: 'git' not installed, can't update submodules")
        endif ()

        # Update submodules as needed
        message (STATUS "Updating Git submodules...")
        execute_process (COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE GIT_CLONE_RESULT)
        if (NOT GIT_CLONE_RESULT EQUAL "0")
            message(FATAL_ERROR "Error: submodules update failed with code: ${GIT_CLONE_RESULT}")
        endif ()
        unset (GIT_CLONE_RESULT)

    endif ()
endif ()

############ Testing
if (BUILD_TESTING)
    list (APPEND REQUIRED_BOOST_LIBS "unit_test_framework")

    if (ENABLE_FAKEIT)
        if (NOT GIT_FOUND)
            find_package (Git REQUIRED)
        endif ()

        # Clone
        if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${EXTLIBS_DIR}/fakeit/CMakeLists.txt")
            message (STATUS "Cloning 'FakeIt' mocking library for the Boost test...")
            set (FAKEIT_URL "git://github.com/eranpeer/FakeIt")
            execute_process (COMMAND ${GIT_EXECUTABLE} clone --depth=1 "${FAKEIT_URL}" "${EXTLIBS_DIR}/fakeit"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                RESULT_VARIABLE GIT_CLONE_RESULT)
            if (NOT GIT_CLONE_RESULT EQUAL "0")
                message (FATAL_ERROR "Error: 'FakeIt' library cloning failed with code: ${GIT_CLONE_RESULT}")
            endif ()
            unset (GIT_CLONE_RESULT)
        endif ()

        # Declare imported library
        add_library (FakeIt INTERFACE IMPORTED)
        set_target_properties (FakeIt PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/${EXTLIBS_DIR}/fakeit/single_header/boost")
    endif ()
endif ()

############ Boost and external libraries

if (BUILD_TESTING OR REQUIRED_BOOST_VERSION)
    if (STATIC_LINKAGE AND NOT DISABLE_STATIC)
        set (Boost_USE_STATIC_LIBS    ON )
    else ()
        set (Boost_USE_STATIC_LIBS    OFF)
    endif ()

    if (NOT REQUIRED_BOOST_VERSION)
        set (REQUIRED_BOOST_VERSION 1.58)
    endif ()

    if (REQUIRED_BOOST_LIBS)
        list (REMOVE_DUPLICATES REQUIRED_BOOST_LIBS)
        find_package (Boost ${REQUIRED_BOOST_VERSION} COMPONENTS ${REQUIRED_BOOST_LIBS} REQUIRED)
    else ()
        find_package (Boost ${REQUIRED_BOOST_VERSION} REQUIRED)
    endif ()
endif ()

add_dir_or_subdirs (${EXTLIBS_DIR})

############ Register targets

# Projects
add_dir_or_subdirs ("${SOURCES_DIR}")

# Examples
if (BUILD_EXAMPLES)
    add_dir_or_subdirs ("${EXAMPLES_DIR}")
endif ()

# Tests
if (BUILD_TESTING)
    add_dir_or_subdirs ("${TESTS_DIR}")
    if (AUTORUN_TESTS)
        get_property (TARGETS_LIST GLOBAL PROPERTY TARGETS_LIST)
        add_custom_target ("AutoRunTests" ALL
            DEPENDS ${TARGETS_LIST}
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
            COMMAND +make test)
    endif ()
endif()

############ End
