import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class WindowsTitleBar extends StatefulWidget {
  const WindowsTitleBar({super.key});

  @override
  State<WindowsTitleBar> createState() => _WindowsTitleBarState();
}

class _WindowsTitleBarState extends State<WindowsTitleBar> {
  bool _isCloseHovered = false;
  bool _isMaximizeHovered = false;
  bool _isMinimizeHovered = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        final backgroundColor = isDark 
            ? const Color(0xFF1e1e1e).withOpacity(0.9)
            : Colors.white.withOpacity(0.8);
        
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF333333).withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 左侧三大金刚键（macOS 风格）
              const SizedBox(width: 12),
              _buildMacOSButton(
                isHovered: _isCloseHovered,
                onHoverChanged: (hovered) {
                  setState(() {
                    _isCloseHovered = hovered;
                  });
                },
                onPressed: () {
                  appWindow.close();
                },
                color: const Color(0xFFFF5F57),
                hoverColor: const Color(0xFFFF3B30),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildMacOSButton(
                isHovered: _isMinimizeHovered,
                onHoverChanged: (hovered) {
                  setState(() {
                    _isMinimizeHovered = hovered;
                  });
                },
                onPressed: () {
                  appWindow.minimize();
                },
                color: const Color(0xFFFEBC2E),
                hoverColor: const Color(0xFFFFB300),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildMacOSButton(
                isHovered: _isMaximizeHovered,
                onHoverChanged: (hovered) {
                  setState(() {
                    _isMaximizeHovered = hovered;
                  });
                },
                onPressed: () {
                  appWindow.maximizeOrRestore();
                },
                color: const Color(0xFF28C840),
                hoverColor: const Color(0xFF00C957),
                isDark: isDark,
              ),
              // 可拖动区域
              Expanded(
                child: MoveWindow(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacOSButton({
    required bool isHovered,
    required Function(bool) onHoverChanged,
    required VoidCallback onPressed,
    required Color color,
    required Color hoverColor,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHovered ? hoverColor : color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 1,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
