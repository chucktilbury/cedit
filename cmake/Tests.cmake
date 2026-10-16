find_program(XVFB Xvfb)
find_program(DBUS dbus-daemon)
set(arguments --compiler "${Cwhip_COMPILER}" --clang "${Cwhip_CLANG_EXECUTABLE}"
    --include "${Cwhip_INCLUDE_DIR}" --native "${CMAKE_SOURCE_DIR}/tests"
    --source "${CMAKE_SOURCE_DIR}/src/cedit.cw" --xvfb "${XVFB}")
add_custom_target(check-noop
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/test_cedit_build.py"
        --build "${CMAKE_BINARY_DIR}" --cmake "${CMAKE_COMMAND}"
        --executable "${CMAKE_BINARY_DIR}/bin/cedit" --compiler "${Cwhip_COMPILER}"
    USES_TERMINAL VERBATIM)
if(XVFB AND DBUS)
    add_test(NAME cedit_binary COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tests/test_smoke.py"
        --executable "${CMAKE_BINARY_DIR}/bin/cedit" --xvfb "${XVFB}"
        --work "${CMAKE_BINARY_DIR}/tests/binary")
    add_test(NAME cedit_shortcuts COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tests/test_cedit_shortcuts.py"
        --executable "${CMAKE_BINARY_DIR}/bin/cedit" --xvfb "${XVFB}"
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
get_property(tests DIRECTORY PROPERTY TESTS)
if(tests)
    set_tests_properties(${tests} PROPERTIES TIMEOUT 300 ENVIRONMENT "PYTHONDONTWRITEBYTECODE=1")
endif()
