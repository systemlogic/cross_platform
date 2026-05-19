#!/usr/bin/env python3
"""Build-time bundler: assembles a self-contained Python executable.

Invoked as a Bazel action by py_self_executable. Produces a shell script
whose tail is a tar.gz payload containing:
  python/        — the CPython runtime (copied from the toolchain repo)
  app/           — all source files laid out in their package structure
  site-packages/ — pip wheel contents (merged into Python's site-packages)

The shell header self-extracts to ~/.cache/py_exe/<hash>/ on first run.
"""
import argparse
import hashlib
import os
import shutil
import stat
import tarfile
import tempfile


def _copy_tree(src, dst):
    """Copy src directory tree to dst, dereferencing ALL symlinks.

    Bazel represents external-repo files as symlinks into its output base.
    Preserving those symlinks would leave the bundle's Python binary pointing
    back to the Bazel execroot, breaking prefix detection when the executable
    runs outside of Bazel.  Always resolving to the real path produces a
    self-contained, relocatable directory.
    """
    os.makedirs(dst, exist_ok=True)
    for item in os.listdir(src):
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        real_s = os.path.realpath(s)   # resolve ALL symlinks (Bazel + internal)
        if os.path.isdir(real_s):
            _copy_tree(real_s, d)
        else:
            shutil.copy2(real_s, d)


def _find_site_packages(python_root):
    """Find the site-packages directory inside the Python runtime tree."""
    for root, dirs, _ in os.walk(python_root):
        if os.path.basename(root) == "site-packages":
            return root
    # Fallback: create one under lib/
    candidate = os.path.join(python_root, "lib", "site-packages")
    os.makedirs(candidate, exist_ok=True)
    return candidate


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--bootstrap", required=True, help="Path to bootstrap.sh.tpl")
    p.add_argument("--output", required=True, help="Output file path")
    p.add_argument("--python-runtime-root", required=True,
                   help="Root dir of the CPython install (contains bin/, lib/)")
    p.add_argument("--main", required=True,
                   help="Relative path of the entry-point inside app/, e.g. main.py")
    p.add_argument("--srcs", nargs="*", default=[],
                   help="Source files to include (Bazel exec-root paths)")
    p.add_argument("--src-strip-prefixes", nargs="*", default=[],
                   help="Path prefixes to strip when placing srcs under app/")
    p.add_argument("--pip-dirs", nargs="*", default=[],
                   help="Directories containing extracted pip wheel contents")
    args = p.parse_args()

    with tempfile.TemporaryDirectory() as tmpdir:
        bundle = os.path.join(tmpdir, "bundle")
        os.makedirs(bundle)

        # --- Python runtime ---
        python_dst = os.path.join(bundle, "python")
        _copy_tree(args.python_runtime_root, python_dst)

        # Make interpreter executable (extraction may drop bits)
        for exe_name in ("python3", "python3.12", "python3.11", "python3.10"):
            exe = os.path.join(python_dst, "bin", exe_name)
            if os.path.exists(exe):
                os.chmod(exe, os.stat(exe).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

        # --- Pip dependencies → site-packages ---
        if args.pip_dirs:
            site_pkgs = _find_site_packages(python_dst)
            for dep_dir in args.pip_dirs:
                if not os.path.isdir(dep_dir):
                    continue
                for item in os.listdir(dep_dir):
                    s = os.path.join(dep_dir, item)
                    d = os.path.join(site_pkgs, item)
                    if os.path.isdir(s):
                        _copy_tree(s, d)
                    else:
                        shutil.copy2(s, d)

        # --- Source files → app/ ---
        app_dir = os.path.join(bundle, "app")
        os.makedirs(app_dir)
        for src_path in args.srcs:
            rel = src_path
            for prefix in args.src_strip_prefixes:
                prefix = prefix.rstrip("/") + "/"
                if src_path.startswith(prefix):
                    rel = src_path[len(prefix):]
                    break
            dst = os.path.join(app_dir, rel)
            os.makedirs(os.path.dirname(dst) or app_dir, exist_ok=True)
            shutil.copy2(src_path, dst)

        # --- Build tar.gz payload ---
        payload_path = os.path.join(tmpdir, "payload.tar.gz")
        with tarfile.open(payload_path, "w:gz") as tf:
            tf.add(bundle, arcname=".")

        # --- Hash payload for cache key ---
        h = hashlib.sha256()
        with open(payload_path, "rb") as f:
            while True:
                chunk = f.read(65536)
                if not chunk:
                    break
                h.update(chunk)
        bundle_hash = h.hexdigest()[:24]

        # --- Render bootstrap template ---
        with open(args.bootstrap) as f:
            template = f.read()

        # Use a fixed-width offset placeholder so the byte length of the
        # script is constant before and after substituting the real value.
        OFFSET_WIDTH = 20
        placeholder = "0" * OFFSET_WIDTH
        script = template.replace("__HASH__", bundle_hash)
        script = script.replace("__MAIN__", args.main)
        script = script.replace("__OFFSET__", placeholder)

        script_bytes = script.encode("utf-8")
        real_offset = len(script_bytes)

        # Substitute real offset (same width, zero-padded)
        real_offset_str = str(real_offset).zfill(OFFSET_WIDTH)
        script_final = script.replace(placeholder, real_offset_str)
        script_final_bytes = script_final.encode("utf-8")

        assert len(script_final_bytes) == real_offset, (
            "Bootstrap byte length changed after offset substitution — "
            "the offset field must stay the same width."
        )

        # --- Write output: bootstrap header + binary payload ---
        with open(args.output, "wb") as out:
            out.write(script_final_bytes)
            with open(payload_path, "rb") as f:
                shutil.copyfileobj(f, out)

        os.chmod(args.output, 0o755)


if __name__ == "__main__":
    main()
