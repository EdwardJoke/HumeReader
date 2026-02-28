import 'package:flutter/material.dart';
import 'package:hume/models/text_highlight.dart';

class HighlightColorPicker extends StatefulWidget {
  final Color initialColor;
  final HighlightStyle initialStyle;

  const HighlightColorPicker({
    super.key,
    required this.initialColor,
    required this.initialStyle,
  });

  @override
  State<HighlightColorPicker> createState() => _HighlightColorPickerState();
}

class _HighlightColorPickerState extends State<HighlightColorPicker> {
  late Color _selectedColor;
  late HighlightStyle _selectedStyle;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _selectedStyle = widget.initialStyle;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Highlight Selection'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Style selection
            Text('Style', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<HighlightStyle>(
              segments: const [
                ButtonSegment(
                  value: HighlightStyle.markpen,
                  label: Text('Markpen'),
                  icon: Icon(Icons.brush),
                ),
                ButtonSegment(
                  value: HighlightStyle.underline,
                  label: Text('Underline'),
                  icon: Icon(Icons.format_underlined),
                ),
              ],
              selected: {_selectedStyle},
              onSelectionChanged: (Set<HighlightStyle> selection) {
                setState(() {
                  _selectedStyle = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            // Color selection
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(HighlightColors.colors.length, (index) {
                final color = HighlightColors.colors[index];
                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: _getContrastColor(color),
                            size: 20,
                          )
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Preview
            Text('Preview', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sample highlighted text',
                style: TextStyle(
                  fontSize: 16,
                  backgroundColor: _selectedStyle == HighlightStyle.markpen
                      ? _selectedColor.withValues(alpha: 0.4)
                      : null,
                  decoration: _selectedStyle == HighlightStyle.underline
                      ? TextDecoration.underline
                      : null,
                  decorationColor: _selectedColor,
                  decorationThickness: 3,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'color': _selectedColor,
              'style': _selectedStyle,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Show the highlight color picker dialog
Future<Map<String, dynamic>?> showHighlightColorPicker(
  BuildContext context, {
  Color? initialColor,
  HighlightStyle initialStyle = HighlightStyle.markpen,
}) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => HighlightColorPicker(
      initialColor: initialColor ?? HighlightColors.colors.first,
      initialStyle: initialStyle,
    ),
  );
}
