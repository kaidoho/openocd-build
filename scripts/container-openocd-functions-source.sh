# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the container build scripts.

# -----------------------------------------------------------------------------

function download_openocd() 
{
  if [ ! -d "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}" ]
  then
    (
      xbb_activate

      cd "${WORK_FOLDER_PATH}"
      git_clone "${OPENOCD_GIT_URL}" "${OPENOCD_GIT_BRANCH}" \
          "${OPENOCD_GIT_COMMIT}" "${OPENOCD_SRC_FOLDER_NAME}"
      cd "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}"
      git submodule update --init --recursive --remote
    )
  fi
}

# -----------------------------------------------------------------------------

function do_openocd()
{
    download_openocd

    (
      xbb_activate
      xbb_activate_this

      cd "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}"
      if [ ! -d "autom4te.cache" ]
      then
        ./bootstrap
      fi

      mkdir -p "${BUILD_FOLDER_PATH}/${OPENOCD_FOLDER_NAME}"
      cd "${BUILD_FOLDER_PATH}/${OPENOCD_FOLDER_NAME}"

      export JAYLINK_CFLAGS='${EXTRA_CFLAGS} -fvisibility=hidden'

      if [ "${TARGET_PLATFORM}" == "win32" ]
      then

        # --enable-minidriver-dummy -> configure error
        # --enable-zy1000 -> netinet/tcp.h: No such file or directory

        # --enable-openjtag_ftdi -> --enable-openjtag
        # --enable-presto_libftdi -> --enable-presto
        # --enable-usb_blaster_libftdi -> --enable-usb_blaster

        export OUTPUT_DIR="${BUILD_FOLDER_PATH}"
        
        export CFLAGS="${EXTRA_CXXFLAGS} -Wno-pointer-to-int-cast" 
        export CXXFLAGS="${EXTRA_CXXFLAGS}" 
        export LDFLAGS="${EXTRA_LDFLAGS_APP}"

        AMTJTAGACCEL="--enable-amtjtagaccel"
        # --enable-buspirate -> not supported on mingw
        BUSPIRATE="--disable-buspirate"
        GW18012="--enable-gw16012"
        PARPORT="--enable-parport"
        PARPORT_GIVEIO="--enable-parport-giveio"
        # --enable-sysfsgpio -> available only on Linux
        SYSFSGPIO="--disable-sysfsgpio"

      elif [ "${TARGET_PLATFORM}" == "linux" ]
      then

        # --enable-minidriver-dummy -> configure error

        # --enable-openjtag_ftdi -> --enable-openjtag
        # --enable-presto_libftdi -> --enable-presto
        # --enable-usb_blaster_libftdi -> --enable-usb_blaster

        export CFLAGS="${EXTRA_CFLAGS} -Wno-format-truncation -Wno-format-overflow"
        export CXXFLAGS="${EXTRA_CXXFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS_APP}" 
        export LIBS="-lpthread -lrt -ludev"

        AMTJTAGACCEL="--enable-amtjtagaccel"
        BUSPIRATE="--enable-buspirate"
        GW18012="--enable-gw16012"
        PARPORT="--enable-parport"
        PARPORT_GIVEIO="--enable-parport-giveio"
        SYSFSGPIO="--enable-sysfsgpio"

      elif [ "${TARGET_PLATFORM}" == "darwin" ]
      then

        # --enable-minidriver-dummy -> configure error

        # --enable-openjtag_ftdi -> --enable-openjtag
        # --enable-presto_libftdi -> --enable-presto
        # --enable-usb_blaster_libftdi -> --enable-usb_blaster

        export CFLAGS="${EXTRA_CFLAGS}"
        export CXXFLAGS="${EXTRA_CXXFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS_APP}"
        # export LIBS="-lobjc"

        # --enable-amtjtagaccel -> 'sys/io.h' file not found
        AMTJTAGACCEL="--disable-amtjtagaccel"
        BUSPIRATE="--enable-buspirate"
        # --enable-gw16012 -> 'sys/io.h' file not found
        GW18012="--disable-gw16012"
        PARPORT="--disable-parport"
        PARPORT_GIVEIO="--disable-parport-giveio"
        # --enable-sysfsgpio -> available only on Linux
        SYSFSGPIO="--disable-sysfsgpio"

      else

        echo "Unsupported target platorm ${TARGET_PLATFORM}."
        exit 1

      fi

      if [ ! -f "config.status" ]
      then

        # May be required for repetitive builds, because this is an executable built 
        # in place and using one for a different architecture may not be a good idea.
        rm -rfv "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}/jimtcl/autosetup/jimsh0"

        (
          echo
          echo "Running openocd configure..."
      
          bash "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}/configure" --help

          bash ${DEBUG} "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}/configure" \
            --prefix="${APP_PREFIX}"  \
            \
            --build=${BUILD} \
            --host=${HOST} \
            --target=${TARGET} \
            \
            --datarootdir="${INSTALL_FOLDER_PATH}" \
            --localedir="${APP_PREFIX}/share/locale"  \
            --mandir="${APP_PREFIX_DOC}/man"  \
            --pdfdir="${APP_PREFIX_DOC}/pdf"  \
            --infodir="${APP_PREFIX_DOC}/info" \
            --docdir="${APP_PREFIX_DOC}"  \
            \
            --disable-wextra \
            --disable-werror \
            --enable-dependency-tracking \
            \
            --enable-branding="${BRANDING}" \
            \
            --enable-aice \
            ${AMTJTAGACCEL} \
            --enable-armjtagew \
            --enable-at91rm9200 \
            --enable-bcm2835gpio \
            ${BUSPIRATE} \
            --enable-cmsis-dap \
            --enable-dummy \
            --enable-ep93xx \
            --enable-ftdi \
            ${GW18012} \
            --disable-ioutil \
            --enable-jlink \
            --enable-jtag_vpi \
            --disable-minidriver-dummy \
            --disable-oocd_trace \
            --enable-opendous \
            --enable-openjtag \
            --enable-osbdm \
            ${PARPORT} \
            --disable-parport-ppdev \
            ${PARPORT_GIVEIO} \
            --enable-presto \
            --enable-remote-bitbang \
            --enable-riscv \
            --enable-rlink \
            --enable-stlink \
            ${SYSFSGPIO} \
            --enable-ti-icdi \
            --enable-ulink \
            --enable-usb-blaster \
            --enable-usb_blaster_2 \
            --enable-usbprog \
            --enable-vsllink \
            --disable-zy1000-master \
            --disable-zy1000 \

        ) 2>&1 | tee "${INSTALL_FOLDER_PATH}/configure-openocd-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}/config-openocd-log.txt"

      fi

      (
        echo
        echo "Running openocd make..."
      
        make ${JOBS} bindir="bin" pkgdatadir=""
        if [ "${WITH_STRIP}" == "y" ]
        then
          make install-strip
        else
          make install  
        fi

        if [ "${TARGET_PLATFORM}" == "linux" ]
        then
          echo
          echo "Shared libraries:"
          echo "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"
          readelf -d "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}" | grep 'Shared library:'

          # For just in case, normally must be done by the make file.
          strip "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"  || true

          echo
          echo "Preparing libraries..."
          patch_linux_elf_origin "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"

          echo
          copy_dependencies_recursive "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"
        elif [ "${TARGET_PLATFORM}" == "darwin" ]
        then
          echo
          echo "Initial dynamic libraries:"
          otool -L "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"

          # For just in case, normally must be done by the make file.
          strip "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}" || true

          echo
          echo "Preparing libraries..."
          copy_dependencies_recursive "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"

          echo
          echo "Updated dynamic libraries:"
          otool -L "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}"
        elif [ "${TARGET_PLATFORM}" == "win32" ]
        then
          echo
          echo "Dynamic libraries:"
          echo "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe"
          ${CROSS_COMPILE_PREFIX}-objdump -x "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe" | grep -i 'DLL Name'

          # For just in case, normally must be done by the make file.
          ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe" || true

          rm -f "${APP_PREFIX}/bin/openocdw.exe"

          echo
          echo "Preparing libraries..."
          copy_dependencies_recursive "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe"
        fi

        if [ "${IS_DEVELOP}" != "y" ]
        then
          strip_binaries
          check_application "${APP_EXECUTABLE_NAME}"
        fi

        if [ "${WITH_PDF}" == "y" ]
        then
          make ${JOBS} bindir="bin" pkgdatadir="" pdf 
          make install-pdf
        fi

        if [ "${WITH_HTML}" == "y" ]
        then
          make ${JOBS} bindir="bin" pkgdatadir="" html
          make install-html
        fi

      ) 2>&1 | tee "${INSTALL_FOLDER_PATH}/make-openocd-output.txt"
    )
}

