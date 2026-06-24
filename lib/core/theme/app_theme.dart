import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

abstract class AppTheme {


  static ThemeData get dark => ThemeData(
    brightness:           Brightness.dark,
    useMaterial3:         true,

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

    scaffoldBackgroundColor: AppColors.bgPrimary,

    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
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
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness:          Brightness.dark,
        statusBarIconBrightness:      Brightness.light,
        systemNavigationBarColor:     AppColors.bgPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      AppColors.navBg,
      selectedItemColor:    AppColors.navActive,
      unselectedItemColor:  AppColors.navInactive,
      showSelectedLabels:   true,
      showUnselectedLabels: true,
      type:                 BottomNavigationBarType.fixed,
      elevation:            0,
    ),

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

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle:       AppTextStyles.link,
        padding:         EdgeInsets.zero,
        minimumSize:     Size.zero,
        tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:           true,
      fillColor:        AppColors.bgElevated,

      border: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius:    AppSpacing.radiusMd,
        borderSide:      const BorderSide(color: AppColors.error, width: 1.5),
      ),
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


    dividerTheme: const DividerThemeData(
      color:     AppColors.border,
      thickness: AppSpacing.borderThin,
      space:     0,
    ),

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

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color:                AppColors.primary,
      linearTrackColor:     AppColors.bgElevated,
      circularTrackColor:   AppColors.bgElevated,
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.bgElevated;
      }),
      checkColor:   WidgetStateProperty.all(AppColors.textPrimary),
      side:         const BorderSide(color: AppColors.border, width: 1.5),
      shape:        const RoundedRectangleBorder(borderRadius: AppSpacing.radiusSm),
    ),

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

    listTileTheme: const ListTileThemeData(
      tileColor:       Colors.transparent,
      contentPadding:  EdgeInsets.symmetric(
                         horizontal: AppSpacing.lg,
                         vertical:   AppSpacing.sm),
      iconColor:       AppColors.textMuted,
      textColor:       AppColors.textPrimary,
      minVerticalPadding: 0,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color:           AppColors.bgElevated,
      elevation:       4,
      shape:           const RoundedRectangleBorder(
                         borderRadius: AppSpacing.radiusMd),
      textStyle:       AppTextStyles.body,
    ),


    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size:  AppSpacing.iconLg,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
      elevation:       0,
      shape:           RoundedRectangleBorder(
                         borderRadius: AppSpacing.radiusMd),
    ),
  );


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
