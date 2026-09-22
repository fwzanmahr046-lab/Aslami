import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// 1) DATA MODELS
// =====================================================================

class PrayerTimeModel {
  final String key;
  final String arabicName;
  final DateTime time;
  final IconData icon;
  const PrayerTimeModel({
    required this.key,
    required this.arabicName,
    required this.time,
    required this.icon,
  });
}

class CityModel {
  final String ar;
  final String en;
  const CityModel(this.ar, this.en);
}

class CountryModel {
  final String nameAr;
  final String nameEn;
  final List<CityModel> cities;
  const CountryModel({
    required this.nameAr,
    required this.nameEn,
    required this.cities,
  });
}

class AdhkarItem {
  final String text;
  final String? count;
  final String? reference;
  const AdhkarItem({required this.text, this.count, this.reference});
}

class AdhkarCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<AdhkarItem> items;
  const AdhkarCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
  });
}

// =====================================================================
// 2) STATIC DATA (Countries + Adhkar)
// =====================================================================

class CountriesData {
  static const List<CountryModel> all = <CountryModel>[
    CountryModel(
      nameAr: 'السعودية',
      nameEn: 'Saudi Arabia',
      cities: <CityModel>[
        CityModel('مكة المكرمة', 'Makkah'),
        CityModel('المدينة المنورة', 'Medina'),
        CityModel('الرياض', 'Riyadh'),
        CityModel('جدة', 'Jeddah'),
        CityModel('الدمام', 'Dammam'),
        CityModel('الطائف', 'Taif'),
        CityModel('أبها', 'Abha'),
        CityModel('تبوك', 'Tabuk'),
      ],
    ),
    CountryModel(
      nameAr: 'مصر',
      nameEn: 'Egypt',
      cities: <CityModel>[
        CityModel('القاهرة', 'Cairo'),
        CityModel('الإسكندرية', 'Alexandria'),
        CityModel('الجيزة', 'Giza'),
        CityModel('الأقصر', 'Luxor'),
        CityModel('أسوان', 'Aswan'),
        CityModel('المنصورة', 'Mansoura'),
        CityModel('طنطا', 'Tanta'),
        CityModel('بورسعيد', 'Port Said'),
      ],
    ),
    CountryModel(
      nameAr: 'الإمارات',
      nameEn: 'United Arab Emirates',
      cities: <CityModel>[
        CityModel('أبوظبي', 'Abu Dhabi'),
        CityModel('دبي', 'Dubai'),
        CityModel('الشارقة', 'Sharjah'),
        CityModel('العين', 'Al Ain'),
        CityModel('رأس الخيمة', 'Ras Al Khaimah'),
        CityModel('الفجيرة', 'Fujairah'),
      ],
    ),
    CountryModel(
      nameAr: 'الكويت',
      nameEn: 'Kuwait',
      cities: <CityModel>[
        CityModel('مدينة الكويت', 'Kuwait City'),
        CityModel('الجهراء', 'Jahra'),
        CityModel('حولي', 'Hawalli'),
        CityModel('الفروانية', 'Farwaniya'),
        CityModel('الأحمدي', 'Ahmadi'),
      ],
    ),
    CountryModel(
      nameAr: 'قطر',
      nameEn: 'Qatar',
      cities: <CityModel>[
        CityModel('الدوحة', 'Doha'),
        CityModel('الوكرة', 'Al Wakrah'),
        CityModel('الخور', 'Al Khor'),
        CityModel('الريان', 'Al Rayyan'),
      ],
    ),
    CountryModel(
      nameAr: 'البحرين',
      nameEn: 'Bahrain',
      cities: <CityModel>[
        CityModel('المنامة', 'Manama'),
        CityModel('المحرق', 'Muharraq'),
        CityModel('الرفاع', 'Riffa'),
        CityModel('مدينة حمد', 'Hamad Town'),
      ],
    ),
    CountryModel(
      nameAr: 'عُمان',
      nameEn: 'Oman',
      cities: <CityModel>[
        CityModel('مسقط', 'Muscat'),
        CityModel('صلالة', 'Salalah'),
        CityModel('نزوى', 'Nizwa'),
        CityModel('صحار', 'Sohar'),
      ],
    ),
    CountryModel(
      nameAr: 'الأردن',
      nameEn: 'Jordan',
      cities: <CityModel>[
        CityModel('عمّان', 'Amman'),
        CityModel('إربد', 'Irbid'),
        CityModel('الزرقاء', 'Zarqa'),
        CityModel('العقبة', 'Aqaba'),
        CityModel('السلط', 'Salt'),
      ],
    ),
    CountryModel(
      nameAr: 'فلسطين',
      nameEn: 'Palestine',
      cities: <CityModel>[
        CityModel('القدس', 'Jerusalem'),
        CityModel('غزة', 'Gaza'),
        CityModel('رام الله', 'Ramallah'),
        CityModel('نابلس', 'Nablus'),
        CityModel('الخليل', 'Hebron'),
        CityModel('بيت لحم', 'Bethlehem'),
      ],
    ),
    CountryModel(
      nameAr: 'لبنان',
      nameEn: 'Lebanon',
      cities: <CityModel>[
        CityModel('بيروت', 'Beirut'),
        CityModel('طرابلس', 'Tripoli'),
        CityModel('صيدا', 'Sidon'),
        CityModel('صور', 'Tyre'),
        CityModel('زحلة', 'Zahle'),
      ],
    ),
    CountryModel(
      nameAr: 'سوريا',
      nameEn: 'Syria',
      cities: <CityModel>[
        CityModel('دمشق', 'Damascus'),
        CityModel('حلب', 'Aleppo'),
        CityModel('حمص', 'Homs'),
        CityModel('اللاذقية', 'Latakia'),
        CityModel('حماة', 'Hama'),
      ],
    ),
    CountryModel(
      nameAr: 'العراق',
      nameEn: 'Iraq',
      cities: <CityModel>[
        CityModel('بغداد', 'Baghdad'),
        CityModel('البصرة', 'Basra'),
        CityModel('الموصل', 'Mosul'),
        CityModel('أربيل', 'Erbil'),
        CityModel('النجف', 'Najaf'),
        CityModel('كربلاء', 'Karbala'),
      ],
    ),
    CountryModel(
      nameAr: 'اليمن',
      nameEn: 'Yemen',
      cities: <CityModel>[
        CityModel('صنعاء', 'Sanaa'),
        CityModel('عدن', 'Aden'),
        CityModel('تعز', 'Taiz'),
        CityModel('الحديدة', 'Hodeidah'),
        CityModel('إب', 'Ibb'),
      ],
    ),
    CountryModel(
      nameAr: 'السودان',
      nameEn: 'Sudan',
      cities: <CityModel>[
        CityModel('الخرطوم', 'Khartoum'),
        CityModel('أم درمان', 'Omdurman'),
        CityModel('بورتسودان', 'Port Sudan'),
        CityModel('كسلا', 'Kassala'),
      ],
    ),
    CountryModel(
      nameAr: 'ليبيا',
      nameEn: 'Libya',
      cities: <CityModel>[
        CityModel('طرابلس', 'Tripoli'),
        CityModel('بنغازي', 'Benghazi'),
        CityModel('مصراتة', 'Misrata'),
        CityModel('سبها', 'Sabha'),
      ],
    ),
    CountryModel(
      nameAr: 'تونس',
      nameEn: 'Tunisia',
      cities: <CityModel>[
        CityModel('تونس', 'Tunis'),
        CityModel('صفاقس', 'Sfax'),
        CityModel('سوسة', 'Sousse'),
        CityModel('القيروان', 'Kairouan'),
      ],
    ),
    CountryModel(
      nameAr: 'الجزائر',
      nameEn: 'Algeria',
      cities: <CityModel>[
        CityModel('الجزائر', 'Algiers'),
        CityModel('وهران', 'Oran'),
        CityModel('قسنطينة', 'Constantine'),
        CityModel('عنابة', 'Annaba'),
      ],
    ),
    CountryModel(
      nameAr: 'المغرب',
      nameEn: 'Morocco',
      cities: <CityModel>[
        CityModel('الرباط', 'Rabat'),
        CityModel('الدار البيضاء', 'Casablanca'),
        CityModel('مراكش', 'Marrakesh'),
        CityModel('فاس', 'Fes'),
        CityModel('طنجة', 'Tangier'),
        CityModel('أكادير', 'Agadir'),
      ],
    ),
    CountryModel(
      nameAr: 'موريتانيا',
      nameEn: 'Mauritania',
      cities: <CityModel>[
        CityModel('نواكشوط', 'Nouakchott'),
        CityModel('نواذيبو', 'Nouadhibou'),
      ],
    ),
    CountryModel(
      nameAr: 'الصومال',
      nameEn: 'Somalia',
      cities: <CityModel>[
        CityModel('مقديشو', 'Mogadishu'),
        CityModel('هرجيسا', 'Hargeisa'),
      ],
    ),
    CountryModel(
      nameAr: 'تركيا',
      nameEn: 'Turkey',
      cities: <CityModel>[
        CityModel('إستنبول', 'Istanbul'),
        CityModel('أنقرة', 'Ankara'),
        CityModel('إزمير', 'Izmir'),
        CityModel('بورصة', 'Bursa'),
      ],
    ),
    CountryModel(
      nameAr: 'باكستان',
      nameEn: 'Pakistan',
      cities: <CityModel>[
        CityModel('إسلام آباد', 'Islamabad'),
        CityModel('كراتشي', 'Karachi'),
        CityModel('لاهور', 'Lahore'),
        CityModel('بيشاور', 'Peshawar'),
      ],
    ),
    CountryModel(
      nameAr: 'الهند',
      nameEn: 'India',
      cities: <CityModel>[
        CityModel('نيودلهي', 'New Delhi'),
        CityModel('مومباي', 'Mumbai'),
        CityModel('حيدر آباد', 'Hyderabad'),
        CityModel('بنغالور', 'Bangalore'),
      ],
    ),
    CountryModel(
      nameAr: 'إندونيسيا',
      nameEn: 'Indonesia',
      cities: <CityModel>[
        CityModel('جاكرتا', 'Jakarta'),
        CityModel('سورابايا', 'Surabaya'),
        CityModel('باندونغ', 'Bandung'),
      ],
    ),
    CountryModel(
      nameAr: 'ماليزيا',
      nameEn: 'Malaysia',
      cities: <CityModel>[
        CityModel('كوالالمبور', 'Kuala Lumpur'),
        CityModel('بينانغ', 'Penang'),
      ],
    ),
    CountryModel(
      nameAr: 'أفغانستان',
      nameEn: 'Afghanistan',
      cities: <CityModel>[
        CityModel('كابول', 'Kabul'),
        CityModel('هرات', 'Herat'),
      ],
    ),
    CountryModel(
      nameAr: 'بنغلاديش',
      nameEn: 'Bangladesh',
      cities: <CityModel>[
        CityModel('دكا', 'Dhaka'),
        CityModel('شيتاغونغ', 'Chittagong'),
      ],
    ),
  ];
}

