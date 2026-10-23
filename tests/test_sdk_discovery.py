"""Exercise real SDK discovery in CMake and setup with mock SDK packages."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CMAKE = os.environ.get("CEDIT_CMAKE", "cmake")


class SdkDiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "project"
        self.project.mkdir()
        for name in ("CMakeLists.txt", ".project_env"):
            shutil.copy2(ROOT / name, self.project / name)
        for name in ("cmake", "scripts", "src", "tests"):
            shutil.copytree(ROOT / name, self.project / name,
                            ignore=shutil.ignore_patterns("__pycache__"))
        self.home = self.root / "home"
        self.home.mkdir()
        self.settings = self.home / ".config/cwhip/settings.toml"
        self.build = self.project / "build"
        self.env = os.environ.copy()
        for name in (
            "CWHIP_SDK", "CMAKE_PREFIX_PATH", "Cwhip_DIR", "Cwhip_ROOT",
            "CMAKE_INSTALL_PREFIX", "CMAKE_BUILD_TYPE",
            "_PROJECT_NAME", "XDG_CONFIG_HOME",
        ):
            self.env.pop(name, None)
        self.env["HOME"] = str(self.home)
        self.fallback = self.make_sdk("fallback")
        self.env["CMAKE_PREFIX_PATH"] = str(self.fallback)
        self.shell_record = self.root / "shell-sdk.txt"
        tools = self.root / "tools"
        tools.mkdir()
        shell = tools / "bash"
        shell.write_text(
            '#!/bin/sh\nprintf "%s" "${CWHIP_SDK-}" > "$SHELL_RECORD"\n'
        )
        shell.chmod(0o755)
        self.env["PATH"] = f"{tools}:{self.env['PATH']}"
        self.env["SHELL_RECORD"] = str(self.shell_record)

    def make_sdk(self, name, install_prefix=None, build_type=None):
        prefix = self.root / name
        package = prefix / "lib/cmake/Cwhip"
        package.mkdir(parents=True)
        (package / "CwhipConfig.cmake").write_text(
            'include("${CMAKE_CURRENT_LIST_DIR}/CwhipApplicationDefaults.cmake")\n'
            'get_filename_component(Cwhip_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)\n'
            'file(WRITE "${CMAKE_BINARY_DIR}/selected-sdk.txt" "${Cwhip_PREFIX}")\n'
            'find_package(Python3 COMPONENTS Interpreter)\n'
            'set(Cwhip_APPLICATION_OUTPUT_DIRECTORIES TRUE)\n'
            'function(cwhip_require_sourceview)\n'
            'endfunction()\n'
            'function(cwhip_add_program name)\n'
            '    add_custom_target("${name}")\n'
            '    set_target_properties("${name}" PROPERTIES\n'
            '        CWHIP_EXECUTABLE "${CMAKE_BINARY_DIR}/cedit.bin")\n'
            '    file(WRITE "${CMAKE_BINARY_DIR}/cedit.bin" "mock executable\\n")\n'
            'endfunction()\n'
        )
        (package / "CwhipConfigVersion.cmake").write_text(
            'set(PACKAGE_VERSION "0.0.1")\n'
            'set(PACKAGE_VERSION_COMPATIBLE TRUE)\n'
            'set(PACKAGE_VERSION_EXACT TRUE)\n'
        )
        defaults = ["function(cwhip_apply_application_defaults)"]
        if install_prefix is not None:
            defaults.extend((
                "    if(NOT DEFINED CMAKE_INSTALL_PREFIX)",
                '        if(DEFINED ENV{CMAKE_INSTALL_PREFIX})',
                '            set(CMAKE_INSTALL_PREFIX "$ENV{CMAKE_INSTALL_PREFIX}" CACHE PATH "Environment install prefix" FORCE)',
                "        else()",
                f'            set(CMAKE_INSTALL_PREFIX "{install_prefix}" CACHE PATH "Application install prefix" FORCE)',
                "        endif()",
                "    endif()",
            ))
        if build_type is not None:
            defaults.extend((
                "    if(NOT DEFINED CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)",
                f'        set(CMAKE_BUILD_TYPE "{build_type}" CACHE STRING "Application build type" FORCE)',
                "    endif()",
            ))
        defaults.append("endfunction()")
        (package / "CwhipApplicationDefaults.cmake").write_text(
            "\n".join(defaults) + "\n"
        )
        return prefix

    def write_settings(self, content):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(content)

    def select(self, prefix):
        self.write_settings(f"sdk_prefix = {json.dumps(str(prefix))}\n")

    def write_sdk_toml(self, content):
        path = self.settings.with_name("sdk.toml")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def quick(self):
        return ("-DCMAKE_DISABLE_FIND_PACKAGE_Python3=TRUE", "-DBUILD_TESTING=OFF")

    def test_sdk_toml_wins_over_legacy_settings(self):
        new = self.make_sdk("new-sdk")
        self.select(self.make_sdk("legacy-sdk"))
        self.write_sdk_toml(f"sdk_prefix = {json.dumps(str(new))}\n")
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_selected(new)

    def test_preference_overwrite_does_not_touch_sdk_toml(self):
        new = self.make_sdk("new-sdk")
        sdk_toml = self.write_sdk_toml(f"sdk_prefix = {json.dumps(str(new))}\n")
        before = sdk_toml.read_bytes()
        self.settings.write_text("version = 1\n")  # simulated editor save
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_selected(new)
        self.assertEqual(sdk_toml.read_bytes(), before)

    def test_absent_sdk_toml_uses_legacy_settings(self):
        legacy = self.make_sdk("legacy-sdk")
        self.select(legacy)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_selected(legacy)

    def test_invalid_sdk_toml_errors_without_legacy_fallback(self):
        self.select(self.make_sdk("legacy-sdk"))
        for content in ('sdk_prefix = "relative"\n', 'sdk_prefix = ""\n',
                        'sdk_prefix = "unterminated\n'):
            with self.subTest(content=content):
                self.write_sdk_toml(content)
                self.assertIn("sdk.toml", self.run_configure(success=False))
                self.run_configure(setup=True, success=False)

    def test_sdk_toml_missing_key_uses_normal_discovery_not_legacy(self):
        self.select(self.make_sdk("legacy-sdk"))
        self.write_sdk_toml('other = "value"\n')
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_selected(self.fallback)
        self.run_configure(setup=True)
        self.assertEqual(self.shell_record.read_text(), "")

    def test_setup_prefers_sdk_toml(self):
        new = self.make_sdk("new-sdk")
        self.select(self.make_sdk("legacy-sdk"))
        self.write_sdk_toml(f"sdk_prefix = {json.dumps(str(new))}\n")
        self.run_configure(setup=True)
        self.assertEqual(self.shell_record.read_text(), str(new))

    def test_env_bypasses_invalid_sdk_toml(self):
        explicit = self.make_sdk("explicit")
        self.write_sdk_toml("not toml\n")
        self.env["CWHIP_SDK"] = str(explicit)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_selected(explicit)

    def test_sdk_prefix_usage_diagnostic_uses_stderr_and_exit_two(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/sdk-prefix.py")],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertTrue(result.stderr.startswith("cedit: error[CEDIT0001]: usage:"),
                        result.stderr)

    def run_configure(self, setup=False, success=True, extra=(), shell_input=None):
        if setup:
            command = ["/bin/bash", str(self.project / "scripts/setup"), *extra]
        else:
            command = [
                CMAKE, "-S", str(self.project), "-B", str(self.build), *extra,
            ]
        result = subprocess.run(
            command, cwd=self.root, env=self.env, capture_output=True, text=True,
            input=shell_input, timeout=60,
        )
        output = result.stdout + result.stderr
        if success:
            self.assertEqual(result.returncode, 0, output)
        else:
            self.assertNotEqual(result.returncode, 0, output)
            if setup:
                self.assertFalse(self.shell_record.exists(), output)
        return output

    def assert_selected(self, prefix):
        self.assertEqual((self.build / "selected-sdk.txt").read_text(), str(prefix))

    def assert_cache_value(self, name, value):
        cache = (self.build / "CMakeCache.txt").read_text()
        self.assertIn(f"{name}:", cache)
        self.assertIn(f"{name}:PATH={value}" if name == "CMAKE_INSTALL_PREFIX"
                      else f"{name}:STRING={value}", cache)

    def test_selected_sdk_application_defaults_are_inherited(self):
        install_prefix = self.root / "application-install"
        sdk = self.make_sdk("defaults-sdk", install_prefix, "RelWithDebInfo")
        self.select(sdk)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_cache_value("CMAKE_INSTALL_PREFIX", str(install_prefix))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "RelWithDebInfo")

    def test_explicit_cmake_values_override_application_defaults(self):
        sdk = self.make_sdk(
            "defaults-sdk", self.root / "sdk-install", "Release"
        )
        self.select(sdk)
        self.env["CMAKE_INSTALL_PREFIX"] = str(self.root / "environment-install")
        install_prefix = self.root / "explicit-install"
        self.run_configure(extra=(
            f"-DCMAKE_INSTALL_PREFIX={install_prefix}",
            "-DCMAKE_BUILD_TYPE=Debug",
            "-DBUILD_TESTING=OFF",
        ))
        self.assert_cache_value("CMAKE_INSTALL_PREFIX", str(install_prefix))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "Debug")

    def test_install_prefix_environment_overrides_sdk_default(self):
        sdk = self.make_sdk(
            "defaults-sdk", self.root / "sdk-install", "Release"
        )
        self.select(sdk)
        install_prefix = self.root / "environment-install"
        self.env["CMAKE_INSTALL_PREFIX"] = str(install_prefix)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_cache_value("CMAKE_INSTALL_PREFIX", str(install_prefix))

    def test_explicit_empty_build_type_overrides_sdk_default(self):
        sdk = self.make_sdk(
            "defaults-sdk", self.root / "sdk-install", "Release"
        )
        self.select(sdk)
        self.run_configure(extra=(
            "-DCMAKE_BUILD_TYPE=",
            "-DBUILD_TESTING=OFF",
        ))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "")

    def test_existing_empty_build_type_cache_survives_sdk_default(self):
        first_sdk = self.make_sdk(
            "first-sdk", self.root / "first-install"
        )
        self.select(first_sdk)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "")

        second_sdk = self.make_sdk(
            "second-sdk", self.root / "second-install", "RelWithDebInfo"
        )
        self.select(second_sdk)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "")

    def test_existing_cache_values_survive_sdk_default_changes(self):
        first_prefix = self.root / "first-application-install"
        first_sdk = self.make_sdk("first-sdk", first_prefix, "Release")
        self.select(first_sdk)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))

        second_sdk = self.make_sdk(
            "second-sdk", self.root / "second-application-install", "Debug"
        )
        self.select(second_sdk)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        self.assert_selected(second_sdk)
        self.assert_cache_value("CMAKE_INSTALL_PREFIX", str(first_prefix))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "Release")

    def test_setup_without_mode_inherits_sdk_build_type(self):
        sdk = self.make_sdk(
            "defaults-sdk", self.root / "application-install", "Release"
        )
        self.select(sdk)
        self.run_configure(setup=True)
        self.assert_cache_value("CMAKE_BUILD_TYPE", "Release")

    def test_setup_explicit_mode_overrides_sdk_build_type(self):
        sdk = self.make_sdk(
            "defaults-sdk", self.root / "application-install", "Debug"
        )
        self.select(sdk)
        self.run_configure(setup=True, extra=("release",))
        self.assert_cache_value("CMAKE_BUILD_TYPE", "Release")

    def test_default_install_prefix_stages_application(self):
        install_prefix = self.root / "staged-app"
        sdk = self.make_sdk("defaults-sdk", install_prefix, "Release")
        self.select(sdk)
        self.run_configure(extra=("-DBUILD_TESTING=OFF",))
        build = subprocess.run(
            [CMAKE, "--build", str(self.build)], cwd=self.root, env=self.env,
            capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
        install = subprocess.run(
            [CMAKE, "--install", str(self.build)], cwd=self.root, env=self.env,
            capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(install.returncode, 0, install.stdout + install.stderr)
        self.assertTrue((install_prefix / "bin/cedit").is_file())
        self.assertTrue((install_prefix / "bin/cedit.bin").is_file())

    def test_missing_settings_preserves_prefix_discovery(self):
        self.run_configure(extra=(
            "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=TRUE", "-DBUILD_TESTING=OFF",
        ))
        self.assert_selected(self.fallback)
        self.assertFalse(self.settings.exists())

    def test_missing_key_preserves_cmake_dir_discovery(self):
        self.write_settings('[compiler]\nsdk_prefix = "/not/a/top-level/key"\n')
        self.env.pop("CMAKE_PREFIX_PATH")
        self.run_configure(extra=(
            f"-DCwhip_DIR={self.fallback / 'lib/cmake/Cwhip'}",
        ))
        self.assert_selected(self.fallback)

    def test_xdg_settings_win_over_home_settings(self):
        self.select(self.make_sdk("home-sdk"))
        home_settings = self.settings
        home_content = home_settings.read_bytes()
        config_home = self.root / 'XDG config with "quotes"'
        self.env["XDG_CONFIG_HOME"] = str(config_home) + "/"
        self.settings = config_home / "cwhip/settings.toml"
        prefix = self.make_sdk("xdg-sdk")
        self.select(prefix)
        xdg_content = self.settings.read_bytes()
        self.run_configure()
        self.assert_selected(prefix)
        self.run_configure(setup=True)
        self.assert_selected(prefix)
        self.assertEqual(self.shell_record.read_text(), str(prefix))
        self.assertEqual(home_settings.read_bytes(), home_content)
        self.assertEqual(self.settings.read_bytes(), xdg_content)

    def test_empty_xdg_uses_home_settings(self):
        self.env["XDG_CONFIG_HOME"] = ""
        prefix = self.make_sdk("home-sdk")
        self.select(prefix)
        self.run_configure()
        self.assert_selected(prefix)
        self.run_configure(setup=True)
        self.assert_selected(prefix)
        self.assertEqual(self.shell_record.read_text(), str(prefix))

    def test_missing_xdg_settings_do_not_fall_back_to_home_settings(self):
        self.write_settings("not valid TOML\n")
        self.env["XDG_CONFIG_HOME"] = str(self.root / "missing-config")
        self.run_configure()
        self.assert_selected(self.fallback)
        self.run_configure(setup=True)
        self.assert_selected(self.fallback)
        self.assertEqual(self.shell_record.read_text(), "")

    def test_relative_xdg_is_rejected_unless_explicit_sdk_is_set(self):
        self.env["XDG_CONFIG_HOME"] = "relative-config"
        self.assertIn("not absolute", self.run_configure(success=False))
        self.assertIn("not absolute", self.run_configure(setup=True, success=False))
        self.env["CWHIP_SDK"] = str(self.fallback)
        self.run_configure()
        self.assert_selected(self.fallback)
        self.run_configure(setup=True)
        self.assert_selected(self.fallback)

    def test_xdg_settings_work_without_home(self):
        self.env.pop("HOME")
        self.env["XDG_CONFIG_HOME"] = str(self.root / "xdg-config")
        self.settings = Path(self.env["XDG_CONFIG_HOME"]) / "cwhip/settings.toml"
        prefix = self.make_sdk("xdg-sdk")
        self.select(prefix)
        self.run_configure()
        self.assert_selected(prefix)
        self.run_configure(setup=True)
        self.assert_selected(prefix)

    def test_no_config_home_preserves_normal_discovery(self):
        self.env.pop("HOME")
        self.run_configure()
        self.assert_selected(self.fallback)
        self.run_configure(setup=True)
        self.assert_selected(self.fallback)

    def test_settings_overrides_fallback_and_preserves_escaped_path(self):
        prefix = self.make_sdk('SDK with spaces and "quotes" ')
        self.select(prefix)
        before = self.settings.read_bytes()
        self.env["CWHIP_SDK"] = ""
        self.run_configure()
        self.assert_selected(prefix)
        self.assertEqual(self.settings.read_bytes(), before)

    def test_literal_toml_string_and_comments(self):
        prefix = self.make_sdk('literal "SDK"')
        self.write_settings(f"# installed SDK\nsdk_prefix = '{prefix}' # prefix\n")
        self.run_configure()
        self.assert_selected(prefix)

    def test_explicit_override_ignores_malformed_settings(self):
        self.write_settings('sdk_prefix = "unterminated\n')
        prefix = self.make_sdk("explicit")
        self.env["CWHIP_SDK"] = str(prefix)
        self.run_configure(extra=(
            "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=TRUE", "-DBUILD_TESTING=OFF",
        ))
        self.assert_selected(prefix)

    def test_explicit_override_wins_over_valid_settings_and_cmake_dir(self):
        self.select(self.make_sdk("settings-sdk"))
        prefix = self.make_sdk('explicit SDK "quotes"')
        self.env["CWHIP_SDK"] = str(prefix)
        self.env["Cwhip_DIR"] = str(self.fallback / "lib/cmake/Cwhip")
        self.run_configure()
        self.assert_selected(prefix)
        self.run_configure(setup=True)
        self.assert_selected(prefix)
        self.assertEqual(self.shell_record.read_text(), str(prefix))

    def test_explicit_invalid_prefix_does_not_fall_back(self):
        self.select(self.fallback)
        self.env["CWHIP_SDK"] = str(self.root / "missing")
        self.assertIn("Cwhip", self.run_configure(success=False))

    def test_invalid_settings_fail_instead_of_falling_back(self):
        invalid = (
            'sdk_prefix = "unterminated\n',
            "sdk_prefix = 42\n",
            'sdk_prefix = ""\n',
            'sdk_prefix = "relative/sdk"\n',
            f"sdk_prefix = {json.dumps(str(self.root / 'missing'))}\n",
            f"sdk_prefix = {json.dumps(str(self.project / 'CMakeLists.txt'))}\n",
        )
        for content in invalid:
            with self.subTest(content=content):
                self.write_settings(content)
                output = self.run_configure(success=False)
                self.assertIn("sdk_prefix", output)
                self.assertIn("settings.toml", output)

    def test_existing_non_sdk_directory_does_not_fall_back(self):
        self.select(self.home)
        self.assertIn("Cwhip", self.run_configure(success=False))

    def test_unreadable_settings_do_not_fall_back(self):
        self.select(self.fallback)
        self.settings.chmod(0)
        self.addCleanup(self.settings.chmod, 0o600)
        if os.access(self.settings, os.R_OK):
            self.skipTest("Current user can read mode-000 files")
        output = self.run_configure(success=False)
        self.assertIn("settings.toml", output)
        self.assertIn("sdk_prefix", output)
        self.run_configure(setup=True, success=False)

    def test_settings_directory_is_diagnosed(self):
        self.settings.mkdir(parents=True)
        self.assertIn("settings.toml", self.run_configure(success=False))
        self.assertIn("sdk_prefix", self.run_configure(setup=True, success=False))

    def test_changed_selection_replaces_cached_package(self):
        self.run_configure()
        prefix = self.make_sdk("settings-sdk")
        self.select(prefix)
        self.run_configure()
        self.assert_selected(prefix)
        explicit = self.make_sdk("explicit-sdk")
        self.env["CWHIP_SDK"] = str(explicit)
        self.run_configure()
        self.assert_selected(explicit)

    def test_setup_exports_settings_prefix_and_build_type(self):
        prefix = self.make_sdk('setup SDK "quotes" ')
        self.select(prefix)
        before = self.settings.read_bytes()
        self.run_configure(setup=True, extra=("release",))
        self.assert_selected(prefix)
        self.assertEqual(self.shell_record.read_text(), str(prefix))
        self.assertIn("CMAKE_BUILD_TYPE:STRING=Release", (self.build / "CMakeCache.txt").read_text())
        self.assertEqual(self.settings.read_bytes(), before)

    def test_setup_real_shell_adds_settings_sdk_to_path(self):
        prefix = self.make_sdk('shell SDK with "quotes"')
        self.select(prefix)
        self.env["PATH"] = os.environ["PATH"]
        self.run_configure(
            setup=True,
            shell_input='printf "%s" "$PATH" > "$SHELL_RECORD"\nexit\n',
        )
        path_entries = self.shell_record.read_text().split(":")
        self.assertEqual(path_entries[:3], [
            str(self.project / "bin"),
            str(self.project / "scripts"),
            str(prefix / "bin"),
        ])
        self.assert_selected(prefix)

    def test_setup_explicit_override_ignores_bad_settings(self):
        self.write_settings("not valid TOML\n")
        self.env["CWHIP_SDK"] = str(self.fallback)
        self.run_configure(setup=True)
        self.assert_selected(self.fallback)
        self.assertEqual(self.shell_record.read_text(), str(self.fallback))

    def test_setup_missing_settings_preserves_discovery(self):
        self.run_configure(setup=True)
        self.assert_selected(self.fallback)
        self.assertEqual(self.shell_record.read_text(), "")
        self.assertFalse(self.settings.exists())

    def test_setup_missing_key_preserves_discovery(self):
        self.write_settings('other_setting = "value"\n')
        self.run_configure(setup=True)
        self.assert_selected(self.fallback)
        self.assertEqual(self.shell_record.read_text(), "")

    def test_setup_bad_settings_never_opens_shell(self):
        self.write_settings('sdk_prefix = "relative"\n')
        output = self.run_configure(setup=True, success=False)
        self.assertIn("sdk_prefix", output)
        self.assertIn("project shell was not started", output)
        self.assertIn("cedit: error[CEDIT2001]:", output)

    def test_setup_malformed_toml_never_opens_shell(self):
        self.write_settings('sdk_prefix = "unterminated\n')
        output = self.run_configure(setup=True, success=False)
        self.assertIn("sdk_prefix", output)
        self.assertIn("cedit: error[CEDIT2001]:", output)

    def test_setup_invalid_override_never_falls_back(self):
        self.select(self.fallback)
        self.env["CWHIP_SDK"] = str(self.root / "missing")
        output = self.run_configure(setup=True, success=False)
        self.assertIn("CMake configuration failed", output)
        self.assertIn("cedit: error[CEDIT3001]:", output)

    def test_setup_invalid_sdk_never_opens_shell(self):
        self.select(self.home)
        output = self.run_configure(setup=True, success=False)
        self.assertIn("CMake configuration failed", output)


if __name__ == "__main__":
    unittest.main()
