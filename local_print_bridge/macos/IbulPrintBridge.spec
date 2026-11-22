# -*- mode: python ; coding: utf-8 -*-
"""macOS one-folder bundle of the existing local_print_bridge. No .env and no secrets."""

from pathlib import Path

from PyInstaller.utils.hooks import collect_all, collect_submodules


script_root = Path(SPECPATH).resolve()
bridge_root = script_root.parent
project_root = bridge_root.parent

pillow_datas, pillow_binaries, pillow_hiddenimports = collect_all("PIL")
try:
    usb_datas, usb_binaries, usb_hiddenimports = collect_all("usb")
except Exception:
    usb_datas, usb_binaries, usb_hiddenimports = [], [], []

hiddenimports = sorted(
    set(
        collect_submodules("local_print_bridge")
        + pillow_hiddenimports
        + usb_hiddenimports
        + [
            "local_print_bridge.server",
            "local_print_bridge.service_host",
            "local_print_bridge.config",
            "local_print_bridge.receipt",
            "local_print_bridge.kitchen",
            "local_print_bridge.raster",
        ]
    )
)

font_datas = [
    (str(path), "local_print_bridge/fonts")
    for path in (bridge_root / "fonts").glob("*.ttf")
]
datas = pillow_datas + usb_datas + font_datas
binaries = pillow_binaries + usb_binaries

a = Analysis(
    [str(bridge_root / "windows" / "bridge_entry.py")],
    pathex=[str(project_root)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["pythoncom", "pywintypes", "win32print", "win32ui"],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

# One-folder build: the bridge runs as the single process launchd started, so
# it can take over launchd's listening socket (on-demand start). A one-file
# build re-executes itself as a child and launchd refuses the child.
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="IbulPrintBridge",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name="IbulPrintBridge",
)
