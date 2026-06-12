#!/bin/bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/system-info.sh
source "$script_dir/../lib/system-info.sh"

case "$(network_type)" in
  wifi)
    echo -e "  "
    ;;
  ethernet)
    echo "󰈀  "
    ;;
  *)
    echo "󰖪  "
    ;;
esac
