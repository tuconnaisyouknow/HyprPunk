#!/bin/bash
# From https://github.com/prasanthrangan/hyprdots/pull/952
# All credits to https://github.com/mislah
# Modified: The HyDE Project
#  Benchmark 1: cpuinfo.sh
#   Time (mean ± σ):     159.4 ms ±  26.1 ms    [User: 38.6 ms, System: 62.2 ms]
#   Range (min … max):    99.8 ms … 182.7 ms    17 runs

map_floor() {
  IFS=', ' read -r -a pairs <<<"$1"
  if [[ ${pairs[-1]} != *":"* ]]; then
    def_val="${pairs[-1]}"
    unset 'pairs[${#pairs[@]}-1]'
  fi
  for pair in "${pairs[@]}"; do
    IFS=':' read -r key value <<<"$pair"
    num="${2%%.*}"
    # if awk -v num="$2" -v k="$key" 'BEGIN { exit !(num > k) }'; then #! causes 50ms+ delay
    if [[ "$num" =~ ^-?[0-9]+$ && "$key" =~ ^-?[0-9]+$ ]]; then # TODO Faster than awk but I might be dumb so checks might be lacking
      if ((num > key)); then
        echo "$value"
        return
      fi
    elif [[ -n "$num" && -n "$key" && "$num" > "$key" ]]; then
      echo "$value"
      return
    fi
  done
  [ -n "$def_val" ] && echo $def_val || echo " "
}

init_query() {
  cpu_info_file="/tmp/hyde-${UID}-processors"

  # Source the file to load existing variables
  [[ -f "${cpu_info_file}" ]] && source "${cpu_info_file}"

  # Get static CPU information
  if [[ -z "$CPUINFO_MODEL" ]]; then
    CPUINFO_MODEL=$(lscpu | awk -F': ' '/Model name/ {gsub(/^ *| *$| CPU.*/,"",$2); print $2}')
    echo "CPUINFO_MODEL=\"$CPUINFO_MODEL\"" >>"${cpu_info_file}"
  fi
  if [[ -z "$CPUINFO_MAX_FREQ" ]]; then
    CPUINFO_MAX_FREQ=$(lscpu | awk '/CPU max MHz/ { sub(/\..*/,"",$4); print $4}')
    echo "CPUINFO_MAX_FREQ=\"$CPUINFO_MAX_FREQ\"" >>"${cpu_info_file}"
  fi

  # Get initial CPU stat
  statFile=$(head -1 /proc/stat)
  if [[ -z "$CPUINFO_PREV_STAT" ]]; then
    CPUINFO_PREV_STAT=$(awk '{print $2+$3+$4+$6+$7+$8 }' <<<"$statFile")
    echo "CPUINFO_PREV_STAT=\"$CPUINFO_PREV_STAT\"" >>"${cpu_info_file}"
  fi
  if [[ -z "$CPUINFO_PREV_IDLE" ]]; then
    CPUINFO_PREV_IDLE=$(awk '{print $5 }' <<<"$statFile")
    echo "CPUINFO_PREV_IDLE=\"$CPUINFO_PREV_IDLE\"" >>"${cpu_info_file}"
  fi
}

get_utilization() {
  local statFile currStat currIdle diffStat diffIdle utilization
  statFile=$(head -1 /proc/stat)
  currStat=$(awk '{print $2+$3+$4+$6+$7+$8 }' <<<"$statFile")
  currIdle=$(awk '{print $5 }' <<<"$statFile")
  diffStat=$((currStat - CPUINFO_PREV_STAT))
  diffIdle=$((currIdle - CPUINFO_PREV_IDLE))

  # Store state and sleep
  CPUINFO_PREV_STAT=$currStat
  CPUINFO_PREV_IDLE=$currIdle

  # Save the current state to the file
  sed -i -e "/^CPUINFO_PREV_STAT=/c\CPUINFO_PREV_STAT=\"$currStat\"" -e "/^CPUINFO_PREV_IDLE=/c\CPUINFO_PREV_IDLE=\"$currIdle\"" "$cpuinfo_file" || {
    echo "CPUINFO_PREV_STAT=\"$currStat\"" >>"$cpuinfo_file"
    echo "CPUINFO_PREV_IDLE=\"$currIdle\"" >>"$cpuinfo_file"
  }

  awk -v stat="$diffStat" -v idle="$diffIdle" 'BEGIN {printf "%.1f", (stat/(stat+idle))*100}'
}

cpuinfo_file="/tmp/hyde-${UID}-processors"
# shellcheck disable=SC1090
source "${cpuinfo_file}"
init_query

# Define glyphs
if [[ $CPUINFO_EMOJI -ne 1 ]]; then
  temp_lv="85:, 65:, 45:☁, ❄"
else
  temp_lv="85:🌋, 65:🔥, 45:☁️, ❄️"
fi
util_lv="90:, 60:󰓅, 30:󰾅, 󰾆"

# Main loop

# Get dynamic CPU information
sensors_json=$(sensors -j 2>/dev/null)

# TODO: Add support for more sensor chips
cpu_temps="$(jq -r '[
.["coretemp-isa-0000"], 
.["k10temp-pci-00c3"]
] | 
map(select(. != null)) | 
map(to_entries) | 
add | 
map(select(.value | 
objects) | 
"\(.key): \((.value | 
to_entries[] | 
select(.key | 
test("temp[0-9]+_input")) | 
.value | floor))°C") | 
join("\\n\t")' <<<"$sensors_json")"

if [ -n "${CPUINFO_TEMPERATURE_ID}" ]; then
  temperature=$(grep -oP "(?<=${CPUINFO_TEMPERATURE_ID}: )\d+" <<<"${cpu_temps}")
fi

if [[ -z "$temperature" ]]; then
  # Extract the first temperature from the JSON
  cpu_temp_line="${cpu_temps%%$'°C'*}" # Get the first line
  temperature="${cpu_temp_line#*: }"   # Remove everything before the colon and space
fi

utilization=$(get_utilization)
frequency=$(perl -ne 'BEGIN { $sum = 0; $count = 0 } if (/cpu MHz\s+:\s+([\d.]+)/) { $sum += $1; $count++ } END { if ($count > 0) { printf "%.2f\n", $sum / $count } else { print "NaN\n" } }' /proc/cpuinfo)

# Generate glyphs
icons="$(map_floor "$util_lv" "$utilization")$(map_floor "$temp_lv" "$temperature")"
speedo="${icons:0:1}"
thermo="${icons:1:1}"
emoji="${icons:2}"

# Prepare the tooltip string
tooltip_str="$emoji $CPUINFO_MODEL\n"
[[ -n "$thermo" ]] && tooltip_str+="$thermo Temperature: \n\t$cpu_temps \n"
[[ -n "$speedo" ]] && tooltip_str+="$speedo Utilization: $utilization%\n"
tooltip_str+=" Clock Speed: $frequency/$CPUINFO_MAX_FREQ MHz"

# Print the output
# Print the output (no custom colors)
cat <<JSON
{"text":"$thermo ${temperature}°C", "tooltip":"$tooltip_str"}
JSON
