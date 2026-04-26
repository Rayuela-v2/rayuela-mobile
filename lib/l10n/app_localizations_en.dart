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
  String dashboard_greeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get dashboard_empty_title => 'No projects yet';

  @override
  String get dashboard_empty_body =>
      'Discover citizen-science projects near you and subscribe to start participating.';

  @override
  String get error_no_internet => 'No internet connection.';

  @override
  String get error_server => 'Something went wrong on our side.';

  @override
  String get error_unauthorized => 'Your session expired. Please log in again.';

  @override
  String get common_retry => 'Try again';

  @override
  String get common_logout => 'Log out';
}
