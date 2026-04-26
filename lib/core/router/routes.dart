/// Route path + name constants. Named routes are referenced from screens
/// via `context.goNamed(AppRoute.dashboard)`.
class AppRoute {
  const AppRoute._();

  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot-password';
  static const String dashboard = 'dashboard';
  static const String projectDetail = 'project-detail';
  static const String tasks = 'project-tasks';
  static const String checkin = 'project-checkin';
  static const String checkinResult = 'project-checkin-result';
  static const String adminNotSupported = 'admin-not-supported';
}

class AppPath {
  const AppPath._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String projectDetail = '/project/:projectId';
  static const String tasks = '/project/:projectId/tasks';
  static const String checkin = '/project/:projectId/checkin';
  static const String checkinResult = '/project/:projectId/checkin/result';
  static const String adminNotSupported = '/admin-not-supported';
}
