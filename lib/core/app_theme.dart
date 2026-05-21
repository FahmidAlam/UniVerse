// ============================================================
// FILE: lib/core/theme/app_theme.dart
// PURPOSE: This is the single entry point that connects ALL
//          theme tokens (colors, text styles, spacing) into
//          Flutter's MaterialApp ThemeData. It also defines
//          the default look for every built-in Flutter widget
//          (buttons, inputs, app bars, bottom nav, cards,
//          checkboxes, dialogs, snackbars) so that widgets
//          look correct with zero extra styling code.
//
// HOW TO USE — in main.dart:
//   import 'package:universe/core/theme/app_theme.dart';
//
//   MaterialApp.router(
//     theme: AppTheme.dark,   // <── single line wires everything
//     routerConfig: appRouter,
//     ...
//   )
//
// WHAT THIS GIVES YOU:
//   After wiring this in main.dart, the following "just work":
//   • Scaffold background = #0F0F10
//   • ElevatedButton = orange gradient, correct height, rounded
//   • TextFormField / TextField = dark input with orange focus
//   • AppBar = dark, no elevation, correct title style
//   • BottomNavigationBar = dark with orange active icon
//   • Card = dark card color with rounded corners
//   • SnackBar = dark elevated surface
//   • CircularProgressIndicator = orange
//   • CheckBox / Switch = orange active state
//   • Dialog = dark background
//   • Divider = subtle border color
//   • IconTheme = secondary text color by default
//
// HOW WIDGETS OVERRIDE THE THEME:
//   Custom widgets (UButton, UTextField, etc.) will sometimes
//   bypass ThemeData to use AppColors/AppTextStyles directly
//   for precise control. That is intentional and fine.
//   ThemeData handles ALL built-in Flutter widgets as a baseline.
//
// FUTURE INTEGRATION:
//   - main.dart uses AppTheme.dark in MaterialApp.router
//   - app_router.dart doesn't need theme — GoRouter is independent
//   - shared/widgets/* use AppColors + AppTextStyles directly,
//     not ThemeData, for full control
//   - If a light theme is ever needed: add AppTheme.light here
//     following the same structure, then toggle in main.dart
//     based on a ThemeNotifier or SharedPreferences value.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:universe_v1/core/app_colors.dart';
import 'package:universe_v1/core/app_spacing.dart';
import 'package:universe_v1/core/app_text_styles.dart';

abstract class AppTheme {

  // ──────────────────────────────────────────────────────────
  // MASTER THEME
  // Call AppTheme.dark in MaterialApp. Everything below is
  // configured once and inherited by the whole widget tree.
  // ──────────────────────────────────────────────────────────

  static ThemeData get dark => ThemeData(
    // ── Core identity ──────────────────────────────────────
    brightness:           Brightness.dark,
    useMaterial3:         true,

    // ── Color scheme ───────────────────────────────────────
    // Flutter's ColorScheme maps semantic roles to our tokens.
    // Widgets that read "colorScheme.primary" will get orange.
    colorScheme: const ColorScheme.dark(
      brightness:      Brightness.dark,
      primary:         AppColors.primary,
      onPrimary:       AppColors.textPrimary,
      primaryContainer:AppColors.primarySoft,
      secondary:       AppColors.info,
      onSecondary:     AppColors.textPrimary,
      surface:         AppColors.bgCard,
      onSurface:       AppColors.textPrimary,
      error:           AppColors.error,
      onError:         AppColors.textPrimary,
      outline:         AppColors.border,
      outlineVariant:  AppColors.bgElevated,
      surfaceContainerHighest: AppColors.bgElevated,
    ),

    // ── Scaffold ────────────────────────────────────────────
    // Sets the default background color for every Scaffold
    // in the app. No screen needs to set backgroundColor.
    scaffoldBackgroundColor: AppColors.bgPrimary,

    // ── Font family ─────────────────────────────────────────
    // Inter is applied to ALL text in the app via GoogleFonts.
    // This means AppTextStyles don't need to specify fontFamily —
    // it's inherited from here automatically.
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      // Map Flutter's named text styles to our tokens.
      // These are used by built-in widgets (AppBar, ListTile…)
      displayLarge:   AppTextStyles.h1,
      headlineLarge:  AppTextStyles.h1,
      headlineMedium: AppTextStyles.h2,
      headlineSmall:  AppTextStyles.h3,
      titleLarge:     AppTextStyles.h3,
      titleMedium:    AppTextStyles.h4,
      titleSmall:     AppTextStyles.bodyMedium,
      bodyLarge:      AppTextStyles.body,
      bodyMedium:     AppTextStyles.bodySm,
      bodySmall:      AppTextStyles.caption,
      labelLarge:     AppTextStyles.button,
      labelMedium:    AppTextStyles.label,
      labelSmall:     AppTextStyles.caption,
    ),