class AdhkarData {
  static const List<AdhkarCategory> categories = <AdhkarCategory>[
    AdhkarCategory(
      id: 'morning',
      title: 'أذكار الصباح',
      subtitle: 'تُقال بعد صلاة الفجر إلى الضحى',
      icon: Icons.wb_sunny_outlined,
      items: <AdhkarItem>[
        AdhkarItem(
          text:
              'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ. اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
          count: 'مرة واحدة',
          reference: 'آية الكرسي - البقرة 255',
        ),
        AdhkarItem(
          text:
              'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
          count: 'ثلاث مرات',
          reference: 'سورة الإخلاص',
        ),
        AdhkarItem(
          text:
              'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
          count: 'ثلاث مرات',
          reference: 'سورة الفلق',
        ),
        AdhkarItem(
          text:
              'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
          count: 'ثلاث مرات',
          reference: 'سورة الناس',
        ),
        AdhkarItem(
          text:
              'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ',
          count: 'مرة واحدة',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
          count: 'مرة واحدة',
          reference: 'رواه الترمذي',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
          count: 'مرة واحدة',
          reference: 'سيد الاستغفار - رواه البخاري',
        ),
        AdhkarItem(
          text:
              'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
          count: 'ثلاث مرات',
          reference: 'رواه أبو داود',
        ),
        AdhkarItem(
          text:
              'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ',
          count: 'ثلاث مرات',
          reference: 'رواه أبو داود والترمذي',
        ),
        AdhkarItem(
          text:
              'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
          count: 'سبع مرات',
          reference: 'رواه ابن السني',
        ),
        AdhkarItem(
          text:
              'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
          count: 'مائة مرة',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
          count: 'عشر مرات أو مائة مرة',
          reference: 'رواه البخاري',
        ),
      ],
    ),
    AdhkarCategory(
      id: 'evening',
      title: 'أذكار المساء',
      subtitle: 'تُقال بعد صلاة العصر إلى المغرب',
      icon: Icons.nights_stay_outlined,
      items: <AdhkarItem>[
        AdhkarItem(
          text:
              'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ. اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ...',
          count: 'مرة واحدة',
          reference: 'آية الكرسي',
        ),
        AdhkarItem(
          text:
              'قُلْ هُوَ اللَّهُ أَحَدٌ... (سورة الإخلاص)، والمعوذتين',
          count: 'ثلاث مرات',
          reference: 'رواه أبو داود والترمذي',
        ),
        AdhkarItem(
          text:
              'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا',
          count: 'مرة واحدة',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
          count: 'مرة واحدة',
          reference: 'رواه الترمذي',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ... (سيد الاستغفار)',
          count: 'مرة واحدة',
          reference: 'رواه البخاري',
        ),
        AdhkarItem(
          text:
              'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
          count: 'ثلاث مرات',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ',
          count: 'ثلاث مرات',
          reference: 'رواه أبو داود',
        ),
        AdhkarItem(
          text:
              'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
          count: 'مائة مرة',
          reference: 'رواه مسلم',
        ),
      ],
    ),
    AdhkarCategory(
      id: 'sleep',
      title: 'أذكار النوم',
      subtitle: 'تُقال عند الاستعداد للنوم',
      icon: Icons.bedtime_outlined,
      items: <AdhkarItem>[
        AdhkarItem(
          text: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
          count: 'مرة واحدة',
          reference: 'رواه البخاري',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
          count: 'ثلاث مرات',
          reference: 'رواه أبو داود',
        ),
        AdhkarItem(
          text:
              'سُبْحَانَ اللَّهِ (٣٣) وَالْحَمْدُ لِلَّهِ (٣٣) وَاللَّهُ أَكْبَرُ (٣٤)',
          count: 'عند النوم',
          reference: 'رواه البخاري ومسلم',
        ),
        AdhkarItem(
          text:
              'آية الكرسي (اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...)',
          count: 'مرة واحدة',
          reference: 'رواه البخاري',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ',
          count: 'مرة واحدة',
          reference: 'رواه البخاري ومسلم',
        ),
      ],
    ),
    AdhkarCategory(
      id: 'wake',
      title: 'أذكار الاستيقاظ',
      subtitle: 'تُقال عند الاستيقاظ من النوم',
      icon: Icons.wb_twilight_outlined,
      items: <AdhkarItem>[
        AdhkarItem(
          text:
              'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
          count: 'مرة واحدة',
          reference: 'رواه البخاري',
        ),
        AdhkarItem(
          text:
              'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ',
          count: 'مرة واحدة',
          reference: 'رواه البخاري',
        ),
      ],
    ),
    AdhkarCategory(
      id: 'after_prayer',
      title: 'أذكار بعد الصلاة',
      subtitle: 'تُقال بعد السلام من الصلاة المفروضة',
      icon: Icons.mosque_outlined,
      items: <AdhkarItem>[
        AdhkarItem(
          text: 'أَسْتَغْفِرُ اللَّهَ',
          count: 'ثلاث مرات',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
          count: 'مرة واحدة',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
          count: 'مرة واحدة',
          reference: 'رواه أبو داود',
        ),
        AdhkarItem(
          text:
              'سُبْحَانَ اللَّهِ (٣٣) وَالْحَمْدُ لِلَّهِ (٣٣) وَاللَّهُ أَكْبَرُ (٣٣) ثُمَّ: لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
          count: 'بعد كل صلاة',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text: 'آيَةُ الْكُرْسِيِّ',
          count: 'بعد كل صلاة',
          reference: 'رواه النسائي',
        ),
      ],
    ),
    AdhkarCategory(
      id: 'general',
      title: 'أذكار عامة',
      subtitle: 'أذكار متنوعة تُقال في أي وقت',
      icon: Icons.auto_awesome_outlined,
      items: <AdhkarItem>[
        AdhkarItem(
          text:
              'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
          count: 'مائة مرة',
          reference: 'رواه البخاري ومسلم',
        ),
        AdhkarItem(
          text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
          count: 'كثيراً',
          reference: 'رواه البخاري ومسلم',
        ),
        AdhkarItem(
          text:
              'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
          count: 'كثيراً',
          reference: 'كنز من كنوز الجنة',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
          count: 'كثيراً',
          reference: 'رواه مسلم',
        ),
        AdhkarItem(
          text:
              'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
          count: 'مائة مرة يومياً',
          reference: 'رواه البخاري',
        ),
        AdhkarItem(
          text:
              'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَأَعُوذُ بِكَ مِنَ النَّارِ',
          count: 'ثلاث مرات',
          reference: 'رواه أبو داود',
        ),
      ],
    ),
  ];
}

