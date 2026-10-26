# Changelog

All notable changes to Kuroku (黒録) will be documented in this file.

## [v1.4.3] - 2026-10-26
### 🐛 Perbaikan Bug & Peningkatan:
- 🛡️ **Proteksi Timpa Cadangan Cold Boot (Custom Sources)**: Menambahkan guard proteksi penulisan SharedPreferences agar startup cold boot tidak menimpa file preferensi dengan list kosong saat database SQLite sedang dalam proses inisialisasi awal.
- 🧩 **Toleransi Runtime Map Parser Dinamis**: Memperbaiki deserialisasi runtime Dart AOT untuk menerima seluruh varian koleksi map (`Map<dynamic, dynamic>`, `Map<String, Object?>`) pada pemulihan sumber kustom dan selektor spesifikasi dari database SQLite serta cadangan lokal.
- 🗑️ **Fitur Hapus Riwayat Massal (Bulk History Deletion)**: Menambahkan mode seleksi interaktif dengan long-press (tekan dan tahan) pada kartu riwayat, feedback getar haptic, aksi centang semua (select all), serta penghapusan massal dalam satu batch dialog konfirmasi.

### 🐛 Perbaikan Bug & Peningkatan:
- 🔄 **Rekonsiliasi Persistensi Ganda Custom Source**: Memperbaiki pemulihan sumber kustom hasil impor agar otomatis menggabungkan (merge) data dari SQLite dan SharedPreferences pada saat startup aplikasi, mencegah sumber hilang saat aplikasi dihentikan paksa (kill task) dari app switcher.
- 🛠️ **Migrasi Skema SQLite `custom_sources` Otomatis**: Menambahkan migrasi kolom `config` otomatis pada tabel SQLite `custom_sources` untuk perangkat yang meng-upgrade dari versi terdahulu.
- 🛡️ **Deserialisasi Aman Konfigurasi Parser**: Parsing konfigurasi kini mendukung format objek map, JSON string, maupun spesifikasi deklaratif langsung tanpa risiko runtime type cast error.

## [v1.4.1] - 2026-10-25
### 🐛 Perbaikan Bug & Peningkatan:
- 💾 **Persistensi Ganda Custom Source**: Sumber kustom yang ditambahkan kini tersimpan permanen menggunakan sistem dual-persistence (SQLite + backup SharedPreferences) sehingga tidak hilang saat aplikasi ditutup atau di-restart.
- 🎯 **Penyimpanan Sumber Aktif Otomatis**: Aplikasi kini mengingat dan memulihkan sumber aktif terakhir yang dipilih pengguna saat aplikasi dibuka kembali.
- 🧩 **Peningkatan Fleksibilitas Engine Parser Dinamis**:
  - Dukungan variasi penamaan kunci selektor fleksibel (`snake_case` dan `camelCase`).
  - Fallback selektor cerdas untuk layout grid modern, deteksi nomor chapter, dan atribut lazy-load gambar.

## [v1.4.0] - 2026-10-25
### ✨ Fitur Baru & Peningkatan:
- 🧩 **Sistem Import & Export Parser Deklaratif**: Pengguna dapat menambahkan sumber komik baru tanpa perlu rebuild aplikasi atau menunggu rilis baru. Cukup salin spesifikasi JSON atau masukkan link URL parser.
  - Mendukung 4 engine parser: `html` (custom CSS selector deklaratif), `rest`/`json_api` (ekstraksi data REST API JSON murni), `madara`, dan `themesia`.
  - Dialog import interaktif dengan tab **Paste JSON** dan **Import URL**, live schema validator preview card (status, domain, locale, engine type), serta tombol paste clipboard & template instan.
  - Opsi export parser terpasang kembali ke clipboard dalam format JSON untuk memudahkan modifikasi dan berbagi antar pengguna.
- 🎨 **Penyempurnaan Antarmuka Manajemen Sumber**:
  - Tombol aksi `Import Parser (.json / URL)` langsung pada bottom sheet *Pilih Sumber Komik*.
  - Menu overflow `more_vert` yang ringkas pada setiap parser kustom: *Edit Domain*, *Export JSON*, dan *Hapus Source*, menyelesaikan isu teks judul terpotong pada layar ponsel sempit.
  - Indikator badge `CUSTOM` yang elegan pada setiap sumber hasil impor pengguna.

