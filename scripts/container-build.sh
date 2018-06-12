#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

# Inner script to run inside Docker containers to build the 
# GNU MCU Eclipse RISC-V Embedded GCC distribution packages.

# For native builds, it runs on the host (macOS build cases,
# and development builds for GNU/Linux).

# -----------------------------------------------------------------------------

# ----- Identify helper scripts. -----

build_script_path=$0
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path=$(pwd)/$0
fi

script_folder_path="$(dirname ${build_script_path})"
script_folder_name="$(basename ${script_folder_path})"

defines_script_path="${script_folder_path}/defs-source.sh"
echo "Definitions source script: \"${defines_script_path}\"."
source "${defines_script_path}"

TARGET_OS=""
TARGET_BITS=""
HOST_UNAME=""

# This file is generated by the host build script.
host_defines_script_path="${script_folder_path}/host-defs-source.sh"
echo "Host definitions source script: \"${host_defines_script_path}\"."
source "${host_defines_script_path}"

container_lib_functions_script_path="${script_folder_path}/${CONTAINER_LIB_FUNCTIONS_SCRIPT_NAME}"
echo "Container lib functions source script: \"${container_lib_functions_script_path}\"."
source "${container_lib_functions_script_path}"

container_app_functions_script_path="${script_folder_path}/${CONTAINER_APP_FUNCTIONS_SCRIPT_NAME}"
echo "Container app functions source script: \"${container_app_functions_script_path}\"."
source "${container_app_functions_script_path}"

container_functions_script_path="${script_folder_path}/helper/container-functions-source.sh"
echo "Container helper functions source script: \"${container_functions_script_path}\"."
source "${container_functions_script_path}"

# -----------------------------------------------------------------------------

WITH_STRIP="y"
WITH_PDF="y"
WITH_HTML="n"
IS_DEVELOP=""
IS_DEBUG=""

# Attempts to use 8 occasionally failed, reduce if necessary.
if [ "$(uname)" == "Darwin" ]
then
  JOBS="--jobs=$(sysctl -n hw.ncpu)"
else
  JOBS="--jobs=$(grep ^processor /proc/cpuinfo|wc -l)"
fi

while [ $# -gt 0 ]
do

  case "$1" in

    --disable-strip)
      WITH_STRIP="n"
      shift
      ;;

    --without-pdf)
      WITH_PDF="n"
      shift
      ;;

    --with-pdf)
      WITH_PDF="y"
      shift
      ;;

    --without-html)
      WITH_HTML="n"
      shift
      ;;

    --with-html)
      WITH_HTML="y"
      shift
      ;;

    --jobs)
      JOBS="--jobs=$2"
      shift 2
      ;;

    --develop)
      IS_DEVELOP="y"
      shift
      ;;

    --debug)
      IS_DEBUG="y"
      shift
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;

  esac

done

if [ "${IS_DEBUG}" == "y" ]
then
  WITH_STRIP="n"
fi

# -----------------------------------------------------------------------------

start_timer

detect_container

# Fix the texinfo path in XBB v1.
if [ -f "/.dockerenv" -a -f "/opt/xbb/xbb.sh" ]
then
  if [ "${TARGET_BITS}" == "64" ]
  then
    sed -e "s|texlive/bin/\$\(uname -p\)-linux|texlive/bin/x86_64-linux|" /opt/xbb/xbb.sh > /opt/xbb/xbb-source.sh
  elif [ "${TARGET_BITS}" == "32" ]
  then
    sed -e "s|texlive/bin/[$][(]uname -p[)]-linux|texlive/bin/i386-linux|" /opt/xbb/xbb.sh > /opt/xbb/xbb-source.sh
  fi

  echo /opt/xbb/xbb-source.sh
  cat /opt/xbb/xbb-source.sh
fi

prepare_prerequisites

if [ -f "/.dockerenv" ]
then
  ( 
    xbb_activate

    # Remove references to libfl.so, to force a static link and
    # avoid references to unwanted shared libraries in binutils.
    sed -i -e "s/dlname=.*/dlname=''/" -e "s/library_names=.*/library_names=''/" "${XBB_FOLDER}"/lib/libfl.la

    echo "${XBB_FOLDER}"/lib/libfl.la
    cat "${XBB_FOLDER}"/lib/libfl.la
  )
fi

# -----------------------------------------------------------------------------

UNAME="$(uname)"

# Make all tools choose gcc, not the old cc.
if [ "${UNAME}" == "Darwin" ]
then
  # For consistency, even on macOS, prefer GCC 7 over clang.
  # (Also because all GCC pre 7 versions fail with 'bracket nesting level 
  # exceeded' with clang; not to mention the too many warnings.)
  # However the oof-the-shelf GCC 7 has a problem, and requires patching,
  # otherwise the generated GDB fails with SIGABRT; to test use 'set 
  # language auto').
  export CC=gcc-7.2.0-patched
  export CXX=g++-7.2.0-patched
elif [ "${TARGET_OS}" == "linux" ]
then
  export CC=gcc
  export CXX=g++
fi

EXTRA_CFLAGS="-ffunction-sections -fdata-sections -m${TARGET_BITS} -pipe"
EXTRA_CXXFLAGS="-ffunction-sections -fdata-sections -m${TARGET_BITS} -pipe"

if [ "${IS_DEBUG}" == "y" ]
then
  EXTRA_CFLAGS+=" -g -O0"
  EXTRA_CXXFLAGS+=" -g -O0"
else
  EXTRA_CFLAGS+=" -O2"
  EXTRA_CXXFLAGS+=" -O2"
fi