    // ── App Bar ─────────────────────────────────────────────
    // Every AppBar in the app gets this look by default.
    // Our UAppBar widget is a wrapper around AppBar, so this
    // applies to it automatically.
    appBarTheme: AppBarTheme(
      backgroundColor:  AppColors.bgPrimary,
      foregroundColor:  AppColors.textPrimary,
      elevation:        0,
      scrolledUnderElevation: 0,
      centerTitle:      false,
      titleTextStyle:   AppTextStyles.h2,
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size:  AppSpacing.iconLg,
      ),
      // Status bar icons are light on dark background
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness:          Brightness.dark,
        statusBarIconBrightness:      Brightness.light,
        systemNavigationBarColor:     AppColors.bgPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),

    // ── Bottom Navigation Bar ────────────────────────────────
    // Applies to the Flutter BottomNavigationBar widget.
    // Our custom UBottomNav widget reads AppColors directly
    // for NavigationBar (Material 3), but this handles fallback.
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      AppColors.navBg,
      selectedItemColor:    AppColors.navActive,
      unselectedItemColor:  AppColors.navInactive,
      showSelectedLabels:   true,
      showUnselectedLabels: true,
      type:                 BottomNavigationBarType.fixed,
      elevation:            0,
    ),

    // Material 3 NavigationBar (used by UBottomNav)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:          AppColors.navBg,
      indicatorColor:           AppColors.primarySoft,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.navActive, size: 24);
        }
        return const IconThemeData(color: AppColors.navInactive, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTextStyles.chip.copyWith(color: AppColors.navActive);
        }
        return AppTextStyles.chip.copyWith(color: AppColors.navInactive);
      }),
      elevation:          0,
      height:             AppSpacing.bottomNavHeight,
      labelBehavior:      NavigationDestinationLabelBehavior.alwaysShow,
    ),

    // ── Elevated Button ─────────────────────────────────────
    // Used as the base for our UButton primary variant.
    // The gradient is applied inside UButton widget directly
    // since ThemeData doesn't support gradients natively.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  AppColors.primary,
        foregroundColor:  AppColors.textPrimary,
        disabledBackgroundColor: AppColors.bgElevated,
        disabledForegroundColor: AppColors.textDisabled,
        minimumSize:      const Size(double.infinity, AppSpacing.buttonHeight),
        shape:            const RoundedRectangleBorder(
          borderRadius:   AppSpacing.radiusMd,
        ),
        elevation:        0,
        textStyle:        AppTextStyles.button,
        padding:          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
    ),

    // ── Outlined Button ─────────────────────────────────────
    // Used as the base for UButton secondary variant.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: AppColors.textDisabled,
        minimumSize:     const Size(double.infinity, AppSpacing.buttonHeight),
        side:            const BorderSide(color: AppColors.border, width: 1),
        shape:           const RoundedRectangleBorder(
          borderRadius:  AppSpacing.radiusMd,
        ),
        elevation:       0,
        textStyle:       AppTextStyles.button,
        padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
    ),

    // ── Text Button ──────────────────────────────────────────
    // For link-style actions like "See all", "Skip".
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle:       AppTextStyles.link,
        padding:         EdgeInsets.zero,
        minimumSize:     Size.zero,
        tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
      ),
    ),

    // ── Input / TextField ────────────────────────────────────
    // Applied to all TextField and TextFormField widgets.
    // Our UTextField widget wraps TextFormField, so this applies.
    inputDecorationTheme: InputDecorationTheme(
      filled:           true,
      fillColor:        AppColors.bgElevated,

      // Default border (unfocused, no error)
      border: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.border, width: 1),
      ),
      // Orange border on focus
      focusedBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      // Red border on validation error
      errorBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.error, width: 1.5),
      ),
      // Disabled state
      disabledBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.bgElevated),
      ),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical:   AppSpacing.md,
      ),
      hintStyle:        AppTextStyles.placeholder,
      labelStyle:       AppTextStyles.label,
      errorStyle:       AppTextStyles.bodyError,
      prefixIconColor:  AppColors.textMuted,
      suffixIconColor:  AppColors.textMuted,
    ),

    // // ── Card ────────────────────────────────────────────────
    // // Base style for Flutter's Card widget.
    // // Our UCard widget uses Container directly for more control,
    // // but built-in widgets that produce Cards (e.g., Drawer items)
    // // will use this.
    // cardTheme: CardTheme(
    //   color:            AppColors.bgCard,
    //   elevation:        0,
    //   shape: RoundedRectangleBorder(
    //     borderRadius:   AppSpacing.radiusLg,
    //     side:           const BorderSide(color: AppColors.border, width: 0.5),
    //   ),
    //   margin:           const EdgeInsets.only(bottom: 10),
    // ),

    // ── Divider ─────────────────────────────────────────────
    // The subtle horizontal line used between sections.
    dividerTheme: const DividerThemeData(
      color:     AppColors.border,
      thickness: AppSpacing.borderThin,
      space:     0,
    ),

    // ── Chip ────────────────────────────────────────────────
    // Base style for Flutter's Chip widget.
    // Our UChip uses Container, but FilterChip/ChoiceChip
    // used in admin screens may use this.
    chipTheme: ChipThemeData(
      backgroundColor:          AppColors.bgElevated,
      selectedColor:            AppColors.primarySoft,
      disabledColor:            AppColors.bgSubtle,
      labelStyle:               AppTextStyles.chip,
      secondaryLabelStyle:      AppTextStyles.chip.copyWith(
                                  color: AppColors.primary),
      side:                     const BorderSide(color: AppColors.border),
      shape:                    const RoundedRectangleBorder(
                                  borderRadius: AppSpacing.radiusFull),
      padding:                  const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical:   AppSpacing.xs),
      elevation:                0,
      checkmarkColor:           AppColors.primary,
    ),

    // ── Progress Indicator ───────────────────────────────────
    // CircularProgressIndicator and LinearProgressIndicator.
    // Used in ULoading widget and anywhere an async wait happens.
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color:                AppColors.primary,
      linearTrackColor:     AppColors.bgElevated,
      circularTrackColor:   AppColors.bgElevated,
    ),

    // ── Checkbox ────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.bgElevated;
      }),
      checkColor:   WidgetStateProperty.all(AppColors.textPrimary),
      side:         const BorderSide(color: AppColors.border, width: 1.5),
      shape:        const RoundedRectangleBorder(borderRadius: AppSpacing.radiusSm),
    ),

    // ── Switch ───────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.textPrimary;
        return AppColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.bgElevated;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    // ── SnackBar ─────────────────────────────────────────────
    // For success/error toast messages (e.g., "Routine updated!",
    // "Failed to send notification"). Used via ScaffoldMessenger.
    snackBarTheme: SnackBarThemeData(
      backgroundColor:    AppColors.bgElevated,
      contentTextStyle:   AppTextStyles.bodySm.copyWith(
                            color: AppColors.textPrimary),
      shape:              RoundedRectangleBorder(
                            borderRadius: AppSpacing.radiusMd),
      behavior:           SnackBarBehavior.floating,
      elevation:          4,
      actionTextColor:    AppColors.primary,
    ),

    // // ── Dialog ───────────────────────────────────────────────
    // // For confirmation dialogs (e.g., "Cancel this class?",
    // // "Sign out?"). Our app uses showDialog with custom content.
    // dialogTheme: DialogTheme(
    //   backgroundColor:  AppColors.bgCard,
    //   elevation:        0,
    //   shape:            const RoundedRectangleBorder(
    //                       borderRadius: AppSpacing.radiusXl),
    //   titleTextStyle:   AppTextStyles.h3,
    //   contentTextStyle: AppTextStyles.bodySm,
    // ),

    // ── Bottom Sheet ─────────────────────────────────────────
    // For teacher cancel-class and send-notice bottom sheets.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:    AppColors.bgCard,
      modalBackgroundColor: AppColors.bgCard,
      dragHandleColor:    AppColors.border,
      showDragHandle:     true,
      shape:              RoundedRectangleBorder(
        borderRadius:     BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      elevation:          0,
    ),

    // ── List Tile ────────────────────────────────────────────
    // For setting rows, user management tiles, etc.
    listTileTheme: const ListTileThemeData(
      tileColor:       Colors.transparent,
      contentPadding:  EdgeInsets.symmetric(
                         horizontal: AppSpacing.lg,
                         vertical:   AppSpacing.sm),
      iconColor:       AppColors.textMuted,
      textColor:       AppColors.textPrimary,
      minVerticalPadding: 0,
    ),

    // ── PopupMenu (dropdown) ─────────────────────────────────
    // For role dropdowns and filter menus in admin screens.
    popupMenuTheme: PopupMenuThemeData(
      color:           AppColors.bgElevated,
      elevation:       4,
      shape:           const RoundedRectangleBorder(
                         borderRadius: AppSpacing.radiusMd),
      textStyle:       AppTextStyles.body,
    ),

    // // ── Tab Bar ──────────────────────────────────────────────
    // // For category tabs in Resource Hub and Notification filters.
    // tabBarTheme: TabBarTheme(
    //   labelColor:         AppColors.primary,
    //   unselectedLabelColor: AppColors.textMuted,
    //   labelStyle:         AppTextStyles.chip.copyWith(
    //                         color: AppColors.primary,
    //                         fontWeight: FontWeight.w600),
    //   unselectedLabelStyle: AppTextStyles.chip,
    //   indicator:          const UnderlineTabIndicator(
    //                         borderSide: BorderSide(
    //                           color: AppColors.primary, width: 2)),
    //   indicatorSize:      TabBarIndicatorSize.label,
    //   overlayColor:       WidgetStateProperty.all(Colors.transparent),
    // ),

    // ── Icon Theme (default) ─────────────────────────────────
    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size:  AppSpacing.iconLg,
    ),

    // ── FloatingActionButton ─────────────────────────────────
    // Not commonly used but set as a fallback.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
      elevation:       0,
      shape:           RoundedRectangleBorder(
                         borderRadius: AppSpacing.radiusMd),
    ),
  );

  // ──────────────────────────────────────────────────────────
  // SYSTEM UI OVERLAY HELPER
  // Call this once at app start (or inside initState of root
  // widget) to make the status bar transparent with light icons.
  //
  // Usage in main.dart:
  //   void main() {
  //     WidgetsFlutterBinding.ensureInitialized();
  //     AppTheme.setSystemUI();
  //     runApp(const UniVerseApp());
  //   }
  // ──────────────────────────────────────────────────────────

  static void setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor:                Colors.transparent,
        statusBarBrightness:           Brightness.dark,
        statusBarIconBrightness:       Brightness.light,
        systemNavigationBarColor:      AppColors.bgPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}