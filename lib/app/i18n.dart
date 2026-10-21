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
    'login_title': 'Sign in',
    'register_title': 'Create account',
    'email': 'Email',
    'password': 'Password',
    'confirm_password': 'Confirm password',
    'name': 'Name',
    'sign_in': 'Sign in',
    'sign_in_google': 'Continue with Google',
    'create_account': 'Create account',
    'have_account': 'Already have an account? Sign in',
    'no_account': 'Don\'t have an account? Create one',
    'home_title': 'Home',
    'profile_title': 'Profile',
    'logout': 'Logout',
    'language': 'Language',
    'guest': 'Guest',
    'field_required': 'This field is required',
    'invalid_email': 'Invalid email',
    'password_min': 'Password must be at least {min} characters',
    'password_mismatch': 'Passwords do not match',
    'login_failed': 'Login failed',
    'register_failed': 'Registration failed',
    'two_factor_required': 'Two-factor authentication required',
    'retry': 'Retry',
    'verify_email_title': 'Verify email',
    'verification_code': 'Verification code',
    'verify': 'Verify',
    'resend': 'Resend code',
    'skip_for_now': 'Skip for now',
    'invalid_code': 'Invalid code',
    'request_failed': 'Request failed',
    'request_failed_desc': 'Something went wrong while processing your request. Please try again.',
    'no_connection': 'No internet connection',
    'no_connection_desc': 'Please check your Wi-Fi or mobile data and try again.',
    'server_unreachable': 'Cannot connect to the server',
    'server_unreachable_desc': 'The service may be temporarily unavailable. Please try again in a moment.',
    'startup_failed': 'Unable to load the app',
    'startup_failed_desc': 'Please check your connection and tap Retry.',
    'no_payment_methods': 'No payment methods available',
    'no_payment_methods_desc': 'There are no active payment methods right now. Please try again later or contact support.',
    'reward': 'Reward',
    'rewards': 'Rewards',
    'reward_center': 'Reward Center',
    'reward_center_desc': 'Claim daily check-in rewards, complete quests, and earn free coins.',
    'top_up_coins': 'Top Up Coins',
    'my_coins_balance': 'MY COINS BALANCE',
    'available_coins_desc': 'Available coins in your wallet',
    'active_streak': 'ACTIVE STREAK',
    'consecutive_checkins_desc': 'Consecutive daily check-ins',
    'todays_reward': "TODAY'S REWARD",
    'ready_to_claim_now': 'Ready to claim now',
    'claimed_for_today': 'Claimed for today',
    'checkin_schedule_title': '7-Day Check-in Schedule',
    'checkin_schedule_desc': 'Log in every day to claim increasing coin rewards.',
    'resets_every_7_days': 'Resets every 7 days',
    'day': 'Day',
    'days_plural': 'Days',
    'streak_day': 'Day',
    'streak_days': 'Days',
    'today': 'Today',
    'claim_daily_coins': 'Claim daily check-in coins.',
    'dont_break_streak': "Don't break your streak!",
    'already_claimed_today': "You have already claimed today's reward.",
    'come_back_tomorrow': 'Come back tomorrow for your next reward!',
    'claim_todays_reward': "Claim Today's Reward",
    'claimed_today': 'Claimed Today',
    'congratulations': 'Congratulations!',
    'you_received_coins': 'You received {count} coins',
    'ok': 'OK',
    'daily_tasks': 'Daily Tasks',
    'daily_tasks_desc': 'Complete activities to earn extra coin bonuses.',
    'watch_rewarded_videos': 'Watch Rewarded Videos',
    'ads_available': 'Ads Available',
    'watch_ads_desc': 'Watch short video ads on the mobile app to earn extra coins daily.',
    'reward_colon': 'Reward:',
    'daily_checkin': 'Daily check-in',
    'claim': 'Claim',
    'claimed': 'Claimed',
    'checkin_claimed': 'Check-in claimed',
    'start': 'Start',
    'more_tasks': 'More tasks',
    'no_tasks_available': 'No tasks available right now',
    'watch_ads': 'Watch ads',
    'ad_not_completed': 'Please watch the ad until the end to continue',
    'task_follow_instruction': 'Follow the instructions',
    'task_browse_15s_then_return': 'Continue browsing for 15 seconds, then return to claim your reward.',
    'task_wait_15s': 'Please wait 15 seconds, then claim your reward.',
    'Cancel': 'Cancel',
    'swipe_up': 'Swipe up',
    'discover': 'Discover',
    'ranking': 'Ranking',
    'dubbed': 'Dubbed',
    'top_now': 'Top now',
    'all_dubbed': 'All dubbed',
    'categories': 'Categories',
    'genres': 'Genres',
    'popular': 'Popular',
    'new_releases': 'New releases',
    'premium': 'Premium',
    'see_all': 'More',
    'watch_now': 'Watch now',
    'my_list': 'My List',
    'episodes': 'Episodes',
    'episode': 'Episode',
    'Episodes': 'Episodes',
    'Episode': 'Episode',
    'locked': 'Locked',
    'section': 'Section',
    'no_content': 'No content available right now',
    'badge_recommended': 'Recommended',
    'badge_dubbed': 'Dubbed',
    'badge_pro': 'PRO',
    'nav_home': 'Home',
    'nav_reels': 'Reels',
    'nav_rewards': 'Rewards', // <--- DITAMBAHKAN DI SINI
    'nav_my_list': 'My List',
    'nav_profile': 'Profile',
    'search': 'Search',
    'search_my_list': 'Search in My List',
    'search_all': 'Search',
    'search_drama_hint': 'Search for drama',
    'people_searching': 'People are searching',
    'user_id': 'ID: {id}',
    'wallet': 'Wallet',
    'wallet_coins': 'coins',
    'recharge': 'Recharge',
    'purchase_history': 'Purchase history',
    'recent_transactions': 'Recent transactions',
    'purchases': 'Purchases',
    'coin_history': 'Coin history',
    'no_transactions': 'No transactions yet',
    'no_packages': 'No packages available',
    'choose_payment_method': 'Choose payment method',
    'secure_checkout': 'Secure Checkout',
    'apple_app_store': 'Apple App Store',
    'secure_payment': 'Secure payment',
    'recommended': 'Recommended',
    'purchase': 'Purchase',
    'stripe': 'Stripe',
    'paypal': 'PayPal',
    'flutterwave': 'Flutterwave',
    'razorpay': 'Razorpay',
    'google_play': 'Google Play',
    'admin': 'Admin',
    'google_play_unavailable': 'Google Play is unavailable on this device',
    'google_play_product_missing': 'This product is not available on Google Play',
    'payment_failed': 'Payment failed',
    'payment_success': 'Payment successful',
    'payment_successful': 'Payment successful!',
    'subscription_successful': 'Subscription Active!',
    'recharge_successful': 'Recharge Successful!',
    'vip_subscription_success_desc': 'Your VIP subscription is active! Enjoy unlimited streaming.',
    'coins_recharge_success_desc': 'Your coins have been added to your wallet balance.',
    'payment_success_desc': 'Your subscription is now active! Enjoy unlimited streaming.',
    'payment_status_paid': 'Paid',
    'payment_status_pending': 'Pending',
    'payment_status_failed': 'Failed',
    'payment_status_canceled': 'Canceled',
    'coin_reason_purchase': 'Purchase',
    'coin_reason_episode_unlock': 'Episode unlock',
    'coin_reason_reward': 'Reward',
    'coin_reason_reward_task': 'Reward task',
    'watch_history': 'Watch history',
    'earn_rewards': 'Earn rewards',
    'inbox': 'Inbox',
    'no_inbox_messages': 'No messages right now',
    'devices': 'Devices',
    'no_devices': 'No devices yet',
    'where_youre_signed_in': "Where you're signed in",
    'devices_security_desc': "You're currently signed in to your account on these devices. Review them to ensure account security.",
    'current_session': 'Current session',
    'this_device': 'This device',
    'active_now': 'Active now',
    'active_now_on_device': 'Active now on this device',
    'last_active': 'Last active',
    'other_devices': 'Other devices',
    'operating_system': 'Operating system',
    'brand_and_model': 'Brand & Model',
    'app_version': 'App version',
    'device_identifier': 'Device identifier',
    'first_sign_in': 'First sign-in',
    'dont_recognize_device': "Don't recognize a device?",
    'dont_recognize_device_desc': "If you see an unfamiliar device, change your password immediately to protect your account.",
    'change_password': 'Change password',
    'change_password_secure': 'Change password to secure account',
    'unrecognized_device_warning': "If you don't recognize this device, change your password immediately to secure your account.",
    'registered_session': 'Registered session',
    'devices_count': '{count} devices',
    'one_device_count': '1 device',
    'open': 'Open',
    'open_link': 'Open link',
    'support': 'Support',
    'support_tickets': 'Support tickets',
    'no_support_tickets': 'No tickets right now',
    'new_ticket': 'New ticket',
    'subject': 'Subject',
    'message': 'Message',
    'send': 'Send',
    'close': 'Close',
    'ticket_closed': 'Ticket closed',
    'help_feedback': 'Help & feedback',
    'settings': 'Settings',
    'coins': 'Coins',
    'membership': 'Membership',
    'membership_packages': 'Membership Packages',
    'membership_title': '{app} Membership',
    'activate': 'Activate',
    'membership_feature_1': 'No ads',
    'membership_feature_2': 'Offline download',
    'membership_feature_unlimited': 'Unlimited access',
    'membership_feature_no_ads': 'No ads',
    'membership_feature_hd_1080': '1080P quality',
    'membership_feature_download': 'Offline download',
    'badge_hot': 'Hot',
    'badge_most_popular': 'Most popular',
    'badge_best_choice': 'Best choice',
    'vip': 'VIP',
    'vip_active': 'VIP Active',
    'vip_expires_on': 'Expires: {date}',
    'vip_days_left': '{days} days left',
    'join_membership': 'Join membership',
    'limited_time': 'Limited time',
    'gold_coins': 'Gold Coins',
    'recharge_tips': 'Tips',
    'recharge_tips_desc': '1. Gold Coins are virtual items and cannot be refunded. Use them within this app.',
    'vip_membership_benefits': 'VIP Membership Benefits',
    'vip_benefit_full_access': 'Full access to all VIP',
    'vip_benefit_no_ads': 'Watch without any ads',
    'vip_benefit_ultra_hd': 'Ultra HD quality',
    'choose_your_plan': 'Choose your plan',
    'membership_plan_weekly': 'Weekly plan',
    'membership_plan_monthly': 'Monthly plan',
    'membership_plan_yearly': 'Yearly plan',
    'membership_subscribe_to': 'Subscribe to {plan}',
    'membership_promo_line': r'First {period} ${promo}, then ${original}/{period}',
    'membership_autorenew_note': 'Auto-renews. Cancel anytime.',
    'extend': 'Extend',
    'edit_profile': 'Edit profile',
    'save': 'Save',
    'saved': 'Saved',
    'share': 'Share',
    'views': 'Views',
    'balance': 'Balance',
    'unlock_cost': 'Unlock cost',
    'coin_unit': 'coin',
    'auto_unlock': 'Auto unlock',
    'auto_unlock_note': 'Next episodes unlock automatically',
    'unlock_with_coins': 'Unlock with {cost} {unit}',
    'unlock_this_episode': 'Unlock this episode',
    'unlock_now': 'Unlock now',
    'watch_ad_to_unlock': 'Watch an ad to unlock this episode',
    'watch_ad_unlock': 'Watch ad',
    'daily_ad_limit_reached': 'Daily ad limit reached',
    'no_video_available': 'No video available',
    'no_video_available_desc': 'This episode has no video source yet.',
    'no_episodes': 'No episodes',
    'no_episodes_desc': 'No episodes are available for this title yet.',
    'loading_episode': 'Loading episode...',
    'loading_video': 'Loading video...',
    'video_failed': 'Video failed',
    'video_failed_desc': 'This video source cannot be played on this device.',
    'open_external': 'Open',
    'quality': 'Quality',
    'choose_quality': 'Choose quality',
    'auto': 'Auto',
    'favorites': 'Favorites',
    'list': 'List',
    'more': 'More',
    'speed': 'Speed',
    'change_photo': 'Change photo',
    'remove_photo': 'Remove photo',
    'delete': 'Delete',
    'delete_account': 'Delete account',
    'delete_account_confirm': 'This will permanently delete your account. This action cannot be undone.',
    'phone': 'Phone',
    'username': 'Username',
    'account': 'Account',
    'security': 'Security',
    'update_password': 'Update password',
    'current_password': 'Current password',
    'new_password': 'New password',
    'confirm_new_password': 'Confirm new password',
    'password_updated': 'Password updated',
    'two_factor_authentication': 'Two-factor authentication',
    'two_factor_secret': 'Secret key',
    'recovery_codes': 'Recovery codes',
    'copy': 'Copy',
    'copied': 'Copied',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'enable': 'Enable',
    'disable': 'Disable',
    'two_factor_enabled_ok': 'Two-factor enabled',
    'two_factor_disabled_ok': 'Two-factor disabled',
    'update_available_title': 'Update Available',
    'update_force_body': 'A new version is required to continue using the app.',
    'update_optional_body': 'A new version is available with new features and improvements.',
    'update_versions': 'Current build: {current}\nLatest build: {latest}',
    'update_open_failed': 'Failed to open update link',
    'update_now': 'Update Now',
    'continue': 'Continue',
    'update_force_hint': 'You must update to continue.',
    'legal_prefix': 'By continuing, you agree to our',
    'legal_and': 'and',
    'privacy_policy': 'Privacy Policy',
    'terms_of_use': 'Terms of Use',
    'unable_open_link': 'Unable to open link',
    'exit_confirm_title': 'Exit app?',
    'exit_confirm_body': 'Do you want to exit?',
    'exit_confirm_cancel': 'Cancel',
    'exit_confirm_exit': 'Exit',
    'days': '{days} Days',
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
