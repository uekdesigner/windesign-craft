import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/projects/project_form_page.dart';
import '../features/settings/settings_page.dart';

import 'dart:io' show Platform, exit;
import '../features/projects/projects_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.width > 600;
    final bool isLandscape = screenSize.width > screenSize.height;

    return Scaffold(
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          child: isLandscape
              ? _buildLandscapeLayout(context, isTablet)
              : _buildPortraitLayout(context, isTablet),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, bool isTablet) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      // 🚨 DEĞİŞTİ: Stack -> Column
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(height: safeTop > 30 ? safeTop - 10 : safeTop),

        _buildPortraitHeader(context, isTablet),
        SizedBox(height: screenHeight * 0.005),

        _buildPortraitButtons(
          context,
          isTablet,
        ), // İçinde ayarlar+çıkış ikonları var
        _buildPortraitFooter(context),
        SizedBox(height: screenHeight * 0.1),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, bool isTablet) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double usableHeight = screenHeight - safeTop - safeBottom;
    final double usableWidth =
        screenWidth -
        MediaQuery.of(context).padding.left -
        MediaQuery.of(context).padding.right;

    // 🚨 EKRAN BOYUTUNA GÖRE OTOMATIK AYAR
    final bool isSmallPhone = usableWidth < 600; // P20 Pro yatay: ~732
    final bool isVerySmallPhone =
        usableHeight < 360; // P20 Pro yatay yükseklik: ~375

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🎨 SOL PANEL: Logo ve Başlık (Esnek genişlik)
            Flexible(
              flex: isVerySmallPhone ? 35 : 45, // Küçük ekranda daha az yer
              fit: FlexFit.tight,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallPhone ? 8 : 16,
                  vertical: safeTop,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // 🚨 İçeriğe göre boyutlan
                  children: [
                    _buildLogoFlexible(context, isTablet, usableHeight),
                    SizedBox(
                      height: maxHeight * 0.02,
                    ), // 🚨 Ekran yüzdesi boşluk
                    _buildTitleFlexible(context, isTablet, usableHeight),
                    SizedBox(height: maxHeight * 0.01),
                    _buildCompanyInfoFlexible(context, usableHeight),
                  ],
                ),
              ),
            ),

            // 🔘 SAĞ PANEL: Butonlar (Esnek genişlik)
            Flexible(
              flex: isVerySmallPhone ? 65 : 55, // Küçük ekranda daha fazla yer
              fit: FlexFit.tight,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallPhone ? 8 : 20,
                  vertical: safeTop + (isVerySmallPhone ? 4 : 12),
                ),
                child: _buildFlexibleButtonColumn(
                  context,
                  usableHeight,
                  usableWidth,
                  isVerySmallPhone,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlexibleButtonColumn(
    BuildContext context,
    double usableHeight,
    double usableWidth,
    bool isVerySmall,
  ) {
    // 🚨 BUTON BOYUTLARINI EKRANA GÖRE OTOMATIK HESAPLA

    // Ekran yüksekliğinin %'si olarak buton yüksekliği
    double buttonHeightPercent = isVerySmall
        ? 0.12
        : 0.16; // Küçük ekranda %14, normalde %16
    double buttonHeight = usableHeight * buttonHeightPercent;
    buttonHeight = buttonHeight.clamp(34, 70); // Min 36, Max 70

    // Boşluklar
    double spacing = usableHeight * 0.025;
    spacing = spacing.clamp(6, 20);

    // Yazı boyutu
    double fontSize = buttonHeight * 0.28;
    fontSize = fontSize.clamp(11, 18);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFlexibleButton(
          text: 'YENİ PROJE OLUŞTUR',
          onTap: () => _handleButtonTap(context, 0),
          height: buttonHeight,
          fontSize: fontSize,
          spacing: spacing,
        ),
        SizedBox(height: spacing),
        _buildFlexibleButton(
          text: 'PROJELERİM',
          onTap: () => _handleButtonTap(context, 1),
          height: buttonHeight,
          fontSize: fontSize,
          spacing: spacing,
        ),
        SizedBox(height: spacing),
        _buildFlexibleButton(
          text: 'AYARLAR',
          onTap: () => _handleButtonTap(context, 2),
          height: buttonHeight,
          fontSize: fontSize,
          spacing: spacing,
        ),
        SizedBox(height: spacing),
        _buildFlexibleCloseButton(
          context: context,
          height: buttonHeight * 0.85, // Çıkış butonu %15 daha küçük
          fontSize: fontSize * 0.9,
          spacing: spacing,
        ),
      ],
    );
  }

  Widget _buildFlexibleButton({
    required String text,
    required VoidCallback onTap,
    required double height,
    required double fontSize,
    required double spacing,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              height * 0.25,
            ), // Yuvarlaklık yüksekliğin %25'i
          ),
          padding: EdgeInsets.symmetric(horizontal: height * 0.3),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFlexibleCloseButton({
    required BuildContext context,
    required double height,
    required double fontSize,
    required double spacing,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton.icon(
        onPressed: () => _closeApp(context),
        icon: Icon(
          Icons.exit_to_app_rounded,
          size: fontSize * 1.1,
          color: Colors.grey[600],
        ),
        label: Text(
          'UYGULAMADAN ÇIK',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height * 0.25),
          ),
          side: BorderSide(color: Colors.grey[400]!),
          padding: EdgeInsets.symmetric(horizontal: height * 0.2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildLogoFlexible(
    BuildContext context,
    bool isTablet,
    double usableHeight,
  ) {
    // 🚨 Ekran yüksekliğine göre logo boyutu (min-max sınırlı)
    double logoSize = usableHeight * 0.35; // Ekran yüksekliğinin %35'i
    logoSize = logoSize.clamp(60, 160); // Min 60, Max 160

    // Tablet ve büyük ekranlar için ayar
    if (isTablet) logoSize = logoSize.clamp(100, 200);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      width: logoSize,
      height: logoSize,
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildTitleFlexible(
    BuildContext context,
    bool isTablet,
    double usableHeight,
  ) {
    // 🚨 Ekran boyutuna göre otomatik yazı boyutu
    double titleSize = usableHeight * 0.06; // Yüksekliğin %6'sı
    double subtitleSize = usableHeight * 0.035; // Yüksekliğin %3.5'i

    // Sınırlar
    titleSize = titleSize.clamp(14, 26);
    subtitleSize = subtitleSize.clamp(10, 18);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 500),
          style: Theme.of(context).textTheme.displayMedium!.copyWith(
            fontSize: titleSize,
            letterSpacing: 1.0,
            color: const Color.fromARGB(255, 69, 69, 70),
            height: 1.2,
          ),
          child: const Text('WinDesign_Craft Pro'),
        ),
        SizedBox(height: usableHeight * 0.015),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 700),
          opacity: 0.7,
          child: Text(
            'PROFESYONEL PVC TASARIMI',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: subtitleSize,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
              color: const Color.fromARGB(255, 76, 76, 77),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfoFlexible(BuildContext context, double usableHeight) {
    double fontSize = usableHeight * 0.025;
    fontSize = fontSize.clamp(10, 14);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 0.8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'UEK DESIGNER',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              color: const Color.fromARGB(255, 106, 107, 107),
            ),
          ),
          SizedBox(height: usableHeight * 0.008),
          Text(
            '© 2026 TÜM HAKLARI SAKLIDIR.',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: fontSize * 0.85,
              color: const Color.fromARGB(255, 90, 90, 90),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitHeader(BuildContext context, bool isTablet) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeTop = MediaQuery.of(context).padding.top;
    final double usableHeight = screenHeight - safeTop;

    // Logo boyutu: Kullanılabilir yüksekliğin %'si
    double logoSize = usableHeight * 0.5;
    logoSize = logoSize.clamp(80, 180);

    return Expanded(
      flex: 2,
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.only(top: safeTop > 24 ? 8 : 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                width: logoSize,
                height: logoSize,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              SizedBox(height: usableHeight * 0.015),
              _buildTitleFlexible(context, isTablet, usableHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitButtons(BuildContext context, bool isTablet) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeTop = MediaQuery.of(context).padding.top;
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double usableHeight = screenHeight - safeTop - safeBottom;
    final double screenWidth = MediaQuery.of(context).size.width;

    final bool isSmallPhone = screenWidth < 380;
    final bool isVerySmallPhone = usableHeight < 650;

    // 🚨 DEĞİŞTİ: Daha yatay butonlar
    double buttonHeightPercent = isVerySmallPhone ? 0.075 : 0.085; // %7.5-8.5
    double buttonHeight = usableHeight * buttonHeightPercent;
    buttonHeight = buttonHeight.clamp(44, 64); // Min 44, Max 64

    double spacingPercent = isVerySmallPhone ? 0.018 : 0.022; // %1.8-2.2
    double spacing = usableHeight * spacingPercent;
    spacing = spacing.clamp(10, 24);

    // 🚨 DEĞİŞTİ: Font oranı artırıldı
    double fontSize = buttonHeight * 0.35; // Yüksekliğin %45'i
    fontSize = fontSize.clamp(16, 24); // Daha büyük yazı

    // İkon boyutları
    double iconSize = isSmallPhone ? 44 : 52;

    return Expanded(
      flex: 2,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.08, // 🚨 Biraz daha içeriden
          vertical: usableHeight * 0.005,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🚨 YENİ: İkonlu, gradientli butonlar
            _buildPortraitButtonWithIcon(
              text: 'YENİ PROJE',
              icon: Icons.add_circle_outline,
              onTap: () => _handleButtonTap(context, 0),
              height: buttonHeight,
              fontSize: fontSize,
              spacing: spacing,
              isPrimary: false, // Mavi, öne çıkan
            ),
            SizedBox(height: spacing),
            _buildPortraitButtonWithIcon(
              text: 'PROJELERİM',
              icon: Icons.folder_open_outlined,
              onTap: () => _handleButtonTap(context, 1),
              height: buttonHeight,
              fontSize: fontSize,
              spacing: spacing,
              isPrimary: false, // Gri, ikincil
            ),

            // Ayarlar ve Çıkış ikonları yan yana
            SizedBox(height: spacing * 1.2),
            _buildIconButtonRow(context, iconSize, spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitButtonWithIcon({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required double height,
    required double fontSize,
    required double spacing,
    bool isPrimary = false,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isPrimary ? null : Colors.grey[200],
        borderRadius: BorderRadius.circular(12), // 🚨 Sabit, az yuvarlak
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? Color(0xFF1565C0).withOpacity(0.25)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: fontSize * 1.1,
          color: isPrimary ? Colors.white : Color(0xFF1565C0),
        ),
        label: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8, // 🚨 Harf aralığı
            color: isPrimary ? Colors.white : Color(0xFF1565C0),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : Color(0xFF1565C0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: height * 0.6),
        ),
      ),
    );
  }

  Widget _buildIconButtonRow(
    BuildContext context,
    double iconSize,
    double spacing,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconButton(
          icon: Icons.settings_outlined, // 🚨 Daha ince çizgi
          onTap: () => _handleButtonTap(context, 2),
          size: iconSize * 0.9, // 🚨 Biraz küçük
          tooltip: 'Ayarlar',
        ),
        SizedBox(width: spacing * 2.5), // 🚨 Biraz daha boşluk
        _buildIconButton(
          icon: Icons.logout_rounded,
          onTap: () => _closeApp(context),
          size: iconSize * 0.9,
          tooltip: 'Çıkış',
          isExit: true,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required String tooltip,
    bool isExit = false,
  }) {
    final Color bgColor = isExit
        ? Colors.red[50]!.withOpacity(0.7)
        : Colors.grey[100]!.withOpacity(0.8);
    final Color iconColor = isExit ? Colors.red[600]! : Colors.grey[700]!;
    final Color borderColor = isExit ? Colors.red[200]! : Colors.grey[300]!;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: size * 0.45, // 🚨 İkon oranı azaltıldı
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitFooter(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double usableHeight =
        screenHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    double fontSize = usableHeight * 0.022;
    fontSize = fontSize.clamp(10, 14);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + (usableHeight * 0.015),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'UEK DESIGNER',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: usableHeight * 0.008),
            Text(
              '© 2026 TÜM HAKLARI SAKLIDIR.',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: fontSize * 0.85,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context, bool isTablet, bool isLandscape) {
    final scaleFactor = _getScaleFactor(context, isLandscape);
    final double usableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;
    final bool isNarrowLandscape = isLandscape && usableHeight < 400;

    // 🚨 DEĞİŞTİ: Dar yatay ekranlarda çok daha küçük logo
    double logoSize = isLandscape
        ? (isTablet
              ? 160
              : (isNarrowLandscape ? 80 : 140)) // 140 -> 80 (dar yatay)
        : (isTablet ? 180 : 160);

    logoSize *= scaleFactor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      width: logoSize,
      height: logoSize,
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildTitle(BuildContext context, bool isTablet, bool isLandscape) {
    final scaleFactor = _getScaleFactor(context, isLandscape);
    final double usableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 380;
    final bool isNarrowLandscape = isLandscape && usableHeight < 400; // 🚨 EKLE

    double titleSize = isLandscape
        ? (isTablet
              ? 24
              : (isNarrowLandscape
                    ? 16
                    : (isSmallScreen ? 18 : 22))) // 🚨 DEĞİŞTİ
        : (isTablet ? 28 : (isSmallScreen ? 20 : 24));

    double subtitleSize = isLandscape
        ? (isTablet
              ? 16
              : (isNarrowLandscape
                    ? 11
                    : (isSmallScreen ? 12 : 14))) // 🚨 DEĞİŞTİ
        : (isTablet ? 16 : (isSmallScreen ? 12 : 14));

    titleSize *= scaleFactor;
    subtitleSize *= scaleFactor;

    // 🚨 EKLE: Çok küçük yazıları sınırlandır
    titleSize = titleSize.clamp(12, 28);
    subtitleSize = subtitleSize.clamp(10, 20);

    return Column(
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 500),
          style: Theme.of(context).textTheme.displayMedium!.copyWith(
            fontSize: titleSize,
            letterSpacing: isNarrowLandscape
                ? 0.8
                : 1.2, // 🚨 DEĞİŞTİ: Dar ekranda az harf aralığı
            color: isLandscape ? const Color.fromARGB(255, 69, 69, 70) : null,
            height: 1.2,
          ),
          child: const Text('WinDesign_Craft Pro'),
        ),
        SizedBox(
          height: (isNarrowLandscape ? 4 : 8) * scaleFactor,
        ), // 🚨 DEĞİŞTİ
        AnimatedOpacity(
          duration: const Duration(milliseconds: 700),
          opacity: 0.7,
          child: Text(
            'PROFESYONEL PVC TASARIMI',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: subtitleSize,
              letterSpacing: isNarrowLandscape ? 0.5 : 0.8, // 🚨 DEĞİŞTİ
              fontWeight: FontWeight.w500,
              color: isLandscape ? const Color.fromARGB(255, 76, 76, 77) : null,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfo(BuildContext context, bool isLandscape) {
    final scaleFactor = _getScaleFactor(context, isLandscape);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 0.8,
      child: Column(
        children: [
          Text(
            'UEK DESIGNER',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14 * scaleFactor,
              color: isLandscape
                  ? const Color.fromARGB(255, 106, 107, 107)
                  : null,
            ),
          ),
          SizedBox(height: 6 * scaleFactor),
          Text(
            '© 2025 TÜM HAKLARI SAKLIDIR.',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12 * scaleFactor,
              color: isLandscape ? const Color.fromARGB(255, 90, 90, 90) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitButton({
    required String text,
    required VoidCallback onTap,
    required double scaleFactor,
    double? height, // 🚨 YENİ: Opsiyonel yükseklik parametresi
  }) {
    return SizedBox(
      width: double.infinity,
      height: (height ?? 62) * scaleFactor, // 🚨 DEĞİŞTİ: Parametreli yükseklik
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30 * scaleFactor),
          ),
          // 🚨 EKLE: Minimum boyut sınırlaması kaldır veya ayarla
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize:
                (height != null && height < 55 ? 14 : 16) *
                scaleFactor, // 🚨 EKLE: Küçük butonlarda daha küçük yazı
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1, // 🚨 EKLE: Tek satırda kal
          overflow: TextOverflow.ellipsis, // 🚨 EKLE: Taşarsa üç nokta
        ),
      ),
    );
  }

  double _getScaleFactor(BuildContext context, bool isLandscape) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeTop = MediaQuery.of(context).padding.top;
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double safeLeft = MediaQuery.of(context).padding.left;
    final double safeRight = MediaQuery.of(context).padding.right;

    // Kullanılabilir alan
    final double usableWidth = screenWidth - safeLeft - safeRight;
    final double usableHeight = screenHeight - safeTop - safeBottom;

    // 🚨 YENİ: Yatay mod için referans ölçüler (daha küçük)
    final double referenceWidth = isLandscape
        ? 720
        : 360; // 600 -> 720 (geniş ekran) ama min clamp var
    final double referenceHeight = isLandscape ? 380 : 640;

    final double widthRatio = screenWidth / referenceWidth;
    final double heightRatio = screenHeight / referenceHeight;

    double scale = widthRatio < heightRatio ? widthRatio : heightRatio;

    // 🚨 YENİ: Yatay modda dar ekranlar için özel kontrol (P20 Pro yatay: ~732x375)
    if (isLandscape) {
      // Yatay modda yükseklik aslında dar telefonun genişliği (P20 Pro: ~375dp)
      if (usableHeight < 400) {
        // Çok dar yatay ekran (küçük telefonlar)
        scale = scale.clamp(0.7, 0.95); // 🚨 KRİTİK: Daha agresif sınır
      } else if (usableHeight < 450) {
        scale = scale.clamp(0.75, 1.0);
      } else {
        scale = scale.clamp(0.8, 1.15);
      }
    } else {
      // Dikey mod (önceki ayarlar)
      if (screenWidth < 380) {
        scale = scale.clamp(0.75, 1.0);
      } else if (screenWidth < 420) {
        scale = scale.clamp(0.8, 1.1);
      } else {
        scale = scale.clamp(0.85, 1.2);
      }

      if (usableHeight < 600) {
        scale *= 0.9;
      }
    }

    return scale;
  }

  void _closeApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isLandscape =
            MediaQuery.of(context).size.width >
            MediaQuery.of(context).size.height;
        final double scaleFactor = _getScaleFactor(context, isLandscape);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20 * scaleFactor),
          ),
          child: Padding(
            padding: EdgeInsets.all(24 * scaleFactor),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.exit_to_app_rounded,
                  size: 48 * scaleFactor,
                  color: Colors.grey[700],
                ),
                SizedBox(height: 16 * scaleFactor),
                Text(
                  'Çıkış Yap',
                  style: TextStyle(
                    fontSize: 20 * scaleFactor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8 * scaleFactor),
                Text(
                  'Uygulamadan çıkmak istediğinizden emin misiniz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16 * scaleFactor,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24 * scaleFactor),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('VAZGEÇ'),
                      ),
                    ),
                    SizedBox(width: 12 * scaleFactor),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _exitAppSafely();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('ÇIKIŞ YAP'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exitAppSafely() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemNavigator.pop();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        exit(0);
      }
    } catch (e) {
      // Hata sessizce yakalandı
    }
  }

  void _handleButtonTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return const ProjectFormPage();
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
        break;
      case 1:
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return const ProjectsListPage();
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
        break;
      case 2:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
        break;
    }
  }
}
