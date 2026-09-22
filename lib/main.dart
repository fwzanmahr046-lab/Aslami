// ============================================================================
// تطبيق نور الإسلام - Islamic App
// مواقيت الصلاة + الأذكار + القبلة - Production Ready
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// أ. نماذج البيانات
// ============================================================================

class City {
  final String name;
  final double lat;
  final double lng;
  const City(this.name, this.lat, this.lng);
}

class Country {
  final String name;
  final String flag;
  final double tzOffset;
  final List<City> cities;
  const Country(this.name, this.flag, this.tzOffset, this.cities);
}

class Dhikr {
  final String text;
  final String? virtue;
  final int count;
  const Dhikr(this.text, {this.virtue, this.count = 1});
}

class AdhkarCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Dhikr> items;
  const AdhkarCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });
}

// ============================================================================
// ب. خدمات الحساب
// ============================================================================

class PrayerCalculator {
  static double _dtr(double d) => d * math.pi / 180.0;
  static double _rtd(double r) => r * 180.0 / math.pi;
  static double _sin(double d) => math.sin(_dtr(d));
  static double _cos(double d) => math.cos(_dtr(d));
  static double _tan(double d) => math.tan(_dtr(d));
  static double _asin(double x) => _rtd(math.asin(x.clamp(-1.0, 1.0)));
  static double _acos(double x) => _rtd(math.acos(x.clamp(-1.0, 1.0)));
  static double _atan(double x) => _rtd(math.atan(x));
  static double _atan2(double y, double x) => _rtd(math.atan2(y, x));

  static double _fixAngle(double a) {
    a = a - 360.0 * (a / 360.0).floorToDouble();
    return a < 0 ? a + 360.0 : a;
  }

  static double _fixHour(double a) {
    a = a - 24.0 * (a / 24.0).floorToDouble();
    return a < 0 ? a + 24.0 : a;
  }

  static double _julian(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floorToDouble();
    final b = 2 - a + (a / 4).floorToDouble();
    return (365.25 * (year + 4716)).floorToDouble() +
        (30.6001 * (month + 1)).floorToDouble() +
        day +
        b -
        1524.5;
  }

  static Map<String, double> _sunPosition(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
    final e = 23.439 - 0.00000036 * d;
    final ra = _fixHour(_atan2(_cos(e) * _sin(l), _cos(l)) / 15.0);
    final eqt = q / 15.0 - ra;
    final decl = _asin(_sin(e) * _sin(l));
    return {'decl': decl, 'eqt': eqt};
  }

  static double _midDay(double jd, double t) {
    final eqt = _sunPosition(jd + t)['eqt']!;
    return _fixHour(12.0 - eqt);
  }

  static double _sunAngleTime(
    double jd,
    double lat,
    double angle,
    double t, {
    bool ccw = false,
  }) {
    final decl = _sunPosition(jd + t)['decl']!;
    final noon = _midDay(jd, t);
    final inner =
        (-_sin(angle) - _sin(decl) * _sin(lat)) / (_cos(decl) * _cos(lat));
    final clamped = inner.clamp(-1.0, 1.0);
    final v = (1.0 / 15.0) * _acos(clamped);
    return noon + (ccw ? -v : v);
  }

  static double _asrTime(double jd, double lat, double factor, double t) {
    final decl = _sunPosition(jd + t)['decl']!;
    final angle = -_atan(1.0 / (factor + _tan((lat - decl).abs())));
    return _sunAngleTime(jd, lat, angle, t);
  }

  static DateTime _toDateTime(DateTime date, double hours) {
    final totalMinutes = (hours * 60).round();
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    final hh = h < 0 ? h + 24 : h;
    final mm = m < 0 ? m + 60 : m;
    return DateTime(date.year, date.month, date.day, hh, mm);
  }

  static PrayerTimes calculate({
    required DateTime date,
    required double lat,
    required double lng,
    required double tzOffset,
    double fajrAngle = 18.0,
    double ishaAngle = 17.0,
  }) {
    final jd = _julian(date.year, date.month, date.day) - lng / (15.0 * 24.0);
    double t = 0.5;
    double fajr = 0, sunrise = 0, dhuhr = 0, asr = 0, maghrib = 0, isha = 0;

    for (int i = 0; i < 3; i++) {
      fajr = _sunAngleTime(jd, lat, fajrAngle, t, ccw: true);
      sunrise = _sunAngleTime(jd, lat, 0.833, t, ccw: true);
      dhuhr = _midDay(jd, t);
      asr = _asrTime(jd, lat, 1.0, t);
      maghrib = _sunAngleTime(jd, lat, 0.833, t);
      isha = _sunAngleTime(jd, lat, ishaAngle, t);
      final avg = (fajr + sunrise + dhuhr + asr + maghrib + isha) / 6.0;
      t = (avg - 12.0) / 24.0;
    }

    fajr = _sunAngleTime(jd, lat, fajrAngle, t, ccw: true);
    sunrise = _sunAngleTime(jd, lat, 0.833, t, ccw: true);
    dhuhr = _midDay(jd, t);
    asr = _asrTime(jd, lat, 1.0, t);
    maghrib = _sunAngleTime(jd, lat, 0.833, t);
    isha = _sunAngleTime(jd, lat, ishaAngle, t);

    final adjust = tzOffset - lng / 15.0;

    return PrayerTimes(
      fajr: _toDateTime(date, fajr + adjust),
      sunrise: _toDateTime(date, sunrise + adjust),
      dhuhr: _toDateTime(date, dhuhr + adjust + (1.0 / 60.0)),
      asr: _toDateTime(date, asr + adjust),
      maghrib: _toDateTime(date, maghrib + adjust + (1.0 / 60.0)),
      isha: _toDateTime(date, isha + adjust),
    );
  }
}

class QiblaCalculator {
  static const double kaabaLat = 21.4225;
  static const double kaabaLng = 39.8262;

  static double direction(double lat, double lng) {
    final phiK = kaabaLat * math.pi / 180.0;
    final lambdaK = kaabaLng * math.pi / 180.0;
    final phi = lat * math.pi / 180.0;
    final lambda = lng * math.pi / 180.0;
    final deltaLambda = lambdaK - lambda;
    final y = math.sin(deltaLambda);
    final x =
        math.cos(phi) * math.tan(phiK) - math.sin(phi) * math.cos(deltaLambda);
    final bearing = math.atan2(y, x);
    return (bearing * 180.0 / math.pi + 360.0) % 360.0;
  }
}

