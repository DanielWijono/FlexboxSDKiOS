# Flexbox SDK untuk iOS: Layout sebagai Data

Revisi 6. Perubahan terhadap Revisi 5: sasaran naik dari portfolio menjadi produksi dan open source, adopter pertama adalah side project milik sendiri dengan adopsi seluruh aplikasi, lisensi Apache-2.0 dengan DCO. Butir yang sebelumnya ditunda dikembalikan, dan pilar produksi ditambahkan sebagai bagian normatif yang berlaku lintas artefak.

---

## 0. Tesis & Batasan

### Tesis

Deskripsi layout adalah **data bernilai** yang terpisah dari pohon layout yang hidup. `FlexStyle` dan `LayoutTree` adalah struct `Equatable`, `Codable`, dan `Sendable`; Yoga adalah mesin yang mengeksekusinya; UIKit adalah target render.

Empat kemampuan berikut mengikuti langsung dari keputusan itu dan tertutup bagi pustaka yang mengekspos gaya sebagai rantai pemanggilan yang memutasi node: layout dapat diserialisasi sehingga dapat dikirim dari server atau dihasilkan dari design token; perubahan dapat di-diff sehingga hanya yang berubah menyentuh C++; layout dapat diuji sebagai nilai, bukan sebagai piksel; dan satu deskripsi yang sama dapat dipakai ulang oleh adapter lain di kemudian hari.

### Konsumen & konsekuensinya

*   **Adopter pertama:** side project milik sendiri, adopsi seluruh aplikasi. Ini kondisi terbaik yang mungkin, karena Anda adalah vendor sekaligus pengguna dan tidak ada masalah tata kelola.
*   **Konsekuensi yang harus disadari:** Anda sekarang punya dua produk yang berbagi satu anggaran waktu. Aplikasi itu sendiri memakan jam di luar rencana ini. Pilih side project yang **kaya layout tetapi miskin fitur**, misalnya aplikasi katalog, dashboard, atau pembaca konten. Aplikasi yang butuh backend, autentikasi, dan pembayaran akan menelan waktu SDK-nya.
*   **Adopsi seluruh aplikasi hanya aman bila jalur mundur ada.** Karena itu koeksistensi dengan Auto Layout dikembalikan ke cakupan wajib: setiap layar harus bisa dikembalikan ke Auto Layout tanpa membongkar layar lain.

### Batasan tetap

*   **Anggaran waktu:** 5–10 jam per minggu, asumsi perencanaan 7,5 jam, dibagi antara SDK dan aplikasi.
*   **Platform:** iOS dan iPadOS. macOS, Catalyst, tvOS, visionOS di luar cakupan.
*   **Deployment target:** iOS 15.0. Yoga tidak memaksakan lantai apa pun; React Native sampai 0.75 menjalankan Yoga 3.x pada iOS 13.4. Fitur baru digerbangi `@available`: `UIViewRepresentable.sizeThatFits` dan protokol `Layout` di iOS 16, `registerForTraitChanges` di iOS 17 dengan fallback `traitCollectionDidChange`.
*   **Toolchain:** Xcode 16+, Swift 5.9 minimum untuk target C++20 Yoga, mode bahasa Swift 6 disarankan.
*   **SwiftUI:** interop lewat `UIViewRepresentable`. Adapter protokol `Layout` tetap non-goal v1.

### Lisensi

*   SDK dirilis di bawah **Apache-2.0**, dengan **DCO** (`Signed-off-by`) alih-alih CLA. DCO lebih ringan bagi kontributor dan cukup bagi sebagian besar adopter korporat.
*   Yoga berlisensi **MIT** dan kompatibel sebagai dependensi. Sertakan berkas `NOTICE` atau `THIRD_PARTY_LICENSES` yang memuat teks lisensi MIT Yoga; ini kewajiban distribusi, bukan formalitas.
*   Tetap di **0.x** sampai aplikasi Anda rilis. Menjanjikan stabilitas API sebelum API itu teruji oleh pemakaian nyata akan menyakiti Anda dua kali, sebagai maintainer dan sebagai pengguna.

---

## 1. Pilar Produksi (normatif, lintas artefak)

Bagian ini yang membedakan Revisi 6 dari rencana portfolio. Setiap artefak diuji terhadap pilar ini, bukan hanya terhadap definisi selesainya sendiri.

### Tidak boleh ada assert fatal di build release

