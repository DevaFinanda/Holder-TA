import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_colors.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final List<Map<String, String>> _languages = [
    {'code': 'id', 'name': 'Bahasa Indonesia', 'flag': '🇮🇩'},
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'jv', 'name': 'Basa Jawa', 'flag': '🇮🇩'},
    {'code': 'su', 'name': 'Basa Sunda', 'flag': '🇮🇩'},
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('language'),
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final language = _languages[index];
          final isSelected = settings.languageCode == language['code'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ListTile(
              leading: Text(
                language['flag']!,
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(
                language['name']!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color:
                      isSelected ? AppColors.primaryBlue : AppColors.textDark,
                ),
              ),
              trailing: isSelected
                  ? const Icon(
                      Icons.check_circle,
                      color: AppColors.primaryBlue,
                    )
                  : null,
              onTap: () async {
                await context
                    .read<AppSettingsProvider>()
                    .setLanguageCode(language['code']!);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      Localizations.localeOf(this.context).languageCode == 'en'
                          ? 'Language changed to ${language['name']}'
                          : 'Bahasa diubah ke ${language['name']}',
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
