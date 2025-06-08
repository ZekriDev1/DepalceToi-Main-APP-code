import 'package:flutter/material.dart';
import '../services/language_service.dart';

class LanguageSelector extends StatelessWidget {
  final LanguageService languageService;

  const LanguageSelector({
    super.key,
    required this.languageService,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: languageService.translate('language'),
      onSelected: (String languageCode) {
        languageService.setLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              const Text('🇺🇸 '),
              const SizedBox(width: 8),
              Text(languageService.translate('language') == 'اللغة' ? 'English' : 'English'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'fr',
          child: Row(
            children: [
              const Text('🇫🇷 '),
              const SizedBox(width: 8),
              Text(languageService.translate('language') == 'اللغة' ? 'Français' : 'Français'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ar',
          child: Row(
            children: [
              const Text('🇸🇦 '),
              const SizedBox(width: 8),
              Text(languageService.translate('language') == 'اللغة' ? 'العربية' : 'العربية'),
            ],
          ),
        ),
      ],
    );
  }
} 