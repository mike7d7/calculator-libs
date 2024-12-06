#!/bin/sh
set -e

TARGET_ARCHS=("arm64")

CURL_VERSION="7.64.1"
OPENSSL_VERSION="3.4.0"
GMP_VERSION="6.3.0"
MPFR_VERSION="4.2.1"
XZ_VERSION="5.6.3"
ICONV_VERSION="1.17"
XML2_VERSION="2.13.5"
QALCULATE_VERSION="5.3.0"

ROOT_DIR=$(pwd)
WORKER=$(getconf _NPROCESSORS_ONLN)
BUILD_DIR_CURL="build/android/curl"
BUILD_DIR_OPENSSL="build/android/openssl"
BUILD_DIR_GMP="build/android/gmp"
BUILD_DIR_MPFR="build/android/mpfr"
BUILD_DIR_XZ="build/android/xz"
BUILD_DIR_ICONV="build/android/iconv"
BUILD_DIR_XML2="build/android/xml2"
BUILD_DIR_QALCULATE="build/android/qalculate"
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
            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="x86_64-linux-android-nm"
            export STRIP="llvm-strip"

            ./Configure android-arm64 no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared no-tests no-ui no-deprecated no-zlib -fPIC -DANDROID -D__ANDROID_API__=21 -Os -fuse-ld="$ANDROID_TOOLCHAIN/bin/ld" -static >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring OpenSSL for $CURRENT_ARCH"
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="aarch64-linux-android-nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export CXXFLAGS="$CFLAGS -fno-exceptions -fno-rtti"
            export LDFLAGS="-static"
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

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -mssse3 -mfpmath=sse -m64 -DANDROID -D__ANDROID_API__=21 -Os"
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
        --without-zlib >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring curl for $CURRENT_ARCH"
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

# gmp
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_GMP/build.log"

if [ -d "$BUILD_DIR_GMP/tar" ]; then
  rm -rf "$BUILD_DIR_GMP/tar"
fi
if [ -d "$BUILD_DIR_GMP/src" ]; then
  rm -rf "$BUILD_DIR_GMP/src"
fi
if [ -d "$BUILD_DIR_GMP/install" ]; then
  rm -rf "$BUILD_DIR_GMP/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_GMP/tar"
mkdir -p "$BUILD_DIR_GMP/src"
mkdir -p "$BUILD_DIR_GMP/install"

cd "$ROOT_DIR"
echo "Downloading GMP..."
curl -Lo "$BUILD_DIR_GMP/tar/gmp-$GMP_VERSION.tar.gz" "https://gmplib.org/download/gmp/gmp-$GMP_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading gmp"
echo "Uncompressing GMP..."
tar xzf "$BUILD_DIR_GMP/tar/gmp-$GMP_VERSION.tar.gz" -C "$BUILD_DIR_GMP/src" || fail "Error Uncompressing GMP"
cd "$BUILD_DIR_GMP/src/gmp-$GMP_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building GMP for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring GMP for $CURRENT_ARCH build..."
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="mold"
            export RANLIB="llvm-ranlib"
            export NM="nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export LDFLAGS="-lc++"

            ./configure --host=$HOST --enable-assembly=no --enable-static --enable-shared=no >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring GMP for $CURRENT_ARCH"
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

    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured GMP for $CURRENT_ARCH"

    echo "-> Compiling GMP for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling GMP for $CURRENT_ARCH"
    echo "-> Compiled GMP for $CURRENT_ARCH"

    echo "-> Installing GMP for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_GMP/install/gmp/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_GMP/install/gmp/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing GMP for $CURRENT_ARCH"
    echo "-> Installed GMP for $CURRENT_ARCH"

    echo "Successfully built GMP for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}gmp built successfully for all ARCH targets.${COLOR_END}"

# mpfr
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_MPFR/build.log"

if [ -d "$BUILD_DIR_MPFR/tar" ]; then
  rm -rf "$BUILD_DIR_MPFR/tar"
fi
if [ -d "$BUILD_DIR_MPFR/src" ]; then
  rm -rf "$BUILD_DIR_MPFR/src"
fi
if [ -d "$BUILD_DIR_MPFR/install" ]; then
  rm -rf "$BUILD_DIR_MPFR/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_MPFR/tar"
mkdir -p "$BUILD_DIR_MPFR/src"
mkdir -p "$BUILD_DIR_MPFR/install"

