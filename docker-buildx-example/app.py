#!/usr/bin/env python3
import platform
import sys

def main():
    print(f"Hello from Python {sys.version.split()[0]}!")
    print(f"Running on {platform.machine()} architecture")
    print(f"Platform: {platform.platform()}")

if __name__ == "__main__":
    main() 