// =====================================================================
// 3) SERVICES
// =====================================================================

class PrayerTimesService {
  Future<Map<String, dynamic>> fetch({
    required String cityEn,
    required String countryEn,
    required DateTime date,
  }) async {
    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
      'city': cityEn,
      'country': countryEn,
      'method': '4',
      'date': '${date.day.toString().padLeft(2, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.year}',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('فشل الاتصال بالخدمة (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['code'] != 200) {
      throw Exception('لم يتم العثور على بيانات لهذه المدينة');
    }
    return decoded['data'] as Map<String, dynamic>;
  }
}

class StorageService {
  static const _kTheme = 'theme_mode';
  static const _kCountryAr = 'country_ar';
  static const _kCountryEn = 'country_en';
  static const _kCityAr = 'city_ar';
  static const _kCityEn = 'city_en';

  Future<Map<String, String>> loadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, String>{
      'countryAr': prefs.getString(_kCountryAr) ?? 'السعودية',
      'countryEn': prefs.getString(_kCountryEn) ?? 'Saudi Arabia',
      'cityAr': prefs.getString(_kCityAr) ?? 'مكة المكرمة',
      'cityEn': prefs.getString(_kCityEn) ?? 'Makkah',
    };
  }

  Future<void> saveLocation({
    required String countryAr,
    required String countryEn,
    required String cityAr,
    required String cityEn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCountryAr, countryAr);
    await prefs.setString(_kCountryEn, countryEn);
    await prefs.setString(_kCityAr, cityAr);
    await prefs.setString(_kCityEn, cityEn);
  }

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTheme) ?? false;
  }

  Future<void> saveDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTheme, dark);
  }
}

