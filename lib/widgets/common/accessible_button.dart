import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/tts_service.dart';

class AccessibleButton extends StatelessWidget {
  final String text;
  final String? description;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AccessibleButton({
    Key? key,
    required this.text,
    this.description,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 50,
              color: foregroundColor ?? AppTheme.textColor,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: foregroundColor ?? AppTheme.textColor,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: (foregroundColor ?? AppTheme.textColor)
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}