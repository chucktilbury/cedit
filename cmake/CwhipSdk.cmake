# Selects the installed Cwhip SDK: non-empty CWHIP_SDK > the top-level
# sdk_prefix in cwhip/sdk.toml (legacy settings.toml only if sdk.toml is absent)
# > normal CMake package discovery.
set(cwhip_sdk_prefix "$ENV{CWHIP_SDK}")
if(cwhip_sdk_prefix STREQUAL "")
    set(cwhip_config_home "$ENV{XDG_CONFIG_HOME}")
    if(cwhip_config_home STREQUAL "" AND NOT "$ENV{HOME}" STREQUAL "")
        set(cwhip_config_home "$ENV{HOME}/.config")
    endif()
    if(NOT cwhip_config_home STREQUAL "")
        if(NOT IS_ABSOLUTE "${cwhip_config_home}")
            message(FATAL_ERROR
                "cedit: error[CEDIT2001]: cannot discover sdk_prefix: config home '${cwhip_config_home}' is not absolute")
        endif()
        cmake_path(APPEND cwhip_config_home "cwhip"
            OUTPUT_VARIABLE cwhip_settings_directory)
        cmake_path(NORMAL_PATH cwhip_settings_directory)
        # EXISTS checks readability; listing lets the parser diagnose unreadable files.
        file(GLOB cwhip_settings_entries "${cwhip_settings_directory}/*")
        if("${cwhip_settings_directory}/sdk.toml" IN_LIST cwhip_settings_entries
           OR "${cwhip_settings_directory}/settings.toml" IN_LIST cwhip_settings_entries)
            find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
            execute_process(
                COMMAND "${Python3_EXECUTABLE}"
                    "${CMAKE_CURRENT_SOURCE_DIR}/scripts/sdk-prefix.py"
                    "${cwhip_settings_directory}"
                RESULT_VARIABLE cwhip_settings_result
                OUTPUT_VARIABLE cwhip_sdk_prefix
                ERROR_VARIABLE cwhip_settings_error)
            if(NOT cwhip_settings_result STREQUAL "0")
                message(FATAL_ERROR "${cwhip_settings_error}")
            endif()
        endif()
    endif()
endif()

if(NOT cwhip_sdk_prefix STREQUAL "")
    message(STATUS "Using Cwhip SDK prefix: ${cwhip_sdk_prefix}")
    # An explicit prefix must never reuse a stale cached package location.
    unset(Cwhip_DIR CACHE)
    unset(Cwhip_DIR)
    find_package(Cwhip 0.0.1 EXACT CONFIG REQUIRED
        PATHS "${cwhip_sdk_prefix}" NO_DEFAULT_PATH)
else()
    find_package(Cwhip 0.0.1 EXACT CONFIG REQUIRED)
endif()

if(NOT COMMAND cwhip_apply_application_defaults)
    if(NOT "${Cwhip_PREFIX}" STREQUAL "")
        set(cwhip_sdk_location "Cwhip SDK '${Cwhip_PREFIX}'")
    elseif(NOT cwhip_sdk_prefix STREQUAL "")
        set(cwhip_sdk_location "Cwhip SDK '${cwhip_sdk_prefix}'")
    else()
        set(cwhip_sdk_location "Cwhip package '${Cwhip_DIR}'")
    endif()
    message(FATAL_ERROR
        "cedit: error[CEDIT2001]: ${cwhip_sdk_location}: missing application-defaults capability "
        "(cwhip_apply_application_defaults); rebuild and reinstall an updated Cwhip SDK "
        "with CwhipApplicationDefaults.cmake included by CwhipConfig.cmake, then reconfigure cedit. "
        "Older SDK installs also report version 0.0.1; the version alone is not sufficient.")
endif()

cwhip_apply_application_defaults()