cd "$ROOT_DIR"
echo "Downloading MPFR..."
curl -Lo "$BUILD_DIR_MPFR/tar/mpfr-$MPFR_VERSION.tar.gz" "https://www.mpfr.org/mpfr-current/mpfr-$MPFR_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading gmp"
echo "Uncompressing MPFR..."
tar xzf "$BUILD_DIR_MPFR/tar/mpfr-$MPFR_VERSION.tar.gz" -C "$BUILD_DIR_MPFR/src" || fail "Error Uncompressing MPFR"
cd "$BUILD_DIR_MPFR/src/mpfr-$MPFR_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building MPFR for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring MPFR for $CURRENT_ARCH build..."
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export LDFLAGS="-static"

            ./configure --host=$HOST --with-gmp="$ROOT_DIR/$BUILD_DIR_GMP/install/gmp/$CURRENT_ARCH/usr/local" >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring GMP for $CURRENT_ARCH"
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

    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured MPFR for $CURRENT_ARCH"

    echo "-> Compiling MPFR for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling MPFR for $CURRENT_ARCH"
    echo "-> Compiled MPFR for $CURRENT_ARCH"

    echo "-> Installing MPFR for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_MPFR/install/mpfr/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_MPFR/install/mpfr/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing MPFR for $CURRENT_ARCH"
    rm $ROOT_DIR/$BUILD_DIR_MPFR/install/mpfr/$CURRENT_ARCH/usr/local/lib/libmpfr.la
    cp $ROOT_DIR/libmpfr.la $ROOT_DIR/$BUILD_DIR_MPFR/install/mpfr/$CURRENT_ARCH/usr/local/lib/libmpfr.la
    echo "-> Installed MPFR for $CURRENT_ARCH"

    echo "Successfully built MPFR for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}MPFR built successfully for all ARCH targets.${COLOR_END}"

# xz
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_XZ/build.log"

if [ -d "$BUILD_DIR_XZ/tar" ]; then
  rm -rf "$BUILD_DIR_XZ/tar"
fi
if [ -d "$BUILD_DIR_XZ/src" ]; then
  rm -rf "$BUILD_DIR_XZ/src"
fi
if [ -d "$BUILD_DIR_XZ/install" ]; then
  rm -rf "$BUILD_DIR_XZ/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_XZ/tar"
mkdir -p "$BUILD_DIR_XZ/src"
mkdir -p "$BUILD_DIR_XZ/install"

cd "$ROOT_DIR"
echo "Downloading XZ..."
curl -Lo "$BUILD_DIR_XZ/tar/xz-$XZ_VERSION.tar.gz" "https://github.com/tukaani-project/xz/releases/download/v5.6.3/xz-$XZ_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading xz"
echo "Uncompressing XZ..."
tar xzf "$BUILD_DIR_XZ/tar/xz-$XZ_VERSION.tar.gz" -C "$BUILD_DIR_XZ/src" || fail "Error Uncompressing GMP"
cd "$BUILD_DIR_XZ/src/xz-$XZ_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building XZ for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring XZ for $CURRENT_ARCH build..."
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export LDFLAGS="-static"

            ./configure --host=$HOST >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring XZ for $CURRENT_ARCH"
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

    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured XZ for $CURRENT_ARCH"

    echo "-> Compiling XZ for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling XZ for $CURRENT_ARCH"
    echo "-> Compiled XZ for $CURRENT_ARCH"

    echo "-> Installing XZ for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_XZ/install/xz/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_XZ/install/xz/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing XZ for $CURRENT_ARCH"
    echo "-> Installed XZ for $CURRENT_ARCH"

    echo "Successfully built XZ for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}xz built successfully for all ARCH targets.${COLOR_END}"

# iconv
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_ICONV/build.log"

if [ -d "$BUILD_DIR_ICONV/tar" ]; then
  rm -rf "$BUILD_DIR_ICONV/tar"
fi
if [ -d "$BUILD_DIR_ICONV/src" ]; then
  rm -rf "$BUILD_DIR_ICONV/src"
fi
if [ -d "$BUILD_DIR_ICONV/install" ]; then
  rm -rf "$BUILD_DIR_ICONV/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_ICONV/tar"
mkdir -p "$BUILD_DIR_ICONV/src"
mkdir -p "$BUILD_DIR_ICONV/install"

