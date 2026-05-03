// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rayuela';

  @override
  String get login_title => 'Welcome back';

  @override
  String get login_subtitle =>
      'Log in to keep contributing to citizen science.';

  @override
  String get login_username => 'Username';

  @override
  String get login_password => 'Password';

  @override
  String get login_submit => 'Log in';

  @override
  String get login_forgot => 'Forgot password?';

  @override
  String get login_no_account => 'Don\'t have an account?';

  @override
  String get login_sign_up => 'Sign up';

  @override
  String get login_google => 'Continue with Google';

  @override
  String get login_google_connecting => 'Connecting to Google…';

  @override
  String get login_google_not_configured =>
      'Google sign-in is not configured for this build. Pass GOOGLE_CLIENT_ID_WEB (and GOOGLE_CLIENT_ID_IOS on iOS) via --dart-define-from-file=.env.development.';

  @override
  String get login_invalid_credentials => 'Invalid username or password.';

  @override
  String get login_username_required => 'Enter your username';

  @override
  String get login_password_required => 'Enter your password';

  @override
  String get login_pick_username_title => 'Pick a username';

  @override
  String get login_pick_username_body =>
      'We didn\'t find a Rayuela account for this Google profile yet. Choose a username to finish signing up.';

  @override
  String get login_pick_username_min => 'At least 3 characters';

  @override
  String get login_pick_username_required => 'Pick a username to continue';

  @override
  String get register_title => 'Create your account';

  @override
  String get register_full_name => 'Full name';

  @override
  String get register_email => 'Email';

  @override
  String get register_confirm_password => 'Confirm password';

  @override
  String get register_accept_terms => 'I accept the terms and privacy policy.';

  @override
  String get register_submit => 'Create account';

  @override
  String get register_have_account => 'I already have an account';

  @override
  String get register_full_name_required => 'Enter your name';

  @override
  String get register_username_min => 'Username must be at least 3 characters';

  @override
  String get register_email_required => 'Email is required';

  @override
  String get register_email_invalid => 'Enter a valid email';

  @override
  String get register_password_min => 'Password must be at least 8 characters';

  @override
  String get register_passwords_no_match => 'Passwords do not match';

  @override
  String get register_must_accept_terms =>
      'Please accept the terms to continue.';

  @override
  String get register_success_snackbar =>
      'Account created. Check your email to verify, then log in.';

  @override
  String dashboard_greeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get dashboard_greeting_fallback => 'Hi';

  @override
  String get dashboard_empty_title => 'No projects yet';

  @override
  String get dashboard_empty_body =>
      'Discover citizen-science projects near you and subscribe to start participating.';

  @override
  String get project_detail_fallback_title => 'Project';

  @override
  String get project_tab_overview => 'Overview';

  @override
  String get project_tab_checkins => 'Check-ins';

  @override
  String get project_tab_progress => 'Progress';

  @override
  String get project_view_tasks => 'View tasks';

  @override
  String get project_add_checkin => 'Add a check-in';

  @override
  String get project_subscribe => 'Subscribe to project';

  @override
  String get project_subscribing => 'Subscribing…';

  @override
  String get project_subscribed_success => 'You\'re subscribed!';

  @override
  String get project_unsubscribe => 'Unsubscribe from this project';

  @override
  String get project_unsubscribe_subtitle =>
      'Your check-ins stay; you stop earning new points and badges.';

  @override
  String get project_unsubscribe_confirm_title => 'Unsubscribe?';

  @override
  String get project_unsubscribe_confirm_body =>
      'You can re-subscribe anytime. Earned badges and points stay on your profile.';

  @override
  String get project_unsubscribe_success => 'Unsubscribed.';

  @override
  String get project_stat_points => 'Points';

  @override
  String get project_stat_badges => 'Badges';

  @override
  String get project_stat_rank => 'Rank';

  @override
  String get project_section_leaderboard => 'Leaderboard';

  @override
  String get project_section_badges => 'Badges';

  @override
  String get project_card_status_active => 'Active';

  @override
  String get project_card_status_paused => 'Paused';

  @override
  String project_card_pts(int count) {
    return '$count pts';
  }

  @override
  String project_card_badges(int count) {
    return '$count badges';
  }

  @override
  String get badge_earned => 'Earned';

  @override
  String get badge_locked => 'Locked';

  @override
  String get badge_requires => 'Requires';

  @override
  String get map_screen_title => 'Map';

  @override
  String get map_full_screen => 'Full screen';

  @override
  String get map_center_on_me => 'Center on me';

  @override
  String get map_location_permission_needed => 'Location permission needed';

  @override
  String get map_fit_to_areas => 'Fit to project areas';

  @override
  String get map_legend_has_open => 'Has open tasks';

  @override
  String get map_legend_no_open => 'No open tasks';

  @override
  String get map_legend_solved_task => 'Check-in solved a task';

  @override
  String get map_legend_no_task => 'Check-in (no task)';

  @override
  String get map_legend_you_here => 'You are here';

  @override
  String get map_legend_your_location => 'Your location';

  @override
  String get map_attribution => '© OpenStreetMap';

  @override
  String get map_area_no_tasks => 'No tasks in this area';

  @override
  String map_area_all_completed(int count) {
    return 'All $count tasks completed';
  }

  @override
  String map_area_pending_only(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks pending',
      one: '1 task pending',
    );
    return '$_temp0';
  }

  @override
  String map_area_pending_done(int pending, int done) {
    return '$pending pending · $done done';
  }

  @override
  String get map_open_tasks => 'Open tasks';

  @override
  String get tasks_appbar_fallback => 'Tasks';

  @override
  String tasks_section_open(int count) {
    return 'Open · $count';
  }

  @override
  String tasks_section_solved(int count) {
    return 'Solved · $count';
  }

  @override
  String get tasks_empty_title => 'No tasks yet';

  @override
  String get tasks_empty_body =>
      'This project does not have any tasks open right now. Pull down to refresh.';

  @override
  String tasks_filter_label(String areaName) {
    return 'Area · $areaName';
  }

  @override
  String tasks_empty_for_area_title(String areaName) {
    return 'No tasks in \"$areaName\"';
  }

  @override
  String get tasks_empty_for_area_body =>
      'This area has no tasks attached right now.';

  @override
  String get tasks_clear_filter => 'Show all areas';

  @override
  String tasks_already_solved(String name) {
    return '\"$name\" has already been solved.';
  }

  @override
  String get task_card_pts_unit => 'pts';

  @override
  String task_card_solved_by(String name) {
    return 'by $name';
  }

  @override
  String get checkin_screen_title_default => 'New check-in';

  @override
  String get checkin_section_kind => 'What kind of check-in?';

  @override
  String checkin_section_photos(int count, int max) {
    return 'Photos · $count/$max';
  }

  @override
  String get checkin_section_location => 'Location';

  @override
  String get checkin_section_notes => 'Notes (optional)';

  @override
  String get checkin_btn_camera => 'Camera';

  @override
  String get checkin_btn_gallery => 'Gallery';

  @override
  String get checkin_btn_submit => 'Submit check-in';

  @override
  String get checkin_picker_freetext_hint =>
      'e.g. observation, photo report, water sample';

  @override
  String get checkin_notes_hint =>
      'Anything the project team should know about this observation?';

  @override
  String checkin_photos_hint(int max) {
    return 'Add up to $max photos to support your observation.';
  }

  @override
  String checkin_camera_error(String detail) {
    return 'Could not open the camera: $detail';
  }

  @override
  String checkin_gallery_error(String detail) {
    return 'Could not open the gallery: $detail';
  }

  @override
  String get checkin_validation_pick_kind =>
      'Pick what kind of check-in this is.';

  @override
  String get checkin_validation_add_photo => 'Add at least one photo first.';

  @override
  String get checkin_validation_waiting_location =>
      'Waiting for your location. Retry or pick a spot on the map.';

  @override
  String get location_resolving => 'Resolving your location…';

  @override
  String get location_unavailable => 'Location not available yet.';

  @override
  String get location_pinned_manual => 'Pinned manually on the map';

  @override
  String location_accuracy(String meters) {
    return 'Accuracy ±$meters m';
  }

  @override
  String get location_btn_pick_on_map => 'Pick on map';

  @override
  String get location_btn_retry => 'Retry';

  @override
  String get location_btn_locate => 'Locate';

  @override
  String get location_btn_use_gps_instead => 'Use GPS instead';

  @override
  String get location_btn_edit_on_map => 'Edit on map';

  @override
  String get location_btn_refresh_gps => 'Refresh GPS';

  @override
  String get location_picker_title => 'Pick location on map';

  @override
  String get location_picker_recenter => 'Re-center';

  @override
  String get location_picker_use_this => 'Use this location';

  @override
  String get location_unknown_error =>
      'Could not determine your location. Try again.';

  @override
  String get location_disabled =>
      'Location services are turned off. Enable them to check in.';

  @override
  String get location_denied =>
      'Location permission is required to attach your check-in to the project area.';

  @override
  String get location_denied_forever =>
      'Location is permanently denied. Open Settings to grant access and try again.';

  @override
  String get checkin_result_title => 'Thanks for contributing';

  @override
  String checkin_result_contributed_to(String name) {
    return 'Contributed to \"$name\"';
  }

  @override
  String checkin_result_points_label(int points) {
    return '+$points pts';
  }

  @override
  String get checkin_result_recorded => 'Check-in recorded';

  @override
  String get checkin_result_earned => 'Earned for this check-in';

  @override
  String get checkin_result_new_badges => 'New badges';

  @override
  String get checkin_back_to_dashboard => 'Back to dashboard';

  @override
  String get checkin_back_to_project => 'Back to project';

  @override
  String get checkin_result_queued_title =>
      'Saved — will sync when you have signal';

  @override
  String get checkin_result_queued_subtitle =>
      'We\'ll send your check-in automatically as soon as you\'re back online. You can keep working in the meantime.';

  @override
  String checkin_result_queued_at(String time) {
    return 'Captured at $time';
  }

  @override
  String get checkin_offline_chip =>
      'No connection — we\'ll send it when you\'re back online';

  @override
  String get outbox_status_pending => 'Pending';

  @override
  String get outbox_status_retrying => 'Retrying…';

  @override
  String get outbox_status_inflight => 'Sending…';

  @override
  String get outbox_status_failed => 'Failed — tap to retry';

  @override
  String get outbox_action_retry => 'Retry now';

  @override
  String get outbox_action_discard => 'Discard';

  @override
  String get outbox_action_retry_all => 'Retry all';

  @override
  String get outbox_section_pending => 'Waiting to sync';

  @override
  String outbox_pending_at(String time) {
    return 'Captured at $time';
  }

  @override
  String outbox_attempt_count(int count) {
    return 'Attempt #$count';
  }

  @override
  String get outbox_discard_confirm_title => 'Discard pending check-in?';

  @override
  String get outbox_discard_confirm_body =>
      'The photos and details will be removed from this device. This cannot be undone.';

  @override
  String get outbox_discard_confirm_cta => 'Discard';

  @override
  String get outbox_cancel => 'Cancel';

  @override
  String get dashboard_outbox_banner_one => '1 check-in waiting to sync';

  @override
  String dashboard_outbox_banner_many(int count) {
    return '$count check-ins waiting to sync';
  }

  @override
  String get dashboard_outbox_banner_action => 'View';

  @override
  String get dashboard_sync_status_offline => 'Offline';

  @override
  String get dashboard_sync_status_syncing => 'Syncing…';

  @override
  String get dashboard_sync_status_error => 'Sync issues';

  @override
  String get pending_data_title => 'Pending data';

  @override
  String get pending_data_empty_title => 'Nothing waiting';

  @override
  String get pending_data_empty_body =>
      'Check-ins you create offline will appear here while we wait for a connection.';

  @override
  String pending_data_project_label(String projectId) {
    return 'Project: $projectId';
  }

  @override
  String get checkins_empty_title => 'No check-ins yet';

  @override
  String get checkins_empty_body =>
      'Your check-ins for this project will appear here. Open a task and add your first one to start earning points.';

  @override
  String get checkins_card_default_kind => 'Check-in';

  @override
  String get checkins_task_solved => 'Task solved';

  @override
  String checkins_task_solved_named(String name) {
    return 'Solved · $name';
  }

  @override
  String get image_viewer_single => 'Photo';

  @override
  String image_viewer_paged(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get leaderboard_empty_title => 'No rankings yet';

  @override
  String get leaderboard_empty_body =>
      'Be the first to log a check-in and start climbing the leaderboard.';

  @override
  String get leaderboard_you => 'YOU';

  @override
  String get leaderboard_pt_singular => 'pt';

  @override
  String get leaderboard_pt_plural => 'pts';

  @override
  String leaderboard_badges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count badges',
      one: '1 badge',
    );
    return '$_temp0';
  }

  @override
  String get admin_not_supported_title => 'The mobile app is for volunteers';

  @override
  String get admin_not_supported_body =>
      'Please manage projects, gamification and tasks from the Rayuela web console.';

  @override
  String router_route_not_found(String uri) {
    return 'Route not found: $uri';
  }

  @override
  String router_missing_params(String what) {
    return 'Missing $what — please open this screen from the dashboard.';
  }

  @override
  String get router_param_project_id => 'project id';

  @override
  String get router_param_checkin_result => 'check-in result';

  @override
  String get language_picker_tooltip => 'Language';

  @override
  String get language_picker_title => 'Language';

  @override
  String get language_picker_subtitle =>
      'Choose the language you\'d like to use across the app. The change applies right away.';

  @override
  String get language_picker_saved => 'Language updated.';

  @override
  String get language_system => 'Follow system';

  @override
  String get language_english => 'English';

  @override
  String get language_spanish => 'Español';

  @override
  String get language_portuguese => 'Português';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_continue => 'Continue';

  @override
  String get common_close => 'Close';

  @override
  String get common_unsubscribe => 'Unsubscribe';

  @override
  String get common_retry => 'Try again';

  @override
  String get common_logout => 'Log out';

  @override
  String get error_no_internet => 'No internet connection.';

  @override
  String get error_no_internet_long =>
      'No internet connection.\nCheck your signal and retry.';

  @override
  String get error_server => 'Something went wrong on our side.';

  @override
  String error_server_with_code(int code) {
    return 'Server error ($code). Please try again.';
  }

  @override
  String get error_server_no_code => 'Server error. Please try again.';

  @override
  String get error_unauthorized => 'Your session expired. Please log in again.';

  @override
  String get error_timeout =>
      'The server is slow to respond. Try again in a moment.';
}
