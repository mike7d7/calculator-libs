#!/bin/sh
set -e

TARGET_ARCHS=("arm64")

CURL_VERSION="7.64.1"
OPENSSL_VERSION="3.4.0"

ROOT_DIR=$(pwd)
WORKER=$(getconf _NPROCESSORS_ONLN)
BUILD_DIR_CURL="build/android/curl"
BUILD_DIR_OPENSSL="build/android/openssl"
LOG_FILE="$ROOT_DIR/$BUILD_DIR_OPENSSL/build.log"

COLOR_GREEN="\033[38;5;48m"
COLOR_END="\033[0m"

#Clean up stale build...
if [ -d "$BUILD_DIR_OPENSSL/tar" ]; then
  rm -rf "$BUILD_DIR_OPENSSL/tar"
fi
if [ -d "$BUILD_DIR_OPENSSL/src" ]; then
  rm -rf "$BUILD_DIR_OPENSSL/src"
fi
if [ -d "$BUILD_DIR_OPENSSL/install" ]; then
  rm -rf "$BUILD_DIR_OPENSSL/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_OPENSSL/tar"
mkdir -p "$BUILD_DIR_OPENSSL/src"
mkdir -p "$BUILD_DIR_OPENSSL/install"

if [[ -z "$ANDROID_NDK_ROOT" ]]; then
    echo "set NDK_ROOT env variable"
    exit 1
fi

export ANDROID_TOOLCHAIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT
export PATH="$ANDROID_TOOLCHAIN/bin:$PATH"

error() {
    echo -e "$@" 1>&2
}

fail() {
    error "$@"
    exit 1
}

# OpenSSL
echo "Downloading OpenSSL..."
curl -Lo "$BUILD_DIR_OPENSSL/tar/openssl-$OPENSSL_VERSION.tar.gz" "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading OpenSSL"

echo "Uncompressing OpenSSL..."
tar xzf "${BUILD_DIR_OPENSSL}/tar/openssl-$OPENSSL_VERSION.tar.gz" -C "$BUILD_DIR_OPENSSL/src" || fail "Error Uncompressing OpenSSL"

cd "$BUILD_DIR_OPENSSL/src/openssl-$OPENSSL_VERSION"

export ANDROID_NDK_HOME="$NDK_ROOT"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building OpenSSL for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring OpenSSL for $CURRENT_ARCH build..."
    case $CURRENT_ARCH in
        armv7)
            export CC="armv7a-linux-androideabi16-clang"
            export CXX="armv7a-linux-androideabi16-clang++"
            export AR="arm-linux-androideabi-ar"
            export AS="arm-linux-androideabi-as"
            export LD="arm-linux-androideabi-ld"
            export RANLIB="arm-linux-androideabi-ranlib"
            export NM="arm-linux-androideabi-nm"
            export STRIP="arm-linux-androideabi-strip"

            ./Configure android-arm no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared no-tests no-ui no-deprecated zlib -Wl,--fix-cortex-a8 -fPIC -DANDROID -D__ANDROID_API__=16 -Os -fuse-ld="$ANDROID_TOOLCHAIN/bin/arm-linux-androideabi-ld" >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring OpenSSL for $CURRENT_ARCH"
        ;;
        arm64)
            export CC="x86_64-linux-android21-clang"
            export CXX="x86_64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="x86_64-linux-android-nm"
            export STRIP="llvm-strip"

            ./Configure android-arm64 no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared no-tests no-ui no-deprecated zlib -fPIC -DANDROID -D__ANDROID_API__=21 -Os -fuse-ld="$ANDROID_TOOLCHAIN/bin/ld" >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring OpenSSL for $CURRENT_ARCH"
        ;;
        x86)
            export CC="i686-linux-android16-clang"
            export CXX="i686-linux-android16-clang++"
            export AR="i686-linux-android-ar"
            export AS="i686-linux-android-as"
            export LD="i686-linux-android-ld"
            export RANLIB="i686-linux-android-ranlib"
            export NM="i686-linux-android-nm"
            export STRIP="i686-linux-android-strip"

            ./Configure android-x86 no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared no-tests no-ui no-deprecated zlib -mtune=intel -mssse3 -mfpmath=sse -m32 -fPIC -DANDROID -D__ANDROID_API__=16 -Os -fuse-ld="$ANDROID_TOOLCHAIN/bin/i686-linux-android-ld" >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring OpenSSL for $CURRENT_ARCH"
        ;;
        x86_64)
            export CC="x86_64-linux-android21-clang"
            export CXX="x86_64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="x86_64-linux-android-nm"
            export STRIP="llvm-strip"

            ./Configure android-x86_64 no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared no-tests no-ui no-deprecated zlib -mtune=intel -mssse3 -mfpmath=sse -m64 -fPIC -DANDROID -D__ANDROID_API__=21 -Os -fuse-ld="$ANDROID_TOOLCHAIN/bin/x86_64-linux-android-ld" >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring OpenSSL for $CURRENT_ARCH"
        ;;
    esac
    # sed -i '' -e "s!-O3!-Os!g" "Makefile" || exit 1
    echo "-> Configured OpenSSL for $CURRENT_ARCH"

    echo "-> Compiling OpenSSL for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling OpenSSL for $CURRENT_ARCH"
    echo "-> Compiled OpenSSL for $CURRENT_ARCH"

    echo "-> Installing OpenSSL for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_OPENSSL/install/openssl/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_OPENSSL/install/openssl/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing OpenSSL for $CURRENT_ARCH"
    echo "-> Installed OpenSSL for $CURRENT_ARCH"

    echo "Successfully built OpenSSL for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}OpenSSL Built Successfully for all ARCH targets.$COLOR_END"