// =====================================================================
// 4) REPOSITORY (ChangeNotifier)
// =====================================================================

class AppRepository extends ChangeNotifier {
  final PrayerTimesService _prayerService = PrayerTimesService();
  final StorageService _storage = StorageService();

  bool initialized = false;
  bool loading = false;
  String? error;

  ThemeMode themeMode = ThemeMode.light;

  String countryAr = 'السعودية';
  String countryEn = 'Saudi Arabia';
  String cityAr = 'مكة المكرمة';
  String cityEn = 'Makkah';

  Map<String, DateTime>? todayTimes;
  String hijriDate = '';
  DateTime? lastUpdated;

  List<AdhkarCategory> get adhkarCategories => AdhkarData.categories;

  Future<void> init() async {
    final loc = await _storage.loadLocation();
    countryAr = loc['countryAr']!;
    countryEn = loc['countryEn']!;
    cityAr = loc['cityAr']!;
    cityEn = loc['cityEn']!;

    final dark = await _storage.loadDarkMode();
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    initialized = true;
    notifyListeners();

    await loadPrayerTimes();
  }

  Future<void> loadPrayerTimes() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _prayerService.fetch(
        cityEn: cityEn,
        countryEn: countryEn,
        date: DateTime.now(),
      );
      final timings = data['timings'] as Map<String, dynamic>;
      final parsed = _parseTimings(timings);

