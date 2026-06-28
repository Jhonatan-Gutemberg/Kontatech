const String apiBaseUrl = 'https://pmg-es-2025-2-ti5-6904100-kontatech.onrender.com';

String apiUrl(String path) => '$apiBaseUrl$path';

String wsNotificationsUrl(String jwt) =>
    'wss://pmg-es-2025-2-ti5-6904100-kontatech.onrender.com/ws/notifications?token=$jwt';
