import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Centered empty screen content. Add the named SVG under
/// `asset/illustrations/`; until then, a themed icon keeps the layout usable.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.illustration,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String illustration;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 180,
                child: SvgPicture.asset(
                  'asset/illustrations/$illustration.svg',
                  semanticsLabel: message,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.inbox_outlined,
                    size: 92,
                    color: colors.primary.withValues(alpha: 0.65),
                  ),
                  placeholderBuilder: (_) => Icon(
                    Icons.inbox_outlined,
                    size: 92,
                    color: colors.primary.withValues(alpha: 0.65),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