# cURL
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_CURL/build.log"

if [ -d "$BUILD_DIR_CURL/tar" ]; then
  rm -rf "$BUILD_DIR_CURL/tar"
fi
if [ -d "$BUILD_DIR_CURL/src" ]; then
  rm -rf "$BUILD_DIR_CURL/src"
fi
if [ -d "$BUILD_DIR_CURL/install" ]; then
  rm -rf "$BUILD_DIR_CURL/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_CURL/tar"
mkdir -p "$BUILD_DIR_CURL/src"
mkdir -p "$BUILD_DIR_CURL/install"

cd "$ROOT_DIR"
echo "Downloading curl..."
curl -Lo "$BUILD_DIR_CURL/tar/curl-$CURL_VERSION.tar.gz" "https://curl.haxx.se/download/curl-$CURL_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading curl"
echo "Uncompressing curl..."
tar xzf "$BUILD_DIR_CURL/tar/curl-$CURL_VERSION.tar.gz" -C "$BUILD_DIR_CURL/src" || fail "Error Uncompressing curl"
cd "$BUILD_DIR_CURL/src/curl-$CURL_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building curl for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring curl for $CURRENT_ARCH build..."
    case $CURRENT_ARCH in
        armv7)
            export HOST="arm-linux-androideabi"

            export CC="armv7a-linux-androideabi16-clang"
            export CXX="armv7a-linux-androideabi16-clang++"
            export AR="arm-linux-androideabi-ar"
            export AS="arm-linux-androideabi-as"
            export LD="arm-linux-androideabi-ld"
            export RANLIB="arm-linux-androideabi-ranlib"
            export NM="arm-linux-androideabi-nm"
            export STRIP="arm-linux-androideabi-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -Wl,--fix-cortex-a8 -fPIC -DANDROID -D__ANDROID_API__=16 -Os"
            export CPPFLAGS="$CFLAGS"
            export CXXFLAGS="$CFLAGS -fno-exceptions -fno-rtti"
            export LDFLAGS="-Wl,--fix-cortex-a8"
        ;;
        arm64)
            export HOST="aarch64-linux-android"

            export CC="x86_64-linux-android21-clang"
            export CXX="x86_64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="x86_64-linux-android-nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export CXXFLAGS="$CFLAGS -fno-exceptions -fno-rtti"
            export LDFLAGS=""
        ;;
        x86)
            export HOST="i686-linux-android"

            export CC="i686-linux-android16-clang"
            export CXX="i686-linux-android16-clang++"
            export AR="i686-linux-android-ar"
            export AS="i686-linux-android-as"
            export LD="i686-linux-android-ld"
            export RANLIB="i686-linux-android-ranlib"
            export NM="i686-linux-android-nm"
            export STRIP="i686-linux-android-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -mtune=intel -mssse3 -mfpmath=sse -m32 -DANDROID -D__ANDROID_API__=16 -Os"
            export CPPFLAGS="$CFLAGS"
            export CXXFLAGS="$CFLAGS -fno-exceptions -fno-rtti"
            export LDFLAGS=""
        ;;
        x86_64)
            export HOST="x86_64-linux-android"

            export CC="x86_64-linux-android21-clang"
            export CXX="x86_64-linux-android21-clang++"
            export AR="x86_64-linux-android-ar"
            export AS="x86_64-linux-android-as"
            export LD="x86_64-linux-android-ld"
            export RANLIB="x86_64-linux-android-ranlib"
            export NM="x86_64-linux-android-nm"
            export STRIP="x86_64-linux-android-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -mtune=intel -mssse3 -mfpmath=sse -m64 -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export CXXFLAGS="$CFLAGS -fno-exceptions -fno-rtti"
            export LDFLAGS=""
        ;;
    esac

    ./configure --host="$HOST" \
        --prefix="$ROOT_DIR/$BUILD_DIR_CURL/install/curl/$CURRENT_ARCH" \
        --with-ssl="$ROOT_DIR/$BUILD_DIR_OPENSSL/install/openssl/$CURRENT_ARCH/usr/local" \
        --enable-static \
        --disable-shared \
        --disable-debug \
        --disable-curldebug \
        --enable-symbol-hiding \
        --enable-optimize \
        --disable-ares \
        --enable-threaded-resolver \
        --disable-manual \
        --disable-ipv6 \
        --enable-proxy \
        --enable-http \
        --disable-rtsp \
        --disable-ftp \
        --disable-file \
        --disable-ldap \
        --disable-ldaps \
        --disable-rtsp \
        --disable-dict \
        --disable-telnet \
        --disable-tftp \
        --disable-pop3 \
        --disable-imap \
        --disable-smtp \
        --disable-gopher \
        --without-libssh2 \
        --without-librtmp \
        --without-libidn \
        --without-ca-bundle \
        --without-ca-path \
        --without-winidn \
        --without-nghttp2 \
        --without-cyassl \
        --without-polarssl \
        --without-gnutls \
        --without-winssl \
        --with-zlib >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring curl for $CURRENT_ARCH"
    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured curl for $CURRENT_ARCH"

    echo "-> Compiling curl for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling curl for $CURRENT_ARCH"
    echo "-> Compiled curl for $CURRENT_ARCH"

    echo "-> Installing curl for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_CURL/install/curl/$CURRENT_ARCH..."
    make install >> "$LOG_FILE" 2>&1 || fail "-> Error Installing curl for $CURRENT_ARCH"
    echo "-> Installed curl for $CURRENT_ARCH"

    echo "Successfully built curl for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}curl built successfully for all ARCH targets.${COLOR_END}"
cd "$ROOT_DIR"
exit 0
