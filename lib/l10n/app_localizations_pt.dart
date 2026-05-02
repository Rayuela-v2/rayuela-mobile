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
  String get login_google => 'Continuar com o Google';

  @override
  String get login_google_connecting => 'Conectando ao Google…';

  @override
  String get login_google_not_configured =>
      'O login com Google não está configurado para esta versão. Passe GOOGLE_CLIENT_ID_WEB (e GOOGLE_CLIENT_ID_IOS no iOS) via --dart-define-from-file=.env.development.';

  @override
  String get login_invalid_credentials => 'Usuário ou senha inválidos.';

  @override
  String get login_username_required => 'Digite seu usuário';

  @override
  String get login_password_required => 'Digite sua senha';

  @override
  String get login_pick_username_title => 'Escolha um nome de usuário';

  @override
  String get login_pick_username_body =>
      'Ainda não encontramos uma conta Rayuela para este perfil do Google. Escolha um nome de usuário para concluir o cadastro.';

  @override
  String get login_pick_username_min => 'Mínimo de 3 caracteres';

  @override
  String get login_pick_username_required =>
      'Escolha um nome de usuário para continuar';

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
  String get register_full_name_required => 'Digite seu nome';

  @override
  String get register_username_min =>
      'O nome de usuário deve ter pelo menos 3 caracteres';

  @override
  String get register_email_required => 'O e-mail é obrigatório';

  @override
  String get register_email_invalid => 'Digite um e-mail válido';

  @override
  String get register_password_min =>
      'A senha deve ter pelo menos 8 caracteres';

  @override
  String get register_passwords_no_match => 'As senhas não coincidem';

  @override
  String get register_must_accept_terms => 'Aceite os termos para continuar.';

  @override
  String get register_success_snackbar =>
      'Conta criada. Verifique seu e-mail para confirmar e faça login.';

  @override
  String dashboard_greeting(String name) {
    return 'Olá, $name';
  }

  @override
  String get dashboard_greeting_fallback => 'Olá';

  @override
  String get dashboard_empty_title => 'Ainda não há projetos';

  @override
  String get dashboard_empty_body =>
      'Descubra projetos de ciência cidadã perto de você e inscreva-se para participar.';

  @override
  String get project_detail_fallback_title => 'Projeto';

  @override
  String get project_tab_overview => 'Visão geral';

  @override
  String get project_tab_checkins => 'Check-ins';

  @override
  String get project_tab_progress => 'Progresso';

  @override
  String get project_view_tasks => 'Ver tarefas';

  @override
  String get project_add_checkin => 'Adicionar check-in';

  @override
  String get project_subscribe => 'Inscrever-se no projeto';

  @override
  String get project_subscribing => 'Inscrevendo…';

  @override
  String get project_subscribed_success => 'Você está inscrito!';

  @override
  String get project_unsubscribe => 'Cancelar inscrição neste projeto';

  @override
  String get project_unsubscribe_subtitle =>
      'Seus check-ins continuam; você deixa de ganhar novos pontos e medalhas.';

  @override
  String get project_unsubscribe_confirm_title => 'Cancelar inscrição?';

  @override
  String get project_unsubscribe_confirm_body =>
      'Você pode se inscrever novamente a qualquer momento. As medalhas e os pontos conquistados ficam no seu perfil.';

  @override
  String get project_unsubscribe_success => 'Inscrição cancelada.';

  @override
  String get project_stat_points => 'Pontos';

  @override
  String get project_stat_badges => 'Medalhas';

  @override
  String get project_stat_rank => 'Posição';

  @override
  String get project_section_leaderboard => 'Ranking';

  @override
  String get project_section_badges => 'Medalhas';

  @override
  String get project_card_status_active => 'Ativo';

  @override
  String get project_card_status_paused => 'Pausado';

  @override
  String project_card_pts(int count) {
    return '$count pts';
  }

  @override
  String project_card_badges(int count) {
    return '$count medalhas';
  }

  @override
  String get badge_earned => 'Conquistada';

  @override
  String get badge_locked => 'Bloqueada';

  @override
  String get badge_requires => 'Requer';

  @override
  String get map_screen_title => 'Mapa';

  @override
  String get map_full_screen => 'Tela cheia';

  @override
  String get map_center_on_me => 'Centralizar em mim';

  @override
  String get map_location_permission_needed =>
      'Permissão de localização necessária';

  @override
  String get map_fit_to_areas => 'Ajustar às áreas do projeto';

  @override
  String get map_legend_has_open => 'Tem tarefas abertas';

  @override
  String get map_legend_no_open => 'Sem tarefas abertas';

  @override
  String get map_legend_solved_task => 'Check-in resolveu uma tarefa';

  @override
  String get map_legend_no_task => 'Check-in (sem tarefa)';

  @override
  String get map_legend_you_here => 'Você está aqui';

  @override
  String get map_legend_your_location => 'Sua localização';

  @override
  String get map_attribution => '© OpenStreetMap';

  @override
  String get map_area_no_tasks => 'Sem tarefas nesta área';

  @override
  String map_area_all_completed(int count) {
    return 'Todas as $count tarefas concluídas';
  }

  @override
  String map_area_pending_only(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas pendentes',
      one: '1 tarefa pendente',
    );
    return '$_temp0';
  }

  @override
  String map_area_pending_done(int pending, int done) {
    return '$pending pendentes · $done concluídas';
  }

  @override
  String get map_open_tasks => 'Tarefas abertas';

  @override
  String get tasks_appbar_fallback => 'Tarefas';

  @override
  String tasks_section_open(int count) {
    return 'Abertas · $count';
  }

  @override
  String tasks_section_solved(int count) {
    return 'Resolvidas · $count';
  }

  @override
  String get tasks_empty_title => 'Ainda não há tarefas';

  @override
  String get tasks_empty_body =>
      'Este projeto não tem tarefas abertas no momento. Puxe para atualizar.';

  @override
  String tasks_filter_label(String areaName) {
    return 'Área · $areaName';
  }

  @override
  String tasks_empty_for_area_title(String areaName) {
    return 'Sem tarefas em \"$areaName\"';
  }

  @override
  String get tasks_empty_for_area_body =>
      'Esta área não tem tarefas associadas no momento.';

  @override
  String get tasks_clear_filter => 'Mostrar todas as áreas';

  @override
  String tasks_already_solved(String name) {
    return '\"$name\" já foi resolvida.';
  }

  @override
  String get task_card_pts_unit => 'pts';

  @override
  String task_card_solved_by(String name) {
    return 'por $name';
  }

  @override
  String get checkin_screen_title_default => 'Novo check-in';

  @override
  String get checkin_section_kind => 'Que tipo de check-in?';

  @override
  String checkin_section_photos(int count, int max) {
    return 'Fotos · $count/$max';
  }

  @override
  String get checkin_section_location => 'Localização';

  @override
  String get checkin_section_notes => 'Observações (opcional)';

  @override
  String get checkin_btn_camera => 'Câmera';

  @override
  String get checkin_btn_gallery => 'Galeria';

  @override
  String get checkin_btn_submit => 'Enviar check-in';

  @override
  String get checkin_picker_freetext_hint =>
      'ex.: observação, registro fotográfico, amostra de água';

  @override
  String get checkin_notes_hint =>
      'Há algo que a equipe do projeto deva saber sobre esta observação?';

  @override
  String checkin_photos_hint(int max) {
    return 'Adicione até $max fotos para apoiar sua observação.';
  }

  @override
  String checkin_camera_error(String detail) {
    return 'Não foi possível abrir a câmera: $detail';
  }

  @override
  String checkin_gallery_error(String detail) {
    return 'Não foi possível abrir a galeria: $detail';
  }

  @override
  String get checkin_validation_pick_kind =>
      'Escolha que tipo de check-in é este.';

  @override
  String get checkin_validation_add_photo =>
      'Adicione pelo menos uma foto antes.';

  @override
  String get checkin_validation_waiting_location =>
      'Aguardando sua localização. Tente novamente ou selecione um ponto no mapa.';

  @override
  String get location_resolving => 'Obtendo sua localização…';

  @override
  String get location_unavailable => 'Localização ainda não disponível.';

  @override
  String get location_pinned_manual => 'Marcada manualmente no mapa';

  @override
  String location_accuracy(String meters) {
    return 'Precisão ±$meters m';
  }

  @override
  String get location_btn_pick_on_map => 'Escolher no mapa';

  @override
  String get location_btn_retry => 'Tentar novamente';

  @override
  String get location_btn_locate => 'Localizar';

  @override
  String get location_btn_use_gps_instead => 'Usar GPS';

  @override
  String get location_btn_edit_on_map => 'Editar no mapa';

  @override
  String get location_btn_refresh_gps => 'Atualizar GPS';

  @override
  String get location_picker_title => 'Escolher localização no mapa';

  @override
  String get location_picker_recenter => 'Recentralizar';

  @override
  String get location_picker_use_this => 'Usar esta localização';

  @override
  String get location_unknown_error =>
      'Não foi possível determinar sua localização. Tente novamente.';

  @override
  String get location_disabled =>
      'Os serviços de localização estão desligados. Ative-os para fazer o check-in.';

  @override
  String get location_denied =>
      'A permissão de localização é necessária para anexar seu check-in à área do projeto.';

  @override
  String get location_denied_forever =>
      'A localização foi negada permanentemente. Abra as configurações para liberar o acesso e tente de novo.';

  @override
  String get checkin_result_title => 'Obrigado por contribuir';

  @override
  String checkin_result_contributed_to(String name) {
    return 'Contribuição para \"$name\"';
  }

  @override
  String checkin_result_points_label(int points) {
    return '+$points pts';
  }

  @override
  String get checkin_result_recorded => 'Check-in registrado';

  @override
  String get checkin_result_earned => 'Conquistado por este check-in';

  @override
  String get checkin_result_new_badges => 'Novas medalhas';

  @override
  String get checkin_back_to_dashboard => 'Voltar ao painel';

  @override
  String get checkin_back_to_project => 'Voltar ao projeto';

  @override
  String get checkin_result_queued_title =>
      'Salvo — vai enviar assim que tiver sinal';

  @override
  String get checkin_result_queued_subtitle =>
      'Vamos enviar seu check-in automaticamente assim que você voltar a ter conexão. Pode continuar usando o app enquanto isso.';

  @override
  String checkin_result_queued_at(String time) {
    return 'Capturado às $time';
  }

  @override
  String get checkin_offline_chip =>
      'Sem conexão — vamos enviar quando você estiver online';

  @override
  String get checkins_empty_title => 'Ainda não há check-ins';

  @override
  String get checkins_empty_body =>
      'Seus check-ins para este projeto vão aparecer aqui. Abra uma tarefa e adicione o primeiro para começar a ganhar pontos.';

  @override
  String get checkins_card_default_kind => 'Check-in';

  @override
  String get checkins_task_solved => 'Tarefa resolvida';

  @override
  String checkins_task_solved_named(String name) {
    return 'Resolvida · $name';
  }

  @override
  String get image_viewer_single => 'Foto';

  @override
  String image_viewer_paged(int index, int total) {
    return 'Foto $index de $total';
  }

  @override
  String get leaderboard_empty_title => 'Ainda não há ranking';

  @override
  String get leaderboard_empty_body =>
      'Seja o primeiro a registrar um check-in e comece a subir no ranking.';

  @override
  String get leaderboard_you => 'VOCÊ';

  @override
  String get leaderboard_pt_singular => 'pt';

  @override
  String get leaderboard_pt_plural => 'pts';

  @override
  String leaderboard_badges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medalhas',
      one: '1 medalha',
    );
    return '$_temp0';
  }

  @override
  String get admin_not_supported_title => 'O app móvel é para voluntários';

  @override
  String get admin_not_supported_body =>
      'Por favor, gerencie projetos, gamificação e tarefas pelo console web do Rayuela.';

  @override
  String router_route_not_found(String uri) {
    return 'Rota não encontrada: $uri';
  }

  @override
  String router_missing_params(String what) {
    return 'Faltando $what — abra esta tela a partir do painel.';
  }

  @override
  String get router_param_project_id => 'id do projeto';

  @override
  String get router_param_checkin_result => 'resultado do check-in';

  @override
  String get language_picker_tooltip => 'Idioma';

  @override
  String get language_picker_title => 'Idioma';

  @override
  String get language_picker_subtitle =>
      'Escolha o idioma que deseja usar no app. A mudança é aplicada imediatamente.';

  @override
  String get language_picker_saved => 'Idioma atualizado.';

  @override
  String get language_system => 'Usar o do sistema';

  @override
  String get language_english => 'English';

  @override
  String get language_spanish => 'Español';

  @override
  String get language_portuguese => 'Português';

  @override
  String get common_cancel => 'Cancelar';

  @override
  String get common_continue => 'Continuar';

  @override
  String get common_close => 'Fechar';

  @override
  String get common_unsubscribe => 'Cancelar inscrição';

  @override
  String get common_retry => 'Tentar novamente';

  @override
  String get common_logout => 'Sair';

  @override
  String get error_no_internet => 'Sem conexão com a internet.';

  @override
  String get error_no_internet_long =>
      'Sem conexão com a internet.\nVerifique seu sinal e tente novamente.';

  @override
  String get error_server => 'Algo deu errado do nosso lado.';

  @override
  String error_server_with_code(int code) {
    return 'Erro do servidor ($code). Tente novamente.';
  }

  @override
  String get error_server_no_code => 'Erro do servidor. Tente novamente.';

  @override
  String get error_unauthorized => 'Sua sessão expirou. Faça login novamente.';

  @override
  String get error_timeout =>
      'O servidor está demorando para responder. Tente novamente em instantes.';
}