      // Hijri date
      final dateData = data['date'] as Map<String, dynamic>?;
      if (dateData != null) {
        final hijri = dateData['hijri'] as Map<String, dynamic>?;
        if (hijri != null) {
          final day = hijri['day']?.toString() ?? '';
          final year = hijri['year']?.toString() ?? '';
          final month = (hijri['month'] as Map<String, dynamic>?)?['ar']
                  ?.toString() ??
              '';
          hijriDate = '$day $month $year هـ';
        }
      }

      todayTimes = parsed;
      lastUpdated = DateTime.now();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Map<String, DateTime> _parseTimings(Map<String, dynamic> t) {
    final now = DateTime.now();
    DateTime parse(String s) {
      final clean = s.split(' ').first;
      final parts = clean.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateTime(now.year, now.month, now.day, h, m);
    }

    return <String, DateTime>{
      'Fajr': parse(t['Fajr'].toString()),
      'Sunrise': parse(t['Sunrise'].toString()),
      'Dhuhr': parse(t['Dhuhr'].toString()),
      'Asr': parse(t['Asr'].toString()),
      'Maghrib': parse(t['Maghrib'].toString()),
      'Isha': parse(t['Isha'].toString()),
    };
  }

  List<PrayerTimeModel> get prayersList {
    if (todayTimes == null) return <PrayerTimeModel>[];
    final t = todayTimes!;
    return <PrayerTimeModel>[
      PrayerTimeModel(
          key: 'Fajr',
          arabicName: 'الفجر',
          time: t['Fajr']!,
          icon: Icons.nightlight_round),
      PrayerTimeModel(
          key: 'Sunrise',
          arabicName: 'الشروق',
          time: t['Sunrise']!,
          icon: Icons.wb_twilight),
      PrayerTimeModel(
          key: 'Dhuhr',
          arabicName: 'الظهر',
          time: t['Dhuhr']!,
          icon: Icons.wb_sunny),
      PrayerTimeModel(
          key: 'Asr',
          arabicName: 'العصر',
          time: t['Asr']!,
          icon: Icons.wb_sunny_outlined),
      PrayerTimeModel(
          key: 'Maghrib',
          arabicName: 'المغرب',
          time: t['Maghrib']!,
          icon: Icons.wb_twilight_outlined),
      PrayerTimeModel(
          key: 'Isha',
          arabicName: 'العشاء',
          time: t['Isha']!,
          icon: Icons.nights_stay),
    ];
  }

