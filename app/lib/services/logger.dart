class Logger {
  static void info(String message, [dynamic data]) {
    print('[INFO] $message${data != null ? ' $data' : ''}');
  }

  static void error(String message, [dynamic data]) {
    print('[ERROR] $message${data != null ? ' $data' : ''}');
  }

  static void debug(String message, [dynamic data]) {
    print('[DEBUG] $message${data != null ? ' $data' : ''}');
  }

  static void warn(String message, [dynamic data]) {
    print('[WARN] $message${data != null ? ' $data' : ''}');
  }
}
