#!/usr/bin/env python3
from __future__ import annotations

import math
import os
import shutil
import subprocess
import sys
import tempfile
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from PIL import Image


APP_TITLE = "Paper Forge"
DEFAULT_DPI = 200


def resource_path(relative: str) -> Path:
    if getattr(sys, "frozen", False):
        base = Path(sys._MEIPASS)  # type: ignore[attr-defined]
        return base / relative
    return Path(__file__).resolve().parent / relative


def find_pdftoppm() -> str | None:
    bundled = resource_path("bin/pdftoppm")
    if bundled.exists():
        return str(bundled)
    runtime_bundled = Path("/Users/chiachung.lim/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/pdftoppm")
    if runtime_bundled.exists():
        return str(runtime_bundled)
    return shutil.which("pdftoppm")


def poppler_fontconfig_env() -> dict[str, str]:
    env = os.environ.copy()
    fontconfig_dir = Path("/Users/chiachung.lim/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/poppler/etc/fonts")
    fontconfig_file = fontconfig_dir / "fonts.conf"
    if fontconfig_file.exists():
        env["FONTCONFIG_PATH"] = str(fontconfig_dir)
        env["FONTCONFIG_FILE"] = "fonts.conf"
    cache_dir = Path(tempfile.gettempdir()) / "pdf_to_image_fontconfig_cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    env["XDG_CACHE_HOME"] = str(cache_dir)
    env["HOME"] = env.get("HOME", str(Path.home()))
    return env


def get_pdf_page_count(pdf_path: Path) -> int:
    pdfinfo = shutil.which("pdfinfo")
    if not pdfinfo:
        runtime_pdfinfo = Path("/Users/chiachung.lim/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/pdfinfo")
        if runtime_pdfinfo.exists():
            pdfinfo = str(runtime_pdfinfo)
    if not pdfinfo:
        raise RuntimeError("Poppler 'pdfinfo' was not found. This app needs it to inspect the PDF page count.")

    completed = subprocess.run([pdfinfo, str(pdf_path)], capture_output=True, text=True, env=poppler_fontconfig_env())
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or "pdfinfo returned an error.")

    for line in completed.stdout.splitlines():
        if line.lower().startswith("pages:"):
            try:
                return int(line.split(":", 1)[1].strip())
            except ValueError as exc:  # noqa: PERF203
                raise RuntimeError(f"Could not parse page count from: {line}") from exc
    raise RuntimeError("Could not determine the page count for the PDF.")


@dataclass
class ConversionResult:
    output_dir: Path
    files: list[Path]


def convert_pdf_to_images(pdf_path: Path, output_dir: Path, dpi: int, image_format: str) -> ConversionResult:
    pdf_path = pdf_path.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    pdftoppm = find_pdftoppm()
    if not pdftoppm:
        raise RuntimeError("Poppler 'pdftoppm' was not found. This app needs it to render PDF pages.")

    prefix = output_dir / "page"
    fmt = image_format.lower()
    poppler_format = {"png": "png", "jpg": "jpeg", "jpeg": "jpeg", "tiff": "tiff"}[fmt]

    page_count = get_pdf_page_count(pdf_path)
    cmd = [
        pdftoppm,
        "-r",
        str(dpi),
        "-f",
        "1",
        "-l",
        str(page_count),
        f"-{poppler_format}",
        str(pdf_path),
        str(prefix),
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True, env=poppler_fontconfig_env())
    if completed.returncode != 0:
        raise RuntimeError(
            "Unable to render the PDF. "
            + (completed.stderr.strip() or "pdftoppm returned an error.")
        )

    generated = sorted(
        output_dir.glob(f"{prefix.name}-*.{fmt}"),
        key=lambda p: int(p.stem.split("-")[-1]),
    )
    page_files: list[Path] = []
    for index, rendered in enumerate(generated, start=1):
        final_name = output_dir / f"{pdf_path.stem}_page_{index:03d}.{fmt}"
        if final_name.exists():
            final_name.unlink()
        rendered.replace(final_name)
        page_files.append(final_name)

    if not page_files:
        raise RuntimeError("No pages were converted from the PDF.")

    # Make sure the first page is not accidentally left behind if the tool reused names.
    for leftover in output_dir.glob("page.*"):
        if leftover.is_file():
            leftover.unlink(missing_ok=True)

    return ConversionResult(output_dir=output_dir, files=page_files)


class PdfToImageApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("720x420")
        self.minsize(680, 400)

        self.pdf_path = tk.StringVar()
        self.output_dir = tk.StringVar()
        self.dpi = tk.IntVar(value=DEFAULT_DPI)
        self.image_format = tk.StringVar(value="PNG")
        self.status = tk.StringVar(value="Choose a PDF, then click Convert.")
        self.last_result: ConversionResult | None = None

        self._build_ui()

    def _build_ui(self) -> None:
        self.configure(padx=18, pady=18)

        title = ttk.Label(self, text=APP_TITLE, font=("Helvetica Neue", 20, "bold"))
        title.pack(anchor="w")

        subtitle = ttk.Label(
            self,
            text="Convert each PDF page into clean images with a simple click-based workflow.",
        )
        subtitle.pack(anchor="w", pady=(6, 16))

        main = ttk.Frame(self)
        main.pack(fill="both", expand=True)

        # PDF picker
        pdf_row = ttk.Frame(main)
        pdf_row.pack(fill="x", pady=6)
        ttk.Label(pdf_row, text="PDF file:").pack(side="left")
        ttk.Entry(pdf_row, textvariable=self.pdf_path).pack(side="left", fill="x", expand=True, padx=8)
        ttk.Button(pdf_row, text="Browse…", command=self.choose_pdf).pack(side="left")

        # Output folder picker
        out_row = ttk.Frame(main)
        out_row.pack(fill="x", pady=6)
        ttk.Label(out_row, text="Output folder:").pack(side="left")
        ttk.Entry(out_row, textvariable=self.output_dir).pack(side="left", fill="x", expand=True, padx=8)
        ttk.Button(out_row, text="Browse…", command=self.choose_output_dir).pack(side="left")

        opts = ttk.Frame(main)
        opts.pack(fill="x", pady=8)

        dpi_row = ttk.Frame(opts)
        dpi_row.pack(side="left", fill="x", expand=True, padx=(0, 12))
        ttk.Label(dpi_row, text="DPI:").pack(side="left")
        ttk.Spinbox(dpi_row, from_=72, to=600, increment=10, textvariable=self.dpi, width=8).pack(
            side="left", padx=8
        )

        fmt_row = ttk.Frame(opts)
        fmt_row.pack(side="left", fill="x", expand=True)
        ttk.Label(fmt_row, text="Format:").pack(side="left")
        ttk.Combobox(
            fmt_row,
            textvariable=self.image_format,
            values=("PNG", "JPG", "TIFF"),
            state="readonly",
            width=8,
        ).pack(side="left", padx=8)

        action_row = ttk.Frame(main)
        action_row.pack(fill="x", pady=(10, 6))
        ttk.Button(action_row, text="Convert PDF", command=self.convert_clicked).pack(side="left")
        ttk.Button(action_row, text="Open Output Folder", command=self.open_output_folder).pack(side="left", padx=8)

        ttk.Label(main, textvariable=self.status, foreground="#333").pack(anchor="w", pady=(6, 8))

        self.progress = ttk.Progressbar(main, mode="indeterminate")
        self.progress.pack(fill="x", pady=(0, 10))

        self.result_box = tk.Text(main, height=10, wrap="word")
        self.result_box.pack(fill="both", expand=True)
        self.result_box.insert("end", "Ready.\n")
        self.result_box.configure(state="disabled")

    def choose_pdf(self) -> None:
        path = filedialog.askopenfilename(
            title="Choose a PDF",
            filetypes=[("PDF files", "*.pdf"), ("All files", "*.*")],
        )
        if path:
            self.pdf_path.set(path)
            if not self.output_dir.get():
                self.output_dir.set(str(Path(path).with_suffix("").parent / f"{Path(path).stem}_images"))

    def choose_output_dir(self) -> None:
        path = filedialog.askdirectory(title="Choose output folder")
        if path:
            self.output_dir.set(path)

    def append_result(self, text: str) -> None:
        self.result_box.configure(state="normal")
        self.result_box.insert("end", text + "\n")
        self.result_box.see("end")
        self.result_box.configure(state="disabled")

    def convert_clicked(self) -> None:
        pdf_value = self.pdf_path.get().strip()
        if not pdf_value:
            messagebox.showwarning("Missing PDF", "Please choose a PDF file first.")
            return

        pdf_path = Path(pdf_value)
        if not pdf_path.exists():
            messagebox.showerror("File not found", f"The PDF does not exist:\n{pdf_path}")
            return

        output_value = self.output_dir.get().strip()
        if not output_value:
            output_value = str(pdf_path.with_suffix("").parent / f"{pdf_path.stem}_images")
            self.output_dir.set(output_value)

        output_dir = Path(output_value)
        self.status.set("Converting PDF pages to images...")
        self.progress.start(12)
        self.update_idletasks()

        try:
            result = convert_pdf_to_images(
                pdf_path=pdf_path,
                output_dir=output_dir,
                dpi=int(self.dpi.get()),
                image_format=self.image_format.get(),
            )
        except Exception as exc:  # noqa: BLE001
            self.progress.stop()
            self.status.set("Conversion failed.")
            messagebox.showerror("Conversion failed", str(exc))
            self.append_result(f"ERROR: {exc}")
            return

        self.progress.stop()
        self.last_result = result
        self.status.set(f"Done. Converted {len(result.files)} page(s).")
        self.append_result(f"Converted {len(result.files)} page(s) to: {result.output_dir}")
        for file in result.files:
            self.append_result(f"  - {file.name}")
        messagebox.showinfo("Conversion complete", f"Saved {len(result.files)} image(s) to:\n{result.output_dir}")

    def open_output_folder(self) -> None:
        folder = self.output_dir.get().strip()
        if not folder:
            messagebox.showinfo("No output folder", "Choose a PDF and convert it first.")
            return
        path = Path(folder)
        path.mkdir(parents=True, exist_ok=True)

        if sys.platform == "darwin":
            subprocess.run(["open", str(path)], check=False)
        elif sys.platform.startswith("win"):
            os.startfile(str(path))  # type: ignore[attr-defined]
        else:
            subprocess.run(["xdg-open", str(path)], check=False)


def main() -> int:
    app = PdfToImageApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
