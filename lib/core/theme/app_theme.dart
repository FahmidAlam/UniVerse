import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 2: Obsidian Orbit theme alignment (Provisional).
abstract class AppTheme {
  // PHASE 2 (PROVISIONAL): Dark Theme aligned to Obsidian Orbit design tokens
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        // Custom GoRouter pages own route motion; this covers Material push routes.
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        }),

        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: AppColors.primary,
          onPrimary: AppColors.textOnPrimary,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primary,
          secondary: AppColors.info,
          onSecondary: AppColors.textOnPrimary,
          secondaryContainer: AppColors.infoSoft,
          onSecondaryContainer: AppColors.info,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerLowest: AppColors.background,
          surfaceContainerLow: AppColors.surfaceSubtle,
          surfaceContainer: AppColors.surface,
          surfaceContainerHigh: AppColors.surfaceElevated,
          surfaceContainerHighest: AppColors.surfaceInteractive,
          error: AppColors.error,
          onError: AppColors.textPrimary,
          errorContainer: AppColors.errorSoft,
          onErrorContainer: AppColors.error,
          outline: AppColors.border,
          outlineVariant: AppColors.borderHighlight,
        ),

        scaffoldBackgroundColor: AppColors.background,

        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          displayLarge: AppTextStyles.displayLarge,
          headlineLarge: AppTextStyles.h1,
          headlineMedium: AppTextStyles.h2,
          headlineSmall: AppTextStyles.h3,
          titleLarge: AppTextStyles.h3,
          titleMedium: AppTextStyles.h4,
          titleSmall: AppTextStyles.bodyMedium,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.bodySm,
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.button,
          labelMedium: AppTextStyles.label,
          labelSmall: AppTextStyles.caption,
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.h2,
          iconTheme: const IconThemeData(
            color: AppColors.textPrimary,
            size: AppSpacing.iconLg,
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.background,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        ),

        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.radiusMd,
            side: const BorderSide(
              color: AppColors.border,
              width: AppSpacing.borderThin,
            ),
          ),
          margin: EdgeInsets.zero,
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.radiusLg,
            side: const BorderSide(
              color: AppColors.border,
              width: AppSpacing.borderThin,
            ),
          ),
          titleTextStyle: AppTextStyles.h2,
          contentTextStyle: AppTextStyles.body,
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.navBg,
          selectedItemColor: AppColors.navActive,
          unselectedItemColor: AppColors.navInactive,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.navBg,
          indicatorColor: AppColors.primarySoft,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.navActive, size: 24);
            }
            return const IconThemeData(color: AppColors.navInactive, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTextStyles.chip.copyWith(
                  color: AppColors.navActive, fontWeight: FontWeight.w700);
            }
            return AppTextStyles.chip.copyWith(color: AppColors.navInactive);
          }),
          elevation: 0,
          height: AppSpacing.bottomNavHeight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            disabledBackgroundColor: AppColors.surfaceElevated,
            disabledForegroundColor: AppColors.textDisabled,
            minimumSize: const Size(64, AppSpacing.buttonHeight),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.radiusMd,
            ),
            elevation: 0,
            textStyle:
                AppTextStyles.button.copyWith(color: AppColors.textOnPrimary),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            disabledBackgroundColor: AppColors.surfaceElevated,
            disabledForegroundColor: AppColors.textDisabled,
            minimumSize: const Size(64, AppSpacing.buttonHeight),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.radiusMd,
            ),
            elevation: 0,
            textStyle:
                AppTextStyles.button.copyWith(color: AppColors.textOnPrimary),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            disabledForegroundColor: AppColors.textDisabled,
            minimumSize: const Size(64, AppSpacing.buttonHeight),
            side: const BorderSide(
                color: AppColors.border, width: AppSpacing.borderThin),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.radiusMd,
            ),
            elevation: 0,
            textStyle: AppTextStyles.button,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),

        // PHASE 2 (PROVISIONAL): Fix global TextButton tap-target risk (>= 44x44 interactive area)
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppTextStyles.link,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(
                color: AppColors.border, width: AppSpacing.borderThin),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(
                color: AppColors.border, width: AppSpacing.borderThin),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(
                color: AppColors.borderFocus, width: AppSpacing.borderFocus),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(
                color: AppColors.borderError, width: AppSpacing.borderThin),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(
                color: AppColors.borderError, width: AppSpacing.borderFocus),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(
                color: AppColors.surfaceSubtle, width: AppSpacing.borderThin),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          hintStyle: AppTextStyles.placeholder,
          labelStyle: AppTextStyles.label,
          errorStyle: AppTextStyles.bodyError,
          prefixIconColor: AppColors.textMuted,
          suffixIconColor: AppColors.textMuted,
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: AppSpacing.borderThin,
          space: 0,
        ),

        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceElevated,
          selectedColor: AppColors.primarySoft,
          disabledColor: AppColors.surfaceSubtle,
          labelStyle: AppTextStyles.chip,
          secondaryLabelStyle: AppTextStyles.chip
              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
          side: const BorderSide(
              color: AppColors.border, width: AppSpacing.borderThin),
          shape:
              const RoundedRectangleBorder(borderRadius: AppSpacing.radiusFull),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          elevation: 0,
          checkmarkColor: AppColors.primary,
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.surfaceElevated,
          circularTrackColor: AppColors.surfaceElevated,
        ),

        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.surfaceElevated;
          }),
          checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
          side: const BorderSide(
              color: AppColors.border, width: AppSpacing.borderThick),
          shape:
              const RoundedRectangleBorder(borderRadius: AppSpacing.radiusSm),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textPrimary;
            }
            return AppColors.textMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.surfaceElevated;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceElevated,
          contentTextStyle:
              AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary),
          shape:
              const RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
          behavior: SnackBarBehavior.floating,
          elevation: 4,
          actionTextColor: AppColors.primary,
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceElevated,
          modalBackgroundColor: AppColors.surfaceElevated,
          dragHandleColor: AppColors.border,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLgD),
            ),
          ),
          elevation: 0,
        ),

        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          iconColor: AppColors.textMuted,
          textColor: AppColors.textPrimary,
          minVerticalPadding: 0,
        ),

        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surfaceElevated,
          elevation: 4,
          shape:
              const RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
          textStyle: AppTextStyles.body,
        ),

        iconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: AppSpacing.iconLg,
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
        ),
      );

  static void setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}