class HijriDate {
  static const List<String> months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static List<int> fromGregorian(DateTime date) {
    final jd = _gregorianToJD(date.year, date.month, date.day);
    final l = jd - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    var l2 = l - 10631 * n + 354;
    final j = (((10985 - l2) / 5316).floor()) *
            (((50 * l2) / 17719).floor()) +
        ((l2 / 5670).floor()) * (((43 * l2) / 15238).floor());
    l2 = l2 -
        (((30 - j) / 15).floor()) * (((17719 * j) / 50).floor()) -
        ((j / 16).floor()) * (((15238 * j) / 43).floor()) +
        29;
    final m = ((24 * l2) / 709).floor();
    final d = l2 - ((709 * m) / 24).floor();
    final y = 30 * n + j - 30;
    return [y, m, d];
  }

  static int _gregorianToJD(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;
  }
}

class ApiService {
  final http.Client _client;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<int>?> fetchHijri(DateTime date) async {
    try {
      final url = Uri.parse(
        'https://api.aladhan.com/v1/gToH/${date.day}-${date.month}-${date.year}',
      );
      final resp = await _client.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final hijri = data['data']?['hijri'] as Map<String, dynamic>?;
        if (hijri == null) return null;
        final y = int.tryParse(hijri['year']?.toString() ?? '');
        final m = int.tryParse(hijri['month']?['number']?.toString() ?? '');
        final d = int.tryParse(hijri['day']?.toString() ?? '');
        if (y == null || m == null || d == null) return null;
        return [y, m, d];
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// ج. قاعدة بيانات الدول والمدن
// ============================================================================

const List<Country> kCountries = [
  Country('السعودية', '🇸🇦', 3.0, [
    City('مكة المكرمة', 21.3891, 39.8579),
    City('المدينة المنورة', 24.5247, 39.5692),
    City('الرياض', 24.7136, 46.6753),
    City('جدة', 21.4858, 39.1925),
    City('الدمام', 26.4207, 50.0888),
    City('الطائف', 21.2854, 40.4183),
    City('تبوك', 28.3835, 36.5662),
    City('أبها', 18.2164, 42.5053),
    City('بريدة', 26.3260, 43.9750),
    City('حائل', 27.5219, 41.6907),
    City('نجران', 17.4917, 44.1322),
    City('جيزان', 16.8892, 42.5511),
  ]),
  Country('مصر', '🇪🇬', 2.0, [
    City('القاهرة', 30.0444, 31.2357),
    City('الإسكندرية', 31.2001, 29.9187),
    City('الجيزة', 30.0131, 31.2089),
    City('المنصورة', 31.0409, 31.3785),
    City('أسيوط', 27.1809, 31.1837),
    City('أسوان', 24.0889, 32.8998),
    City('طنطا', 30.7865, 31.0004),
    City('بورسعيد', 31.2653, 32.3019),
    City('الأقصر', 25.6872, 32.6396),
    City('الإسماعيلية', 30.5965, 32.2715),
    City('الفيوم', 29.3084, 30.8428),
    City('المنيا', 28.1099, 30.7503),
  ]),
  Country('الإمارات', '🇦🇪', 4.0, [
    City('أبوظبي', 24.4539, 54.3773),
    City('دبي', 25.2048, 55.2708),
    City('الشارقة', 25.3463, 55.4209),
    City('العين', 24.2075, 55.7447),
    City('عجمان', 25.4052, 55.5136),
    City('رأس الخيمة', 25.7895, 55.9432),
    City('الفجيرة', 25.1288, 56.3265),
    City('أم القيوين', 25.5647, 55.5533),
  ]),
  Country('الكويت', '🇰🇼', 3.0, [
    City('مدينة الكويت', 29.3759, 47.9774),
    City('حولي', 29.3328, 48.0286),
    City('الفروانية', 29.2775, 47.9586),
    City('الأحمدي', 29.0769, 48.0838),
    City('الجهراء', 29.3375, 47.6581),
  ]),
  Country('قطر', '🇶🇦', 3.0, [
    City('الدوحة', 25.2854, 51.5310),
    City('الوكرة', 25.1659, 51.5976),
    City('الخور', 25.6804, 51.4969),
    City('الريان', 25.2537, 51.4219),
    City('دخان', 25.4400, 50.7856),
  ]),
  Country('البحرين', '🇧🇭', 3.0, [
    City('المنامة', 26.2285, 50.5860),
    City('المحرق', 26.2572, 50.6119),
    City('الرفاع', 26.1300, 50.5550),
    City('مدينة حمد', 26.1167, 50.5069),
    City('مدينة عيسى', 26.1736, 50.5483),
  ]),
  Country('عُمان', '🇴🇲', 4.0, [
    City('مسقط', 23.5880, 58.3829),
    City('صلالة', 17.0151, 54.0924),
    City('صحار', 24.3419, 56.7094),
    City('نزوى', 22.9333, 57.5333),
    City('صور', 22.5667, 59.5289),
    City('البريمي', 24.2500, 55.7933),
  ]),
  Country('الأردن', '🇯🇴', 3.0, [
    City('عمّان', 31.9454, 35.9284),
    City('الزرقاء', 32.0728, 36.0875),
    City('إربد', 32.5556, 35.8500),
    City('العقبة', 29.5320, 35.0063),
    City('السلط', 32.0392, 35.7272),
    City('مادبا', 31.7159, 35.7938),
    City('الكرك', 31.1853, 35.7047),
    City('معان', 30.1944, 35.7339),
  ]),
  Country('اليمن', '🇾🇪', 3.0, [
    City('صنعاء', 15.3694, 44.1910),
    City('عدن', 12.7855, 45.0187),
    City('تعز', 13.5789, 44.0219),
    City('الحديدة', 14.7978, 42.9545),
    City('إب', 13.9667, 44.1786),
    City('المكلا', 14.5411, 49.1242),
  ]),
  Country('العراق', '🇮🇶', 3.0, [
    City('بغداد', 33.3152, 44.3661),
    City('البصرة', 30.5085, 47.7804),
    City('الموصل', 36.3350, 43.1189),
    City('أربيل', 36.1911, 44.0092),
    City('النجف', 31.9892, 44.3148),
    City('كربلاء', 32.6160, 44.0249),
    City('السليمانية', 35.5613, 45.4412),
    City('كركوك', 35.4681, 44.3922),
    City('الرمادي', 33.4259, 43.2992),
    City('الناصرية', 31.0439, 46.2570),
    City('الحلة', 32.4833, 44.4333),
    City('ديالى', 33.7444, 44.6439),
  ]),
  Country('سوريا', '🇸🇾', 3.0, [
    City('دمشق', 33.5138, 36.2765),
    City('حلب', 36.2021, 37.1343),
    City('حمص', 34.7308, 36.7094),
    City('حماة', 35.1318, 36.7578),
    City('اللاذقية', 35.5137, 35.7838),
    City('طرطوس', 34.8896, 35.8866),
    City('دير الزور', 35.3396, 40.1499),
    City('الرقة', 35.9594, 39.0079),
  ]),
  Country('لبنان', '🇱🇧', 2.0, [
    City('بيروت', 33.8938, 35.5018),
    City('طرابلس', 34.4367, 35.8497),
    City('صيدا', 33.5571, 35.3729),
    City('صور', 33.2705, 35.2038),
    City('زحلة', 33.8463, 35.9019),
    City('جونية', 33.9800, 35.6200),
  ]),
  Country('فلسطين', '🇵🇸', 2.0, [
    City('القدس', 31.7683, 35.2137),
    City('غزة', 31.5017, 34.4668),
    City('رام الله', 31.8996, 35.2042),
    City('نابلس', 32.2211, 35.2544),
    City('الخليل', 31.5326, 35.0998),
    City('بيت لحم', 31.7054, 35.2024),
    City('جنين', 32.4616, 35.3008),
    City('طولكرم', 32.3104, 35.0286),
  ]),
  Country('ليبيا', '🇱🇾', 2.0, [
    City('طرابلس', 32.8872, 13.1913),
    City('بنغازي', 32.1167, 20.0667),
    City('مصراتة', 32.3754, 15.0925),
    City('الزاوية', 32.7571, 12.7278),
    City('سبها', 27.0377, 14.4283),
    City('درنة', 32.7670, 22.6423),
    City('طبرق', 32.0836, 23.9608),
  ]),
  Country('تونس', '🇹🇳', 1.0, [
    City('تونس', 36.8065, 10.1815),
    City('صفاقس', 34.7406, 10.7603),
    City('سوسة', 35.8256, 10.6084),
    City('القيروان', 35.6781, 10.0963),
    City('بنزرت', 37.2746, 9.8739),
    City('قابس', 33.8815, 10.0982),
    City('المنستير', 35.7770, 10.8262),
  ]),
  Country('الجزائر', '🇩🇿', 1.0, [
    City('الجزائر', 36.7538, 3.0588),
    City('وهران', 35.6971, -0.6308),
    City('قسنطينة', 36.3650, 6.6147),
    City('عنابة', 36.9000, 7.7667),
    City('باتنة', 35.5550, 6.1741),
    City('سطيف', 36.1898, 5.4108),
    City('تلمسان', 34.8828, -1.3167),
  ]),
  Country('المغرب', '🇲🇦', 1.0, [
    City('الرباط', 34.0209, -6.8416),
    City('الدار البيضاء', 33.5731, -7.5898),
    City('فاس', 34.0331, -5.0003),
    City('مراكش', 31.6295, -7.9811),
    City('طنجة', 35.7595, -5.8340),
    City('أكادير', 30.4278, -9.5981),
    City('مكناس', 33.8935, -5.5473),
    City('وجدة', 34.6814, -1.9086),
  ]),
  Country('السودان', '🇸🇩', 2.0, [
    City('الخرطوم', 15.5007, 32.5599),
    City('أم درمان', 15.6445, 32.4777),
    City('بورتسودان', 19.6158, 37.2164),
    City('كسلا', 15.4500, 36.4000),
    City('نيالا', 12.0500, 24.8833),
    City('الأبيض', 13.1833, 30.2167),
  ]),
  Country('موريتانيا', '🇲🇷', 0.0, [
    City('نواكشوط', 18.0735, -15.9582),
    City('نواذيبو', 20.9425, -17.0365),
    City('روصو', 16.5128, -15.8050),
    City('كيفة', 16.6167, -11.4000),
  ]),
  Country('الصومال', '🇸🇴', 3.0, [
    City('مقديشو', 2.0469, 45.3182),
    City('هرجيسا', 9.5600, 44.0650),
    City('بوساسو', 11.2842, 49.1816),
    City('كيسمايو', -0.3582, 42.5453),
  ]),
  Country('جيبوتي', '🇩🇯', 3.0, [
    City('جيبوتي', 11.5721, 43.1456),
    City('علي صبيح', 11.1558, 42.7125),
    City('تاجورة', 11.7878, 42.8822),
  ]),
  Country('جزر القمر', '🇰🇲', 3.0, [
    City('موروني', -11.7172, 43.2473),
    City('موتسامودو', -12.1667, 44.4000),
  ]),
  Country('تركيا', '🇹🇷', 3.0, [
    City('إسطنبول', 41.0082, 28.9784),
    City('أنقرة', 39.9334, 32.8597),
    City('إزمير', 38.4237, 27.1428),
    City('بورصة', 40.1826, 29.0665),
    City('أنطاليا', 36.8969, 30.7133),
    City('قونية', 37.8746, 32.4932),
    City('أضنة', 37.0000, 35.3213),
  ]),
  Country('إيران', '🇮🇷', 3.5, [
    City('طهران', 35.6892, 51.3890),
    City('مشهد', 36.2605, 59.6168),
    City('أصفهان', 32.6546, 51.6680),
    City('تبريز', 38.0800, 46.2919),
    City('شيراز', 29.5918, 52.5837),
  ]),
  Country('باكستان', '🇵🇰', 5.0, [
    City('كراتشي', 24.8607, 67.0011),
    City('لاهور', 31.5497, 74.3436),
    City('إسلام آباد', 33.6844, 73.0479),
    City('راولبندي', 33.5651, 73.0169),
    City('فيصل آباد', 31.4180, 73.0790),
    City('بيشاور', 34.0151, 71.5249),
    City('كويته', 30.1798, 66.9750),
  ]),
  Country('الهند', '🇮🇳', 5.5, [
    City('دلهي', 28.6139, 77.2090),
    City('مومباي', 19.0760, 72.8777),
    City('كلكتا', 22.5726, 88.3639),
    City('حيدر آباد', 17.3850, 78.4867),
    City('بنغالور', 12.9716, 77.5946),
    City('لكناو', 26.8467, 80.9462),
  ]),
  Country('بنغلاديش', '🇧🇩', 6.0, [
    City('داكا', 23.8103, 90.4125),
    City('شيتاغونغ', 22.3569, 91.7832),
    City('خولنا', 22.8456, 89.5403),
    City('راجشاهي', 24.3745, 88.6042),
  ]),
  Country('أفغانستان', '🇦🇫', 4.5, [
    City('كابل', 34.5553, 69.2075),
    City('هرات', 34.3529, 62.2040),
    City('قندهار', 31.6289, 65.7372),
    City('مزار الشريف', 36.7090, 67.1109),
  ]),
  Country('إندونيسيا', '🇮🇩', 7.0, [
    City('جاكرتا', -6.2088, 106.8456),
    City('سورابايا', -7.2575, 112.7521),
    City('باندونغ', -6.9175, 107.6191),
    City('ميدان', 3.5952, 98.6722),
    City('يوغياكارتا', -7.7956, 110.3695),
  ]),
  Country('ماليزيا', '🇲🇾', 8.0, [
    City('كوالالمبور', 3.1390, 101.6869),
    City('بينانغ', 5.4164, 100.3327),
    City('جوهور باهرو', 1.4927, 103.7414),
    City('إيبوه', 4.5975, 101.0901),
  ]),
  Country('نيجيريا', '🇳🇬', 1.0, [
    City('لاغوس', 6.5244, 3.3792),
    City('أبوجا', 9.0765, 7.3986),
    City('كانو', 12.0022, 8.5920),
    City('إبادان', 7.3775, 3.9470),
  ]),
  Country('السنغال', '🇸🇳', 0.0, [
    City('داكار', 14.7167, -17.4677),
    City('توبا', 14.8500, -15.8833),
    City('سانت لويس', 16.0179, -16.4896),
  ]),
  Country('تنزانيا', '🇹🇿', 3.0, [
    City('دار السلام', -6.7924, 39.2083),
    City('دودوما', -6.1630, 35.7516),
    City('زنجبار', -6.1659, 39.2026),
  ]),
  Country('كينيا', '🇰🇪', 3.0, [
    City('نيروبي', -1.2921, 36.8219),
    City('مومباسا', -4.0435, 39.6682),
    City('كيسومو', -0.0917, 34.7680),
  ]),
  Country('أوغندا', '🇺🇬', 3.0, [
    City('كمبالا', 0.3476, 32.5825),
    City('عنتيبي', 0.3163, 32.5822),
  ]),
  Country('إثيوبيا', '🇪🇹', 3.0, [
    City('أديس أبابا', 9.0320, 38.7469),
    City('دير داوا', 9.5931, 41.8661),
  ]),
  Country('بريطانيا', '🇬🇧', 0.0, [
    City('لندن', 51.5074, -0.1278),
    City('مانشستر', 53.4808, -2.2426),
    City('برمنغهام', 52.4862, -1.8904),
    City('غلاسكو', 55.8642, -4.2518),
  ]),
  Country('فرنسا', '🇫🇷', 1.0, [
    City('باريس', 48.8566, 2.3522),
    City('مرسيليا', 43.2965, 5.3698),
    City('ليون', 45.7640, 4.8357),
    City('ليل', 50.6292, 3.0573),
  ]),
  Country('ألمانيا', '🇩🇪', 1.0, [
    City('برلين', 52.5200, 13.4050),
    City('ميونخ', 48.1351, 11.5820),
    City('فرانكفورت', 50.1109, 8.6821),
    City('هامبورغ', 53.5511, 9.9937),
  ]),
  Country('أمريكا', '🇺🇸', -5.0, [
    City('نيويورك', 40.7128, -74.0060),
    City('شيكاغو', 41.8781, -87.6298),
    City('ديترويت', 42.3314, -83.0458),
    City('هيوستن', 29.7604, -95.3698),
    City('لوس أنجلوس', 34.0522, -118.2437),
  ]),
  Country('كندا', '🇨🇦', -5.0, [
    City('تورونتو', 43.6532, -79.3832),
    City('مونتريال', 45.5017, -73.5673),
    City('فانكوفر', 49.2827, -123.1207),
    City('أوتاوا', 45.4215, -75.6972),
  ]),
  Country('أستراليا', '🇦🇺', 10.0, [
    City('سيدني', -33.8688, 151.2093),
    City('ملبورن', -37.8136, 144.9631),
    City('بريزبان', -27.4698, 153.0251),
    City('بيرث', -31.9505, 115.8605),
  ]),
  Country('روسيا', '🇷🇺', 3.0, [
    City('موسكو', 55.7558, 37.6173),
    City('قازان', 55.8304, 49.0661),
    City('سانت بطرسبرغ', 59.9311, 30.3609),
  ]),
];

// ============================================================================
// د. قاعدة بيانات الأذكار
// ============================================================================

const List<AdhkarCategory> kAdhkarCategories = [
  AdhkarCategory(
    id: 'morning',
    title: 'أذكار الصباح',
    subtitle: 'حصّن نفسك من الفجر إلى الضحى',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFF5A623),
    items: [
      Dhikr(
        'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ. اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ.',
        virtue: 'من قالها حين يصبح أُجير من الجن حتى يمسي',
      ),
      Dhikr(
        'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
        virtue: 'من قالها مع المعوذتين ثلاث مرات كفته من كل شيء',
        count: 3,
      ),
      Dhikr(
        'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
        count: 3,
      ),
      Dhikr(
        'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
        count: 3,
      ),
      Dhikr(
        'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ.',
      ),
      Dhikr(
        'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ.',
      ),
      Dhikr(
        'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
        virtue: 'من قالها موقناً بها حين يصبح فمات من يومه دخل الجنة',
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ.',
        count: 4,
      ),
      Dhikr(
        'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
        virtue: 'من قالها سبع مرات كفاه الله ما أهمّه',
        count: 7,
      ),
      Dhikr(
        'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
        virtue: 'من قالها ثلاثاً لم يضره شيء',
        count: 3,
      ),
      Dhikr(
        'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا.',
        virtue: 'من قالها ثلاثاً كان حقاً على الله أن يرضيه يوم القيامة',
        count: 3,
      ),
      Dhikr(
        'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.',
      ),
      Dhikr(
        'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ.',
      ),
      Dhikr(
        'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.',
        virtue: 'من قالها مئة مرة حُطّت خطاياه وإن كانت مثل زبد البحر',
        count: 100,
      ),
      Dhikr(
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        virtue: 'من قالها عشر مرات كان كمن أعتق أربع أنفس من الرقيق',
        count: 10,
      ),
      Dhikr(
        'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ.',
        count: 3,
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا.',
      ),
      Dhikr('أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.', count: 100),
      Dhikr(
        'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ.',
        count: 3,
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَقَهْرِ الرِّجَالِ.',
      ),
      Dhikr('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', count: 10),
    ],
  ),
  AdhkarCategory(
    id: 'evening',
    title: 'أذكار المساء',
    subtitle: 'حصنك من العصر إلى المغرب',
    icon: Icons.nightlight_round,
    color: Color(0xFF3A5A8C),
    items: [
      Dhikr(
        'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ. اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ.',
      ),
      Dhikr(
        'قُلْ هُوَ اللَّهُ أَحَدٌ... (الإخلاص والمعوذتين)',
        virtue: 'من قالها ثلاثاً كفته من كل شيء',
        count: 3,
      ),
      Dhikr(
        'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا.',
      ),
      Dhikr(
        'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ.',
      ),
      Dhikr(
        'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ.',
        count: 4,
      ),
      Dhikr(
        'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
        count: 7,
      ),
      Dhikr(
        'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
        count: 3,
      ),
      Dhikr(
        'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا.',
        count: 3,
      ),
      Dhikr(
        'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.',
      ),
      Dhikr(
        'أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ.',
      ),
      Dhikr(
        'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
        virtue: 'من قالها ثلاثاً لم يضره شيء تلك الليلة',
        count: 3,
      ),
      Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', count: 100),
      Dhikr(
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        count: 10,
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَقَهْرِ الرِّجَالِ.',
      ),
      Dhikr('أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.', count: 100),
      Dhikr('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', count: 10),
    ],
  ),
  AdhkarCategory(
    id: 'sleep',
    title: 'أذكار النوم',
    subtitle: 'كيف تنام وأنت في حفظ الله',
    icon: Icons.bedtime_rounded,
    color: Color(0xFF2C3E50),
    items: [
      Dhikr('بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.'),
      Dhikr(
        'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ... (آية الكرسي)',
        virtue: 'من قرأها عند نومه لم يزل عليه من الله حافظ',
      ),
      Dhikr(
        'الإخلاص والمعوذتين: ثم ينفث في كفيه ويمسح بهما ما استطاع من جسده.',
        count: 3,
      ),
      Dhikr(
        'سُبْحَانَ اللَّهِ (33) — الْحَمْدُ لِلَّهِ (33) — اللَّهُ أَكْبَرُ (34)',
        virtue: 'خير لك من خادم',
      ),
      Dhikr('اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', count: 3),
      Dhikr(
        'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، فَإِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ.',
      ),
      Dhikr(
        'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ.',
      ),
      Dhikr(
        'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا، وَكَفَانَا، وَآوَانَا، فَكَمْ مِمَّنْ لَا كَافِيَ لَهُ وَلَا مُؤْوِيَ.',
      ),
    ],
  ),
  AdhkarCategory(
    id: 'wakeup',
    title: 'أذكار الاستيقاظ',
    subtitle: 'ابدأ يومك بذكر الله',
    icon: Icons.wb_twilight_rounded,
    color: Color(0xFFE67E22),
    items: [
      Dhikr(
        'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ.',
      ),
      Dhikr(
        'الْحَمْدُ لِلَّهِ الَّذِي رَدَّ عَلَيَّ رُوحِي، وَعَافَانِي فِي جَسَدِي، وَأَذِنَ لِي بِذِكْرِهِ.',
      ),
      Dhikr(
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ.',
      ),
      Dhikr('اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.'),
    ],
  ),
  AdhkarCategory(
    id: 'after_prayer',
    title: 'أذكار بعد الصلاة',
    subtitle: 'ما يُقال عقب الصلوات المكتوبة',
    icon: Icons.mosque_rounded,
    color: Color(0xFF16A085),
    items: [
      Dhikr('أَسْتَغْفِرُ اللَّهَ.', count: 3),
      Dhikr(
        'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.',
      ),
      Dhikr(
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.',
      ),
      Dhikr('اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.'),
      Dhikr(
        'سُبْحَانَ اللَّهِ (33) — الْحَمْدُ لِلَّهِ (33) — اللَّهُ أَكْبَرُ (33) — لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        virtue: 'غُفرت خطاياه وإن كانت مثل زبد البحر',
      ),
      Dhikr('آية الكرسي.'),
      Dhikr('المعوذات (الإخلاص والفلق والناس).', count: 3),
    ],
  ),
  AdhkarCategory(
    id: 'home',
    title: 'أذكار المنزل',
    subtitle: 'الدخول والخروج والسفر',
    icon: Icons.home_rounded,
    color: Color(0xFF8E44AD),
    items: [
      Dhikr(
        'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى رَبِّنَا تَوَكَّلْنَا. (عند الدخول)',
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلَجِ وَخَيْرَ الْمَخْرَجِ، بِسْمِ اللَّهِ وَلَجْنَا وَبِسْمِ اللَّهِ خَرَجْنَا وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا.',
      ),
      Dhikr(
        'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ. (عند الخروج)',
        virtue: 'يقال له: هُديتَ وكُفيتَ ووُقيتَ',
      ),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ أَنْ أَضِلَّ أَوْ أُضَلَّ، أَوْ أَزِلَّ أَوْ أُزَلَّ، أَوْ أَظْلِمَ أَوْ أُظْلَمَ، أَوْ أَجْهَلَ أَوْ يُجْهَلَ عَلَيَّ.',
      ),
    ],
  ),
  AdhkarCategory(
    id: 'food',
    title: 'أذكار الطعام',
    subtitle: 'قبل الطعام وبعده',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFD35400),
    items: [
      Dhikr('بِسْمِ اللَّهِ. (قبل الطعام)'),
      Dhikr('بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ. (إذا نسي في أوله)'),
      Dhikr(
        'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ. (بعد الطعام)',
      ),
      Dhikr(
        'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَ وَسَقَى، وَسَوَّغَهُ وَجَعَلَ لَهُ مَخْرَجًا.',
      ),
      Dhikr('اللَّهُمَّ بَارِكْ لَنَا فِيهِ، وَأَطْعِمْنَا خَيْرًا مِنْهُ.'),
    ],
  ),
  AdhkarCategory(
    id: 'general',
    title: 'أذكار عامة',
    subtitle: 'كنوز الذكر اليومي',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFC0392B),
    items: [
      Dhikr(
        'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ.',
        virtue: 'كنز من كنوز الجنة',
      ),
      Dhikr(
        'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ.',
        virtue: 'كلمتان خفيفتان على اللسان، ثقيلتان في الميزان',
      ),
      Dhikr('لَا إِلَهَ إِلَّا اللَّهُ.', virtue: 'أفضل الذكر'),
      Dhikr('الْحَمْدُ لِلَّهِ.', virtue: 'تملأ الميزان'),
      Dhikr(
        'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ.',
        virtue: 'الباقيات الصالحات',
      ),
      Dhikr(
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        count: 10,
      ),
      Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', count: 100),
      Dhikr('أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ.'),
      Dhikr('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', count: 10),
      Dhikr('يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ.'),
      Dhikr(
        'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى.',
      ),
      Dhikr(
        'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.',
      ),
    ],
  ),
];

