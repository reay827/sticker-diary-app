import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'store.dart';
import 'widgets.dart';
import 'home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StickerDiaryApp());
}

class StickerDiaryApp extends StatelessWidget {
  const StickerDiaryApp({super.key, this.store});
  final DiaryStore? store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '하루 조각',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: moss, surface: paper),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1ECDD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: moss,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    ),
    home: store != null ? HomeScreen(store: store!) : const _Startup(),
  );
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<DiaryStore> future = DiaryStore.open();
  @override
  Widget build(BuildContext context) => FutureBuilder<DiaryStore>(
    future: future,
    builder: (context, result) {
      if (result.hasData) return HomeScreen(store: result.data!);
      return Scaffold(
        body: result.hasError
            ? EmptyNote(
                icon: Icons.folder_off_outlined,
                title: '기록을 불러오지 못했어요',
                message: '기존 파일을 보존하고 있어요.\n저장 공간을 확인한 후 다시 시도해 주세요.',
                button: FilledButton(
                  onPressed: () => setState(() => future = DiaryStore.open()),
                  child: const Text('다시 시도'),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    },
  );
}
