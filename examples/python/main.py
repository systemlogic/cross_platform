"""Example entry point for the py_self_executable demo."""
import sys
import platform

def main():
    print("Python self-executable demo")
    print("  Python version :", platform.python_version())
    print("  Platform       :", platform.platform())
    print("  Executable     :", sys.executable)
    print("  argv           :", sys.argv[1:])

    try:
        import requests  # noqa: F401
        print("  requests       : available (version {})".format(requests.__version__))
    except ImportError:
        print("  requests       : not bundled (build without @pip_requests dep)")

if __name__ == "__main__":
    main()
