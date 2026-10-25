"""Check cedit numeric boundaries and the SDK's staged syntax definitions."""

import argparse
from pathlib import Path
import tempfile

from gtk_support import headless
from program_runner import environment, invoke


DRIVER = r"""
class NumericChecks {
    int64 checks
    void noop() {}
    int add(int32 left, int8 right) { return(left + right) }
    void require(bool condition, String label) {
        if (!condition) {
            System.StandardIO().writeErrorLine(format("FAIL numeric: {}", label))
            System.Process().exit(1)
        }
        checks = checks + 1
    }
    void run() {
        CeditSettings settings = CeditSettings()
        require(settings.writable && settings.errors.equals(""), "settings load")
        require(settings.fontSize == 72 && settings.tabWidth == 16, "maximum preferences")
        require(Gtk.Config().value(settings.serialize(), "editor", "font_size").equals("i72"),
            "preference serialization")
        Cedit editor = Cedit()
        require(editor.preferenceNumber("72", 6, 72) == 72 &&
            editor.preferenceNumber("16", 1, 16) == 16 &&
            editor.preferenceNumber("73", 6, 72) == -1, "preference input bounds")
        CwhipProject project = CwhipProject(System.FileSystem().getCwd())
        String workspace = "version = 1\n[workspace]\nexplorer_width = 5000\nwindow_width = 10000\nwindow_height = 10000\nfiles = [{path = \"large.cw\", line = 100000000, column = 99999999}]\n"
        require(project.parseWorkspace(workspace).equals(""), "large workspace positions")
        require(project.explorerWidth == 5000 && project.windowWidth == 10000 &&
            project.windowHeight == 10000 && project.files.length == 1, "workspace dimensions")
        WorkspaceFile file = project.files[0] as WorkspaceFile
        require(file.line == 100000000 && file.column == 99999999, "int64 string conversion")
        require(!project.validPosition("i100000001") && !project.validPosition("i0"),
            "workspace position bounds")
        GtkSource.View view = GtkSource.View()
        require(view.setLanguage("cwhip"), "staged Cwhip language available")
        list types = "int8 uint8 int16 uint16 int32 uint32 int64 uint64 fp32 fp64 int uint float".split(" ")
        int64 index = 0
        while (index < types.length) {
            String spelling = types[index] as String
            view.setText(spelling)
            require(view.hasContextAt("type", 0), format("{} type highlighting", spelling))
            index = index + 1
        }
        view.setText("unsigned")
        require(!view.hasContextAt("type", 0) && view.hasContextAt("keyword", 0),
            "unsigned reserved, not a type")
        view.setText("int<int32,int8> callback")
        require(view.hasContextAt("type", 0) && view.hasContextAt("type", 4) &&
            view.hasContextAt("type", 10), "callable return and parameter type highlighting")
        require(!view.hasContextAt("type", 16) && !view.hasContextAt("keyword", 16),
            "callback is an ordinary identifier")
        view.setText("void<> action")
        require(view.hasContextAt("type", 0), "zero-argument callable highlighting")
        view.setText("0.1f64 0xf64 255u")
        require(view.hasContextAt("number", 5) && view.hasContextAt("number", 11) &&
            view.hasContextAt("number", 16), "numeric suffix and hex highlighting")
        view.setText("range<int64> bounds = first..last")
        require(view.hasContextAt("type", 0), "range type highlighting")
        require(view.hasContextAt("type", 6), "range element type highlighting")
        view.setText("value in bounds")
        require(view.hasContextAt("keyword", 6), "range membership highlighting")
        view.setText("items[1:3]")
        require(view.hasContextAt("number", 6) && view.hasContextAt("number", 8),
            "slice bound highlighting")
        view.setText("case (0, 2..4) { next }")
        require(view.hasContextAt("keyword", 0) && view.hasContextAt("keyword", 17),
            "grouped switch range and next highlighting")
        view.setText("# comment")
        require(view.hasContextAt("comment", 2), "hash comment highlighting")
        view.setText("; not a comment")
        require(!view.hasContextAt("comment", 2), "semicolon is not a comment")
        view.setText("return(42)")
        require(view.hasContextAt("keyword", 0) && view.hasContextAt("number", 7),
            "parenthesized return highlighting")
        # Exercise the same syntax accepted in editor buffers and generated drivers.
        dict empty = [:]
        dict values = [
            "answer": targetValue(),
            "empty": empty,
        ]
        list sequence = [
            values["answer"],
            7,
        ]
        require(empty.length == 0 && values.length == 2, "bracket dictionary literals")
        require(sequence.length == 2 && sequence[0] as int32 == 42,
            "multiline literals with trailing commas")
        Gtk.MenuBar menu = Gtk.MenuBar()
        int64 parent = menu.addMenu("Numeric")
        NumericChecks target = NumericChecks()
        int signedNative = 1
        uint unsignedNative = 1u
        float floatNative = 1.0
        list aliases = [signedNative, unsignedNative, floatNative]
        require(aliases[0] is int32 && aliases[1] is uint32 && aliases[2] is fp32,
            "native aliases keep canonical dynamic numeric tags")
        int<int32,int8> callback = target.add
        require(callback(40, 2) == 42, "native alias callable and ordinary callback symbol")
        list items = [menu.addItem(parent, "Check", target.noop)]
        require(items[0] is int64, "native menu ID keeps exact dynamic int64 tag")
        menu.setItemEnabled(items[0] as int64, false)
        print(format("PASS numeric {}", checks))
        Gtk.Application().quit()
    }
    int32 targetValue() { return(42) }
}

start {
    Gtk.Application app = Gtk.Application("org.cw.CeditNumericChecks")
    NumericChecks checks = NumericChecks()
    app.onActivate(checks.run)
    app.run()
    app.shutdown()
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--xvfb", required=True)
    # Keep the shared CTest arguments accepted; this fixture has no native shim.
    parser.add_argument("--clang")
    parser.add_argument("--include")
    parser.add_argument("--native")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.work, prefix="numeric-") as directory:
        work = Path(directory).resolve()
        env = environment(work)
        config = Path(env["XDG_CONFIG_HOME"]) / "cwhip"
        config.mkdir()
        (config / "settings.toml").write_text(
            "version = 1\n[editor]\nfont_size = 72\ntab_width = 16\n")
        text = args.source.read_text()
        source = work / "numeric.cw"
        source.write_text(text[:text.rindex("\nstart {")] + DRIVER)
        executable = work / "numeric"
        result = invoke([str(args.compiler.resolve()), str(source), "-o",
                         str(executable)], work, env)
        assert result.returncode == 0, result.stderr
        with headless(args.xvfb, work, env) as gui_env:
            result = invoke([str(executable)], work, gui_env)
        assert result.returncode == 0, result
        assert result.stdout == "PASS numeric 40" and not result.stderr, result


if __name__ == "__main__":
    main()