function run_openocd()
{
  echo

  if [ "${TARGET_PLATFORM}" == "linux" ]
  then
    "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}" --version
  elif [ "${TARGET_PLATFORM}" == "darwin" ]
  then
    "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}" --version
  elif [ "${TARGET_PLATFORM}" == "win32" ]
  then
    local wsl_path=$(which wsl.exe)
    if [ ! -z "${wsl_path}" ]
    then
      "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe" --version
    else 
      (
        xbb_activate

        local wine_path=$(which wine)
        if [ ! -z "${wine_path}" ]
        then
          wine "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe" --version
        else
          echo "Install wine if you want to run the .exe binaries on Linux."
        fi
      )
    fi
  fi
}

function strip_binaries()
{
  if [ "${WITH_STRIP}" == "y" ]
  then
    (
      xbb_activate

      echo
      echo "Striping binaries..."

      if [ "${TARGET_PLATFORM}" == "win32" ]
      then
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}.exe" || true
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/"*.dll || true
      else
        strip "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}" || true
        if [ "${TARGET_PLATFORM}" == "linux" ]
        then
          : # strip "${APP_PREFIX}/bin/${APP_EXECUTABLE_NAME}" || true
        fi
      fi
    )
  fi
}

# -----------------------------------------------------------------------------

function copy_gme_files()
{
  rm -rf "${APP_PREFIX}/${DISTRO_LC_NAME}"
  mkdir -p "${APP_PREFIX}/${DISTRO_LC_NAME}"

  echo
  echo "Copying license files..."

  copy_license \
    "${SOURCES_FOLDER_PATH}/${LIBUSB1_SRC_FOLDER_NAME}" \
    "${LIBUSB1_FOLDER_NAME}"

  if [ "${TARGET_PLATFORM}" != "win32" ]
  then
    copy_license \
      "${SOURCES_FOLDER_PATH}/${LIBUSB0_SRC_FOLDER_NAME}" \
      "${LIBUSB0_FOLDER_NAME}"
  else
    copy_license \
      "${SOURCES_FOLDER_PATH}/${LIBUSB_W32_SRC_FOLDER_NAME}" \
      "${LIBUSB_W32_FOLDER_NAME}"
  fi

  copy_license \
    "${SOURCES_FOLDER_PATH}/${LIBFTDI_SRC_FOLDER_NAME}" \
    "${LIBFTDI_FOLDER_NAME}"
  copy_license \
    "${SOURCES_FOLDER_PATH}/${LIBICONV_SRC_FOLDER_NAME}" \
    "${LIBICONV_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${OPENOCD_SRC_FOLDER_NAME}" \
    "${OPENOCD_FOLDER_NAME}"

  copy_build_files

  echo
  echo "Copying GME files..."

  cd "${WORK_FOLDER_PATH}/build.git"
  /usr/bin/install -v -c -m 644 "${README_OUT_FILE_NAME}" \
    "${APP_PREFIX}/README.md"
}
