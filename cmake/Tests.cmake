find_program(XVFB Xvfb)
find_program(DBUS dbus-daemon)
set(arguments --compiler "${Cwhip_COMPILER}" --clang "${Cwhip_CLANG_EXECUTABLE}"
    --include "${Cwhip_INCLUDE_DIR}" --native "${CMAKE_SOURCE_DIR}/tests"
    --source "${CMAKE_SOURCE_DIR}/src/cedit.cw" --xvfb "${XVFB}")
add_custom_target(check-noop
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/test_cedit_build.py"
        --build "${CMAKE_BINARY_DIR}" --cmake "${CMAKE_COMMAND}"
        --executable "${CWHIP_BIN_DIR}/cedit" --compiler "${Cwhip_COMPILER}"
    USES_TERMINAL VERBATIM)
if(XVFB AND DBUS)
    add_test(NAME cedit_numeric COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tests/test_cedit_numeric.py" ${arguments}
        --work "${CMAKE_BINARY_DIR}/tests/numeric")
    add_test(NAME cedit_project_setup COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tests/test_project_setup.py"
        --source "${CMAKE_SOURCE_DIR}" --sdk "${Cwhip_PREFIX}"
        --cmake "${CMAKE_COMMAND}" --xvfb "${XVFB}")
    add_test(NAME cedit_binary COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tests/test_smoke.py"
        --executable "${CWHIP_BIN_DIR}/cedit" --xvfb "${XVFB}"
        --work "${CMAKE_BINARY_DIR}/tests/binary")
    add_test(NAME cedit_shortcuts COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tests/test_cedit_shortcuts.py"
        --executable "${CWHIP_BIN_DIR}/cedit" --xvfb "${XVFB}"
        --work "${CMAKE_BINARY_DIR}/tests/shortcuts")
    foreach(group ui migration save invalid)
        add_test(NAME cedit_preferences_${group} COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/tests/test_cedit_preferences.py" ${arguments}
            --work "${CMAKE_BINARY_DIR}/tests/preferences-${group}" --group "${group}")
    endforeach()
    foreach(group session switching lifecycle invalid)
        add_test(NAME cedit_project_${group} COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/tests/test_cedit_project.py" ${arguments}
            --version "${PROJECT_VERSION}"
            --work "${CMAKE_BINARY_DIR}/tests/project-${group}" --group "${group}")
    endforeach()
    foreach(driver project_explorer editor_dialogs)
        add_test(NAME cedit_${driver} COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/tests/test_${driver}.py" ${arguments}
            --work "${CMAKE_BINARY_DIR}/tests/${driver}")
    endforeach()
else()
    message(STATUS "EXCLUDED: editor headless GUI tests require Xvfb and dbus-daemon")
endif()
add_test(NAME cedit_sdk_discovery COMMAND "${Python3_EXECUTABLE}"
    "${CMAKE_SOURCE_DIR}/tests/test_sdk_discovery.py" -v)
get_property(tests DIRECTORY PROPERTY TESTS)
if(tests)
    set_tests_properties(${tests} PROPERTIES TIMEOUT 300 ENVIRONMENT "PYTHONDONTWRITEBYTECODE=1")
endif()
set_property(TEST cedit_sdk_discovery APPEND PROPERTY ENVIRONMENT "CEDIT_CMAKE=${CMAKE_COMMAND}")
