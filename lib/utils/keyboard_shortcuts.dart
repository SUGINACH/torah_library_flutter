// lib/utils/keyboard_shortcuts.dart
// שיפור #3: Keyboard Shortcuts לשינויים מהירים

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DisplayKeyboardShortcuts {
  // קבועים למקשים חמים
  static const LogicalKeyboardKey _modifierKey = LogicalKeyboardKey.control;
  
  // הגדרות מקשים חמים
  static const LogicalKeyboardKey fontSizeIncrease = LogicalKeyboardKey.equal;
  static const LogicalKeyboardKey fontSizeDecrease = LogicalKeyboardKey.minus;
  static const LogicalKeyboardKey toggleAnimations = LogicalKeyboardKey.keyA;
  static const LogicalKeyboardKey toggleRTL = LogicalKeyboardKey.keyR;
  static const LogicalKeyboardKey openSettings = LogicalKeyboardKey.keyS;
  static const LogicalKeyboardKey resetSettings = LogicalKeyboardKey.keyD;
  static const LogicalKeyboardKey quickProfile1 = LogicalKeyboardKey.digit1;
  static const LogicalKeyboardKey quickProfile2 = LogicalKeyboardKey.digit2;
  static const LogicalKeyboardKey quickProfile3 = LogicalKeyboardKey.digit3;
  static const LogicalKeyboardKey quickProfile4 = LogicalKeyboardKey.digit4;
  
  // משלוח הודעות
  static Function(double)? onFontSizeChange;
  static Function(bool)? onAnimationsToggle;
  static Function(bool)? onRTLTogge;
  static Function()? onSettingsOpen;
  static Function()? onSettingsReset;
  static Function(int)? onProfileSelect;
  
  static void initialize({
    Function(double)? onFontSizeChanged,
    Function(bool)? onAnimationsToggled,
    Function(bool)? onRTLToggled,
    Function()? onSettingsOpened,
    Function()? onSettingsReseted,
    Function(int)? onProfileSelected,
  }) {
    onFontSizeChange = onFontSizeChanged;
    onAnimationsToggle = onAnimationsToggled;
    onRTLTogge = onRTLToggled;
    onSettingsOpen = onSettingsOpened;
    onSettingsReset = onSettingsReseted;
    onProfileSelect = onProfileSelected;
    
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }
  
  static bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final keyboard = HardwareKeyboard.instance;
      final isModifierPressed = keyboard.isControlPressed || 
                                keyboard.isMetaPressed;
      
      if (!isModifierPressed && event.logicalKey == fontSizeIncrease) {
        onFontSizeChange?.call(1.0);
        return true;
      }
      
      if (!isModifierPressed && event.logicalKey == fontSizeDecrease) {
        onFontSizeChange?.call(-1.0);
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == toggleAnimations) {
        onAnimationsToggle?.call(true);
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == toggleRTL) {
        onRTLTogge?.call(true);
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == openSettings) {
        onSettingsOpen?.call();
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == resetSettings) {
        onSettingsReset?.call();
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == quickProfile1) {
        onProfileSelect?.call(1);
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == quickProfile2) {
        onProfileSelect?.call(2);
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == quickProfile3) {
        onProfileSelect?.call(3);
        return true;
      }
      
      if (isModifierPressed && event.logicalKey == quickProfile4) {
        onProfileSelect?.call(4);
        return true;
      }
    }
    
    return false;
  }
  
  static void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }
  
  static String getShortcutDescription() {
    return '''
מקשי קיצור זמינים:
+ / - : הגדלת/הקטנת גודל גופן
Ctrl+A: החלפת אנימציות
Ctrl+R: החלפת כיוון טקסט (RTL/LTR)
Ctrl+S: פתיחת הגדרות תצוגה
Ctrl+D: איפוס הגדרות
Ctrl+1 עד Ctrl+4: פרופילים מהירים
''';
  }
}

// Widget Helper ליצירת Shortcut Actions
class DisplayShortcutsWidget extends StatelessWidget {
  final Widget child;
  final Function(double) onFontSizeChange;
  final Function(bool) onAnimationsToggle;
  final Function(bool) onRTLTogge;
  final Function() onSettingsOpen;
  final Function() onSettingsReset;
  final Function(int) onProfileSelect;
  
  const DisplayShortcutsWidget({
    super.key,
    required this.child,
    required this.onFontSizeChange,
    required this.onAnimationsToggle,
    required this.onRTLTogge,
    required this.onSettingsOpen,
    required this.onSettingsReset,
    required this.onProfileSelect,
  });
  
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // הגדלת גופן
        const SingleActivator(LogicalKeyboardKey.equal): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.plus): const ActivateIntent(),
        // הקטנת גופן
        const SingleActivator(LogicalKeyboardKey.minus): const ActivateIntent(),
        // החלפת אנימציות
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): const ActivateIntent(),
        // החלפת RTL
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): const ActivateIntent(),
        // פתיחת הגדרות
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): const ActivateIntent(),
        // איפוס הגדרות
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): const ActivateIntent(),
        // פרופילים מהירים
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              final keyboard = HardwareKeyboard.instance;
              final key = keyboard.logicalKeysPressed.last;
              
              if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.plus) {
                onFontSizeChange(1.0);
              } else if (key == LogicalKeyboardKey.minus) {
                onFontSizeChange(-1.0);
              } else if (key == LogicalKeyboardKey.keyA) {
                onAnimationsToggle(true);
              } else if (key == LogicalKeyboardKey.keyR) {
                onRTLTogge(true);
              } else if (key == LogicalKeyboardKey.keyS) {
                onSettingsOpen();
              } else if (key == LogicalKeyboardKey.keyD) {
                onSettingsReset();
              } else if (key == LogicalKeyboardKey.digit1) {
                onProfileSelect(1);
              } else if (key == LogicalKeyboardKey.digit2) {
                onProfileSelect(2);
              } else if (key == LogicalKeyboardKey.digit3) {
                onProfileSelect(3);
              } else if (key == LogicalKeyboardKey.digit4) {
                onProfileSelect(4);
              }
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
