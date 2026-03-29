from __future__ import annotations

from pathlib import Path

from cyclopts import App

app = App(name="kicad-lib")


def _lib_name(path: Path, suffix: str) -> str:
    if path.name.endswith(suffix):
        return path.name[: -len(suffix)]
    return path.stem


def _render_fp_table(base_path: str, lib_dirs: list[Path]) -> str:
    lines = ["(fp_lib_table", "  (version 7)"]
    for lib_dir in sorted(lib_dirs, key=lambda p: p.name.lower()):
        name = _lib_name(lib_dir, ".pretty")
        uri = f"{base_path}/footprints/{lib_dir.name}"
        lines.append(
            f'  (lib (name "{name}")(type "KiCad")(uri "{uri}")(options "")(descr ""))'
        )
    lines.append(")")
    return "\n".join(lines) + "\n"


def _render_sym_table(base_path: str, sym_files: list[Path]) -> str:
    lines = ["(sym_lib_table", "  (version 7)"]
    for sym_file in sorted(sym_files, key=lambda p: p.name.lower()):
        name = _lib_name(sym_file, ".kicad_sym")
        uri = f"{base_path}/symbols/{sym_file.name}"
        lines.append(
            f'  (lib (name "{name}")(type "KiCad")(uri "{uri}")(options "")(descr ""))'
        )
    lines.append(")")
    return "\n".join(lines) + "\n"


@app.command
def generate(
    repo_root: Path = Path("."),
    templates_dir: Path = Path("templates"),
    project_lib_base: str = "${KIPRJMOD}/kicad-library",
) -> None:
    """Update templates/fp-lib-table and templates/sym-lib-table for project libraries."""

    root = repo_root.resolve()
    footprints_dir = root / "footprints"
    symbols_dir = root / "symbols"
    output_dir = root / templates_dir

    if not footprints_dir.exists():
        raise FileNotFoundError(f"Missing footprints directory: {footprints_dir}")
    if not symbols_dir.exists():
        raise FileNotFoundError(f"Missing symbols directory: {symbols_dir}")

    fp_lib_dirs = [
        path
        for path in footprints_dir.iterdir()
        if path.is_dir() and path.name.endswith(".pretty")
    ]
    sym_lib_files = [path for path in symbols_dir.iterdir() if path.is_file() and path.suffix == ".kicad_sym"]

    output_dir.mkdir(parents=True, exist_ok=True)

    fp_table_text = _render_fp_table(project_lib_base, fp_lib_dirs)
    sym_table_text = _render_sym_table(project_lib_base, sym_lib_files)

    fp_table_path = output_dir / "fp-lib-table"
    sym_table_path = output_dir / "sym-lib-table"

    fp_table_path.write_text(fp_table_text, encoding="utf-8")
    sym_table_path.write_text(sym_table_text, encoding="utf-8")

    print(f"Updated {fp_table_path}")
    print(f"Updated {sym_table_path}")


def main() -> None:
    app()

if __name__ == "__main__":
    main()