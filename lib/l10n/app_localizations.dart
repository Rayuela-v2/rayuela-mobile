import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Rayuela'**
  String get appTitle;

  /// No description provided for @login_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get login_title;

  /// No description provided for @login_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to keep contributing to citizen science.'**
  String get login_subtitle;

  /// No description provided for @login_username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get login_username;

  /// No description provided for @login_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get login_password;

  /// No description provided for @login_submit.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login_submit;

  /// No description provided for @login_forgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get login_forgot;

  /// No description provided for @login_no_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get login_no_account;

  /// No description provided for @login_sign_up.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get login_sign_up;

  /// No description provided for @login_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get login_google;

  /// No description provided for @login_google_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google…'**
  String get login_google_connecting;

  /// No description provided for @login_google_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not configured for this build. Pass GOOGLE_CLIENT_ID_WEB (and GOOGLE_CLIENT_ID_IOS on iOS) via --dart-define-from-file=.env.development.'**
  String get login_google_not_configured;

  /// No description provided for @login_invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password.'**
  String get login_invalid_credentials;

  /// No description provided for @login_username_required.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get login_username_required;

  /// No description provided for @login_password_required.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get login_password_required;

  /// No description provided for @login_pick_username_title.
  ///
  /// In en, this message translates to:
  /// **'Pick a username'**
  String get login_pick_username_title;

  /// No description provided for @login_pick_username_body.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t find a Rayuela account for this Google profile yet. Choose a username to finish signing up.'**
  String get login_pick_username_body;

  /// No description provided for @login_pick_username_min.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get login_pick_username_min;

  /// No description provided for @login_pick_username_required.
  ///
  /// In en, this message translates to:
  /// **'Pick a username to continue'**
  String get login_pick_username_required;

  /// No description provided for @register_title.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get register_title;

  /// No description provided for @register_full_name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get register_full_name;

  /// No description provided for @register_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get register_email;

  /// No description provided for @register_confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get register_confirm_password;

  /// No description provided for @register_accept_terms.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms and privacy policy.'**
  String get register_accept_terms;

  /// No description provided for @register_submit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register_submit;

  /// No description provided for @register_have_account.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get register_have_account;

  /// No description provided for @register_full_name_required.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get register_full_name_required;

  /// No description provided for @register_username_min.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get register_username_min;

  /// No description provided for @register_email_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get register_email_required;

  /// No description provided for @register_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get register_email_invalid;

  /// No description provided for @register_password_min.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get register_password_min;

  /// No description provided for @register_passwords_no_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get register_passwords_no_match;

  /// No description provided for @register_must_accept_terms.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms to continue.'**
  String get register_must_accept_terms;

  /// No description provided for @register_success_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to verify, then log in.'**
  String get register_success_snackbar;

  /// No description provided for @dashboard_greeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String dashboard_greeting(String name);

  /// No description provided for @dashboard_greeting_fallback.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get dashboard_greeting_fallback;

  /// No description provided for @dashboard_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get dashboard_empty_title;

  /// No description provided for @dashboard_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Discover citizen-science projects near you and subscribe to start participating.'**
  String get dashboard_empty_body;

  /// No description provided for @project_detail_fallback_title.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project_detail_fallback_title;

  /// No description provided for @project_tab_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get project_tab_overview;

  /// No description provided for @project_tab_checkins.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get project_tab_checkins;

  /// No description provided for @project_tab_progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get project_tab_progress;

  /// No description provided for @project_view_tasks.
  ///
  /// In en, this message translates to:
  /// **'View tasks'**
  String get project_view_tasks;

  /// No description provided for @project_add_checkin.
  ///
  /// In en, this message translates to:
  /// **'Add a check-in'**
  String get project_add_checkin;

  /// No description provided for @project_subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to project'**
  String get project_subscribe;

  /// No description provided for @project_subscribing.
  ///
  /// In en, this message translates to:
  /// **'Subscribing…'**
  String get project_subscribing;

  /// No description provided for @project_subscribed_success.
  ///
  /// In en, this message translates to:
  /// **'You\'re subscribed!'**
  String get project_subscribed_success;

  /// No description provided for @project_unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe from this project'**
  String get project_unsubscribe;

  /// No description provided for @project_unsubscribe_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins stay; you stop earning new points and badges.'**
  String get project_unsubscribe_subtitle;

  /// No description provided for @project_unsubscribe_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe?'**
  String get project_unsubscribe_confirm_title;

  /// No description provided for @project_unsubscribe_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You can re-subscribe anytime. Earned badges and points stay on your profile.'**
  String get project_unsubscribe_confirm_body;

  /// No description provided for @project_unsubscribe_success.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed.'**
  String get project_unsubscribe_success;

  /// No description provided for @project_stat_points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get project_stat_points;

  /// No description provided for @project_stat_badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get project_stat_badges;

  /// No description provided for @project_stat_rank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get project_stat_rank;

  /// No description provided for @project_section_leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get project_section_leaderboard;

  /// No description provided for @project_section_badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get project_section_badges;

  /// No description provided for @project_card_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get project_card_status_active;

  /// No description provided for @project_card_status_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get project_card_status_paused;

  /// No description provided for @project_card_pts.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String project_card_pts(int count);

  /// No description provided for @project_card_badges.
  ///
  /// In en, this message translates to:
  /// **'{count} badges'**
  String project_card_badges(int count);

  /// No description provided for @badge_earned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get badge_earned;

  /// No description provided for @badge_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get badge_locked;

  /// No description provided for @badge_requires.
  ///
  /// In en, this message translates to:
  /// **'Requires'**
  String get badge_requires;

  /// No description provided for @map_screen_title.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map_screen_title;

  /// No description provided for @map_full_screen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get map_full_screen;

  /// No description provided for @map_center_on_me.
  ///
  /// In en, this message translates to:
  /// **'Center on me'**
  String get map_center_on_me;

  /// No description provided for @map_location_permission_needed.
  ///
  /// In en, this message translates to:
  /// **'Location permission needed'**
  String get map_location_permission_needed;

  /// No description provided for @map_fit_to_areas.
  ///
  /// In en, this message translates to:
  /// **'Fit to project areas'**
  String get map_fit_to_areas;

  /// No description provided for @map_legend_has_open.
  ///
  /// In en, this message translates to:
  /// **'Has open tasks'**
  String get map_legend_has_open;

  /// No description provided for @map_legend_no_open.
  ///
  /// In en, this message translates to:
  /// **'No open tasks'**
  String get map_legend_no_open;

  /// No description provided for @map_legend_solved_task.
  ///
  /// In en, this message translates to:
  /// **'Check-in solved a task'**
  String get map_legend_solved_task;

  /// No description provided for @map_legend_no_task.
  ///
  /// In en, this message translates to:
  /// **'Check-in (no task)'**
  String get map_legend_no_task;

  /// No description provided for @map_legend_you_here.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get map_legend_you_here;

  /// No description provided for @map_legend_your_location.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get map_legend_your_location;

  /// No description provided for @map_attribution.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap'**
  String get map_attribution;

  /// No description provided for @map_area_no_tasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this area'**
  String get map_area_no_tasks;

  /// No description provided for @map_area_all_completed.
  ///
  /// In en, this message translates to:
  /// **'All {count} tasks completed'**
  String map_area_all_completed(int count);

  /// No description provided for @map_area_pending_only.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 task pending} other{{count} tasks pending}}'**
  String map_area_pending_only(int count);

  /// No description provided for @map_area_pending_done.
  ///
  /// In en, this message translates to:
  /// **'{pending} pending · {done} done'**
  String map_area_pending_done(int pending, int done);

  /// No description provided for @map_open_tasks.
  ///
  /// In en, this message translates to:
  /// **'Open tasks'**
  String get map_open_tasks;

  /// No description provided for @tasks_appbar_fallback.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks_appbar_fallback;

  /// No description provided for @tasks_section_open.
  ///
  /// In en, this message translates to:
  /// **'Open · {count}'**
  String tasks_section_open(int count);

  /// No description provided for @tasks_section_solved.
  ///
  /// In en, this message translates to:
  /// **'Solved · {count}'**
  String tasks_section_solved(int count);

  /// No description provided for @tasks_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get tasks_empty_title;

  /// No description provided for @tasks_empty_body.
  ///
  /// In en, this message translates to:
  /// **'This project does not have any tasks open right now. Pull down to refresh.'**
  String get tasks_empty_body;

  /// No description provided for @tasks_filter_label.
  ///
  /// In en, this message translates to:
  /// **'Area · {areaName}'**
  String tasks_filter_label(String areaName);

  /// No description provided for @tasks_empty_for_area_title.
  ///
  /// In en, this message translates to:
  /// **'No tasks in \"{areaName}\"'**
  String tasks_empty_for_area_title(String areaName);

  /// No description provided for @tasks_empty_for_area_body.
  ///
  /// In en, this message translates to:
  /// **'This area has no tasks attached right now.'**
  String get tasks_empty_for_area_body;

  /// No description provided for @tasks_clear_filter.
  ///
  /// In en, this message translates to:
  /// **'Show all areas'**
  String get tasks_clear_filter;

  /// No description provided for @tasks_already_solved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has already been solved.'**
  String tasks_already_solved(String name);

  /// No description provided for @task_card_pts_unit.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get task_card_pts_unit;

  /// No description provided for @task_card_solved_by.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String task_card_solved_by(String name);

  /// No description provided for @checkin_screen_title_default.
  ///
  /// In en, this message translates to:
  /// **'New check-in'**
  String get checkin_screen_title_default;

  /// No description provided for @checkin_section_kind.
  ///
  /// In en, this message translates to:
  /// **'What kind of check-in?'**
  String get checkin_section_kind;

  /// No description provided for @checkin_section_photos.
  ///
  /// In en, this message translates to:
  /// **'Photos · {count}/{max}'**
  String checkin_section_photos(int count, int max);

  /// No description provided for @checkin_section_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get checkin_section_location;

  /// No description provided for @checkin_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get checkin_section_notes;

  /// No description provided for @checkin_btn_camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get checkin_btn_camera;

  /// No description provided for @checkin_btn_gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get checkin_btn_gallery;

  /// No description provided for @checkin_btn_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit check-in'**
  String get checkin_btn_submit;

  /// No description provided for @checkin_picker_freetext_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. observation, photo report, water sample'**
  String get checkin_picker_freetext_hint;

  /// No description provided for @checkin_notes_hint.
  ///
  /// In en, this message translates to:
  /// **'Anything the project team should know about this observation?'**
  String get checkin_notes_hint;

  /// No description provided for @checkin_photos_hint.
  ///
  /// In en, this message translates to:
  /// **'Add up to {max} photos to support your observation.'**
  String checkin_photos_hint(int max);

  /// No description provided for @checkin_camera_error.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera: {detail}'**
  String checkin_camera_error(String detail);

  /// No description provided for @checkin_gallery_error.
  ///
  /// In en, this message translates to:
  /// **'Could not open the gallery: {detail}'**
  String checkin_gallery_error(String detail);

  /// No description provided for @checkin_validation_pick_kind.
  ///
  /// In en, this message translates to:
  /// **'Pick what kind of check-in this is.'**
  String get checkin_validation_pick_kind;

  /// No description provided for @checkin_validation_add_photo.
  ///
  /// In en, this message translates to:
  /// **'Add at least one photo first.'**
  String get checkin_validation_add_photo;

  /// No description provided for @checkin_validation_waiting_location.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your location. Retry or pick a spot on the map.'**
  String get checkin_validation_waiting_location;

  /// No description provided for @location_resolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving your location…'**
  String get location_resolving;

  /// No description provided for @location_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Location not available yet.'**
  String get location_unavailable;

  /// No description provided for @location_pinned_manual.
  ///
  /// In en, this message translates to:
  /// **'Pinned manually on the map'**
  String get location_pinned_manual;

  /// No description provided for @location_accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy ±{meters} m'**
  String location_accuracy(String meters);

  /// No description provided for @location_btn_pick_on_map.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get location_btn_pick_on_map;

  /// No description provided for @location_btn_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get location_btn_retry;

  /// No description provided for @location_btn_locate.
  ///
  /// In en, this message translates to:
  /// **'Locate'**
  String get location_btn_locate;

  /// No description provided for @location_btn_use_gps_instead.
  ///
  /// In en, this message translates to:
  /// **'Use GPS instead'**
  String get location_btn_use_gps_instead;

  /// No description provided for @location_btn_edit_on_map.
  ///
  /// In en, this message translates to:
  /// **'Edit on map'**
  String get location_btn_edit_on_map;

  /// No description provided for @location_btn_refresh_gps.
  ///
  /// In en, this message translates to:
  /// **'Refresh GPS'**
  String get location_btn_refresh_gps;

  /// No description provided for @location_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Pick location on map'**
  String get location_picker_title;

  /// No description provided for @location_picker_recenter.
  ///
  /// In en, this message translates to:
  /// **'Re-center'**
  String get location_picker_recenter;

  /// No description provided for @location_picker_use_this.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get location_picker_use_this;

  /// No description provided for @location_unknown_error.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location. Try again.'**
  String get location_unknown_error;

  /// No description provided for @location_disabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off. Enable them to check in.'**
  String get location_disabled;

  /// No description provided for @location_denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to attach your check-in to the project area.'**
  String get location_denied;

  /// No description provided for @location_denied_forever.
  ///
  /// In en, this message translates to:
  /// **'Location is permanently denied. Open Settings to grant access and try again.'**
  String get location_denied_forever;

  /// No description provided for @checkin_result_title.
  ///
  /// In en, this message translates to:
  /// **'Thanks for contributing'**
  String get checkin_result_title;

  /// No description provided for @checkin_result_contributed_to.
  ///
  /// In en, this message translates to:
  /// **'Contributed to \"{name}\"'**
  String checkin_result_contributed_to(String name);

  /// No description provided for @checkin_result_points_label.
  ///
  /// In en, this message translates to:
  /// **'+{points} pts'**
  String checkin_result_points_label(int points);

  /// No description provided for @checkin_result_recorded.
  ///
  /// In en, this message translates to:
  /// **'Check-in recorded'**
  String get checkin_result_recorded;

  /// No description provided for @checkin_result_earned.
  ///
  /// In en, this message translates to:
  /// **'Earned for this check-in'**
  String get checkin_result_earned;

  /// No description provided for @checkin_result_new_badges.
  ///
  /// In en, this message translates to:
  /// **'New badges'**
  String get checkin_result_new_badges;

  /// No description provided for @checkin_back_to_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get checkin_back_to_dashboard;

  /// No description provided for @checkin_back_to_project.
  ///
  /// In en, this message translates to:
  /// **'Back to project'**
  String get checkin_back_to_project;

  /// No description provided for @checkin_result_queued_title.
  ///
  /// In en, this message translates to:
  /// **'Saved — will sync when you have signal'**
  String get checkin_result_queued_title;

  /// No description provided for @checkin_result_queued_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send your check-in automatically as soon as you\'re back online. You can keep working in the meantime.'**
  String get checkin_result_queued_subtitle;

  /// No description provided for @checkin_result_queued_at.
  ///
  /// In en, this message translates to:
  /// **'Captured at {time}'**
  String checkin_result_queued_at(String time);

  /// No description provided for @checkin_offline_chip.
  ///
  /// In en, this message translates to:
  /// **'No connection — we\'ll send it when you\'re back online'**
  String get checkin_offline_chip;

  /// No description provided for @outbox_status_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get outbox_status_pending;

  /// No description provided for @outbox_status_retrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get outbox_status_retrying;

  /// No description provided for @outbox_status_inflight.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get outbox_status_inflight;

  /// No description provided for @outbox_status_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed — tap to retry'**
  String get outbox_status_failed;

  /// No description provided for @outbox_action_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get outbox_action_retry;

  /// No description provided for @outbox_action_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get outbox_action_discard;

  /// No description provided for @outbox_action_retry_all.
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get outbox_action_retry_all;

  /// No description provided for @outbox_section_pending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get outbox_section_pending;

  /// No description provided for @outbox_pending_at.
  ///
  /// In en, this message translates to:
  /// **'Captured at {time}'**
  String outbox_pending_at(String time);

  /// No description provided for @outbox_attempt_count.
  ///
  /// In en, this message translates to:
  /// **'Attempt #{count}'**
  String outbox_attempt_count(int count);

  /// No description provided for @outbox_discard_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Discard pending check-in?'**
  String get outbox_discard_confirm_title;

  /// No description provided for @outbox_discard_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'The photos and details will be removed from this device. This cannot be undone.'**
  String get outbox_discard_confirm_body;

  /// No description provided for @outbox_discard_confirm_cta.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get outbox_discard_confirm_cta;

  /// No description provided for @outbox_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get outbox_cancel;

  /// No description provided for @dashboard_outbox_banner_one.
  ///
  /// In en, this message translates to:
  /// **'1 check-in waiting to sync'**
  String get dashboard_outbox_banner_one;

  /// No description provided for @dashboard_outbox_banner_many.
  ///
  /// In en, this message translates to:
  /// **'{count} check-ins waiting to sync'**
  String dashboard_outbox_banner_many(int count);

  /// No description provided for @dashboard_outbox_banner_action.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get dashboard_outbox_banner_action;

  /// No description provided for @dashboard_sync_status_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get dashboard_sync_status_offline;

  /// No description provided for @dashboard_sync_status_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get dashboard_sync_status_syncing;

  /// No description provided for @dashboard_sync_status_error.
  ///
  /// In en, this message translates to:
  /// **'Sync issues'**
  String get dashboard_sync_status_error;

  /// No description provided for @pending_data_title.
  ///
  /// In en, this message translates to:
  /// **'Pending data'**
  String get pending_data_title;

  /// No description provided for @pending_data_empty_title.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting'**
  String get pending_data_empty_title;

  /// No description provided for @pending_data_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Check-ins you create offline will appear here while we wait for a connection.'**
  String get pending_data_empty_body;

  /// No description provided for @pending_data_project_label.
  ///
  /// In en, this message translates to:
  /// **'Project: {projectId}'**
  String pending_data_project_label(String projectId);

  /// No description provided for @checkins_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet'**
  String get checkins_empty_title;

  /// No description provided for @checkins_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins for this project will appear here. Open a task and add your first one to start earning points.'**
  String get checkins_empty_body;

  /// No description provided for @checkins_card_default_kind.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkins_card_default_kind;

  /// No description provided for @checkins_task_solved.
  ///
  /// In en, this message translates to:
  /// **'Task solved'**
  String get checkins_task_solved;

  /// No description provided for @checkins_task_solved_named.
  ///
  /// In en, this message translates to:
  /// **'Solved · {name}'**
  String checkins_task_solved_named(String name);

  /// No description provided for @image_viewer_single.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get image_viewer_single;

  /// No description provided for @image_viewer_paged.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {total}'**
  String image_viewer_paged(int index, int total);

  /// No description provided for @leaderboard_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No rankings yet'**
  String get leaderboard_empty_title;

  /// No description provided for @leaderboard_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Be the first to log a check-in and start climbing the leaderboard.'**
  String get leaderboard_empty_body;

  /// No description provided for @leaderboard_you.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get leaderboard_you;

  /// No description provided for @leaderboard_pt_singular.
  ///
  /// In en, this message translates to:
  /// **'pt'**
  String get leaderboard_pt_singular;

  /// No description provided for @leaderboard_pt_plural.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get leaderboard_pt_plural;

  /// No description provided for @leaderboard_badges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 badge} other{{count} badges}}'**
  String leaderboard_badges(int count);

  /// No description provided for @admin_not_supported_title.
  ///
  /// In en, this message translates to:
  /// **'The mobile app is for volunteers'**
  String get admin_not_supported_title;

  /// No description provided for @admin_not_supported_body.
  ///
  /// In en, this message translates to:
  /// **'Please manage projects, gamification and tasks from the Rayuela web console.'**
  String get admin_not_supported_body;

  /// No description provided for @router_route_not_found.
  ///
  /// In en, this message translates to:
  /// **'Route not found: {uri}'**
  String router_route_not_found(String uri);

  /// No description provided for @router_missing_params.
  ///
  /// In en, this message translates to:
  /// **'Missing {what} — please open this screen from the dashboard.'**
  String router_missing_params(String what);

  /// No description provided for @router_param_project_id.
  ///
  /// In en, this message translates to:
  /// **'project id'**
  String get router_param_project_id;

  /// No description provided for @router_param_checkin_result.
  ///
  /// In en, this message translates to:
  /// **'check-in result'**
  String get router_param_checkin_result;

  /// No description provided for @language_picker_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language_picker_tooltip;

  /// No description provided for @language_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language_picker_title;

  /// No description provided for @language_picker_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language you\'d like to use across the app. The change applies right away.'**
  String get language_picker_subtitle;

  /// No description provided for @language_picker_saved.
  ///
  /// In en, this message translates to:
  /// **'Language updated.'**
  String get language_picker_saved;

  /// No description provided for @language_system.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get language_system;

  /// No description provided for @language_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language_english;

  /// No description provided for @language_spanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get language_spanish;

  /// No description provided for @language_portuguese.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get language_portuguese;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continue;

  /// No description provided for @common_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// No description provided for @common_unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get common_unsubscribe;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get common_retry;

  /// No description provided for @common_logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get common_logout;

  /// No description provided for @error_no_internet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get error_no_internet;

  /// No description provided for @error_no_internet_long.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.\nCheck your signal and retry.'**
  String get error_no_internet_long;

  /// No description provided for @error_server.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side.'**
  String get error_server;

  /// No description provided for @error_server_with_code.
  ///
  /// In en, this message translates to:
  /// **'Server error ({code}). Please try again.'**
  String error_server_with_code(int code);

  /// No description provided for @error_server_no_code.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again.'**
  String get error_server_no_code;

  /// No description provided for @error_unauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get error_unauthorized;

  /// No description provided for @error_timeout.
  ///
  /// In en, this message translates to:
  /// **'The server is slow to respond. Try again in a moment.'**
  String get error_timeout;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
