import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/core/constants/app_constants.dart';
import 'package:my_btcz_wallet/core/di/injection_container.dart' as di;
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_event.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';
import 'package:my_btcz_wallet/presentation/pages/home_page.dart';
import 'package:my_btcz_wallet/presentation/pages/welcome_page.dart';
import 'package:my_btcz_wallet/core/theme/app_theme.dart';

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
        BlocProvider<WalletBloc>(
          create: (context) {
            final bloc = di.sl<WalletBloc>();
            // Load wallet on app start
            bloc.add(LoadWalletEvent());
            return bloc;
          },
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            // Show home page if wallet is loaded or created
            if (state is WalletLoaded || state is WalletCreated) {
              return const HomePage();
            }
            // Show welcome page for initial state or if no wallet exists
            return const WelcomePage();
          },
        ),
      ),
    );
  }
}