cd "$ROOT_DIR"
echo "Downloading ICONV..."
curl -Lo "$BUILD_DIR_ICONV/tar/iconv-$ICONV_VERSION.tar.gz" "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$ICONV_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading iconv"
echo "Uncompressing ICONV..."
tar xzf "$BUILD_DIR_ICONV/tar/iconv-$ICONV_VERSION.tar.gz" -C "$BUILD_DIR_ICONV/src" || fail "Error Uncompressing ICONV"
cd "$BUILD_DIR_ICONV/src/libiconv-$ICONV_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building ICONV for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring ICONV for $CURRENT_ARCH build..."
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="ld"
            export RANLIB="llvm-ranlib"
            export NM="nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export LDFLAGS="-lc++"

            ./configure --host=$HOST --enable-static --enable-shared=no >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring ICONV for $CURRENT_ARCH"
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

    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured ICONV for $CURRENT_ARCH"

    echo "-> Compiling ICONV for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling ICONV for $CURRENT_ARCH"
    echo "-> Compiled ICONV for $CURRENT_ARCH"

    echo "-> Installing ICONV for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_ICONV/install/iconv/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_ICONV/install/iconv/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing ICONV for $CURRENT_ARCH"
    echo "-> Installed ICONV for $CURRENT_ARCH"

    echo "Successfully built ICONV for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}iconv built successfully for all ARCH targets.${COLOR_END}"

# xml2
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_XML2/build.log"

if [ -d "$BUILD_DIR_XML2/tar" ]; then
  rm -rf "$BUILD_DIR_XML2/tar"
fi
if [ -d "$BUILD_DIR_XML2/src" ]; then
  rm -rf "$BUILD_DIR_XML2/src"
fi
if [ -d "$BUILD_DIR_XML2/install" ]; then
  rm -rf "$BUILD_DIR_XML2/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_XML2/tar"
mkdir -p "$BUILD_DIR_XML2/src"
mkdir -p "$BUILD_DIR_XML2/install"

cd "$ROOT_DIR"
echo "Downloading XML2..."
curl -Lo "$BUILD_DIR_XML2/tar/xml2-$XML2_VERSION.tar.gz" "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v$XML2_VERSION/libxml2-v$XML2_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading xml2"
echo "Uncompressing XML2..."
tar xzf "$BUILD_DIR_XML2/tar/xml2-$XML2_VERSION.tar.gz" -C "$BUILD_DIR_XML2/src" || fail "Error Uncompressing XML2"
cd "$BUILD_DIR_XML2/src/libxml2-v$XML2_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building XML2 for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring XML2 for $CURRENT_ARCH build..."
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="mold"
            export RANLIB="llvm-ranlib"
            export NM="nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"
            export CPPFLAGS="$CFLAGS"
            export LDFLAGS="-L$ROOT_DIR/$BUILD_DIR_XZ/install/xz/arm64/usr/local/lib/liblzma.a -static"

            ./autogen.sh --host=$HOST --enable-static --disable-shared --without-python --with-lzma="$ROOT_DIR/$BUILD_DIR_XZ/install/xz/$CURRENT_ARCH/usr/local/lib/liblzma.a" >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring XML2 for $CURRENT_ARCH"
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

    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured XML2 for $CURRENT_ARCH"

    echo "-> Compiling XML2 for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling XML2 for $CURRENT_ARCH"
    echo "-> Compiled XML2 for $CURRENT_ARCH"

    echo "-> Installing XML2 for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_XML2/install/xml2/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_XML2/install/xml2/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing XML2 for $CURRENT_ARCH"
    echo "-> Installed XML2 for $CURRENT_ARCH"

    echo "Successfully built XML2 for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}xml2 built successfully for all ARCH targets.${COLOR_END}"

# qalculate
cd "$ROOT_DIR" || exit 1

LOG_FILE="$ROOT_DIR/$BUILD_DIR_QALCULATE/build.log"

if [ -d "$BUILD_DIR_QALCULATE/tar" ]; then
  rm -rf "$BUILD_DIR_QALCULATE/tar"
fi
if [ -d "$BUILD_DIR_QALCULATE/src" ]; then
  rm -rf "$BUILD_DIR_QALCULATE/src"
fi
if [ -d "$BUILD_DIR_QALCULATE/install" ]; then
  rm -rf "$BUILD_DIR_QALCULATE/install"
fi

if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    touch "$LOG_FILE"
fi

mkdir -p "$BUILD_DIR_QALCULATE/tar"
mkdir -p "$BUILD_DIR_QALCULATE/src"
mkdir -p "$BUILD_DIR_QALCULATE/install"

cd "$ROOT_DIR"
echo "Downloading QALCULATE..."
curl -Lo "$BUILD_DIR_QALCULATE/tar/qalculate-$QALCULATE_VERSION.tar.gz" "https://github.com/Qalculate/libqalculate/releases/download/v$QALCULATE_VERSION/libqalculate-$QALCULATE_VERSION.tar.gz" >> "$LOG_FILE" 2>&1 || fail "Error Downloading qalculate"
echo "Uncompressing QALCULATE..."
tar xzf "$BUILD_DIR_QALCULATE/tar/qalculate-$QALCULATE_VERSION.tar.gz" -C "$BUILD_DIR_QALCULATE/src" || fail "Error Uncompressing QALCULATE"
cd "$BUILD_DIR_QALCULATE/src/libqalculate-$QALCULATE_VERSION"

