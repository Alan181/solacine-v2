import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppI18n {
  AppI18n(this.locale);

  final Locale locale;

  static final Map<String, Map<String, String>> _runtime = {};

  static const _fallbackEn = <String, String>{
    'app_name': 'Solacine',
    'login_title': 'Masuk',
    'register_title': 'Buat akun',
    'email': 'Email',
    'password': 'Kata sandi',
    'confirm_password': 'Konfirmasi kata sandi',
    'name': 'Nama',
    'sign_in': 'Masuk',
    'sign_in_google': 'Lanjutkan dengan Google',
    'create_account': 'Buat akun',
    'have_account': 'Sudah punya akun? Masuk',
    'no_account': 'Belum punya akun? Buat akun',
    'home_title': 'Beranda',
    'profile_title': 'Profil',
    'logout': 'Keluar',
    'language': 'Bahasa',
    'guest': 'Tamu',
    'field_required': 'Kolom ini wajib diisi',
    'invalid_email': 'Email tidak valid',
    'password_min': 'Kata sandi minimal {min} karakter',
    'password_mismatch': 'Kata sandi tidak cocok',
    'login_failed': 'Gagal masuk',
    'register_failed': 'Gagal mendaftar',
    'two_factor_required': 'Autentikasi dua faktor diperlukan',
    'retry': 'Coba lagi',
    'verify_email_title': 'Verifikasi email',
    'verification_code': 'Kode verifikasi',
    'verify': 'Verifikasi',
    'resend': 'Kirim ulang kode',
    'skip_for_now': 'Lewati untuk sekarang',
    'invalid_code': 'Kode tidak valid',
    'request_failed': 'Permintaan gagal',
    'request_failed_desc': 'Terjadi kesalahan saat memproses permintaan Anda. Silakan coba lagi.',
    'no_connection': 'Tidak ada koneksi internet',
    'no_connection_desc': 'Periksa Wi-Fi atau data seluler Anda lalu coba lagi.',
    'server_unreachable': 'Tidak dapat terhubung ke server',
    'server_unreachable_desc': 'Layanan mungkin sedang tidak tersedia. Silakan coba lagi dalam beberapa saat.',
    'startup_failed': 'Gagal memuat aplikasi',
    'startup_failed_desc': 'Periksa koneksi Anda dan ketuk Coba Lagi.',
    'no_payment_methods': 'Tidak ada metode pembayaran yang tersedia',
    'no_payment_methods_desc': 'Saat ini tidak ada metode pembayaran yang aktif. Silakan coba lagi nanti atau hubungi dukungan.',
    'reward': 'Hadiah',
    'rewards': 'Hadiah',
    'reward_center': 'Pusat Hadiah',
    'reward_center_desc': 'Klaim hadiah absensi harian, selesaikan misi, dan dapatkan koin gratis.',
    'top_up_coins': 'Top Up Koin',
    'my_coins_balance': 'SALDO KOIN SAYA',
    'available_coins_desc': 'Koin yang tersedia di dompet Anda',
    'active_streak': 'RENTETAN AKTIF',
    'consecutive_checkins_desc': 'Absensi harian berturut-turut',
    'todays_reward': 'HADIAH HARI INI',
    'ready_to_claim_now': 'Siap diklaim sekarang',
    'claimed_for_today': 'Sudah diklaim hari ini',
    'checkin_schedule_title': 'Jadwal Absensi 7 Hari',
    'checkin_schedule_desc': 'Masuk setiap hari untuk mengklaim hadiah koin yang terus meningkat.',
    'resets_every_7_days': 'Reset setiap 7 hari',
    'day': 'Hari',
    'days_plural': 'Hari',
    'streak_day': 'Hari',
    'streak_days': 'Hari',
    'today': 'Hari ini',
    'claim_daily_coins': 'Klaim koin absensi harian.',
    'dont_break_streak': 'Jangan putuskan rentetan Anda!',
    'already_claimed_today': 'Anda sudah mengklaim hadiah hari ini.',
    'come_back_tomorrow': 'Kembali besok untuk hadiah berikutnya!',
    'claim_todays_reward': 'Klaim Hadiah Hari Ini',
    'claimed_today': 'Sudah Diklaim Hari Ini',
    'congratulations': 'Selamat!',
    'you_received_coins': 'Anda menerima {count} koin',
    'ok': 'OK',
    'daily_tasks': 'Tugas Harian',
    'daily_tasks_desc': 'Selesaikan aktivitas untuk mendapatkan bonus koin ekstra.',
    'watch_rewarded_videos': 'Tonton Video Berhadiah',
    'ads_available': 'Iklan Tersedia',
    'watch_ads_desc': 'Tonton iklan video pendek di aplikasi seluler untuk mendapatkan koin ekstra setiap hari.',
    'reward_colon': 'Hadiah:',
    'daily_checkin': 'Absensi harian',
    'claim': 'Klaim',
    'claimed': 'Diklaim',
    'checkin_claimed': 'Absensi diklaim',
    'start': 'Mulai',
    'more_tasks': 'Tugas lainnya',
    'no_tasks_available': 'Tidak ada tugas yang tersedia saat ini',
    'watch_ads': 'Tonton iklan',
    'ad_not_completed': 'Tonton iklan sampai selesai untuk melanjutkan',
    'task_follow_instruction': 'Ikuti petunjuknya',
    'task_browse_15s_then_return': 'Lanjutkan menjelajah selama 15 detik, lalu kembali untuk mengklaim hadiah Anda.',
    'task_wait_15s': 'Harap tunggu 15 detik, lalu klaim hadiah Anda.',
    'Cancel': 'Batal',
    'swipe_up': 'Usap ke atas',
    'discover': 'Temukan',
    'ranking': 'Peringkat',
    'dubbed': 'Alih suara',
    'top_now': 'Teratas saat ini',
    'all_dubbed': 'Semua alih suara',
    'categories': 'Kategori',
    'genres': 'Genre',
    'popular': 'Populer',
    'new_releases': 'Rilisan baru',
    'premium': 'Premium',
    'see_all': 'Lainnya',
    'watch_now': 'Tonton sekarang',
    'my_list': 'Daftar Saya',
    'episodes': 'Episode',
    'episode': 'Episode',
    'Episodes': 'Episode',
    'Episode': 'Episode',
    'locked': 'Terkunci',
    'section': 'Bagian',
    'no_content': 'Tidak ada konten yang tersedia saat ini',
    'badge_recommended': 'Direkomendasikan',
    'badge_dubbed': 'Alih Suara',
    'badge_pro': 'PRO',
    'nav_home': 'Beranda',
    'nav_reels': 'Reels',
    'nav_rewards': 'Hadiah',
    'nav_my_list': 'Daftar Saya',
    'nav_profile': 'Profil',
    'search': 'Cari',
    'search_my_list': 'Cari di Daftar Saya',
    'search_all': 'Cari',
    'search_drama_hint': 'Cari drama',
    'people_searching': 'Pencarian populer',
    'user_id': 'ID: {id}',
    'wallet': 'Dompet',
    'wallet_coins': 'koin',
    'recharge': 'Isi Ulang',
    'purchase_history': 'Riwayat pembelian',
    'recent_transactions': 'Transaksi terbaru',
    'purchases': 'Pembelian',
    'coin_history': 'Riwayat koin',
    'no_transactions': 'Belum ada transaksi',
    'no_packages': 'Tidak ada paket yang tersedia',
    'choose_payment_method': 'Pilih metode pembayaran',
    'secure_checkout': 'Checkout Aman',
    'apple_app_store': 'Apple App Store',
    'secure_payment': 'Pembayaran aman',
    'recommended': 'Direkomendasikan',
    'purchase': 'Beli',
    'stripe': 'Stripe',
    'paypal': 'PayPal',
    'flutterwave': 'Flutterwave',
    'razorpay': 'Razorpay',
    'google_play': 'Google Play',
    'admin': 'Admin',
    'google_play_unavailable': 'Google Play tidak tersedia di perangkat ini',
    'google_play_product_missing': 'Produk ini tidak tersedia di Google Play',
    'payment_failed': 'Pembayaran gagal',
    'payment_success': 'Pembayaran berhasil',
    'payment_successful': 'Pembayaran berhasil!',
    'subscription_successful': 'Langganan Aktif!',
    'recharge_successful': 'Isi Ulang Berhasil!',
    'vip_subscription_success_desc': 'Langganan VIP Anda aktif! Nikmati streaming tanpa batas.',
    'coins_recharge_success_desc': 'Koin Anda telah ditambahkan ke saldo dompet.',
    'payment_success_desc': 'Langganan Anda kini aktif! Nikmati streaming tanpa batas.',
    'payment_status_paid': 'Dibayar',
    'payment_status_pending': 'Tertunda',
    'payment_status_failed': 'Gagal',
    'payment_status_canceled': 'Dibatalkan',
    'coin_reason_purchase': 'Pembelian',
    'coin_reason_episode_unlock': 'Buka kunci episode',
    'coin_reason_reward': 'Hadiah',
    'coin_reason_reward_task': 'Tugas berhadiah',
    'watch_history': 'Riwayat tontonan',
    'earn_rewards': 'Dapatkan hadiah',
    'inbox': 'Pesan Masuk',
    'no_inbox_messages': 'Tidak ada pesan saat ini',
    'devices': 'Perangkat',
    'no_devices': 'Belum ada perangkat',
    'where_youre_signed_in': 'Tempat Anda masuk',
    'devices_security_desc': 'Anda saat ini masuk ke akun Anda di perangkat ini. Periksa untuk memastikan keamanan akun.',
    'current_session': 'Sesi saat ini',
    'this_device': 'Perangkat ini',
    'active_now': 'Aktif sekarang',
    'active_now_on_device': 'Aktif sekarang di perangkat ini',
    'last_active': 'Terakhir aktif',
    'other_devices': 'Perangkat lain',
    'operating_system': 'Sistem operasi',
    'brand_and_model': 'Merek & Model',
    'app_version': 'Versi aplikasi',
    'device_identifier': 'Pengidentifikasi perangkat',
    'first_sign_in': 'Masuk pertama kali',
    'dont_recognize_device': 'Tidak mengenali perangkat?',
    'dont_recognize_device_desc': 'Jika Anda melihat perangkat yang tidak dikenal, segera ubah kata sandi Anda untuk melindungi akun.',
    'change_password': 'Ubah kata sandi',
    'change_password_secure': 'Ubah kata sandi untuk mengamankan akun',
    'unrecognized_device_warning': 'Jika Anda tidak mengenali perangkat ini, segera ubah kata sandi Anda untuk mengamankan akun.',
    'registered_session': 'Sesi terdaftar',
    'devices_count': '{count} perangkat',
    'one_device_count': '1 perangkat',
    'open': 'Buka',
    'open_link': 'Buka tautan',
    'support': 'Dukungan',
    'support_tickets': 'Tiket dukungan',
    'no_support_tickets': 'Tidak ada tiket saat ini',
    'new_ticket': 'Tiket baru',
    'subject': 'Subjek',
    'message': 'Pesan',
    'send': 'Kirim',
    'close': 'Tutup',
    'ticket_closed': 'Tiket ditutup',
    'help_feedback': 'Bantuan & masukan',
    'settings': 'Pengaturan',
    'coins': 'Koin',
    'membership': 'Keanggotaan',
    'membership_packages': 'Paket Keanggotaan',
    'membership_title': 'Keanggotaan {app}',
    'activate': 'Aktifkan',
    'membership_feature_1': 'Tanpa iklan',
    'membership_feature_2': 'Unduh offline',
    'membership_feature_unlimited': 'Akses tanpa batas',
    'membership_feature_no_ads': 'Tanpa iklan',
    'membership_feature_hd_1080': 'Kualitas 1080P',
    'membership_feature_download': 'Unduh offline',
    'badge_hot': 'Populer',
    'badge_most_popular': 'Terpopuler',
    'badge_best_choice': 'Pilihan terbaik',
    'vip': 'VIP',
    'vip_active': 'VIP Aktif',
    'vip_expires_on': 'Berakhir: {date}',
    'vip_days_left': 'Sisa {days} hari',
    'join_membership': 'Bergabung dengan keanggotaan',
    'limited_time': 'Waktu terbatas',
    'gold_coins': 'Koin Emas',
    'recharge_tips': 'Tips',
    'recharge_tips_desc': '1. Koin Emas adalah item virtual dan tidak dapat dikembalikan. Gunakan di dalam aplikasi ini.',
    'vip_membership_benefits': 'Keuntungan Keanggotaan VIP',
    'vip_benefit_full_access': 'Akses penuh ke semua VIP',
    'vip_benefit_no_ads': 'Menonton tanpa iklan apa pun',
    'vip_benefit_ultra_hd': 'Kualitas Ultra HD',
    'choose_your_plan': 'Pilih paket Anda',
    'membership_plan_weekly': 'Paket mingguan',
    'membership_plan_monthly': 'Paket bulanan',
    'membership_plan_yearly': 'Paket tahunan',
    'membership_subscribe_to': 'Berlangganan {plan}',
    'membership_promo_line': r'Pertama {period} ${promo}, lalu ${original}/{period}',
    'membership_autorenew_note': 'Perpanjangan otomatis. Batalkan kapan saja.',
    'extend': 'Perpanjang',
    'edit_profile': 'Edit profil',
    'save': 'Simpan',
    'saved': 'Disimpan',
    'share': 'Bagikan',
    'views': 'Ditonton',
    'balance': 'Saldo',
    'unlock_cost': 'Biaya buka kunci',
    'coin_unit': 'koin',
    'auto_unlock': 'Buka kunci otomatis',
    'auto_unlock_note': 'Episode berikutnya terbuka secara otomatis',
    'unlock_with_coins': 'Buka dengan {cost} {unit}',
    'unlock_this_episode': 'Buka kunci episode ini',
    'unlock_now': 'Buka sekarang',
    'watch_ad_to_unlock': 'Tonton iklan untuk membuka episode ini',
    'watch_ad_unlock': 'Tonton iklan',
    'daily_ad_limit_reached': 'Batas iklan harian telah tercapai',
    'no_video_available': 'Video tidak tersedia',
    'no_video_available_desc': 'Episode ini belum memiliki sumber video.',
    'no_episodes': 'Tidak ada episode',
    'no_episodes_desc': 'Belum ada episode yang tersedia untuk judul ini.',
    'loading_episode': 'Memuat episode...',
    'loading_video': 'Memuat video...',
    'video_failed': 'Video gagal',
    'video_failed_desc': 'Sumber video ini tidak dapat diputar di perangkat ini.',
    'open_external': 'Buka',
    'quality': 'Kualitas',
    'choose_quality': 'Pilih kualitas',
    'auto': 'Otomatis',
    'favorites': 'Favorit',
    'list': 'Daftar',
    'more': 'Lainnya',
    'speed': 'Kecepatan',
    'change_photo': 'Ubah foto',
    'remove_photo': 'Hapus foto',
    'delete': 'Hapus',
    'delete_account': 'Hapus akun',
    'delete_account_confirm': 'Ini akan menghapus akun Anda secara permanen. Tindakan ini tidak dapat dibatalkan.',
    'phone': 'Telepon',
    'username': 'Nama pengguna',
    'account': 'Akun',
    'security': 'Keamanan',
    'update_password': 'Perbarui kata sandi',
    'current_password': 'Kata sandi saat ini',
    'new_password': 'Kata sandi baru',
    'confirm_new_password': 'Konfirmasi kata sandi baru',
    'password_updated': 'Kata sandi diperbarui',
    'two_factor_authentication': 'Autentikasi dua faktor',
    'two_factor_secret': 'Kunci rahasia',
    'recovery_codes': 'Kode pemulihan',
    'copy': 'Salin',
    'copied': 'Disalin',
    'enabled': 'Diaktifkan',
    'disabled': 'Dinonaktifkan',
    'enable': 'Aktifkan',
    'disable': 'Nonaktifkan',
    'two_factor_enabled_ok': 'Autentikasi dua faktor diaktifkan',
    'two_factor_disabled_ok': 'Autentikasi dua faktor dinonaktifkan',
    'update_available_title': 'Pembaruan Tersedia',
    'update_force_body': 'Versi baru diperlukan untuk terus menggunakan aplikasi.',
    'update_optional_body': 'Versi baru tersedia dengan fitur dan peningkatan baru.',
    'update_versions': 'Build saat ini: {current}\nBuild terbaru: {latest}',
    'update_open_failed': 'Gagal membuka tautan pembaruan',
    'update_now': 'Perbarui Sekarang',
    'continue': 'Lanjutkan',
    'update_force_hint': 'Anda harus memperbarui untuk melanjutkan.',
    'legal_prefix': 'Dengan melanjutkan, Anda menyetujui',
    'legal_and': 'dan',
    'privacy_policy': 'Kebijakan Privasi',
    'terms_of_use': 'Ketentuan Penggunaan',
    'unable_open_link': 'Tidak dapat membuka tautan',
    'exit_confirm_title': 'Keluar aplikasi?',
    'exit_confirm_body': 'Apakah Anda ingin keluar?',
    'exit_confirm_cancel': 'Batal',
    'exit_confirm_exit': 'Keluar',
    'days': '{days} Hari',
  };

  static const _fallbackAr = <String, String>{
    'payment_success': 'تم الدفع بنجاح',
    'payment_successful': 'تم الدفع بنجاح!',
    'subscription_successful': 'تم الاشتراك بنجاح!',
    'recharge_successful': 'تم شحن الرصيد بنجاح!',
    'vip_subscription_success_desc': 'تم تفعيل اشتراك VIP بنجاح! استمتع بمشاهدة جميع المسلسلات بدون إعلانات.',
    'coins_recharge_success_desc': 'تمت إضافة رصيد النقاط بنجاح إلى محفظتك.',
    'payment_success_desc': 'تم تفعيل اشتراكك بنجاح! استمتع بمشاهدة غير محدودة لجميع مسلسلات VIP.',
    'congratulations': 'تهانينا!',
    'ok': 'حسناً',
    'close': 'إغلاق',
    'watch_now': 'ابدأ المشاهدة',
    'badge_pro': 'VIP PRO',
    'vip': 'VIP',
    'coins': 'نقاط',
    'wallet_coins': 'نقاط',
    'nav_rewards': 'المكافآت',
  };

  static void setTranslations(String lang, Map<String, String> translations) {
    _runtime[lang] = translations;
  }

  static const _cachePrefix = 'i18n_cache_';

  static Future<void> saveTranslationsCache(String lang, SharedPreferences prefs) async {
    final data = _runtime[lang];
    if (data == null || data.isEmpty) return;
    try {
      await prefs.setString('$_cachePrefix$lang', jsonEncode(data));
    } catch (_) {}
  }

  static Future<Map<String, String>> loadTranslationsCache(String lang, SharedPreferences prefs) async {
    try {
      final raw = prefs.getString('$_cachePrefix$lang');
      if (raw == null || raw.isEmpty) return const <String, String>{};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as String?) ?? v.toString()));
    } catch (_) {
      return const <String, String>{};
    }
  }

  static AppI18n of(BuildContext context) {
    return Localizations.of<AppI18n>(context, AppI18n) ?? AppI18n(const Locale('en'));
  }

  String t(String key, {Map<String, String> params = const {}}) {
    final lang = locale.languageCode;
    final runtimeMap = _runtime[lang] ?? const <String, String>{};

    // 1) Exact match in runtime (admin-translated values take priority)
    var raw = runtimeMap[key];

    // 2) Exact match in static Arabic fallback if active
    if (lang == 'ar') {
      raw ??= _fallbackAr[key];
    }

    // 3) Exact match in static English fallback
    raw ??= _fallbackEn[key];

    // 4) Case-insensitive fallbacks (try lowercase then capitalized) so keys
    //    that differ only by casing (e.g. "episode" vs "Episode") still resolve
    //    before we surrender to a humanised placeholder instead of the raw key.
    if (raw == null) {
      final lower = key.toLowerCase();
      raw = runtimeMap[lower] ?? (lang == 'ar' ? _fallbackAr[lower] : null) ?? _fallbackEn[lower];
    }
    if (raw == null && key.isNotEmpty) {
      final cap = key[0].toUpperCase() + (key.length > 1 ? key.substring(1) : '');
      raw = runtimeMap[cap] ?? (lang == 'ar' ? _fallbackAr[cap] : null) ?? _fallbackEn[cap];
    }

    // 4) Final safety-net: NEVER render raw technical keys to the end user.
    //    Show a readable English sentence instead of something like
    //    "request_failed_desc" leaking into the UI.
    raw ??= _humanizeKey(key);

    if (params.isEmpty) return raw;
    var out = raw;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  static String _humanizeKey(String key) {
    if (key.isEmpty) return 'Something went wrong';
    final words = key.replaceAllMapped(RegExp(r'[_\-\.]+'), (m) => ' ').split(' ');
    final human = words.where((w) => w.isNotEmpty).map((w) {
      if (w.length == 1) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
    return human.isEmpty ? 'Something went wrong' : human;
  }
}

({String titleKey, String descKey}) appUserErrorFor(Object? error) {
  if (error == null) {
    return (titleKey: 'request_failed', descKey: 'request_failed_desc');
  }
  if (error is SocketException) {
    return (titleKey: 'no_connection', descKey: 'no_connection_desc');
  }
  if (error is DioException) {
    final type = error.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      final inner = error.error;
      if (inner is SocketException) {
        return (titleKey: 'no_connection', descKey: 'no_connection_desc');
      }
      return (titleKey: 'server_unreachable', descKey: 'server_unreachable_desc');
    }
    final status = error.response?.statusCode ?? 0;
    if (status >= 500) {
      return (titleKey: 'server_unreachable', descKey: 'server_unreachable_desc');
    }
    return (titleKey: 'request_failed', descKey: 'request_failed_desc');
  }
  if (error is HttpException) {
    return (titleKey: 'no_connection', descKey: 'no_connection_desc');
  }
  final s = error.toString().toLowerCase();
  if (s.contains('socketexception')) {
    return (titleKey: 'no_connection', descKey: 'no_connection_desc');
  }
  return (titleKey: 'request_failed', descKey: 'request_failed_desc');
}

class AppI18nDelegate extends LocalizationsDelegate<AppI18n> {
  const AppI18nDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppI18n> load(Locale locale) => SynchronousFuture(AppI18n(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppI18n> old) => false;
}
