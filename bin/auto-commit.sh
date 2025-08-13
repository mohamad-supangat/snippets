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

DEBOUNCE_TIME=5 # Waktu tunda dalam detik sebelum push

PUSH_PID="" # Variabel untuk menyimpan PID dari proses push yang ditunda

# Fungsi untuk menjadwalkan push yang ditunda
schedule_debounced_push() {
  # Jika ada proses push yang sedang menunggu, batalkan
  if [ -n "$PUSH_PID" ]; then
    kill "$PUSH_PID" 2>/dev/null
    echo "Membatalkan push yang sebelumnya dijadwalkan."
  fi

  # Jadwalkan push di latar belakang setelah penundaan
  (
    sleep "$DEBOUNCE_TIME"
    echo "Mendorong perubahan ke origin..."
    git push origin
    # Setelah push selesai, kosongkan PUSH_PID di proses utama
    # (Ini sulit dilakukan dari sub-shell, jadi kita akan mengandalkan pembaruan PUSH_PID pada event baru)
  ) &
  PUSH_PID=$! # Simpan PID dari proses latar belakang
  echo "Push ke origin akan dijadwalkan dalam $DEBOUNCE_TIME detik."
}

# Trap untuk membersihkan proses latar belakang saat skrip keluar
trap "if [ -n \"$PUSH_PID\" ]; then kill \"$PUSH_PID\" 2>/dev/null; fi" EXIT

echo "Memantau perubahan di direktori: $DIRECTORY_TO_WATCH (Tekan Ctrl+C untuk keluar)"
echo "-------------------------------------------------------------"

# -m: mode pemantauan berkelanjutan
# -r: memantau direktori secara rekursif (termasuk subdirektori)
# -e: tentukan jenis kejadian yang akan dipantau
# --exclude '\.git/': mengabaikan folder .git
inotifywait -m -r -e create,delete,modify,move "$DIRECTORY_TO_WATCH" --exclude '\.git/' |
  while read -r directory event file; do
    echo "Waktu: $(date '+%Y-%m-%d %H:%M:%S') - Direktori: $directory - Kejadian: $event - Berkas: $file"

    git add .

    # Periksa apakah ada perubahan untuk di-commit
    if ! git diff-index --quiet HEAD --; then
      git commit -m "auto commit dari inotifywait"
      # Jika commit berhasil, jadwalkan push
      schedule_debounced_push
    else
      echo "Tidak ada perubahan yang perlu di-commit."
    fi
  done