// ============================================================================
// هـ. محرك إدارة الحالة
// ============================================================================

class AppRepository extends ChangeNotifier {
  final ApiService _api;
  SharedPreferences? _prefs;

  Country _country = kCountries.first;
  City _city = kCountries.first.cities.first;
  ThemeMode _themeMode = ThemeMode.system;

  PrayerTimes? _todayTimes;
  PrayerTimes? _tomorrowTimes;
  List<int>? _hijri;
  double _qibla = 0;

  bool _loading = true;
  String _nextPrayerName = '';
  DateTime? _nextPrayerTime;
  Duration _untilNext = Duration.zero;

  Timer? _timer;

  AppRepository({ApiService? api}) : _api = api ?? ApiService();

  Country get country => _country;
  City get city => _city;
  ThemeMode get themeMode => _themeMode;
  PrayerTimes? get todayTimes => _todayTimes;
  List<int>? get hijri => _hijri;
  double get qibla => _qibla;
  bool get loading => _loading;
  String get nextPrayerName => _nextPrayerName;
  DateTime? get nextPrayerTime => _nextPrayerTime;
  Duration get untilNext => _untilNext;

  String get hijriFormatted {
    final h = _hijri;
    if (h == null) return '';
    final m = h[1].clamp(1, 12);
    return '${h[2]} ${HijriDate.months[m - 1]} ${h[0]} هـ';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final cName = _prefs!.getString('country');
    final cityName = _prefs!.getString('city');
    final themeStr = _prefs!.getString('theme');

    if (cName != null) {
      final c = kCountries.firstWhere(
        (x) => x.name == cName,
        orElse: () => kCountries.first,
      );
      _country = c;
      _city = c.cities.firstWhere(
        (x) => x.name == cityName,
        orElse: () => c.cities.first,
      );
    }
    if (themeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (x) => x.name == themeStr,
        orElse: () => ThemeMode.system,
      );
    }

