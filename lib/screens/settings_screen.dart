import 'package:flutter/material.dart';
import 'package:hume/providers.dart';
import 'package:hume/services/theme_provider.dart';
import 'package:hume/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _projectUri = Uri.parse(
    'https://github.com/EdwardJoke/HumeReader',
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Setting')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'Appearance'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                      title: const Text('Dark Mode'),
                      subtitle: Text(
                        themeProvider.isDarkMode
                            ? 'Dark theme enabled'
                            : 'Light theme enabled',
                      ),
                      value: themeProvider.isDarkMode,
                      onChanged: themeProvider.toggleTheme,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Theme Color'),
                      subtitle: Text(themeProvider.selectedColor.label),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ColorSeed.values.map((color) {
                          final isSelected =
                              color == themeProvider.selectedColor;
                          return GestureDetector(
                            onTap: () => themeProvider.selectColor(color),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: colorScheme.onSurface,
                                        width: 3,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.color.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Update'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<UpdateChannel>(
                      secondary: const Icon(Icons.check_circle_outline),
                      title: const Text('Stable'),
                      subtitle: const Text('Recommended for most users'),
                      value: UpdateChannel.stable,
                      groupValue: themeProvider.updateChannel,
                      onChanged: (channel) {
                        if (channel != null) {
                          themeProvider.selectUpdateChannel(channel);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<UpdateChannel>(
                      secondary: const Icon(Icons.science_outlined),
                      title: const Text('Beta'),
                      subtitle: const Text('Get early access to new features'),
                      value: UpdateChannel.beta,
                      groupValue: themeProvider.updateChannel,
                      onChanged: (channel) {
                        if (channel != null) {
                          themeProvider.selectUpdateChannel(channel);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please read https://github.com/EdwardJoke/HumeReader for details.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _openProjectLink(context),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Project Page'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Future<void> _openProjectLink(BuildContext context) async {
    final launched = await launchUrl(
      _projectUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the project page.')),
      );
    }
  }
}
