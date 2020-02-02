############ Utilities

include (GNUInstallDirs)

set (BUILD_TESTING OFF CACHE BOOL "Build the testing tree.")
include (CTest)

# Add target configuration ini file:
#   infile  - input file name
#   outfile - output file name
#   ARGV2   - deploy path (optional)
function (add_config infile outfile)
    configure_file ("${infile}" "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}/${PROJECT_NAME}/${outfile}" @ONLY)
    if (ARGV2)
        install (FILES "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}/${PROJECT_NAME}/${outfile}"
            DESTINATION "${ARGV2}")
    endif ()
endfunction ()

# Add 'parent' as subproject if CMakeLists.txt present there or
# add all subprojects from 'parent'
function (add_dir_or_subdirs parent)
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${parent}/CMakeLists.txt")
        add_subdirectory ("${parent}")
    else ()
        file (GLOB SDIRS RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${parent}/*")
        foreach (SUBDIR ${SDIRS})
            if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${SUBDIR}/CMakeLists.txt")
                add_subdirectory ("${CMAKE_CURRENT_SOURCE_DIR}/${SUBDIR}")
            endif ()
        endforeach ()
    endif ()
endfunction()

# Add custom library target:
#   name         - library name
#   sources_list - source files list
#   ARGV2        - public headers dir (optional)
#   ARGV3        - extra libraries list to link with (optional)
#   ARGV4        - private headers dir (optional)
function (add_custom_library name sources_list)
    # Objects library to reduce compile time
    add_library ("${name}" OBJECT ${sources_list})
    set_target_properties ("${name}" PROPERTIES POSITION_INDEPENDENT_CODE ON)

    source_group("Header Files\\Private" REGULAR_EXPRESSION ".*/[Pp]rivate/.*\\.h(pp|xx)?$")
    source_group("Source Files\\Private" REGULAR_EXPRESSION ".*/[Pp]rivate/.*\\.c(pp|xx)?$")

    get_property (targets_list GLOBAL PROPERTY TARGETS_LIST)
    list (APPEND targets_list "${name}")

    set (public_headers_dir "${CMAKE_CURRENT_SOURCE_DIR}")
    if (ARGV2)
        set (public_headers_dir "${public_headers_dir}/${ARGV2}")
    endif ()
    target_include_directories ("${name}" PUBLIC "${public_headers_dir}" PRIVATE "${ARGV4}")

    target_link_libraries ("${name}" ${ARGV3})

    string (TOLOWER "${name}" name_lowercase)
    set (export_config "${CMAKE_PROJECT_NAME}Config")

    # Static variant
    if (NOT DISABLE_STATIC)
        add_library ("${name}_static" STATIC "$<TARGET_OBJECTS:${name}>")
        list (APPEND targets_list "${name}_static")

        set_target_properties ("${name}_static" PROPERTIES
            EXPORT_NAME "${name_lowercase}::static"
            OUTPUT_NAME "${name_lowercase}"
            CLEAN_DIRECT_OUTPUT ON
            )

        target_link_libraries ("${name}_static" ${ARGV3})

        target_include_directories ("${name}_static"
            PUBLIC
            "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
            "$<BUILD_INTERFACE:${public_headers_dir}>"
            PRIVATE
            "${ARGV4}"
            )
        install (TARGETS "${name}_static" EXPORT "${export_config}"
            ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
            )
        export (TARGETS "${name}_static" NAMESPACE "${CMAKE_PROJECT_NAME}::"
            FILE "${CMAKE_CURRENT_BINARY_DIR}/${export_config}.cmake"
            )
        add_library ("${CMAKE_PROJECT_NAME}::${name_lowercase}::static" ALIAS "${name}_static")
    endif ()

    # Dynamic variant
    if (NOT DISABLE_SHARED)
        add_library ("${name}_shared" SHARED "$<TARGET_OBJECTS:${name}>")
        list (APPEND targets_list "${name}_shared")

        set (lib_version_major "${CMAKE_PROJECT_VERSION_MAJOR}")
        set (lib_version "${CMAKE_PROJECT_VERSION}")
        if (PROJECT_VERSION)
            set (lib_version_major "${PROJECT_VERSION_MAJOR}")
            set (lib_version "${PROJECT_VERSION}")
        endif ()

        set_target_properties ("${name}_shared" PROPERTIES
            VERSION "${lib_version}"
            SOVERSION "${lib_version_major}"
            EXPORT_NAME "${name_lowercase}::shared"
            OUTPUT_NAME "${name_lowercase}"
            CLEAN_DIRECT_OUTPUT ON
            )
        target_link_libraries ("${name}_shared" ${ARGV3})

        target_include_directories ("${name}_shared"
            PUBLIC
            "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
            "$<BUILD_INTERFACE:${public_headers_dir}>"
            PRIVATE
            "${ARGV4}"
            )
        install (TARGETS "${name}_shared" EXPORT "${export_config}"
            LIBRARY NAMELINK_COMPONENT Development DESTINATION "${CMAKE_INSTALL_LIBDIR}"
            )
        export(TARGETS "${name}_shared" NAMESPACE "${CMAKE_PROJECT_NAME}::"
            FILE "${CMAKE_CURRENT_BINARY_DIR}/${export_config}.cmake"
            )
        add_library("${CMAKE_PROJECT_NAME}::${name_lowercase}::shared" ALIAS "${name}_shared")
    endif ()

    if (NOT DISABLE_STATIC OR NOT DISABLE_SHARED)
        install (EXPORT "${export_config}" NAMESPACE "${CMAKE_PROJECT_NAME}::"
            DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${CMAKE_PROJECT_NAME}"
            )
        install (DIRECTORY "${public_headers_dir}/"
            DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
            FILES_MATCHING REGEX "^.*\.h(pp|xx)?$"
            PATTERN "private" EXCLUDE
            )
    endif ()

    set_property (GLOBAL PROPERTY TARGETS_LIST "${targets_list}")
endfunction ()

# Add executable target:
#   name         - application name
#   sources_list - source files list
#   ARGV2        - extra libraries to link with (optional)
#   ARGV3        - headers include dir (optional)
function (add_application name sources_list)
    add_executable ("${name}" "${sources_list}")

    get_property (targets_list GLOBAL PROPERTY TARGETS_LIST)
    list (APPEND targets_list "${name}")
    set_property (GLOBAL PROPERTY TARGETS_LIST "${targets_list}")

    string (TOLOWER "${name}" name_lowercase)
    set_target_properties ("${name}" PROPERTIES OUTPUT_NAME "${name_lowercase}")

    target_link_libraries ("${name}" "${ARGV2}")
    target_include_directories("${name}" PRIVATE "${ARGV3}")

    install (TARGETS "${name}" RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endfunction ()

# Add Boost test with separate test cases for CTest:
#   name         - test target name
#   sources_list - test source files
#   ARGN         - extra libraries to link with (optional)
# also add post-build action to run tests after build.
function (add_boost_test name sources_list)
    add_executable ("${name}" ${sources_list})

    get_property (targets_list GLOBAL PROPERTY TARGETS_LIST)
    list (APPEND targets_list "${name}")
    set_property (GLOBAL PROPERTY TARGETS_LIST "${targets_list}")

    target_link_libraries("${name}"
        Boost::system
        Boost::unit_test_framework
        ${ARGN}
        )

    foreach (src IN LISTS sources_list)
        get_filename_component (src_name ${src} NAME)
        file (READ "${src_name}" src_contents)
        string (REGEX MATCHALL "BOOST_(AUTO|DATA|FIXTURE|PARAM)_TEST_CASE(_F)?\\( *([A-Za-z_0-9]+)[^)]*\\)"
            found_tests "${src_contents}")
        foreach (test ${found_tests})
            string (REGEX REPLACE ".*\\( *([A-Za-z_0-9]+)[^)]*\\)" "\\1" test_name "${test}")
            add_test (NAME "${name}.${test_name}"
                COMMAND "${name}" --run_test=${test_name} --catch_system_error=yes)
        endforeach ()
    endforeach ()
endfunction()

############ End