    await _refresh();
    _startTimer();
  }

  Future<void> _refresh() async {
    _loading = true;
    notifyListeners();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    _todayTimes = PrayerCalculator.calculate(
      date: today,
      lat: _city.lat,
      lng: _city.lng,
      tzOffset: _country.tzOffset,
    );
    _tomorrowTimes = PrayerCalculator.calculate(
      date: tomorrow,
      lat: _city.lat,
      lng: _city.lng,
      tzOffset: _country.tzOffset,
    );

    _hijri = HijriDate.fromGregorian(now);
    _qibla = QiblaCalculator.direction(_city.lat, _city.lng);

    try {
      final remote = await _api.fetchHijri(now);
      if (remote != null) {
        _hijri = remote;
      }
    } catch (_) {}

    _updateCountdown();
    _loading = false;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
      notifyListeners();
    });
  }

  void _updateCountdown() {
    final pt = _todayTimes;
    if (pt == null) return;
    final now = DateTime.now();

    final prayers = <MapEntry<String, DateTime>>[
      MapEntry('الفجر', pt.fajr),
      MapEntry('الشروق', pt.sunrise),
      MapEntry('الظهر', pt.dhuhr),
      MapEntry('العصر', pt.asr),
      MapEntry('المغرب', pt.maghrib),
      MapEntry('العشاء', pt.isha),
    ];

    for (final p in prayers) {
      if (p.value.isAfter(now)) {
        _nextPrayerName = p.key;
        _nextPrayerTime = p.value;
        _untilNext = p.value.difference(now);
        return;
      }
    }
    final tpt = _tomorrowTimes;
    if (tpt != null) {
      _nextPrayerName = 'الفجر';
      _nextPrayerTime = tpt.fajr;
      _untilNext = tpt.fajr.difference(now);
    }
  }

  Future<void> refresh() => _refresh();

  Future<void> selectCountry(Country c) async {
    _country = c;
    _city = c.cities.first;
    await _prefs?.setString('country', c.name);
    await _prefs?.setString('city', _city.name);
    await _refresh();
  }

  Future<void> selectCity(City c) async {
    _city = c;
    await _prefs?.setString('city', c.name);
    await _refresh();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await _prefs?.setString('theme', m.name);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// و. نظام التصميم
// ============================================================================

class AppColors {
  static const Color primary = Color(0xFF0F5132);
  static const Color primaryDark = Color(0xFF083D24);
  static const Color accent = Color(0xFFD4AF37);
  static const Color accentSoft = Color(0xFFE8C766);
  static const Color cream = Color(0xFFFAF7F0);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121A17);
  static const Color cardDark = Color(0xFF1A2420);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        bodyMedium: TextStyle(color: AppColors.textDark, height: 1.6),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accentSoft,
      surface: AppColors.surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B1210),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(color: Colors.white, height: 1.6),
      ),
    );
  }
}

