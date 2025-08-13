#!/bin/bash

# Periksa apakah direktori disediakan sebagai argumen
if [ -z "$1" ]; then
  echo "Penggunaan: $0 <path_ke_direktori>"
  echo "Contoh: $0 /var/log"
  exit 1
fi

DIRECTORY_TO_WATCH="$1"

# Periksa apakah direktori ada
if [ ! -d "$DIRECTORY_TO_WATCH" ]; then
  echo "Error: Direktori '$DIRECTORY_TO_WATCH' tidak ditemukan."
  exit 1
fi

echo "Memantau perubahan di direktori: $DIRECTORY_TO_WATCH (Tekan Ctrl+C untuk keluar)"
echo "-------------------------------------------------------------"

# -m: mode pemantauan berkelanjutan
# -r: memantau direktori secara rekursif (termasuk subdirektori)
# -e: tentukan jenis kejadian yang akan dipantau
inotifywait -m -r -e create,delete,modify,move "$DIRECTORY_TO_WATCH" --exclude '\.git/' |
  while read -r directory event file; do
    echo "Waktu: $(date '+%Y-%m-%d %H:%M:%S') - Direktori: $directory - Kejadian: $event - Berkas: $file"
    git add .
    git commit -m "auto commit"
    git push origin
    # Di sini Anda bisa menambahkan tindakan lain yang ingin Anda lakukan
    # misalnya, menjalankan skrip lain, mengirim notifikasi, dll.
    # if [[ "$event" == "CREATE" ]]; then
    #   echo "Berkas baru dibuat: $directory$file"
    # fi
  done
