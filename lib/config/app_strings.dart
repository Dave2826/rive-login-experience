abstract final class AppStrings {
  // ------------------------------
  // LoginScreen
  // ------------------------------
  static const String loginScreenTitle = 'Iniciar sesión';
  static const String forgotPasswordLink = '¿Olvidaste tu contraseña?';
  static const String emailFieldLabel = 'Correo electrónico';
  static const String emailHint = 'tu@correo.com';
  static const String passwordFieldLabel = 'Contraseña';
  static const String noAccountLabel = '¿No tienes una cuenta? ';
  static const String registerButton = 'Regístrate';
  static const String verificationPending = 'La cuenta {email} aún no ha verificado su correo institucional.';
  static const String resendVerification = 'Reenviar correo de verificación';
  static const String alreadyVerified = 'Ya verifiqué mi correo';
  static const String loginErrorInvalid = 'Credenciales inválidas';
  static const String loginErrorUnverified = 'Tu correo aún no está verificado.';
  static const String loginErrorNetwork = 'No se pudo iniciar sesión en este momento. Verifica tu conexión e inténtalo de nuevo.';
  static const String resendEmail = 'Si existe una cuenta asociada a este correo, recibirás las instrucciones para restablecer tu contraseña.';

  // ------------------------------
  // SignUpScreen
  // ------------------------------
  static const String signUpTitle = 'Crear cuenta';
  static const String institutionalEmailLabel = 'Correo institucional';
  static const String institutionalEmailHint = 'usuario@tecdesoftware.edu.mx';
  static const String passwordLabel = 'Contraseña';
  static const String confirmPasswordLabel = 'Confirmar contraseña';
  static const String signUpButton = 'Crear cuenta';
  static const String minEightChars = '• Mínimo 8 caracteres';
  static const String minUppercase = '• Al menos una letra mayúscula';
  static const String minLowercase = '• Al menos una letra minúscula';
  static const String minNumber = '• Al menos un número';
  static const String minSymbol = '• Al menos un símbolo (@!%*?&)';
  static const String emailRequired = 'El correo es obligatorio';
  static const String passwordRequired = 'La contraseña es obligatoria';
  static const String confirmRequired = 'Confirma tu contraseña';
  static const String nonInstitutionalDomain = 'Usa tu correo institucional (@tecdesoftware.edu.mx)';
  static const String emailAlreadyRegistered = 'Este correo ya está registrado';

  // ------------------------------
  // ProductsScreen
  // ------------------------------
  static const String platillosTitle = 'Menú de platillos';
  static const String closeSessionDialog = '¿Quieres cerrar la sesión actual?';
  static const String cancelButton = 'Cancelar';
  static const String closeSessionButton = 'Cerrar sesión';
  static const String retryButton = 'Reintentar';
  static const String noPlatillosDisponibles = 'No hay platillos disponibles';
  static const String disponible = 'Disponible';
  static const String agotado = 'Agotado';
  static const String sinNombre = 'Sin nombre';
  static const String tituloPlatillo = 'Platillo';
  static const String subtituloDescripcion = 'Descripción';
  static const String categoria = 'Categoría';
  static const String precio = 'Precio';
  static const String errorServidor = 'Error interno del servidor al cargar el menú.';
  static const String errorConexion = 'No fue posible conectar con el servidor. Verifica tu conexión e inténtalo de nuevo.';
  static const String errorTimeout = 'Tiempo de espera agotado al conectar con el servidor. Inténtalo más tarde.';
  static const String errorFormato = 'No se pudo interpretar la respuesta del catálogo.';

  // ------------------------------
  // SessionGate
  // ------------------------------
  static const String sessionExpiredMessage = 'Tu sesión expiró o ya no es válida. Inicia sesión de nuevo.';

  // ------------------------------
  // Mensajes generales / Wrappers
  // ------------------------------
  static const String errorAlIniciarSesion = 'No se pudo iniciar sesión en este momento. Verifica tu conexión e inténtalo de nuevo.';

  // ------------------------------
  // Auth errors / snackbars
  // ------------------------------
  static const String verificationSentMessage = 'Cuenta creada. Revisa tu correo institucional para verificarla antes de iniciar sesión.';
  static const String verificationFailedMessage = 'Cuenta creada, pero no se pudo enviar el correo de verificación. Podrá solicitarlo nuevamente desde el inicio de sesión.';
  static const String emailAlreadyInUse = 'Este correo ya está registrado';
  static const String invalidEmail = 'Correo inválido';
  static const String weakPassword = 'Contraseña muy débil';
  static const String createAccountError = 'Error al crear cuenta:';
  static const String unexpectedError = 'Error inesperado al crear cuenta';
}