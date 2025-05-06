#!/bin/bash

# Script to build OpenSSL 3.x static libraries for Android (32-bit and 64-bit) on macOS (or other OS, with modifications)

# Configuration variables
OPENSSL_VERSION="3.5.0"
ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/29.0.13113456"  # Replace with your NDK path
ANDROID_API=21
BUILD_DIR="build"
OPENSSL_DIR="openssl-$OPENSSL_VERSION"
ARCHS=("armeabi-v7a" "arm64-v8a")
CONFIG_TARGETS=("android-arm" "android-arm64")

# Ensure NDK path is valid
if [ ! -d "$ANDROID_NDK_HOME" ]; then
  echo "Error: ANDROID_NDK_HOME is not set or invalid. Please set it to the NDK path."
  exit 1
fi

# Set up environment
export ANDROID_NDK_HOME
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin:$PATH"

# Step 1: Prepare the Build Environment
echo "Setting up build environment..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || exit 1

# Download and extract OpenSSL if not already present
if [ ! -d "$OPENSSL_DIR" ]; then
  OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
  echo "Downloading OpenSSL $OPENSSL_VERSION from $OPENSSL_URL"
  curl -L -O "$OPENSSL_URL"
  tar -xzf "openssl-$OPENSSL_VERSION.tar.gz"
fi

# Convert OPENSSL_DIR to an absolute path
ABS_OPENSSL_DIR="$(pwd)/$OPENSSL_DIR"
cd "$OPENSSL_DIR" || exit 1

# Step 2 & 3: Build for each architecture
for ((i=0; i<${#ARCHS[@]}; i++)); do
  ARCH="${ARCHS[$i]}"
  CONFIG_TARGET="${CONFIG_TARGETS[$i]}"
  PREFIX="$ABS_OPENSSL_DIR/build/$ARCH"
  
  echo "Building OpenSSL for $ARCH..."

  # Configure OpenSSL
  ./Configure "$CONFIG_TARGET" \
    -D__ANDROID_API__="$ANDROID_API" \
    no-shared \
    no-ssl2 no-ssl3 no-comp no-hw no-engine \
    --prefix="$PREFIX" \
    --openssldir="$PREFIX" || {
    echo "Configuration failed for $ARCH"
    exit 1
  }

  # Modify Makefile to create unversioned libraries (libcrypto.so, libssl.so)
  sed -i '' 's/SHLIB_EXT=.so.[0-9]*/SHLIB_EXT=.so/' Makefile
  sed -i '' 's/SHLIB_VERSION_NUMBER=[0-9.]*/SHLIB_VERSION_NUMBER=/' Makefile

  # Build and install
  make -j$(sysctl -n hw.ncpu) || {
    echo "Build failed for $ARCH"
    exit 1
  }
  make install || {
    echo "Install failed for $ARCH"
    exit 1
  }

  # Clean up for the next architecture
  make clean
  echo "Completed build for $ARCH"
done

echo "Build completed successfully for all architectures!"
echo "Libraries are located in:"
for ARCH in "${ARCHS[@]}"; do
  echo "  - $ABS_OPENSSL_DIR/build/$ARCH/lib (libcrypto.a, libssl.a)"
done