## [v1.3.9] - 2026-10-24
### ✨ Fitur Baru & Peningkatan:
- 📜 **Bidirectional Infinite Scroll Reader**: Dukungan infinite scroll dua arah untuk Webtoon dan Continuous Vertical mode. Pengguna dapat langsung scroll ke bawah untuk memuat chapter selanjutnya, atau scroll ke puncak untuk memuat chapter sebelumnya tanpa jeda atau lompatan viewport.
- 🎴 **Kartu Pemisah Inter-Chapter**: Menampilkan kartu transisi yang rapi di antara chapter (`Akhir Chapter X` → garis pemisah cyan → `Chapter Y: Subtitle`) dengan indikator status pembacaan.
- ⏭️ **Navigasi Cepat Prev / Next Chapter**: Tombol `Prev Ch` dan `Next Ch` pada Bottom HUD memungkinkan pembaca melompati chapter secara instan tanpa perlu kembali ke layar detail manga.
- 🏷️ **Multi-Genre Filter & Interactive Tags**:
  - Filter katalog kini mendukung pemilihan multi-genre secara simultan via toggle chip dengan badge counter `Filter (N)` dan chip removable `✕`.
  - Penambahan 38 genre dan tag lengkap Weeb Central (termasuk tag kritis seperti Adult, Sci-fi, Seinen, Yaoi, Yuri, OEL).
  - Chip genre pada layar Detail Manga kini dapat diketuk langsung untuk mencari komik terkait di katalog secara instan.
- 🔄 **Sinkronisasi Dinamis Progress & History**: Indikator judul chapter aktif, nomor halaman, scrubber progress slider, dan riwayat SQLite (`updateChapterProgress`, `recordHistory`) tersinkronisasi otomatis saat user melintasi perbatasan antar chapter.

## [v1.3.8] - 2026-10-24
### 🎨 Perbaikan Bug UI & Peningkatan:
- 📱 **Fix Library UI & Filter Chips**: Memperbaiki AppBar dan tata letak chip kategori filter (`Favorit`, `Didownload (Offline)`, `Update Terbaru`) yang sebelumnya hilang/rusak akibat layout exception `unbounded height` di `PreferredSize` dan tertimpa status bar.
- 👁️ **High-Contrast Dark Theme Chips**: Label teks dan ikon chip kategori kini tampil kontras dan tajam pada tema gelap tanpa glitch visual.
- 🎯 **Verifikasi Resume Tengah Chapter**: Pengujian e2e membuktikan posisi scroll di tengah-tengah panel gambar Webtoon tersimpan dan dipulihkan secara 1:1 saat kembali lewat History atau tombol Continue.
- 🧪 **E2E Visual Regression Harness**: Penyediaan preview harness pengujian headless Skia untuk kestabilan visual UI antarmuka Kuroku.

## [v1.3.7] - 2026-10-24
### ✨ Fitur Baru & Peningkatan:
- ⚡ **Auto-Mark Previous Chapters Read**: Saat membaca atau menyelesaikan chapter N (misal Chapter 258), seluruh chapter sebelumnya (Chapter 1 hingga 257) secara otomatis ditandai sebagai sudah dibaca (`is_read = 1`). Persentase progress membaca di halaman detail dan kartu Library langsung mengikuti chapter tertinggi yang sedang dibaca.
- 🔄 **Auto Progress Propagation in SQLite**: Penyesuaian query kalkulasi progress database agar menghitung chapter sebelumnya sebagai terbaca berdasarkan chapter tertinggi yang memiliki riwayat baca.

## [v1.3.6] - 2026-10-24
### 🐛 Perbaikan Bug & Peningkatan:
- 🎯 **Focal Point Reading Tracking**: Memperbaiki bug lompat halaman saat melanjutkan bacaan dari History (misal dari Page 19 lompat ke Page 21). Posisi halaman aktif kini dihitung berdasarkan garis fokus pandangan mata (35% dari atas layar) dengan penyesuaian scroll desimal via `ScrollOffsetController` sehingga kembali persis ke panel gambar yang sedang dibaca tanpa pergeseran anchor viewport.
- 🛡️ **Safe Viewport Alignment**: Mencegah nilai alignment negatif yang dapat mengacaukan perhitungan `RenderViewport` Flutter pada tampilan Webtoon bersambung.

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
