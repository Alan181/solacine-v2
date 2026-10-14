// ------------------------------
// 1. Backend API Base URL
//    NOTE: Must end with  /api
// ------------------------------
const defaultApiBaseUrl = 'https://solacine.shop/api';

const _defaultAndroidAppKey = 'Drame_android_6ef8b7fd066ffc6357441089b854abfe';
const _defaultIOSAppKey     = 'Drame_ios_8ec8f97acd5aad86b51af73c3ac7cc8b';


const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultApiBaseUrl);
const androidAppConfigKey = String.fromEnvironment('ANDROID_APP_KEY', defaultValue: _defaultAndroidAppKey);
const iosAppConfigKey = String.fromEnvironment('IOS_APP_KEY',     defaultValue: _defaultIOSAppKey);