Yoga melakukan assert fatal pada beberapa jalur: menyisipkan child yang sudah punya owner, menandai dirty pada node tanpa measure function, dan memasang measure function pada node yang bukan leaf. Rencana ini menambahkan payload dari jaringan di atasnya. Aplikasi yang crash karena JSON tata letak rusak adalah kegagalan yang Anda ciptakan sendiri.

Setiap jalur assert Yoga didahului precondition Swift yang: melakukan assert di DEBUG, dan di RELEASE menolak operasi, mencatat log, lalu melanjutkan dengan keadaan terakhir yang valid. Buat daftar lengkapnya di Artefak 2 dan perlakukan sebagai checklist, bukan sebagai penanganan ad hoc.

### Tata letak cadangan

Setiap layar wajib punya `LayoutTree` cadangan yang dibundel di dalam aplikasi. Cadangan dipakai otomatis bila payload gagal diurai, versinya tidak dikenal, atau validasi gagal. Aplikasi tidak boleh menampilkan layar kosong karena berkas tata letak bermasalah.

### Validasi payload

Versi skema disertakan dalam payload. Kunci yang tidak dikenal diabaikan, tidak menggagalkan parsing, agar payload baru aman dibaca aplikasi versi lama. Batasi kedalaman pohon dan jumlah node saat parsing. Tolak payload yang melampaui batas dan jatuh ke cadangan.

### Batas terhadap kebijakan App Store

JSON hanya mendeskripsikan tata letak, tidak pernah perilaku. Tidak ada evaluasi kode, tidak ada ekspresi yang dieksekusi, tidak ada penentuan navigasi dari payload. Batas ini bukan sekadar keamanan; ia juga yang menjaga fitur ini tetap berada di wilayah yang sama dengan konten dinamis biasa.

### Observabilitas

Sediakan hook untuk logging dan metrik: berapa kali cadangan terpakai, berapa lama kalkulasi berjalan, berapa node yang direkonsiliasi per pembaruan. Tanpa ini Anda tidak akan tahu SDK bermasalah di perangkat pengguna.

### Kebocoran memori

Gerbang dari Artefak 1 berlaku permanen di CI, bukan hanya saat artefak itu dikerjakan.

---

## Artefak 1 — Jembatan Engine & Kepemilikan Memori

**Estimasi:** ~30 jam (4 minggu).

### Integrasi

*   Tautkan Yoga resmi via SPM, pin ke rentang mayor 3.x.
*   ClangImporter terhadap `yoga/Yoga.h`, tautkan `libc++`. Jangan aktifkan interop C++; permukaan publik Yoga adalah ABI C yang memang dipelihara untuk pembuat binding.
*   **Koreksi terhadap revisi sebelumnya:** SPM tidak mengenal dependensi privat, dan `Package.swift` Yoga mendeklarasikan `publicHeadersPath`, sehingga modul `yoga` akan tetap dapat diimpor oleh konsumen paket Anda. Yang bisa Anda lakukan adalah tidak memakai `@_exported import`, tidak membocorkan tipe `YG*` di permukaan API publik, dan mendokumentasikan bahwa aplikasi yang juga menautkan salinan Yoga lain (umumnya lewat React Native di CocoaPods) berpotensi mengalami benturan simbol. Isolasi penuh hanya mungkin lewat distribusi XCFramework, dan itu di luar cakupan 0.x.

### Kontrak kepemilikan (normatif)

*   `FlexNode` induk memegang referensi **kuat** ke anak. Pohon dapat dipakai headless tanpa UIKit.
*   `UIView` memegang referensi **kuat** ke `FlexNode` miliknya lewat associated object.
*   `FlexNode` memegang referensi **lemah** ke `UIView`. Arah ini wajib lemah; membalikkannya menghasilkan siklus retain.
*   `FlexNode` memegang `YGNodeRef` secara eksklusif dan unik.
*   Closure yang disimpan pada node tidak boleh menangkap node atau view secara kuat.

Node anak punya dua pemilik kuat: node induk dan view-nya. Tidak ada siklus, tetapi ada satu mode kegagalan: jika subview dilepas tanpa node-nya dicabut dari induk, node tertahan dan bocor. Address Sanitizer tidak melihatnya karena memorinya masih terjangkau.

### Aturan pembongkaran

