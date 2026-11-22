import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/firebase_config_service.dart';
import 'services/hybrid_ai_service.dart';
import 'services/model_manager.dart';
import 'services/image_service.dart';
import 'services/local_db_service.dart';
import 'services/mesh_service.dart';
import 'services/voice_service.dart';
import 'services/recipe_export_service.dart';
import 'viewmodels/chat_view_model.dart';
import 'viewmodels/scan_view_model.dart';
import 'viewmodels/daily_intake_view_model.dart';
import 'viewmodels/onboarding_view_model.dart';
import 'viewmodels/describe_meal_view_model.dart';
import 'viewmodels/theme_view_model.dart';
import 'viewmodels/recipe_view_model.dart';
import 'viewmodels/pantry_view_model.dart';
import 'viewmodels/mesh_view_model.dart';
import 'viewmodels/meal_plan_view_model.dart';
import 'viewmodels/nutrition_view_model.dart';
import 'viewmodels/ingrediguard_view_model.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'views/screens/home_page.dart';
import 'views/screens/onboarding_screen.dart';
import 'views/screens/model_download_screen.dart';
import 'views/screens/describe_meal_screen.dart';
import 'views/screens/profile_edit_screen.dart';
import 'views/screens/settings_screen.dart';
import 'views/screens/meal_plan_screen.dart';
import 'views/screens/meal_prep_screen.dart';
import 'views/screens/nutrition_analytics_screen.dart';
import 'views/screens/voice_cooking_screen.dart';
import 'views/screens/qr_share_screen.dart';
import 'views/screens/diet_plan_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  // Initialize Firebase ecosystem (App Check, Remote Config, Auth) for #BuildHybridAI 2026
  await FirebaseConfigService.instance.initialize();

  try {
    FlutterGemma.initialize(maxDownloadRetries: 2);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: true,
  ));

  final hasProfile = await LocalDbService.instance.hasProfile();

  // Firebase AI Logic operates immediately in Hybrid mode (no massive 2.7GB model download needed)
  runApp(ChowGenieApp(
    initialRoute: !hasProfile ? '/onboarding' : '/home',
  ));
}

Future<bool> _checkModelOnDisk() async {
  try {
    final dir = await _docDir();
    final gemma4File = File('$dir/gemma-4-E2B-it.litertlm');
    final gemma3File = File('$dir/gemma-3n-E2B-it-int4.litertlm');
    return (gemma4File.existsSync() && await gemma4File.length() > 100000) ||
           (gemma3File.existsSync() && await gemma3File.length() > 100000);
  } catch (_) {
    return false;
  }
}

Future<String> _docDir() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

class ChowGenieApp extends StatelessWidget {
  final String initialRoute;
  const ChowGenieApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(create: (_) => ModelManager()),
        Provider(create: (_) => ImageService()),
        Provider.value(value: LocalDbService.instance),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        Provider(create: (_) => RecipeExportService()),
        ChangeNotifierProvider(create: (_) => MeshService()),
        ChangeNotifierProxyProvider<ModelManager, ChatViewModel>(
          create: (ctx) => ChatViewModel(
            ctx.read<ModelManager>(),
            ctx.read<ImageService>(),
          ),
          update: (_, mm, prev) => prev!,
        ),
        ChangeNotifierProvider(
          create: (ctx) => DescribeMealViewModel(
            ctx.read<ModelManager>(),
            ctx.read<LocalDbService>(),
          ),
        ),
        ChangeNotifierProvider<ScanViewModel>(
          create: (ctx) => ScanViewModel(
            ctx.read<ModelManager>(),
            ctx.read<ImageService>(),
            ctx.read<LocalDbService>(),
          ),
        ),
        ChangeNotifierProvider<IngrediGuardViewModel>(
          create: (ctx) => IngrediGuardViewModel(
            ctx.read<ModelManager>(),
            ctx.read<ImageService>(),
            ctx.read<LocalDbService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DailyIntakeViewModel(ctx.read<LocalDbService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => OnboardingViewModel(ctx.read<LocalDbService>()),
        ),
        // ChowGenie feature viewmodels
        ChangeNotifierProvider(
          create: (ctx) => RecipeViewModel(ctx.read<ModelManager>()),
        ),
        ChangeNotifierProvider(
          create: (_) => PantryViewModel(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MeshViewModel(ctx.read<MeshService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MealPlanViewModel(ctx.read<ModelManager>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => NutritionViewModel(ctx.read<ModelManager>()),
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ChowGenie',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeVm.themeMode,
            initialRoute: initialRoute,
            onGenerateRoute: (settings) {
              final routes = <String, WidgetBuilder>{
                '/onboarding': (context) => const OnboardingScreen(),
                '/home': (context) => const HomePage(),
                '/model-setup': (context) => const ModelDownloadSetupScreen(),
                '/describe-meal': (context) => const DescribeMealScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/profile-edit': (context) => const ProfileEditScreen(),
                '/meal-plan': (context) => const MealPlanScreen(),
                '/meal-prep': (context) => const MealPrepScreen(),
                '/nutrition': (context) => const NutritionAnalyticsScreen(),
                '/voice-cooking': (context) => const VoiceCookingScreen(),
                '/qr-share': (context) => const QrShareScreen(),
                '/diet-plan': (context) => const DietPlanScreen(),
              };
              final builder = routes[settings.name];
              if (builder != null) return MaterialPageRoute(builder: builder, settings: settings);
              return null;
            },
          );
        },
      ),
    );
  }
}
