/// Single source of truth for backend routes. Keep in sync with
/// rayuela-NodeBackend controllers.
class ApiPaths {
  const ApiPaths._();

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String google = '/auth/google';
  static const String forgotPassword = '/auth/forgot-password';
  
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';
  static const String me = '/user';

  // --- Voluntariado / Tareas ---
  static const String volunteerPublicProjects = '/volunteer/public/projects';
  static const String volunteerProjects = '/volunteer/projects';
  static String project(String id) => '/projects/$id';
  static String publicProject(String id) => '/projects/public/$id';
  static String subscribe(String projectId) =>
      '/volunteer/subscription/$projectId';

  // Tasks
  static String projectTasks(String projectId) => '/task/project/$projectId';
  static String task(String id) => '/task/$id';

  // Check-ins
  static const String checkins = '/checkin';
  static const String rateCheckin = '/checkin/rate';
  static String checkin(String id) => '/checkin/$id';
  static String userCheckins(String projectId) => '/checkin/user/$projectId';

  // Leaderboard
  static String leaderboard(String projectId) => '/leaderboard/$projectId';

  // Gamification
  static String gamification(String projectId) => '/gamification/$projectId';

  // Storage
  static String storageFile(String key) =>
      '/storage/file?key=${Uri.encodeQueryComponent(key)}';
}