  PrayerTimeModel? get nextPrayer {
    final list = prayersList;
    if (list.isEmpty) return null;
    final now = DateTime.now();
    for (final p in list) {
      if (p.time.isAfter(now)) return p;
    }
    return null;
  }

  Duration? get timeUntilNextPrayer {
    final next = nextPrayer;
    if (next == null) return null;
    return next.time.difference(DateTime.now());
  }

  Future<void> updateLocation({
    required String newCountryAr,
    required String newCountryEn,
    required String newCityAr,
    required String newCityEn,
  }) async {
    countryAr = newCountryAr;
    countryEn = newCountryEn;
    cityAr = newCityAr;
    cityEn = newCityEn;
    notifyListeners();

    await _storage.saveLocation(
      countryAr: newCountryAr,
      countryEn: newCountryEn,
      cityAr: newCityAr,
      cityEn: newCityEn,
    );
    await loadPrayerTimes();
  }

  Future<void> toggleTheme(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _storage.saveDarkMode(dark);
  }
}

// =====================================================================
// 5) APP SCOPE (InheritedNotifier)
// =====================================================================

class AppScope extends InheritedNotifier<AppRepository> {
  const AppScope({
    super.key,
    required AppRepository repo,
    required super.child,
  }) : super(notifier: repo);

  static AppRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope غير موجود في شجرة الواجهات');
    return scope!.notifier!;
  }
}

// =====================================================================
// 6) THEME
// =====================================================================

class AppTheme {
  static const Color primaryGreen = Color(0xFF0E5A3C);
  static const Color darkGreen = Color(0xFF083D28);
  static const Color accentGold = Color(0xFFC9A227);
  static const Color creamBg = Color(0xFFF6F7F3);
  static const Color darkBg = Color(0xFF0F1A14);
  static const Color darkSurface = Color(0xFF16241C);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryGreen,
      secondary: accentGold,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: creamBg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primaryGreen.withOpacity(0.14),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF7FD3A9),
      secondary: accentGold,
      surface: darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0xFF7FD3A9).withOpacity(0.18),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// =====================================================================
// 7) APP ROOT
// =====================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
      repo: _repo,
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
            home: const RootShell(),
          );
        },
      ),
    );
  }
}

// =====================================================================
// 8) ROOT SHELL (Bottom Navigation)
// =====================================================================

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const <Widget>[
            HomeTab(),
            PrayerTimesTab(),
            AdhkarTab(),
            SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'المواقيت',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'الأذكار',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 9) HOME TAB
