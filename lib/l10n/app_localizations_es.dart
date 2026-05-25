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
  String get login_google_connecting => 'Conectando con Google…';

  @override
  String get login_google_not_configured =>
      'El inicio de sesión con Google no está configurado en esta versión. Pasa GOOGLE_CLIENT_ID_WEB (y GOOGLE_CLIENT_ID_IOS en iOS) usando --dart-define-from-file=.env.development.';

  @override
  String get login_invalid_credentials => 'Usuario o contraseña no válidos.';

  @override
  String get login_username_required => 'Ingresá tu usuario';

  @override
  String get login_password_required => 'Ingresá tu contraseña';

  @override
  String get login_pick_username_title => 'Elegí un nombre de usuario';

  @override
  String get login_pick_username_body =>
      'Aún no encontramos una cuenta de Rayuela para este perfil de Google. Elegí un nombre de usuario para terminar el registro.';

  @override
  String get login_pick_username_min => 'Al menos 3 caracteres';

  @override
  String get login_pick_username_required =>
      'Elegí un nombre de usuario para continuar';

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
  String get register_full_name_required => 'Ingresá tu nombre';

  @override
  String get register_username_min =>
      'El usuario debe tener al menos 3 caracteres';

  @override
  String get register_email_required => 'El correo es obligatorio';

  @override
  String get register_email_invalid => 'Ingresá un correo válido';

  @override
  String get register_password_min =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get register_passwords_no_match => 'Las contraseñas no coinciden';

  @override
  String get register_must_accept_terms =>
      'Aceptá los términos para continuar.';

  @override
  String get register_success_snackbar =>
      'Cuenta creada. Revisa tu correo para verificarla y luego inicia sesión.';

  @override
  String dashboard_greeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get dashboard_greeting_fallback => 'Hola';

  @override
  String get dashboard_empty_title => 'Aún no tienes proyectos';

  @override
  String get dashboard_empty_body =>
      'Descubre proyectos de ciencia ciudadana cerca de ti y suscríbete para participar.';

  @override
  String get project_detail_fallback_title => 'Proyecto';

  @override
  String get project_tab_overview => 'Resumen';

  @override
  String get project_tab_checkins => 'Check-ins';

  @override
  String get project_tab_progress => 'Progreso';

  @override
  String get project_view_tasks => 'Ver tareas';

  @override
  String get project_add_checkin => 'Agregar un check-in';

  @override
  String get project_subscribe => 'Suscribirse al proyecto';

  @override
  String get project_subscribing => 'Suscribiendo…';

  @override
  String get project_subscribed_success => '¡Te suscribiste!';

  @override
  String get project_unsubscribe => 'Cancelar suscripción a este proyecto';

  @override
  String get project_unsubscribe_subtitle =>
      'Tus check-ins se mantienen; dejas de ganar nuevos puntos e insignias.';

  @override
  String get project_unsubscribe_confirm_title => '¿Cancelar suscripción?';

  @override
  String get project_unsubscribe_confirm_body =>
      'Puedes volver a suscribirte cuando quieras. Las insignias y puntos ganados quedan en tu perfil.';

  @override
  String get project_unsubscribe_success => 'Suscripción cancelada.';

  @override
  String get project_stat_points => 'Puntos';

  @override
  String get project_stat_badges => 'Insignias';

  @override
  String get project_stat_rank => 'Puesto';

  @override
  String get project_section_leaderboard => 'Tabla de posiciones';

  @override
  String get project_section_badges => 'Insignias';

  @override
  String get project_card_status_active => 'Activo';

  @override
  String get project_card_status_paused => 'En pausa';

  @override
  String project_card_pts(int count) {
    return '$count pts';
  }

  @override
  String project_card_badges(int count) {
    return '$count insignias';
  }

  @override
  String get badge_earned => 'Conseguida';

  @override
  String get badge_locked => 'Bloqueada';

  @override
  String get badge_requires => 'Requiere';

  @override
  String get map_screen_title => 'Mapa';

  @override
  String get map_full_screen => 'Pantalla completa';

  @override
  String get map_center_on_me => 'Centrar en mí';

  @override
  String get map_location_permission_needed =>
      'Se necesita permiso de ubicación';

  @override
  String get map_fit_to_areas => 'Ajustar a las áreas del proyecto';

  @override
  String get map_legend_has_open => 'Tiene tareas abiertas';

  @override
  String get map_legend_no_open => 'Sin tareas abiertas';

  @override
  String get map_legend_solved_task => 'Check-in que resolvió una tarea';

  @override
  String get map_legend_no_task => 'Check-in (sin tarea)';

  @override
  String get map_legend_you_here => 'Estás aquí';

  @override
  String get map_legend_your_location => 'Tu ubicación';

  @override
  String get map_attribution => '© OpenStreetMap';

  @override
  String get map_area_no_tasks => 'Esta área no tiene tareas';

  @override
  String map_area_all_completed(int count) {
    return 'Las $count tareas están completadas';
  }

  @override
  String map_area_pending_only(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas pendientes',
      one: '1 tarea pendiente',
    );
    return '$_temp0';
  }

  @override
  String map_area_pending_done(int pending, int done) {
    return '$pending pendientes · $done hechas';
  }

  @override
  String get map_open_tasks => 'Abrir tareas';

  @override
  String get tasks_appbar_fallback => 'Tareas';

  @override
  String tasks_section_open(int count) {
    return 'Abiertas · $count';
  }

  @override
  String tasks_section_solved(int count) {
    return 'Resueltas · $count';
  }

  @override
  String get tasks_empty_title => 'Aún no hay tareas';

  @override
  String get tasks_empty_body =>
      'Este proyecto no tiene tareas abiertas en este momento. Desliza para refrescar.';

  @override
  String tasks_filter_label(String areaName) {
    return 'Área · $areaName';
  }

  @override
  String tasks_empty_for_area_title(String areaName) {
    return 'No hay tareas en \"$areaName\"';
  }

  @override
  String get tasks_empty_for_area_body =>
      'Esta área no tiene tareas asociadas en este momento.';

  @override
  String get tasks_clear_filter => 'Mostrar todas las áreas';

  @override
  String tasks_already_solved(String name) {
    return '\"$name\" ya fue resuelta.';
  }

  @override
  String get task_card_pts_unit => 'pts';

  @override
  String task_card_solved_by(String name) {
    return 'por $name';
  }

  @override
  String get checkin_screen_title_default => 'Nuevo check-in';

  @override
  String get checkin_section_kind => '¿Qué tipo de check-in?';

  @override
  String checkin_section_photos(int count, int max) {
    return 'Fotos · $count/$max';
  }

  @override
  String get checkin_section_location => 'Ubicación';

  @override
  String get checkin_section_notes => 'Notas (opcional)';

  @override
  String get checkin_btn_camera => 'Cámara';

  @override
  String get checkin_btn_gallery => 'Galería';

  @override
  String get checkin_btn_submit => 'Enviar check-in';

  @override
  String get checkin_picker_freetext_hint =>
      'p. ej. observación, reporte fotográfico, muestra de agua';

  @override
  String get checkin_notes_hint =>
      '¿Algo que el equipo del proyecto deba saber sobre esta observación?';

  @override
  String checkin_photos_hint(int max) {
    return 'Agrega hasta $max fotos para respaldar tu observación.';
  }

  @override
  String checkin_camera_error(String detail) {
    return 'No se pudo abrir la cámara: $detail';
  }

  @override
  String checkin_gallery_error(String detail) {
    return 'No se pudo abrir la galería: $detail';
  }

  @override
  String get checkin_validation_pick_kind => 'Elegí qué tipo de check-in es.';

  @override
  String get checkin_validation_add_photo =>
      'Agregá al menos una foto primero.';

  @override
  String get checkin_validation_waiting_location =>
      'Esperando tu ubicación. Reintentá o elegí un punto en el mapa.';

  @override
  String get location_resolving => 'Obteniendo tu ubicación…';

  @override
  String get location_unavailable => 'Ubicación todavía no disponible.';

  @override
  String get location_pinned_manual => 'Marcada manualmente en el mapa';

  @override
  String location_accuracy(String meters) {
    return 'Precisión ±$meters m';
  }

  @override
  String get location_btn_pick_on_map => 'Elegir en el mapa';

  @override
  String get location_btn_retry => 'Reintentar';

  @override
  String get location_btn_locate => 'Localizar';

  @override
  String get location_btn_use_gps_instead => 'Usar GPS';

  @override
  String get location_btn_edit_on_map => 'Editar en el mapa';

  @override
  String get location_btn_refresh_gps => 'Refrescar GPS';

  @override
  String get location_picker_title => 'Elegí la ubicación en el mapa';

  @override
  String get location_picker_recenter => 'Re-centrar';

  @override
  String get location_picker_use_this => 'Usar esta ubicación';

  @override
  String get location_unknown_error =>
      'No pudimos determinar tu ubicación. Probá de nuevo.';

  @override
  String get location_disabled =>
      'Los servicios de ubicación están desactivados. Activalos para hacer check-in.';

  @override
  String get location_denied =>
      'El permiso de ubicación es necesario para asociar tu check-in al área del proyecto.';

  @override
  String get location_denied_forever =>
      'La ubicación está bloqueada permanentemente. Abrí la configuración para concederla y volvé a intentarlo.';

  @override
  String get checkin_result_title => '¡Gracias por contribuir!';

  @override
  String checkin_result_contributed_to(String name) {
    return 'Contribuiste a \"$name\"';
  }

  @override
  String checkin_result_points_label(int points) {
    return '+$points pts';
  }

  @override
  String get checkin_result_recorded => 'Check-in registrado';

  @override
  String get checkin_result_earned => 'Ganado por este check-in';

  @override
  String get checkin_result_new_badges => 'Nuevas insignias';

  @override
  String get checkin_back_to_dashboard => 'Volver al panel';

  @override
  String get checkin_back_to_project => 'Volver al proyecto';

  @override
  String get checkin_result_queued_title =>
      'Guardado — se enviará cuando tengas señal';

  @override
  String get checkin_result_queued_subtitle =>
      'Enviaremos tu check-in automáticamente apenas vuelvas a tener conexión. Puedes seguir usando la app mientras tanto.';

  @override
  String checkin_result_queued_at(String time) {
    return 'Capturado a las $time';
  }

  @override
  String get checkin_offline_chip =>
      'Sin conexión — lo enviaremos cuando vuelvas a tener red';

  @override
  String get cache_just_now => 'ahora mismo';

  @override
  String cache_seconds_ago(int count) {
    return 'hace $count s';
  }

  @override
  String cache_minutes_ago(int count) {
    return 'hace $count min';
  }

  @override
  String cache_hours_ago(int count) {
    return 'hace $count h';
  }

  @override
  String cache_days_ago(int count) {
    return 'hace $count d';
  }

  @override
  String cache_updated_chip(String age) {
    return 'Actualizado $age';
  }

  @override
  String cache_offline_chip(String age) {
    return 'Mostrando copia sin conexión · última actualización $age';
  }

  @override
  String get map_download_offline_tooltip =>
      'Descargar mapas para uso sin conexión';

  @override
  String get map_download_offline_title => '¿Descargar mapas?';

  @override
  String get map_download_offline_body =>
      'Vamos a guardar las baldosas del proyecto en este dispositivo para que el mapa funcione sin conexión. Puede descargar hasta 30 MB.';

  @override
  String get map_download_offline_cta => 'Descargar';

  @override
  String get map_download_offline_starting => 'Preparando la descarga…';

  @override
  String map_download_offline_progress(int percent) {
    return 'Descargando mapas · $percent%';
  }

  @override
  String map_download_offline_done(int count) {
    return 'Mapas listos ($count baldosas)';
  }

  @override
  String map_download_offline_too_large(int estimated, int cap) {
    return 'Área del proyecto demasiado grande ($estimated baldosas, máx $cap)';
  }

  @override
  String get map_download_offline_cancelled => 'Descarga de mapas cancelada';

  @override
  String get map_clear_cache_tooltip => 'Borrar mapas sin conexión';

  @override
  String get map_clear_cache_title => '¿Borrar mapas sin conexión?';

  @override
  String get map_clear_cache_body =>
      'Se eliminarán todas las baldosas en caché. Los mapas seguirán funcionando online y se redescargarán cuando haga falta.';

  @override
  String get map_clear_cache_cta => 'Borrar';

  @override
  String get map_clear_cache_done => 'Mapas sin conexión borrados';

  @override
  String get outbox_status_pending => 'Pendiente';

  @override
  String get outbox_status_retrying => 'Reintentando…';

  @override
  String get outbox_status_inflight => 'Enviando…';

  @override
  String get outbox_status_failed => 'Falló — toca para reintentar';

  @override
  String get outbox_action_retry => 'Reintentar ahora';

  @override
  String get outbox_action_discard => 'Descartar';

  @override
  String get outbox_action_retry_all => 'Reintentar todos';

  @override
  String get outbox_section_pending => 'Por enviar';

  @override
  String outbox_pending_at(String time) {
    return 'Capturado a las $time';
  }

  @override
  String outbox_attempt_count(int count) {
    return 'Intento N° $count';
  }

  @override
  String get outbox_discard_confirm_title =>
      '¿Descartar el check-in pendiente?';

  @override
  String get outbox_discard_confirm_body =>
      'Las fotos y los datos se borrarán de este dispositivo. Esta acción no se puede deshacer.';

  @override
  String get outbox_discard_confirm_cta => 'Descartar';

  @override
  String get outbox_cancel => 'Cancelar';

  @override
  String get dashboard_outbox_banner_one => '1 check-in por enviar';

  @override
  String dashboard_outbox_banner_many(int count) {
    return '$count check-ins por enviar';
  }

  @override
  String get dashboard_outbox_banner_action => 'Ver';

  @override
  String get dashboard_sync_status_offline => 'Sin conexión';

  @override
  String get dashboard_sync_status_syncing => 'Sincronizando…';

  @override
  String get dashboard_sync_status_error => 'Problemas de sincronización';

  @override
  String get pending_data_title => 'Datos pendientes';

  @override
  String get pending_data_empty_title => 'Nada por sincronizar';

  @override
  String get pending_data_empty_body =>
      'Los check-ins que crees sin conexión aparecerán acá mientras esperamos red.';

  @override
  String pending_data_project_label(String projectId) {
    return 'Proyecto: $projectId';
  }

  @override
  String get checkins_empty_title => 'Aún no hay check-ins';

  @override
  String get checkins_empty_body =>
      'Tus check-ins para este proyecto aparecerán aquí. Abrí una tarea y agregá el primero para empezar a ganar puntos.';

  @override
  String get checkins_card_default_kind => 'Check-in';

  @override
  String get checkins_task_solved => 'Tarea resuelta';

  @override
  String checkins_task_solved_named(String name) {
    return 'Resolvió · $name';
  }

  @override
  String get image_viewer_single => 'Foto';

  @override
  String image_viewer_paged(int index, int total) {
    return 'Foto $index de $total';
  }

  @override
  String get leaderboard_empty_title => 'Aún no hay rankings';

  @override
  String get leaderboard_empty_body =>
      'Sé el primero en registrar un check-in y empezar a escalar la tabla.';

  @override
  String get leaderboard_you => 'TÚ';

  @override
  String get leaderboard_pt_singular => 'pt';

  @override
  String get leaderboard_pt_plural => 'pts';

  @override
  String leaderboard_badges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count insignias',
      one: '1 insignia',
    );
    return '$_temp0';
  }

  @override
  String get admin_not_supported_title => 'La app móvil es para voluntarios';

  @override
  String get admin_not_supported_body =>
      'Por favor gestiona los proyectos, la gamificación y las tareas desde la consola web de Rayuela.';

  @override
  String router_route_not_found(String uri) {
    return 'Ruta no encontrada: $uri';
  }

  @override
  String router_missing_params(String what) {
    return 'Falta $what — abrí esta pantalla desde el panel.';
  }

  @override
  String get router_param_project_id => 'el id del proyecto';

  @override
  String get router_param_checkin_result => 'el resultado del check-in';

  @override
  String get language_picker_tooltip => 'Idioma';

  @override
  String get language_picker_title => 'Idioma';

  @override
  String get language_picker_subtitle =>
      'Elegí el idioma que querés usar en toda la app. El cambio se aplica al instante.';

  @override
  String get language_picker_saved => 'Idioma actualizado.';

  @override
  String get language_system => 'Usar el del sistema';

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
  String get common_close => 'Cerrar';

  @override
  String get common_unsubscribe => 'Cancelar suscripción';

  @override
  String get common_retry => 'Reintentar';

  @override
  String get common_logout => 'Cerrar sesión';

  @override
  String get error_no_internet => 'Sin conexión a internet.';

  @override
  String get error_no_internet_long =>
      'Sin conexión a internet.\nVerificá tu señal y reintentá.';

  @override
  String get error_server => 'Algo salió mal de nuestro lado.';

  @override
  String error_server_with_code(int code) {
    return 'Error del servidor ($code). Probá de nuevo.';
  }

  @override
  String get error_server_no_code => 'Error del servidor. Probá de nuevo.';

  @override
  String get error_unauthorized => 'Tu sesión expiró. Iniciá sesión de nuevo.';

  @override
  String get error_timeout =>
      'El servidor está tardando en responder. Probá en un momento.';

  @override
  String get wizard_step1_guide =>
      '¡Hola! ¿Qué tipo de tarea querés registrar hoy?';

  @override
  String get wizard_step1_title => 'TIPO DE TAREA';

  @override
  String get wizard_step1_empty =>
      'No hay tipos de tareas disponibles para este proyecto.';

  @override
  String get wizard_step1_empty_back => 'Volver';

  @override
  String get wizard_next => 'Siguiente →';

  @override
  String get wizard_submit => '¡COLABORAR!';

  @override
  String get wizard_step4_guide_custom =>
      'Estableciste una fecha y hora personalizada para esta colaboración.';

  @override
  String get wizard_step4_guide_current =>
      'Estamos usando la fecha y hora actual para este check-in. ¿Querés modificarla?';

  @override
  String get wizard_step4_title => 'FECHA Y HORA';

  @override
  String get wizard_step4_subtitle_custom => 'Fecha/hora modificada';

  @override
  String get wizard_step4_subtitle_current => 'Fecha/hora actual';

  @override
  String get wizard_step4_restore => 'Restablecer a la hora actual';

  @override
  String get wizard_error_select_type => 'Elegí qué tipo de check-in es.';

  @override
  String get wizard_error_waiting_location => 'Esperando tu ubicación.';

  @override
  String get wizard_error_future_date =>
      'La fecha y hora no pueden ser futuras.';

  @override
  String get wizard_step2_guide =>
      '¿Tenés evidencia para agregar? Podés subir hasta 3 fotos.';

  @override
  String get wizard_step2_title => 'EVIDENCIA';

  @override
  String get wizard_step2_cam => 'Cámara';

  @override
  String get wizard_step2_gal => 'Galería';

  @override
  String get wizard_step2_skip => 'saltear si no tenés fotos';

  @override
  String get wizard_step3_guide =>
      'Estamos usando tu ubicación actual. ¿Querés modificarla?';

  @override
  String get wizard_step3_title => 'COORDENADAS';
}
