let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in
let
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "13.0";
    toolsVersion = "26.1.1";
    platformToolsVersion = "34.0.4";
    buildToolsVersions = [ "34.0.0" ];
    includeEmulator = false;
    emulatorVersion = "30.3.4";
    platformVersions = [ "34" ];
    includeSources = false;
    includeSystemImages = false;
    systemImageTypes = [ "google_apis_playstore" ];
    abiVersions = [ "arm64-v8a" ];
    cmakeVersions = [ "3.22.1" ];
    includeNDK = true;
    ndkVersions = ["26.2.11394342"];
    useGoogleAPIs = false;
    useGoogleTVAddOns = false;
  };
in

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    intltool
    autoconf
    libtool
    automake
    gnupatch
    cmake
    swig
    pkg-config
    jdk17
    ninja
    libclang
    clang
  ];
  shellHook = ''
    export ANDROID_HOME="${androidComposition.androidsdk}/libexec/android-sdk";
    export NDK="${androidComposition.androidsdk}/libexec/android-sdk";
    export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/26.2.11394342";
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/34.0.0/aapt2";
  '';
}
