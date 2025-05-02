#!/usr/bin/env python3
import platform
import sys

def main():
    print(f"Hello from Python {sys.version.split()[0]}!")
    print(f"Running on {platform.machine()} architecture")
    print(f"Platform: {platform.platform()}")
    
    # Show build artifacts from both architectures
    print("\nBuild artifacts from both architectures:")
    
    print("\nAMD64 build info:")
    with open("amd64_arch.txt", "r") as f:
        print(f.read().strip())
    with open("amd64_message.txt", "r") as f:
        print(f.read().strip())
        
    print("\nARM64 build info:")
    with open("arm64_arch.txt", "r") as f:
        print(f.read().strip())
    with open("arm64_message.txt", "r") as f:
        print(f.read().strip())

if __name__ == "__main__":
    main() 