// ============================================================================
// ز. تطبيق الجذر
// ============================================================================

class AppScope extends InheritedNotifier<AppRepository> {
  const AppScope({
    super.key,
    required AppRepository notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope not found in widget tree');
    }
    return scope.notifier!;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const IslamicApp());
}

class IslamicApp extends StatefulWidget {
  const IslamicApp({super.key});

  @override
  State<IslamicApp> createState() => _IslamicAppState();
}

class _IslamicAppState extends State<IslamicApp> {
  late final AppRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AppRepository();
    _repo.init();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _repo,
      child: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          return MaterialApp(
            title: 'نور الإسلام',
            debugShowCheckedModeBanner: false,
            themeMode: _repo.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            locale: const Locale('ar'),
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const RootScreen(),
          );
        },
      ),
    );
  }
}

// ============================================================================
// ح. الشاشة الجذرية
// ============================================================================

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      AdhkarListScreen(),
      QiblaScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.access_time_rounded),
                selectedIcon: Icon(Icons.access_time_filled_rounded),
                label: 'المواقيت',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_rounded),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'الأذكار',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'القبلة',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ط. الشاشة الرئيسية
// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _formatTime(DateTime t) {
    final h24 = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h24 >= 12 ? 'م' : 'ص';
    int h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:$m $period';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h س ${m.toString().padLeft(2, '0')} د';
    if (m > 0) return '$m د ${s.toString().padLeft(2, '0')} ث';
    return '$s ث';
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pt = repo.todayTimes;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: repo.refresh,
          color: AppColors.accent,
          backgroundColor: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(repo, isDark),
              if (pt == null || repo.loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  ),
                )
              else ...[
                _buildCountdownCard(repo, isDark),
                _buildPrayersCard(repo, isDark, pt),
                _buildQuickActions(isDark),
                const SizedBox(height: 100),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppRepository repo, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.city.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${repo.country.flag}  ${repo.country.name}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'اليوم',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            repo.hijriFormatted.isEmpty
                ? 'التقويم الهجري'
                : repo.hijriFormatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _gregorianString(DateTime.now()),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _gregorianString(DateTime d) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    const days = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
    ];
    return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildCountdownCard(AppRepository repo, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.cardDark, AppColors.surfaceDark]
              : [Colors.white, AppColors.cream],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(
                        alpha: 0.15 + (_pulse.value * 0.15),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الصلاة القادمة',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      repo.nextPrayerName.isEmpty
                          ? '—'
                          : repo.nextPrayerName,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                repo.nextPrayerTime == null
                    ? '--:--'
                    : _formatTime(repo.nextPrayerTime!),
                style: TextStyle(
                  color: isDark ? AppColors.accent : AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: isDark ? 0.25 : 0.08,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 18,
                  color: isDark ? AppColors.accent : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'متبقٍ: ',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDuration(repo.untilNext),
                  style: TextStyle(
                    color: isDark ? AppColors.accent : AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayersCard(
    AppRepository repo,
    bool isDark,
    PrayerTimes pt,
  ) {
    final items = <MapEntry<String, DateTime>>[
      MapEntry('الفجر', pt.fajr),
      MapEntry('الشروق', pt.sunrise),
      MapEntry('الظهر', pt.dhuhr),
      MapEntry('العصر', pt.asr),
      MapEntry('المغرب', pt.maghrib),
      MapEntry('العشاء', pt.isha),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.mosque_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'مواقيت الصلاة اليوم',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ...items.map((e) {
            final isNext = repo.nextPrayerName == e.key;
            return _PrayerRow(
              name: e.key,
              time: _formatTime(e.value),
              isNext: isNext,
              isSunrise: e.key == 'الشروق',
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionChip(
              icon: Icons.menu_book_rounded,
              label: 'الأذكار',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionChip(
              icon: Icons.explore_rounded,
              label: 'القبلة',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionChip(
              icon: Icons.location_city_rounded,
              label: 'المدينة',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final String name;
  final String time;
  final bool isNext;
  final bool isSunrise;
  final bool isDark;

  const _PrayerRow({
    required this.name,
    required this.time,
    required this.isNext,
    required this.isSunrise,
    required this.isDark,
  });

  IconData _icon() {
    switch (name) {
      case 'الفجر':
        return Icons.wb_twilight_rounded;
      case 'الشروق':
        return Icons.wb_sunny_outlined;
      case 'الظهر':
        return Icons.wb_sunny_rounded;
      case 'العصر':
        return Icons.wb_cloudy_rounded;
      case 'المغرب':
        return Icons.wb_twilight_rounded;
      case 'العشاء':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = isNext ? AppColors.accent : AppColors.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext
            ? accent.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isNext
            ? Border.all(color: accent.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(), color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: 15,
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (isSunrise)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'غير مكتوبة',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (isSunrise) const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              color: isNext
                  ? accent
                  : (isDark ? Colors.white : AppColors.textDark),
              fontSize: 15,
              fontWeight: isNext ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ي. شاشة الأذكار
// ============================================================================

class AdhkarListScreen extends StatelessWidget {
  const AdhkarListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
                itemCount: kAdhkarCategories.length,
                itemBuilder: (context, i) {
                  final cat = kAdhkarCategories[i];
                  return _CategoryCard(category: cat, isDark: isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [AppColors.cardDark, AppColors.surfaceDark]
              : [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأذكار والأدعية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${kAdhkarCategories.length} أقسام • أذكار مأثورة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AdhkarCategory category;
  final bool isDark;

  const _CategoryCard({required this.category, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdhkarDetailScreen(category: category),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                category.color.withValues(alpha: isDark ? 0.35 : 0.12),
                category.color.withValues(alpha: isDark ? 0.15 : 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: category.color.withValues(
                alpha: isDark ? 0.5 : 0.25,
              ),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Text(
                  category.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  category.subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textMuted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 13,
                      color: category.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${category.items.length} ذكر',
                      style: TextStyle(
                        color: category.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ك. شاشة تفاصيل الأذكار
// ============================================================================

class AdhkarDetailScreen extends StatefulWidget {
  final AdhkarCategory category;
  const AdhkarDetailScreen({super.key, required this.category});

  @override
  State<AdhkarDetailScreen> createState() => _AdhkarDetailScreenState();
}

class _AdhkarDetailScreenState extends State<AdhkarDetailScreen> {
  late List<int> _counters;

  @override
  void initState() {
    super.initState();
    _counters = widget.category.items.map((e) => e.count).toList();
  }

  void _decrement(int index) {
    if (_counters[index] > 0) {
      setState(() => _counters[index]--);
      HapticFeedback.lightImpact();
    }
  }

  void _resetAll() {
    setState(() {
      _counters = widget.category.items.map((e) => e.count).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.category.title,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textDark,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.accent : AppColors.primary,
            ),
            onPressed: _resetAll,
            tooltip: 'إعادة العدّاد',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: widget.category.items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _buildIntro(isDark);
            }
            final idx = i - 1;
            return _DhikrCard(
              dhikr: widget.category.items[idx],
              remaining: _counters[idx],
              total: widget.category.items[idx].count,
              color: widget.category.color,
              isDark: isDark,
              index: idx + 1,
              onTap: () => _decrement(idx),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.category.color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.category.color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: widget.category.color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'اضغط على البطاقة لتصغير العدّاد',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  final Dhikr dhikr;
  final int remaining;
  final int total;
  final Color color;
  final bool isDark;
  final int index;
  final VoidCallback onTap;

  const _DhikrCard({
    required this.dhikr,
    required this.remaining,
    required this.total,
    required this.color,
    required this.isDark,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = remaining == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? color.withValues(alpha: 0.6)
              : AppColors.accent.withValues(alpha: 0.15),
          width: done ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$index',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (total > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: done ? 0.1 : 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              done
                                  ? Icons.check_circle_rounded
                                  : Icons.repeat_rounded,
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              done ? 'تمّ' : 'التكرار: $remaining / $total',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (done)
                      Icon(
                        Icons.verified_rounded,
                        color: color,
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  dhikr.text,
                  style: TextStyle(
                    color: done
                        ? (isDark ? Colors.white60 : AppColors.textMuted)
                        : (isDark ? Colors.white : AppColors.textDark),
                    fontSize: 15,
                    height: 1.9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                if (dhikr.virtue != null && dhikr.virtue!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dhikr.virtue!,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ل. شاشة القبلة
// ============================================================================

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qibla = repo.qibla;
    final cardinal = _cardinal(qibla);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'اتجاه القبلة',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${repo.city.name} • ${repo.country.name}',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isDark
                              ? [AppColors.cardDark, AppColors.surfaceDark]
                              : [Colors.white, AppColors.cream],
                        ),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    ..._buildTicks(),
                    Transform.rotate(
                      angle: qibla * math.pi / 180.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mosque_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Container(
                            width: 3,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.accent,
                                  AppColors.accent.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${qibla.toStringAsFixed(1)}°',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.accent
                              : AppColors.primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'من الشمال باتجاه $cardinal',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'وجّه أعلى هاتفك نحو الشمال، ثم أدره بمقدار الزاوية الموضحة لتحديد اتجاه القبلة بدقة.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textDark,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTicks() {
    final widgets = <Widget>[];
    for (int i = 0; i < 24; i++) {
      final isMajor = i % 6 == 0;
      widgets.add(
        Transform.rotate(
          angle: (i * 15) * math.pi / 180.0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: isMajor ? 3 : 1.5,
              height: isMajor ? 14 : 8,
              color: isMajor
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }
    const labels = ['ش', 'ق', 'ج', 'غ'];
    for (int i = 0; i < 4; i++) {
      final angle = i * 90.0;
      widgets.add(
        Transform.rotate(
          angle: angle * math.pi / 180.0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 34),
              child: Transform.rotate(
                angle: -angle * math.pi / 180.0,
                child: Text(
                  labels[i],
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  String _cardinal(double deg) {
    if (deg >= 337.5 || deg < 22.5) return 'الشمال';
    if (deg < 67.5) return 'الشمال الشرقي';
    if (deg < 112.5) return 'الشرق';
    if (deg < 157.5) return 'الجنوب الشرقي';
    if (deg < 202.5) return 'الجنوب';
    if (deg < 247.5) return 'الجنوب الغربي';
    if (deg < 292.5) return 'الغرب';
    return 'الشمال الغربي';
  }
}

// ============================================================================
// م. شاشة الإعدادات
// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('الموقع', isDark),
            _tile(
              icon: Icons.flag_rounded,
              title: 'الدولة',
              value: '${repo.country.flag} ${repo.country.name}',
              isDark: isDark,
              onTap: () => _showCountryPicker(context, repo),
            ),
            _tile(
              icon: Icons.location_city_rounded,
              title: 'المدينة',
              value: repo.city.name,
              isDark: isDark,
              onTap: () => _showCityPicker(context, repo),
            ),
            const SizedBox(height: 12),
            _sectionTitle('المظهر', isDark),
            _themeTile(repo, isDark),
            const SizedBox(height: 12),
            _sectionTitle('حول التطبيق', isDark),
            _infoCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeTile(AppRepository repo, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'وضع المظهر',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _themeOption(
                  repo,
                  ThemeMode.light,
                  Icons.light_mode_rounded,
                  'فاتح',
                  isDark,
                ),
                _themeOption(
                  repo,
                  ThemeMode.system,
                  Icons.brightness_auto_rounded,
                  'تلقائي',
                  isDark,
                ),
                _themeOption(
                  repo,
                  ThemeMode.dark,
                  Icons.dark_mode_rounded,
                  'داكن',
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    AppRepository repo,
    ThemeMode mode,
    IconData icon,
    String label,
    bool isDark,
  ) {
    final selected = repo.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => repo.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.accent : AppColors.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white70 : AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : AppColors.textMuted),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نور الإسلام',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الإصدار 1.0.0',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'تطبيق إسلامي شامل لمواقيت الصلاة بدقة فلكية، وأذكار مأثورة، وتحديد دقيق لاتجاه القبلة. يعمل بدون إنترنت ويعتمد على حسابات فلكية معتمدة.',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textMuted,
              fontSize: 12.5,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker(BuildContext context, AppRepository repo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _PickerSheet(
          title: 'اختر الدولة',
          items: kCountries.map((c) => '${c.flag}  ${c.name}').toList(),
          onSelect: (i) {
            repo.selectCountry(kCountries[i]);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showCityPicker(BuildContext context, AppRepository repo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _PickerSheet(
          title: 'اختر المدينة',
          items: repo.country.cities.map((c) => c.name).toList(),
          onSelect: (i) {
            repo.selectCity(repo.country.cities[i]);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final ValueChanged<int> onSelect;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.onSelect,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final TextEditingController _search = TextEditingController();
  late List<int> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.generate(widget.items.length, (i) => i);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {
      if (q.trim().isEmpty) {
        _filtered = List.generate(widget.items.length, (i) => i);
      } else {
        _filtered = List.generate(widget.items.length, (i) => i)
            .where((i) => widget.items[i].contains(q.trim()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.cream,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : AppColors.textMuted,
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.cardDark
                    : Colors.white.withValues(alpha: 0.8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: _filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'لا توجد نتائج مطابقة',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    itemBuilder: (context, idx) {
                      final originalIndex = _filtered[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelect(originalIndex),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.items[originalIndex],
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textDark,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_left_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
