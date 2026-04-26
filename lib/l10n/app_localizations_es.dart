// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Rayuela';

  @override
  String get login_title => 'Bienvenido de vuelta';

  @override
  String get login_subtitle =>
      'Inicia sesión para seguir contribuyendo a la ciencia ciudadana.';

  @override
  String get login_username => 'Usuario';

  @override
  String get login_password => 'Contraseña';

  @override
  String get login_submit => 'Iniciar sesión';

  @override
  String get login_forgot => '¿Olvidaste tu contraseña?';

  @override
  String get login_no_account => '¿No tienes cuenta?';

  @override
  String get login_sign_up => 'Registrarse';

  @override
  String get login_google => 'Continuar con Google';

  @override
  String get register_title => 'Crea tu cuenta';

  @override
  String get register_full_name => 'Nombre completo';

  @override
  String get register_email => 'Correo electrónico';

  @override
  String get register_confirm_password => 'Confirmar contraseña';

  @override
  String get register_accept_terms =>
      'Acepto los términos y la política de privacidad.';

  @override
  String get register_submit => 'Crear cuenta';

  @override
  String get register_have_account => 'Ya tengo una cuenta';

  @override
  String dashboard_greeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get dashboard_empty_title => 'Aún no tienes proyectos';

  @override
  String get dashboard_empty_body =>
      'Descubre proyectos de ciencia ciudadana cerca de ti y suscríbete para participar.';

  @override
  String get error_no_internet => 'Sin conexión a internet.';

  @override
  String get error_server => 'Algo salió mal de nuestro lado.';

  @override
  String get error_unauthorized => 'Tu sesión expiró. Inicia sesión de nuevo.';

  @override
  String get common_retry => 'Reintentar';

  @override
  String get common_logout => 'Cerrar sesión';
}