*   Urutan `deinit` tidak boleh diubah: bersihkan measure function dan context, lepas dari owner bila masih terpasang, baru `YGNodeFree`.
*   `YGNodeFreeRecursive` dilarang.
*   Reparenting wajib `YGNodeRemoveChild` lebih dulu.
*   Context measure function memakai `Unmanaged.passUnretained(...).toOpaque()`. `passRetained` dilarang.
*   **Masa hidup selama kalkulasi:** kalkulasi meminjam pohon; pemanggil wajib menahan root selama durasinya. Tanpa klausa ini, melepas view root saat kalkulasi berjalan menukar kebocoran dengan use-after-free.

### Konkurensi

*   Tidak ada `@MainActor` di lapisan inti. Pohon bersifat thread-confined, dan `final class FlexNode` sudah non-Sendable secara default di Swift 6 sehingga kompilator menegakkannya.
*   Measure function yang memanggil `sizeThatFits` UIKit hanya boleh berjalan di main thread. Dokumentasikan sebagai batas kontrak publik, karena kontributor akan melanggarnya bila tidak tertulis.

### Config per pohon

*   `YGConfig` per pohon, bukan singleton. Sejak Yoga 3.0, PointScaleFactor dihormati pada config tiap node.
*   Skala dari `traitCollection.displayScale`, bukan `UIScreen.main`, karena Split View, Slide Over, dan Stage Manager membuatnya berbeda antar scene dan berubah saat runtime.
*   Errata level ditetapkan eksplisit dan didokumentasikan.

### Gerbang kebocoran (permanen di CI)

*   Counter node hidup khusus DEBUG; setiap tes mengasersi kembali ke nol pada teardown.
*   `addTeardownBlock` dengan `weak var` ke view dan node, keduanya diasersi `nil`.
*   Invarian DEBUG: jumlah anak node sama dengan jumlah subview berpartisipasi setelah setiap pass. Ini satu-satunya pemeriksaan otomatis untuk mode kegagalan di atas.
*   ASan dengan LeakSanitizer sebagai gerbang yang memblokir merge.
*   Siklus push/pop 100 layar di bawah Instruments Allocations dengan generation mark, untuk memori terbengkalai yang tidak dilaporkan LeakSanitizer.

**Selesai bila:** pohon 3 tingkat dibangun, dihitung, di-reparent, dan dibongkar dengan counter nol, referensi lemah nihil, tanpa temuan ASan.

---

## Artefak 2 — Lapisan Nilai, Rekonsiliasi & Diagnostik

**Estimasi:** ~35 jam (5 minggu). Inti tesis.

### Model data

*   `FlexStyle`: struct `Equatable`, `Codable`, `Sendable`, tanpa pointer.
*   `LayoutTree`: struct rekursif berisi identitas, `FlexStyle`, tipe konten, dan anak. Juga `Codable`.
*   **Identitas stabil wajib.** Tanpa kunci yang stabil antar versi pohon, diffing merosot menjadi bangun ulang penuh dan tesisnya kehilangan separuh nilainya.

### Skema dan serialisasi

*   **NaN tidak dapat di-encode ke JSON.** `YGUndefined` adalah NaN, sehingga round-trip Codable memetakannya ke ketiadaan kunci, bukan ke angka. Ini keputusan skema.
*   Representasi nilai berunit: `12` untuk poin, `"50%"` untuk persentase, `"auto"` untuk auto.
*   Versi skema dan kebijakan kunci tak dikenal ditetapkan di sini, bukan di lapisan aplikasi, karena keduanya bagian dari kontrak publik.

### Rekonsiliasi

*   Diff dari `LayoutTree` lama ke baru menghasilkan operasi minimal terhadap pohon Yoga: sisip, cabut, pindah, perbarui gaya.
*   Hanya properti yang berubah yang diterapkan ke node.
*   Uji rekonsiliasi sebagai fungsi murni terhadap nilai, tanpa view. Ini sekaligus demonstrasi paling langsung dari tesis dan bagian yang paling mudah dikontribusikan orang lain.

### Invalidasi

*   Setter gaya tidak memanggil `YGNodeMarkDirty`; Yoga menandainya sendiri. Leaf bermeasure function wajib ditandai manual lewat `markContentDirty()` karena Yoga tidak tahu konten eksternal berubah.
*   `YGNodeSetDirtiedFunc` dibungkus sebagai closure tingkat engine. Notifikasinya edge-triggered: `setDirty` keluar lebih awal bila status tidak berubah dan propagasi berhenti pada leluhur yang sudah dirty. Jadikan jalur pelengkap, bukan satu-satunya sumber invalidasi.

### Diagnostik produksi

