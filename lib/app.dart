import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/intake_repository.dart';
import 'repositories/medicine_repository.dart';
import 'services/notification_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/intake_viewmodel.dart';
import 'viewmodels/medicine_viewmodel.dart';
import 'views/auth/login_screen.dart';
import 'views/home/home_shell.dart';

class MedicineTrackerApp extends StatelessWidget {
  const MedicineTrackerApp({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services and repositories (no UI state).
        Provider<NotificationService>.value(value: notifications),
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<MedicineRepository>(create: (_) => MedicineRepository()),
        Provider<IntakeRepository>(create: (_) => IntakeRepository()),

        // View-models.
        ChangeNotifierProvider<AuthViewModel>(
          create: (c) => AuthViewModel(c.read<AuthRepository>()),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, MedicineViewModel>(
          create: (c) => MedicineViewModel(
            c.read<MedicineRepository>(),
            c.read<NotificationService>(),
          ),
          update: (_, auth, vm) => vm!..bindUser(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider2<AuthViewModel, MedicineViewModel,
            IntakeViewModel>(
          create: (c) => IntakeViewModel(
            c.read<IntakeRepository>(),
            c.read<MedicineViewModel>(),
            c.read<NotificationService>(),
          ),
          update: (_, auth, medicines, vm) => vm!..bindUser(auth.user?.uid),
        ),
      ],
      child: MaterialApp(
        title: 'DailyDose',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// Shows the login screen or the app depending on the auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.user == null ? const LoginScreen() : const HomeShell();
  }
}
