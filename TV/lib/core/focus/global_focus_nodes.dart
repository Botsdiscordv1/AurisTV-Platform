import 'package:flutter/widgets.dart';

/// Nodo de foco del icono de perfil (avatar) en la topbar de Home.
///
/// Es un nodo de vida de aplicación: ProfileScreen lo solicita al volver
/// con BACK para restaurar el foco en el punto desde el que se abrió la
/// pantalla, y HomeScreen lo pasa a su `_FocusIconButton`.
final FocusNode homeProfileIconFocusNode =
    FocusNode(debugLabel: 'homeProfileIcon');
