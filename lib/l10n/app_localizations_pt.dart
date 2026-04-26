// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Rayuela';

  @override
  String get login_title => 'Bem-vindo de volta';

  @override
  String get login_subtitle =>
      'Faça login para continuar contribuindo com a ciência cidadã.';

  @override
  String get login_username => 'Usuário';

  @override
  String get login_password => 'Senha';

  @override
  String get login_submit => 'Entrar';

  @override
  String get login_forgot => 'Esqueceu sua senha?';

  @override
  String get login_no_account => 'Não tem conta?';

  @override
  String get login_sign_up => 'Cadastre-se';

  @override
  String get login_google => 'Continuar com Google';

  @override
  String get register_title => 'Crie sua conta';

  @override
  String get register_full_name => 'Nome completo';

  @override
  String get register_email => 'E-mail';

  @override
  String get register_confirm_password => 'Confirmar senha';

  @override
  String get register_accept_terms =>
      'Aceito os termos e a política de privacidade.';

  @override
  String get register_submit => 'Criar conta';

  @override
  String get register_have_account => 'Já tenho uma conta';

  @override
  String dashboard_greeting(String name) {
    return 'Olá, $name';
  }

  @override
  String get dashboard_empty_title => 'Ainda não há projetos';

  @override
  String get dashboard_empty_body =>
      'Descubra projetos de ciência cidadã perto de você e inscreva-se para participar.';

  @override
  String get error_no_internet => 'Sem conexão com a internet.';

  @override
  String get error_server => 'Algo deu errado do nosso lado.';

  @override
  String get error_unauthorized => 'Sua sessão expirou. Faça login novamente.';

  @override
  String get common_retry => 'Tentar novamente';

  @override
  String get common_logout => 'Sair';
}