Daftar lengkap jalur assert fatal Yoga, masing-masing dengan precondition Swift berpesan jelas yang berperilaku sesuai pilar produksi: assert di DEBUG, tolak dan catat di RELEASE. Definisikan juga perilaku saat konsumen menambahkan anak ke node yang sudah punya measure function.

**Selesai bila:** modul dikompilasi tanpa menautkan UIKit, suite rekonsiliasi berjalan tanpa view, dan tidak ada jalur yang bisa mematikan proses di RELEASE.

---

## Artefak 3 — Renderer UIKit Tingkat Produksi

**Estimasi:** ~85 jam (11 minggu). Artefak terberat. Adopsi seluruh aplikasi menghapus kemungkinan menunda butir mana pun di bawah ini.

### Inti

*   **Measure function:** `YGNodeSetMeasureFunc` dengan `YGNodeSetContext`. Terjemahkan `YGMeasureMode` (`Exactly`, `AtMost`, `Undefined`) ke pemanggilan `sizeThatFits` yang sesuai; memperlakukan semuanya sebagai batas maksimum adalah kesalahan umum.
*   **Cache pengukuran dan penjaga reentrancy.** `intrinsicContentSize` yang menjalankan Yoga akan memanggil measure function yang memanggil `sizeThatFits`, yang bisa kembali berkonsultasi ke `intrinsicContentSize`. Tanpa cache per pass dan penjaga, biaya pengukuran meledak pada hierarki dalam.
*   **Pemicu layout:** pemanggilan eksplisit dari `layoutSubviews` view inang. Menimpa `layoutSubviews` lewat extension `UIView` tidak dimungkinkan di Swift, dan swizzling ditolak karena efek globalnya.
*   **Geometri:** hasil diterapkan ke `bounds.size` dan `center`, bukan `frame`, agar `transform` tidak rusak. Pertahankan `bounds.origin` yang ada; menimpanya mereset `contentOffset` pada `UIScrollView`. Jangan membulatkan di sisi Swift.
*   **Sinkronisasi pohon:** hook penyisipan dan pencabutan node saat subview berubah, dengan indeks yang benar. Pencabutan wajib; melewatkannya adalah mode kebocoran dari Artefak 1.
*   **Registry view:** peta dari tipe konten dalam `LayoutTree` ke factory view. Buat dapat diperluas oleh konsumen, karena ini titik ekstensi paling alami bagi kontributor.
*   **Invalidasi konten:** perubahan `text`, `attributedText`, `font`, dan `image` memanggil `markContentDirty()`.

### Dikembalikan karena produksi

*   **Self-sizing sel:** jalur `sizeThatFits` dan `intrinsicContentSize` pada container yang menjalankan kalkulasi dalam mode `AtMost` pada satu sumbu, terpisah dari siklus `layoutSubviews`. Prasyarat untuk `UITableViewCell` dan `UICollectionViewCell`, sekaligus melayani interop `UIViewRepresentable`.
*   **Koeksistensi Auto Layout:** container flex yang ditanam di hierarki Auto Layout membutuhkan `translatesAutoresizingMaskIntoConstraints` yang benar dan `intrinsicContentSize` yang valid, sementara subview di dalamnya tidak boleh membawa constraint sendiri. Tulis aturan ini sebagai kontrak publik; pelanggarannya menghasilkan gejala membingungkan, bukan crash. Ini juga jalur mundur Anda dari adopsi seluruh aplikasi.
*   **Safe area:** tetapkan apakah `safeAreaInsets` menjadi padding node root secara otomatis atau eksplisit. Keputusan ini memengaruhi API, jadi tidak bisa ditunda.
*   **Dynamic Type:** perubahan `preferredContentSizeCategory` membatalkan seluruh cache pengukuran.
*   **`isIncludedInLayout`** untuk view yang tidak berpartisipasi, dan pemetaan `isHidden` ke `display: none`.
*   **RTL:** teruskan `effectiveUserInterfaceLayoutDirection` ke parameter direction pada `YGNodeCalculateLayout`.
*   **UIScrollView:** definisikan bagaimana `contentSize` diturunkan dari hasil kalkulasi. Tanpa ini, layar yang dapat digulir tidak terpakai, dan hampir semua layar nyata dapat digulir.

**Selesai bila:** layar bertingkat dengan sel self-sizing dan konten dapat digulir merender benar di iPhone dan iPad, bertahan melewati transisi Split View dan perubahan Dynamic Type, dan lolos seluruh gerbang kebocoran.

