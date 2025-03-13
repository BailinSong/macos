#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${DEVICE_SERIAL:=""}"                # Device serial SN
: "${BOARD_SERIAL:=""}"               # Board serial MLB
: "${MAC_ADDRESS:=""}"               # MAC address MAC
: "${UUID:=""}"              # Unique ID UUID
: "${WIDTH:="1920"}"         # Horizontal
: "${HEIGHT:="1080"}"        # Vertical
: "${VERSION:="13"}"         # OSX Version
: "${DEVICE_MODEL:="iMacPro1,1"}"   # Device model MODEL
: "${VNC_PASS:="12345678"}"   # Device model MODEL

TMP="$STORAGE/tmp"
BASE_IMG_ID="InstallMedia"
BASE_IMG="$STORAGE/base.dmg"
BASE_VERSION="$STORAGE/$PROCESS.version"

downloadImage() {

  local board
  local version="$1"
  local file="BaseSystem"
  local path="$TMP/$file.dmg"

  case "${version,,}" in
    "sequoia" | "15"* )
      board="Mac-937A206F2EE63C01" ;;
    "sonoma" | "14"* )
      board="Mac-827FAC58A8FDFA22" ;;
    "ventura" | "13"* )
      board="Mac-4B682C642B45593E" ;;
    "monterey" | "12"* )
      board="Mac-B809C3757DA9BB8D" ;;
    "bigsur" | "big-sur" | "11"* )
      board="Mac-2BD1B31983FE1663" ;;
    "catalina" | "10"* )
      board="Mac-00BE6ED71E35EB86" ;;
    *)
      error "Unknown VERSION specified, value \"${version}\" is not recognized!"
      return 1 ;;
  esac

  local msg="Downloading macOS ${version^}"
  info "$msg recovery image..." && html "$msg..."

  rm -rf "$TMP"
  mkdir -p "$TMP"

  /run/progress.sh "$path" "" "$msg ([P])..." &

  if ! /run/fetch.py -b "$board" -n "$file" -os latest -o "$TMP" download; then
    error "Failed to fetch macOS \"${version^}\" recovery image with board id \"$board\"!"
    fKill "progress.sh"
    return 1
  fi

  fKill "progress.sh"

  if [ ! -f "$path" ] || [ ! -s "$path" ]; then
    error "Failed to find file \"$path\" !"
    return 1
  fi

  mv -f "$path" "$BASE_IMG"
  rm -rf "$TMP"

  echo "$version" > "$BASE_VERSION"
  return 0
}

generateID() {

  local file="$STORAGE/$PROCESS.id"

  [ -n "$UUID" ] && return 0
  [ -s "$file" ] && UUID=$(<"$file")
  [ -n "$UUID" ] && return 0

  UUID=$(cat /proc/sys/kernel/random/uuid 2> /dev/null || uuidgen --random)
  UUID="${UUID^^}"
  echo "$UUID" > "$file"

  return 0
}

generateAddress() {

  local file="$STORAGE/$PROCESS.mac"

  [ -n "$MAC_ADDRESS" ] && return 0
  [ -s "$file" ] && MAC_ADDRESS=$(<"$file")
  [ -n "$MAC_ADDRESS" ] && return 0

  # Generate Apple MAC address based on Docker container ID in hostname
  MAC_ADDRESS=$(echo "$HOST" | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/00:16:cb:\3:\4:\5/')
  MAC_ADDRESS="${MAC_ADDRESS^^}" 
  echo "$MAC_ADDRESS" > "$file"

  return 0
}


generateFiveSerial() {
  local env_file="$STORAGE/$PROCESS.env.sh"

  echo "generate five serial"

  if [ -s "$env_file" ]; then
    source "${env_file}"
    echo "has five serial"
  else
    echo "not has five serial"
    # First check the variable
    if [ -n "$DEVICE_SERIAL" ] && [ -n "$BOARD_SERIAL" ] && [ -n "$MAC_ADDRESS" ] && [ -n "$UUID" ]; then

      echo "has custom  five serial"
      return 0
    fi
    echo "will generate five serial"
    # Generate new value
    /run/generate-unique-machine-values.sh --envs --model "${DEVICE_MODEL}"
    mv env.sh "${env_file}"
    source "${env_file}"

    echo "$MAC_ADDRESS" > "$STORAGE/$PROCESS.mac"
    echo "$DEVICE_SERIAL" > "$STORAGE/$PROCESS.sn"
    echo "$BOARD_SERIAL" > "$STORAGE/$PROCESS.mlb"
    echo "$UUID" > "$STORAGE/$PROCESS.id"
 

  fi

  echo "${env_file}:"
  cat "${env_file}"

  local file="$STORAGE/$PROCESS.mac"

  return 0
}


generateSerial() {

  local file="$STORAGE/$PROCESS.sn"
  local file2="$STORAGE/$PROCESS.mlb"

  [ -n "$DEVICE_SERIAL" ] && [ -n "$BOARD_SERIAL" ] && return 0
  [ -s "$file" ] && DEVICE_SERIAL=$(<"$file")
  [ -s "$file2" ] && BOARD_SERIAL=$(<"$file2")
  [ -n "$DEVICE_SERIAL" ] && [ -n "$BOARD_SERIAL" ] && return 0

  # Generate unique serial numbers for machine
  DEVICE_SERIAL=$(/usr/local/bin/macserial --num 1 --model "${DEVICE_MODEL}" 2>/dev/null)

  DEVICE_SERIAL="${DEVICE_SERIAL##*$'\n'}"
  [[ "$DEVICE_SERIAL" != *" | "* ]] && error "$DEVICE_SERIAL" && return 1

  BOARD_SERIAL=${DEVICE_SERIAL#*|}
  BOARD_SERIAL="${BOARD_SERIAL#"${BOARD_SERIAL%%[![:space:]]*}"}"
  DEVICE_SERIAL="${DEVICE_SERIAL%%|*}"
  DEVICE_SERIAL="${DEVICE_SERIAL%"${DEVICE_SERIAL##*[![:space:]]}"}"

  echo "$DEVICE_SERIAL" > "$file"
  echo "$BOARD_SERIAL" > "$file2"

  return 0
}


if [ ! -f "$BASE_IMG" ] || [ ! -s "$BASE_IMG" ]; then
  if ! downloadImage "$VERSION"; then
    rm -rf "$TMP"
    exit 34
  fi
fi

STORED_VERSION=""
if [ -f "$BASE_VERSION" ]; then
  STORED_VERSION=$(<"$BASE_VERSION")
fi

if [ "$VERSION" != "$STORED_VERSION" ]; then
  info "Different version detected, switching base image from \"$STORED_VERSION\" to \"$VERSION\""
  if ! downloadImage "$VERSION"; then
    rm -rf "$TMP"
    exit 34
  fi
fi

if ! generateFiveSerial ; then
  error "Failed to generate five serial!" && exit 35
fi


DISK_OPTS="-device virtio-blk-pci,drive=${BASE_IMG_ID},bus=pcie.0,addr=0x6"
DISK_OPTS+=" -drive file=$BASE_IMG,id=$BASE_IMG_ID,format=dmg,cache=unsafe,readonly=on,if=none"

return 0
