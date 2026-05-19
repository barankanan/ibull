# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

from PyInstaller.utils.hooks import collect_all, collect_submodules


script_root = Path(SPECPATH).resolve()
bridge_root = script_root.parent
project_root = bridge_root.parent

pillow_datas, pillow_binaries, pillow_hiddenimports = collect_all("PIL")
usb_datas, usb_binaries, usb_hiddenimports = collect_all("usb")

hiddenimports = sorted(
    set(
        collect_submodules("local_print_bridge")
        + pillow_hiddenimports
        + usb_hiddenimports
        + [
            "local_print_bridge.server",
            "local_print_bridge.config",
            "local_print_bridge.receipt",
            "local_print_bridge.kitchen",
            "local_print_bridge.raster",
            "pythoncom",
            "pywintypes",
            "win32print",
            "win32ui",
        ]
    )
)

_font_datas = [
    (str(path), "local_print_bridge/fonts")
    for path in (bridge_root / "fonts").glob("*.ttf")
]
datas = pillow_datas + usb_datas + [(str(bridge_root / ".env.example"), ".")] + _font_datas
binaries = pillow_binaries + usb_binaries

a = Analysis(
    [str(script_root / "bridge_entry.py")],
    pathex=[str(project_root)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="IbulPrintBridge",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
