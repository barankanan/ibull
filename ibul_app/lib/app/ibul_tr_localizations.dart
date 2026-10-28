import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// Turkish-only Material/Cupertino/Widgets bundles.
///
/// [GlobalMaterialLocalizations.delegate] links every SDK locale through one
/// switch, so the entry JS evaluates all of them. The app locale is `tr`.
class IbulTrMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const IbulTrMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tr';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    const name = 'tr';
    return SynchronousFuture<MaterialLocalizations>(
      MaterialLocalizationTr(
        fullYearFormat: intl.DateFormat.y(name),
        compactDateFormat: intl.DateFormat.yMd(name),
        shortDateFormat: intl.DateFormat.yMMMd(name),
        mediumDateFormat: intl.DateFormat.MMMEd(name),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(name),
        yearMonthFormat: intl.DateFormat.yMMMM(name),
        shortMonthDayFormat: intl.DateFormat.MMMd(name),
        decimalFormat: intl.NumberFormat.decimalPattern(name),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),
      ),
    );
  }

  @override
  bool shouldReload(IbulTrMaterialLocalizationsDelegate old) => false;
}

class IbulTrWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const IbulTrWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tr';

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    return SynchronousFuture<WidgetsLocalizations>(
      const WidgetsLocalizationTr(),
    );
  }

  @override
  bool shouldReload(IbulTrWidgetsLocalizationsDelegate old) => false;
}

class IbulTrCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const IbulTrCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tr';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    const name = 'tr';
    return SynchronousFuture<CupertinoLocalizations>(
      CupertinoLocalizationTr(
        fullYearFormat: intl.DateFormat.y(name),
        dayFormat: intl.DateFormat.d(name),
        weekdayFormat: intl.DateFormat.E(name),
        mediumDateFormat: intl.DateFormat.MMMEd(name),
        singleDigitHourFormat: intl.DateFormat('HH', name),
        singleDigitMinuteFormat: intl.DateFormat.m(name),
        doubleDigitMinuteFormat: intl.DateFormat('mm', name),
        singleDigitSecondFormat: intl.DateFormat.s(name),
        decimalFormat: intl.NumberFormat.decimalPattern(name),
      ),
    );
  }

  @override
  bool shouldReload(IbulTrCupertinoLocalizationsDelegate old) => false;
}
