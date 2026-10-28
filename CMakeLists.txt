cmake_minimum_required(VERSION 3.24)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR
        "cedit: error[CEDIT0001]: configure out of source: cmake -S . -B build")
endif()
include(cmake/CwhipSdk.cmake)
project(cedit VERSION 0.0.1 LANGUAGES NONE)
if(NOT Cwhip_APPLICATION_OUTPUT_DIRECTORIES)
    message(FATAL_ERROR
        "cedit: error[CEDIT2001]: install a Cwhip SDK with application output-directory support")
endif()
set(CWHIP_BIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bin" CACHE PATH "Application executable directory")
set(CWHIP_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib" CACHE PATH "Native library directory")
get_filename_component(CWHIP_BIN_DIR "${CWHIP_BIN_DIR}" ABSOLUTE BASE_DIR "${CMAKE_BINARY_DIR}")
get_filename_component(CWHIP_LIB_DIR "${CWHIP_LIB_DIR}" ABSOLUTE BASE_DIR "${CMAKE_BINARY_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CWHIP_LIB_DIR}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CWHIP_LIB_DIR}")
cwhip_require_sourceview(RESOURCE_DIRECTORY
    "${CWHIP_BIN_DIR}/../share/cwhip/modules/sourceview/0.1.0/language-specs")
cwhip_add_program(cedit SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/cedit.cw"
    OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}")
get_target_property(editor_binary cedit CWHIP_EXECUTABLE)
# cwhip_add_program() creates a custom target, which install(TARGETS) cannot
# install. Copy the built program and force the installed command name.
install(PROGRAMS "${editor_binary}" DESTINATION bin RENAME cedit)
include(CTest)
if(BUILD_TESTING)
    include(cmake/Tests.cmake)
    add_custom_target(test-all
        COMMAND "${CMAKE_CTEST_COMMAND}" --output-on-failure --parallel 1
        DEPENDS cedit USES_TERMINAL VERBATIM)
endif()
set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${CMAKE_BINARY_DIR}/tests")
