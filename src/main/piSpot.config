#!/bin/bash

clear
echo
echo

#TARGET_DIR="/home/pit/piSpot"
TARGET_DIR="/home/pit/OneDrive/HowTOs/RaspBerry/piSpot/piSpot"

# Dateien sammeln
mapfile -t ALL_SH_FILES < <(find "$TARGET_DIR" -type f -name "*.sh" | sort)

# Anzeige vorbereiten
declare -A INDEX_TO_FILE
counter=1

echo " piSpot:"
echo "   0) QUIT Menu"

# Zuerst Scripts im Hauptverzeichnis
for file in "${ALL_SH_FILES[@]}"; do
  rel_path="${file#$TARGET_DIR/}"  # Pfad relativ zum Zielverzeichnis
  dir="$(dirname "$rel_path")"
  base="$(basename "$file")"

  if [[ "$dir" == "." ]]; then
    printf "  %2d) %s\n" "$counter" "$base"
    INDEX_TO_FILE["$counter"]="$file"
    ((counter++))
  fi
done

# Jetzt Scripts in Unterverzeichnissen gruppiert anzeigen
current_dir=""
for file in "${ALL_SH_FILES[@]}"; do
  rel_path="${file#$TARGET_DIR/}"
  dir="$(dirname "$rel_path")"
  base="$(basename "$file")"

  if [[ "$dir" != "." ]]; then
    if [[ "$dir" != "$current_dir" ]]; then
      echo
      echo "   $dir:"
      current_dir="$dir"
    fi
    printf "    %2d) %s\n" "$counter" "$base"
    INDEX_TO_FILE["$counter"]="$file"
    ((counter++))
  fi
done

# Auswahl
echo
read -p "Select Script: " auswahl
if [[ "$auswahl" == "0" ]]; then
  echo
  exit 0
fi

file="${INDEX_TO_FILE[$auswahl]}"
if [[ -z "$file" ]]; then
  echo " Ungültige Auswahl"
  sleep 1
  exec bash "$0"
fi

bash "$file"
exec bash "$0"