---

## Artefak 4 — Aplikasi Side Project (Dogfooding)

**Estimasi:** ~45 jam SDK-side (6 minggu), di luar waktu fitur aplikasi itu sendiri.

*   Bangun aplikasi dengan seluruh layout melalui SDK. Ini satu-satunya cara menemukan kasus tepi yang tidak muncul di unit test.
*   Aktifkan jalur JSON pada minimal satu layar nyata, dengan muat ulang tanpa rekompilasi. Ini demonstrasi tesis sekaligus pembuktian bahwa jalur produksinya bekerja.
*   Terapkan tata letak cadangan dan validasi payload sesuai pilar produksi. Uji dengan sengaja mengirim payload rusak.
*   Catat setiap friksi yang Anda temui sebagai issue di repo. Daftar ini kemudian menjadi peta jalan publik dan titik masuk kontributor yang paling berguna.
*   **Aturan disiplin:** setiap kali aplikasi memaksa Anda menambah API, tanyakan apakah itu memang milik SDK atau milik aplikasi. Adopsi seluruh aplikasi membuat batas ini mudah kabur.

**Selesai bila:** aplikasi berjalan sepenuhnya di atas SDK, satu layar digerakkan JSON, dan payload rusak jatuh ke cadangan tanpa crash.

---

## Artefak 5 — Rilis Publik

**Estimasi:** ~25 jam (3 minggu).

*   `LICENSE` Apache-2.0, `NOTICE` dengan lisensi MIT Yoga, dan pemeriksaan DCO otomatis di CI.
*   `README` dengan contoh call site di paruh atas layar, bukan di bawah daftar fitur.
*   `ARCHITECTURE.md` yang memuat kontrak kepemilikan, model konkurensi, dan daftar diagnostik. Ini dokumen yang menentukan apakah kontributor bisa masuk tanpa merusak invarian.
*   `CONTRIBUTING.md` dengan cara menjalankan tes, gerbang yang harus hijau, dan area yang terbuka untuk kontribusi. Tandai rekonsiliasi dan registry view sebagai titik masuk yang baik.
*   Templat issue, `CODE_OF_CONDUCT.md`, dan CI yang menjalankan tes, ASan, serta pemeriksaan kebocoran pada setiap PR.
*   Kebijakan versi: tetap 0.x, dokumentasikan bahwa perubahan breaking mungkin terjadi sampai 1.0, dan tetapkan syarat untuk 1.0, yaitu aplikasi Anda sudah rilis dan API tidak berubah selama dua bulan.
*   Benchmark diterbitkan sebagai pengukuran, bukan klaim keunggulan. Adopter akan menanyakannya, dan angka yang diukur sendiri lebih baik daripada asumsi mereka.

**Selesai bila:** orang lain dapat mengkloning repo, menjalankan tes sampai hijau, dan mengerti invarian arsitekturnya tanpa bertanya kepada Anda.

---

## Jadwal & Risiko

Pada 7,5 jam per minggu untuk sisi SDK: Artefak 1 selesai sekitar minggu ke-4, Artefak 2 minggu ke-9, Artefak 3 minggu ke-20, Artefak 4 minggu ke-26, Artefak 5 minggu ke-29. Sekitar tujuh bulan untuk SDK, dan delapan hingga sembilan bulan bila waktu fitur aplikasi diperhitungkan.

Tiga risiko, berurutan menurut kemungkinan.

**Aplikasi menelan SDK.** Ini yang paling mungkin terjadi. Mitigasinya adalah memilih aplikasi yang miskin fitur sejak awal, dan menjaga aturan disiplin di Artefak 4.

**Artefak 3 membengkak.** Daftar produksinya panjang dan tidak ada yang bisa dipotong tanpa merusak adopsi seluruh aplikasi. Bila minggu ke-20 terlewat, opsi yang tersedia bukan memotong butir, melainkan mempersempit adopsi menjadi sebagian layar dan menunda sisanya. Koeksistensi Auto Layout adalah yang membuat opsi itu mungkin, jadi kerjakan lebih awal di dalam artefak ini, bukan terakhir.

**Beban maintenance datang sebelum manfaatnya.** Repo publik menghasilkan issue jauh sebelum menghasilkan PR. Tetapkan sejak awal berapa jam per minggu yang Anda sediakan untuk itu, dan nyatakan di `README` bahwa proyek ini dipelihara secara sukarela dengan kapasitas terbatas.
