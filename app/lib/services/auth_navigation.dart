import 'package:flutter/material.dart';

import '../models/user.dart';
import '../screens/client/client_shell.dart';
import '../screens/professional/pending_approval_screen.dart';
import '../screens/professional/professional_shell.dart';
import '../screens/shared/admin_shell.dart';

/// Tela inicial após login ou restauração de sessão.
Widget homeForUser(AppUser user) {
  if (user.type == AccountType.professional && !user.approved) {
    return const PendingApprovalScreen();
  }

  return switch (user.type) {
    AccountType.professional => const ProfessionalShell(),
    AccountType.admin => const AdminShell(),
    AccountType.client => const ClientShell(),
  };
}
