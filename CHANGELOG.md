# Changelog

All notable changes to Kuroku (黒録) will be documented in this file.

## [v1.3.5] - 2026-10-24
### 🐛 Perbaikan Bug & Peningkatan:
- 🔄 **Multi-Key Chapter Matching**: Perekaman progres baca dan status `is_read` di SQLite kini mencocokkan ID, URL, dan nomor chapter secara serentak sehingga pembacaan chapter terakhir selalu tercatat akurat.
- 📊 **Reading Progress Persistence**: Memperbaiki bug reading progress 0% di detail manga dan library; sinkronisasi status `is_read` menggunakan multi-key matching (ID, URL, nomor chapter) sehingga tidak terhapus saat memuat ulang dari internet.
- 🎨 **Visual Chapter Contrast**: Pembedaan visual yang jelas antara chapter yang sudah dibaca (warna teks redup & ikon centang hijau), chapter sedang dibaca (badge halaman cyan & ikon play), dan belum dibaca.
- 🖐️ **Draggable Sheet Handle**: Area drag bar drawer sekarang terhubung langsung ke `DraggableScrollableController` sehingga dapat digeser mulus ke atas/bawah.
- 🎯 **Sub-Page Alignment Tracking**: Merekam koordinat scroll desimal (`itemLeadingEdge`) ke SQLite dan memulihkan posisi baca persis di tengah/bawah panel webtoon via `initialAlignment`.
- 📚 **Library Progress Overlay**: Kartu manga di halaman Library kini menampilkan badge persentase progres dan progress bar membaca secara real-time.

## [v1.3.4] - 2026-10-24
### 🐛 Perbaikan Bug & Peningkatan:
- 📊 **Reading Progress Persistence**: Memperbaiki bug reading progress 0% di detail manga dan library; sinkronisasi status `is_read` menggunakan multi-key matching (ID, URL, nomor chapter) sehingga tidak terhapus saat memuat ulang dari internet.
- 🎨 **Visual Chapter Contrast**: Pembedaan visual yang jelas antara chapter yang sudah dibaca (warna teks redup & ikon centang hijau), chapter sedang dibaca (badge halaman cyan & ikon play), dan belum dibaca.
- 🖐️ **Draggable Sheet Handle**: Area drag bar drawer sekarang terhubung langsung ke `DraggableScrollableController` sehingga dapat digeser mulus ke atas/bawah.
- 🎯 **Sub-Page Alignment Tracking**: Merekam koordinat scroll desimal (`itemLeadingEdge`) ke SQLite dan memulihkan posisi baca persis di tengah/bawah panel webtoon via `initialAlignment`.
- 📚 **Library Progress Overlay**: Kartu manga di halaman Library kini menampilkan badge persentase progres dan progress bar membaca secara real-time.

## [v1.3.3] - 2026-10-24
### ✨ Fitur Baru & Peningkatan:
- 📰 **Kotatsu-Style Feed Layout**: Redesain tab History dengan antarmuka Feed modern.
- 🔍 **Live Search Bar**: Cari komik dan chapter langsung dari bar pencarian atas dengan live filtering.
- ⚡ **Updates Highlight Carousel**: Kartu komik horizontal dengan badge jumlah chapter baru & indikator progres baca (%).
- 🏷️ **Read Later & Filter Chips**: Filter cepat untuk komik favorit (Read later), semua entri, notifikasi update, atau riwayat baca.
- 📅 **Pengelompokan Waktu Kronologis**: Feed terorganisir rapi dalam grup *Today*, *Yesterday*, *2 days ago*, dst.
- 🔔 **Badge Notifikasi Navbar**: Ikon History di navigasi bawah otomatis menampilkan counter chapter baru yang belum dibaca.

## [v1.3.2] - 2026-10-24
### ✨ Fitur Baru:
- 📜 **Kotatsu-Style Chapter Drawer**: Daftar chapter kini ditarik dari bawah (bottom sheet draggable) dengan opsi sorting dan filter download offline.
- 📊 **Metadata & Reading Progress Card**: Header detail manga menampilkan info Author, Artist, Status, dan progress bar membaca (X dari Y chapter).
- 🔄 **Unified History & Updates**: Menggabungkan notifikasi rilis chapter baru dengan riwayat bacaan.

## [v1.3.1] - 2026-10-24
### ✨ Fitur Baru:
- 🚀 **In-App Updater**: Unduh dan pasang update langsung dari aplikasi Android via FileProvider tanpa perlu download manual dari browser.
- 🔍 **Cek Update Otomatis & Manual**: Notifikasi update otomatis saat aplikasi dibuka dan opsi cek update manual di Settings.

## [v1.3.0] - 2026-10-24
### ✨ Fitur Baru:
- 📥 **Offline Download Manager**: Unduh chapter komik untuk dibaca tanpa koneksi internet.
- 🏷️ **Filter Kategori & Genre**: Filter mendalam untuk format (Manhwa/Manga/Manhua) dan genre pada katalog Shinigami.