// =====================================================================

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatGregorian(DateTime d) {
    const months = <String>[
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const days = <String>[
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    int h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'م' : 'ص';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $period';
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final now = DateTime.now();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: repo.loadPrayerTimes,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _HomeHeader(
              cityAr: repo.cityAr,
              countryAr: repo.countryAr,
              hijri: repo.hijriDate,
              gregorian: _formatGregorian(now),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _NextPrayerCard(
                repo: repo,
                isDark: isDark,
                formatTime: _formatTime,
                formatCountdown: _formatCountdown,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'مواقيت اليوم',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverToBoxAdapter(
              child: _PrayerTimesGrid(repo: repo, formatTime: _formatTime),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'أذكار مختارة',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _QuickAdhkarRow(repo: repo),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String cityAr;
  final String countryAr;
  final String hijri;
  final String gregorian;

  const _HomeHeader({
    required this.cityAr,
    required this.countryAr,
    required this.hijri,
    required this.gregorian,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            AppTheme.darkGreen,
            AppTheme.primaryGreen,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mosque,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'نور الإسلام',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تطبيقك اليومي للصلاة والذكر',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cityAr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              gregorian,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hijri.isEmpty ? 'التقويم الهجري' : hijri,
              style: const TextStyle(
                color: AppTheme.accentGold,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              countryAr,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  final AppRepository repo;
  final bool isDark;
  final String Function(DateTime) formatTime;
  final String Function(Duration) formatCountdown;

  const _NextPrayerCard({
    required this.repo,
    required this.isDark,
    required this.formatTime,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context) {
    if (repo.loading && repo.todayTimes == null) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              SizedBox(height: 14),
              Text('جارٍ تحميل المواقيت...'),
            ],
          ),
        ),
      );
    }

    if (repo.error != null && repo.todayTimes == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              repo.error ?? 'حدث خطأ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: repo.loadPrayerTimes,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    final next = repo.nextPrayer;
    final remaining = repo.timeUntilNextPrayer;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            AppTheme.primaryGreen,
            AppTheme.darkGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.access_time_filled,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                next != null ? 'الصلاة القادمة' : 'انتهت صلوات اليوم',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (next != null) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(next.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        next.arabicName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTime(next.time),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'الوقت المتبقي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    remaining == null ? '--:--:--' : formatCountdown(remaining),
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Text(
              'تابع صلاتك القادمة غداً بإذن الله',
              style: TextStyle(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _PrayerTimesGrid extends StatelessWidget {
  final AppRepository repo;
  final String Function(DateTime) formatTime;

  const _PrayerTimesGrid({required this.repo, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final list = repo.prayersList;
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    final next = repo.nextPrayer;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.65,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final isNext = next != null && next.key == p.key;
        return _PrayerCell(
          prayer: p,
          isNext: isNext,
          formatTime: formatTime,
        );
      },
    );
  }
}

class _PrayerCell extends StatelessWidget {
  final PrayerTimeModel prayer;
  final bool isNext;
  final String Function(DateTime) formatTime;

  const _PrayerCell({
    required this.prayer,
    required this.isNext,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isNext
        ? AppTheme.primaryGreen
        : (isDark ? AppTheme.darkSurface : Colors.white);
    final fg = isNext ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: isNext
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
              ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                prayer.icon,
                color: isNext ? Colors.white : AppTheme.accentGold,
                size: 20,
              ),
              const Spacer(),
              if (isNext)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'القادمة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                prayer.arabicName,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatTime(prayer.time),
                style: TextStyle(
                  color: isNext ? Colors.white : theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAdhkarRow extends StatelessWidget {
  final AppRepository repo;

  const _QuickAdhkarRow({required this.repo});

  @override
  Widget build(BuildContext context) {
    final categories = repo.adhkarCategories.take(4).toList();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdhkarDetailScreen(category: cat),
                ),
              );
            },
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      cat.icon,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  Text(
                    cat.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${cat.items.length} ذكر',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =====================================================================
// 10) PRAYER TIMES TAB
// =====================================================================

class PrayerTimesTab extends StatelessWidget {
  const PrayerTimesTab({super.key});

  String _formatTime(DateTime d) {
    int h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'م' : 'ص';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final theme = Theme.of(context);
    final list = repo.prayersList;
    final next = repo.nextPrayer;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            title: const Text('مواقيت الصلاة'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: <Color>[
                      AppTheme.darkGreen,
                      AppTheme.primaryGreen,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${repo.cityAr}، ${repo.countryAr}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        repo.hijriDate.isEmpty
                            ? 'التقويم الهجري'
                            : repo.hijriDate,
                        style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _LocationSelectorCard(repo: repo),
            ),
          ),
          if (repo.loading && list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else if (repo.error != null && list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.cloud_off,
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      repo.error ?? 'خطأ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: repo.loadPrayerTimes,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = list[index];
                  final isNext = next != null && next.key == p.key;
                  return _PrayerRow(
                    prayer: p,
                    isNext: isNext,
                    timeStr: _formatTime(p.time),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Text(
                repo.lastUpdated == null
                    ? ''
                    : 'آخر تحديث: ${_formatTime(repo.lastUpdated!)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSelectorCard extends StatelessWidget {
  final AppRepository repo;

  const _LocationSelectorCard({required this.repo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const LocationPickerScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_city,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'الموقع الحالي',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${repo.cityAr}، ${repo.countryAr}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final PrayerTimeModel prayer;
  final bool isNext;
  final String timeStr;

  const _PrayerRow({
    required this.prayer,
    required this.isNext,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isNext
            ? AppTheme.primaryGreen
            : (isDark ? AppTheme.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: isNext
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
              ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNext
                  ? Colors.white.withOpacity(0.18)
                  : AppTheme.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              prayer.icon,
              color: isNext ? Colors.white : AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  prayer.arabicName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isNext ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                if (isNext)
                  const Text(
                    'الصلاة القادمة',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isNext
                  ? AppTheme.accentGold
                  : theme.colorScheme.onSurface,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 11) ADHKAR TAB
// =====================================================================

class AdhkarTab extends StatelessWidget {
  const AdhkarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final theme = Theme.of(context);
    final categories = repo.adhkarCategories;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            title: const Text('الأذكار'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: <Color>[
                      AppTheme.darkGreen,
                      AppTheme.primaryGreen,
                    ],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 90, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'حصّن يومك بالذكر',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'أذكار الصباح والمساء والنوم وغيرها',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _AdhkarCategoryCard(category: cat);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Text(
                '﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdhkarCategoryCard extends StatelessWidget {
  final AdhkarCategory category;

  const _AdhkarCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdhkarDetailScreen(category: category),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    AppTheme.primaryGreen,
                    AppTheme.darkGreen,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(category.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${category.items.length} ذكر',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 12) ADHKAR DETAIL SCREEN
// =====================================================================

class AdhkarDetailScreen extends StatefulWidget {
  final AdhkarCategory category;

  const AdhkarDetailScreen({super.key, required this.category});

  @override
  State<AdhkarDetailScreen> createState() => _AdhkarDetailScreenState();
}

class _AdhkarDetailScreenState extends State<AdhkarDetailScreen> {
  final List<int> _counts = <int>[];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.category.items.length; i++) {
      _counts.add(0);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _increment(int index) {
    setState(() {
      _counts[index] = _counts[index] + 1;
    });
    HapticFeedback.lightImpact();
  }

  void _resetAll() {
    setState(() {
      for (int i = 0; i < _counts.length; i++) {
        _counts[i] = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.category.items;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[
                    AppTheme.darkGreen,
                    AppTheme.primaryGreen,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.category.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _resetAll,
                        icon: const Icon(
                          Icons.restart_alt,
                          color: AppTheme.accentGold,
                          size: 18,
                        ),
                        label: const Text(
                          'تصفير',
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.category.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (item.count != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.count!,
                                  style: const TextStyle(
                                    color: AppTheme.accentGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.text,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.9,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        if (item.reference != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            item.reference!,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.55),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _increment(index),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('تسبيح'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryGreen,
                                  side: const BorderSide(
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_counts[index]}',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 13) SETTINGS TAB
// =====================================================================

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  AppTheme.darkGreen,
                  AppTheme.primaryGreen,
                ],
              ),
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mosque,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'نور الإسلام',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الإصدار 1.0.0',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'المظهر'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'الوضع الداكن',
            subtitle: 'تفعيل المظهر الداكن للتطبيق',
            trailing: Switch(
              value: repo.themeMode == ThemeMode.dark,
              activeColor: AppTheme.primaryGreen,
              onChanged: (v) => repo.toggleTheme(v),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'الموقع'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.location_city,
            title: 'المدينة الحالية',
            subtitle: '${repo.cityAr}، ${repo.countryAr}',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LocationPickerScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.refresh,
            title: 'تحديث المواقيت',
            subtitle: 'إعادة تحميل مواقيت الصلاة',
            onTap: repo.loadPrayerTimes,
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'حول التطبيق'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'عن التطبيق',
            subtitle: 'تطبيق إسلامي شامل للمواقيت والأذكار',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'نور الإسلام',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.mosque,
                  color: AppTheme.primaryGreen,
                  size: 40,
                ),
                children: const <Widget>[
                  Text(
                    'تطبيق إسلامي متكامل يوفر مواقيت الصلاة الدقيقة '
                    'لمختلف الدول والمدن، وقسم شامل للأذكار النبوية '
                    'الصحيحة، مع واجهة أنيقة ودعم للمظهر الفاتح والداكن.',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'صُنع بحب لخدمة المسلمين',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.accentGold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!
            else if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 14) LOCATION PICKER SCREEN
// =====================================================================

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryModel> get _filtered {
    if (_query.isEmpty) return CountriesData.all;
    final q = _query;
    final result = <CountryModel>[];
    for (final country in CountriesData.all) {
      final matchingCities = country.cities
          .where((c) =>
              c.ar.contains(q) || c.en.toLowerCase().contains(q.toLowerCase()))
          .toList();
      if (country.nameAr.contains(q) ||
          country.nameEn.toLowerCase().contains(q.toLowerCase()) ||
          matchingCities.isNotEmpty) {
        result.add(CountryModel(
          nameAr: country.nameAr,
          nameEn: country.nameEn,
          cities: matchingCities.isEmpty ? country.cities : matchingCities,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final countries = _filtered;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('اختر الموقع'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن دولة أو مدينة...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: countries.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد نتائج مطابقة',
                        style: TextStyle(fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        return _CountryExpansionTile(
                          country: country,
                          onCitySelected: (city) async {
                            await repo.updateLocation(
                              newCountryAr: country.nameAr,
                              newCountryEn: country.nameEn,
                              newCityAr: city.ar,
                              newCityEn: city.en,
                            );
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryExpansionTile extends StatelessWidget {
  final CountryModel country;
  final ValueChanged<CityModel> onCitySelected;

  const _CountryExpansionTile({
    required this.country,
    required this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: AppTheme.primaryGreen,
              size: 18,
            ),
          ),
          title: Text(
            country.nameAr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${country.cities.length} مدينة',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          children: country.cities.map((city) {
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onCitySelected(city),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        city.ar,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      city.en,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
