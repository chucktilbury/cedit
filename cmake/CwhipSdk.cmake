# Selects the installed Cwhip SDK: non-empty CWHIP_SDK > the top-level
# sdk_prefix in the shared user settings.toml > normal CMake package discovery.
set(cwhip_sdk_prefix "$ENV{CWHIP_SDK}")
if(cwhip_sdk_prefix STREQUAL "")
    set(cwhip_config_home "$ENV{XDG_CONFIG_HOME}")
    if(cwhip_config_home STREQUAL "" AND NOT "$ENV{HOME}" STREQUAL "")
        set(cwhip_config_home "$ENV{HOME}/.config")
    endif()
    if(NOT cwhip_config_home STREQUAL "")
        if(NOT IS_ABSOLUTE "${cwhip_config_home}")
            message(FATAL_ERROR
                "Cannot discover sdk_prefix: config home '${cwhip_config_home}' is not absolute")
        endif()
        cmake_path(APPEND cwhip_config_home "cwhip"
            OUTPUT_VARIABLE cwhip_settings_directory)
        cmake_path(NORMAL_PATH cwhip_settings_directory)
        set(cwhip_settings "${cwhip_settings_directory}/settings.toml")
        # EXISTS checks readability; listing lets the parser diagnose unreadable files.
        file(GLOB cwhip_settings_entries "${cwhip_settings_directory}/*")
        if("${cwhip_settings}" IN_LIST cwhip_settings_entries)
            find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
            execute_process(
                COMMAND "${Python3_EXECUTABLE}"
                    "${PROJECT_SOURCE_DIR}/scripts/sdk-prefix.py" "${cwhip_settings}"
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
