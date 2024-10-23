import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/core/di/injection_container.dart' as di;
import 'package:my_btcz_wallet/core/theme/app_theme.dart';
import 'package:my_btcz_wallet/core/constants/app_constants.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/pages/welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.sl<WalletBloc>(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const WelcomePage(),
      ),
    );
  }
}