for CURRENT_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "Building QALCULATE for $CURRENT_ARCH build..."

    make clean 1>& /dev/null || true

    echo "-> Configuring QALCULATE for $CURRENT_ARCH build..."
    patch -u $ROOT_DIR/$BUILD_DIR_QALCULATE/src/libqalculate-$QALCULATE_VERSION/libqalculate/util.cc -i $ROOT_DIR/pthread.patch >> "$LOG_FILE" 2>&1 || fail "-> Error Patching QALCULATE for $CURRENT_ARCH"
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

            export CC="aarch64-linux-android21-clang"
            export CXX="aarch64-linux-android21-clang++"
            export AR="llvm-ar"
            export AS="$CC"
            export LD="mold"
            export RANLIB="llvm-ranlib"
            export NM="nm"
            export STRIP="llvm-strip"

            export CFLAGS="--sysroot=$ANDROID_TOOLCHAIN/sysroot -fPIC -DANDROID -D__ANDROID_API__=21 -Os"

            export CPPFLAGS="-I$ROOT_DIR/$BUILD_DIR_GMP/install/gmp/arm64/usr/local/include -I$ROOT_DIR/$BUILD_DIR_MPFR/install/mpfr/arm64/usr/local/include -I$ROOT_DIR/$BUILD_DIR_ICONV/install/iconv/arm64/usr/local/include -I$ROOT_DIR/$BUILD_DIR_XML2/install/xml2/arm64/usr/local/include/libxml2 $CFLAGS"
            export LDFLAGS="-static -L$ROOT_DIR/$BUILD_DIR_GMP/install/gmp/arm64/usr/local/lib -L$ROOT_DIR/$BUILD_DIR_MPFR/install/mpfr/arm64/usr/local/lib -L$ROOT_DIR/$BUILD_DIR_ICONV/install/iconv/arm64/usr/local/lib -L$ROOT_DIR/$BUILD_DIR_XML2/install/xml2/arm64/usr/local/lib/libxml2.a -Wl,--allow-shlib-undefined"
            QALCULATE_LIBXML_CFLAGS="$ROOT_DIR/$BUILD_DIR_XML2/install/xml2/arm64/usr/local/include/libxml2"
            QALCULATE_LIBXML_LIBS="$ROOT_DIR/$BUILD_DIR_XML2/install/xml2/arm64/usr/local/lib/libxml2.a"
            QALCULATE_LIBCURL_CFLAGS="-I$ROOT_DIR/$BUILD_DIR_CURL/install/curl/arm64/include"
            QALCULATE_LIBCURL_LIBS="$ROOT_DIR/$BUILD_DIR_CURL/install/curl/arm64/lib/libcurl.a"
            ./autogen.sh --host=$HOST --enable-static --disable-shared --without-icu --without-libintl-prefix --enable-compiled-definitions LIBXML_CFLAGS=$QALCULATE_LIBXML_CFLAGS LIBXML_LIBS=$QALCULATE_LIBXML_LIBS LIBCURL_CFLAGS=$QALCULATE_LIBCURL_CFLAGS LIBCURL_LIBS=$QALCULATE_LIBCURL_LIBS >> "$LOG_FILE" 2>&1 || fail "-> Error Configuring QALCULATE for $CURRENT_ARCH"
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

    # sed -i '' -e 's~#define HAVE_STRDUP~//#define HAVE_STRDUP~g' configure
    echo "-> Configured QALCULATE for $CURRENT_ARCH"

    echo "-> Compiling QALCULATE for $CURRENT_ARCH..."
    make -j "$WORKER" >> "$LOG_FILE" 2>&1 || fail "-> Error Compiling QALCULATE for $CURRENT_ARCH"
    echo "-> Compiled QALCULATE for $CURRENT_ARCH"

    echo "-> Installing QALCULATE for $CURRENT_ARCH to $ROOT_DIR/$BUILD_DIR_QALCULATE/install/qalculate/$CURRENT_ARCH..."
    make install DESTDIR="$ROOT_DIR/$BUILD_DIR_QALCULATE/install/qalculate/$CURRENT_ARCH" >> "$LOG_FILE" 2>&1 || fail "-> Error Installing QALCULATE for $CURRENT_ARCH"
    echo "-> Installed QALCULATE for $CURRENT_ARCH"

    echo "Successfully built QALCULATE for $CURRENT_ARCH"
done

echo -e "${COLOR_GREEN}qalculate built successfully for all ARCH targets.${COLOR_END}"
exit 0