EXTRA_CPPFLAGS="-I${INSTALL_FOLDER_PATH}"/include
EXTRA_LDFLAGS_LIB="-L${INSTALL_FOLDER_PATH}"/lib
EXTRA_LDFLAGS="${EXTRA_LDFLAGS_LIB}"
if [ "${IS_DEBUG}" == "y" ]
then
  EXTRA_LDFLAGS+=" -g"
fi

if [ "${TARGET_OS}" == "macos" ]
then
  # Note: macOS linker ignores -static-libstdc++, so 
  # libstdc++.6.dylib should be handled.
  EXTRA_LDFLAGS_APP="${EXTRA_LDFLAGS} -Wl,-dead_strip"
elif [ "${TARGET_OS}" == "linux" ]
then
  # Do not add -static here, it fails.
  # Do not try to link pthread statically, it must match the system glibc.
  EXTRA_LDFLAGS_APP+="${EXTRA_LDFLAGS} -static-libstdc++ -Wl,--gc-sections"
elif [ "${TARGET_OS}" == "win" ]
then
  # CRT_glob is from ARM script
  # -static avoids libwinpthread-1.dll 
  # -static-libgcc avoids libgcc_s_sjlj-1.dll 
  EXTRA_LDFLAGS_APP+="${EXTRA_LDFLAGS} -static -static-libgcc -static-libstdc++ -Wl,--gc-sections"
fi

export PKG_CONFIG=pkg-config-verbose
if [ "${TARGET_OS}" == "linux" -a "${TARGET_BITS}" == "64" ]
then
  export PKG_CONFIG_LIBDIR="${INSTALL_FOLDER_PATH}"/lib64/pkgconfig:"${INSTALL_FOLDER_PATH}"/lib/pkgconfig
else
  export PKG_CONFIG_LIBDIR="${INSTALL_FOLDER_PATH}"/lib/pkgconfig
fi

APP_PREFIX="${INSTALL_FOLDER_PATH}/${APP_LC_NAME}"
APP_PREFIX_DOC="${APP_PREFIX}"/share/doc

APP_PREFIX_NANO="${INSTALL_FOLDER_PATH}/${APP_LC_NAME}"-nano

# The \x2C is a comma in hex; without this trick the regular expression
# that processes this string in the Makefile, silently fails and the 
# bfdver.h file remains empty.
BRANDING="${BRANDING}\x2C ${TARGET_BITS}-bits"
CFLAGS_OPTIMIZATIONS_FOR_TARGET="-ffunction-sections -fdata-sections -O2"

OPENOCD_PROJECT_NAME="openocd"

# Keep them in sync with combo archive content.
if [[ "${RELEASE_VERSION}" =~ 0\.10\.0-7 ]]
then

  # ---------------------------------------------------------------------------

  OPENOCD_VERSION="0.10.0-7"
 
  OPENOCD_GIT_BRANCH=${OPENOCD_GIT_BRANCH:-"gnu-mcu-eclipse-dev"}
  OPENOCD_GIT_COMMIT=${OPENOCD_GIT_COMMIT:-"20463c28affea880d167b000192785a48f8974ca"}
  
  BUILD_GIT_PATH="${WORK_FOLDER_PATH}"/build.git

  # ---------------------------------------------------------------------------

  LIBUSB1_VERSION="1.0.20"
  LIBUSB0_VERSION="0.1.5"
  LIBUSB_W32_VERSION="1.2.6.0"
  LIBFTDI_VERSION="1.2"
  LIBICONV_VERSION="1.15"
  HIDAPI_VERSION="0.8.0-rc1"

  # ---------------------------------------------------------------------------
elif [[ "${RELEASE_VERSION}" =~ 0\.10\.0-8 ]]
then

  # ---------------------------------------------------------------------------

  OPENOCD_VERSION="0.10.0-8"
 
  OPENOCD_GIT_BRANCH=${OPENOCD_GIT_BRANCH:-"gnu-mcu-eclipse-dev"}
  OPENOCD_GIT_COMMIT=${OPENOCD_GIT_COMMIT:-"af359c18327b9852219ddab74c7fe175853f10ae"}
  
  BUILD_GIT_PATH="${WORK_FOLDER_PATH}"/build.git

  # ---------------------------------------------------------------------------

  LIBUSB1_VERSION="1.0.20"
  LIBUSB0_VERSION="0.1.5"
  LIBUSB_W32_VERSION="1.2.6.0"
  LIBFTDI_VERSION="1.2"
  LIBICONV_VERSION="1.15"
  HIDAPI_VERSION="0.8.0-rc1"

  # ---------------------------------------------------------------------------
else
  echo "Unsupported version ${RELEASE_VERSION}."
  exit 1
fi

# -----------------------------------------------------------------------------

OPENOCD_SRC_FOLDER_NAME=${OPENOCD_SRC_FOLDER_NAME:-"${OPENOCD_PROJECT_NAME}.git"}
OPENOCD_GIT_URL=${OPENOCD_GIT_URL:-"https://github.com/gnu-mcu-eclipse/openocd.git"}

OPENOCD_FOLDER_NAME="openocd-${OPENOCD_VERSION}"

# -----------------------------------------------------------------------------

echo
echo "Here we go..."
echo

# -----------------------------------------------------------------------------
# Build dependent libraries.

do_libusb1
if [ "${TARGET_OS}" != "win" ]
then
  do_libusb0
else
  do_libusb_w32
fi

do_libftdi

do_libiconv

do_hidapi

# -----------------------------------------------------------------------------

do_openocd

# -----------------------------------------------------------------------------

check_binaries

copy_gme_files

create_archive

# Change ownership to non-root Linux user.
fix_ownership

# -----------------------------------------------------------------------------

echo
echo "Done."

stop_timer

exit 0

# -----------------------------------------------------------------------------
