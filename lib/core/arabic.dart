import 'package:flutter/material.dart';

const _labels = <String, String>{
  "Settings": "الإعدادات",
  "Required PPE": "المعدات المطلوبة",
  "SITE CONFIGURATION": "متطلبات الموقع",
  "Only enabled items count toward compliance. Unsupported model classes remain unknown.":
      "يُحسب الالتزام للمعدات المفعلة فقط. تظهر المعدات غير المدعومة كغير مؤكدة.",
  "Detection confidence": "حساسية الكشف",
  "Minimum confidence": "الحد الأدنى للثقة",
  "Low-confidence results are excluded from detection and rules.":
      "خفض القيمة يزيد حساسية الكشف. القيمة المقترحة للمعالجة المحلية 40٪.",
  "Worker feedback": "تنبيه العامل",
  "Alert sounds": "أصوات التنبيهات",
  "Vibration": "الاهتزاز",
  "Notification permission": "السماح بالإشعارات",
  "Privacy & storage": "الخصوصية والتخزين",
  "Privacy information": "معلومات الخصوصية",
  "Save event snapshots": "حفظ لقطات الأحداث",
  "Store selected violation images locally on this device.":
      "حفظ صور المخالفات المختارة على هذا الجهاز فقط.",
  "Delete event history": "حذف سجل الأحداث",
  "Includes all saved snapshots": "يشمل جميع اللقطات المحفوظة",
  "Delete all event history?": "حذف جميع الأحداث؟",
  "Events and snapshots will be permanently removed from this device. Zones and settings will remain.":
      "ستحذف الأحداث والصور نهائيًا من الجهاز. ستبقى المناطق والإعدادات.",
  "Cancel": "إلغاء",
  "Delete": "حذف",
  "Your site. Your data.": "موقعك. بياناتك.",
  "Safety zones": "مناطق السلامة",
  "Define the boundaries. Know the risk.":
      "حدّد مناطق العمل وراقب الاقتراب من المخاطر.",
  "Add zone": "إضافة منطقة",
  "Add safety zone": "إضافة منطقة سلامة",
  "Saved zones": "المناطق المحفوظة",
  "Your site starts here": "ابدأ بتحديد موقعك",
  "Add a work area and a restricted area to enable zone monitoring.":
      "أضف منطقة عمل ومنطقة محظورة لتفعيل المراقبة.",
  "Start": "تشغيل",
  "Stop": "إيقاف",
  "Active monitoring": "المراقبة نشطة",
  "Location monitoring is off": "مراقبة الموقع متوقفة",
  "Edit zone": "تعديل المنطقة",
  "Delete zone": "حذف المنطقة",
  "Monitoring for this zone will stop. Recorded events remain.":
      "ستتوقف مراقبة هذه المنطقة. تبقى الأحداث المسجلة.",
  "Create safety zone": "إنشاء منطقة سلامة",
  "Edit safety zone": "تعديل منطقة السلامة",
  "Zone name": "اسم المنطقة",
  "Enter a zone name": "أدخل اسم المنطقة",
  "Zone type": "نوع المنطقة",
  "Green · Work zone": "أخضر · منطقة عمل",
  "Red · Restricted zone": "أحمر · منطقة محظورة",
  "Orange · High risk zone": "برتقالي · مخاطر مرتفعة",
  "Latitude": "خط العرض",
  "Longitude": "خط الطول",
  "Radius (meters)": "نصف القطر بالمتر",
  "Save zone": "حفظ المنطقة",
  "Tap the map to choose a zone center. Map tiles need internet.":
      "اضغط الخريطة لاختيار مركز المنطقة. عرض الخريطة يحتاج الإنترنت.",
  "GPS boundaries are approximate. Small 2–5 m warnings may be unreliable indoors.":
      "حدود GPS تقريبية. قد لا تكون تنبيهات المسافات الصغيرة دقيقة داخل المباني.",
  "Open device settings": "فتح إعدادات الجهاز",
  "All": "الكل",
  "PPE": "المعدات",
  "Zones": "المناطق",
  "Critical": "حرج",
  "Safety events": "أحداث السلامة",
  "A clear event log": "سجل الأحداث جاهز",
  "Recorded PPE checks and zone events will appear here.":
      "ستظهر نتائج فحوص المعدات وأحداث المناطق هنا.",
  "Event details": "تفاصيل الحدث",
  "Event type": "نوع الحدث",
  "Location": "الموقع",
  "Recorded": "وقت التسجيل",
  "Compliance": "الالتزام",
  "Zone": "المنطقة",
  "Deleted zone": "منطقة محذوفة",
  "Not associated": "غير مرتبط بمنطقة",
  "Not available": "غير متاح",
  "Safety snapshot": "لقطة الحدث",
  "No snapshot saved": "لا توجد لقطة محفوظة",
  "Snapshot no longer available": "اللقطة لم تعد متاحة",
  "Snapshots are optional and stored only on this device.":
      "حفظ اللقطات اختياري وتبقى على الجهاز.",
  "Exit camera": "إغلاق الكاميرا",
  "PPE SCANNER": "فحص معدات الوقاية",
  "SAFETY VISION": "رؤية السلامة",
  "GPS + COMPASS HUD": "توجيه الموقع والبوصلة",
  "LIVE": "مباشر",
  "READY": "جاهز",
  "Camera paused": "الكاميرا متوقفة",
  "Camera unavailable. A physical device is required.":
      "الكاميرا غير متاحة. يتطلب الفحص جهازًا حقيقيًا.",
  "Retry camera": "إعادة المحاولة",
  "Finish check": "إنهاء الفحص",
  "Start PPE check": "ابدأ الفحص المحلي",
  "PPE STATUS": "معدات العامل",
  "NOT ASSESSED": "لم يكتمل التقييم",
  "Select required PPE in Settings": "حدد المعدات المطلوبة من الإعدادات",
  "Keep one worker fully visible for at least 2 seconds":
      "أظهر عاملًا واحدًا كاملًا وثبّت الكاميرا لثانيتين",
  "PPE CHECK PASSED": "اكتمل الفحص · المعدات موجودة",
  "PPE CHECK FAILED · Verify missing items":
      "تحتاج مراجعة · تحقق من المعدات الناقصة",
  "Last check result · start a new check for another worker":
      "نتيجة الفحص الأخير · ابدأ فحصًا جديدًا لعامل آخر",
  "Position one worker fully in the frame":
      "اقترب وأظهر العامل كاملًا داخل الإطار",
  "Scan one worker at a time": "افحص عاملًا واحدًا في كل مرة",
  "Some required PPE is unsupported by this model":
      "بعض المعدات المطلوبة غير مدعومة",
  "Waiting for GPS signal": "بانتظار إشارة الموقع",
  "Waiting for location signal": "بانتظار تحديد الموقع",
  "Compass signal unavailable": "إشارة البوصلة غير متاحة",
  "Boundary position uncertain — verify surroundings":
      "حدود الموقع غير مؤكدة · تحقق من محيطك",
  "Add safety zones to activate the HUD": "أضف مناطق السلامة لتفعيل المؤشرات",
  "Compass unavailable\nDistances remain available below":
      "البوصلة غير متاحة\nالمسافات متاحة في الأسفل",
  "WORK AREA": "منطقة عمل",
  "RESTRICTED": "منطقة محظورة",
  "HIGH RISK": "مخاطر مرتفعة",
  "INSIDE": "داخل المنطقة",
  "NEAREST HAZARD": "أقرب خطر",
  "No hazard distance available": "لا توجد مسافة خطر متاحة",
  "CRITICAL · RESTRICTED AREA ENTERED": "خطر حرج · دخلت منطقة محظورة",
  "DO NOT ENTER": "لا تدخل",
  "WARNING · RESTRICTED ZONE AHEAD": "تحذير · منطقة محظورة أمامك",
  "Approximate camera markers · not spatial anchors":
      "المؤشرات الاتجاهية تقريبية حسب GPS والبوصلة",
  "Helmet": "الخوذة",
  "Hardhat": "الخوذة",
  "Safety Vest": "سترة السلامة",
  "Gloves": "القفازات",
  "Safety Glasses": "نظارات السلامة",
  "Goggles": "نظارات السلامة",
  "Mask": "الكمامة",
  "Person": "عامل",
  "Fall-Detected": "اشتباه سقوط",
  "No_Harness": "حزام أمان غير ظاهر",
  "safe": "آمن",
  "SAFE": "آمن",
  "Safe": "آمن",
  "warning": "تحذير",
  "WARNING": "تحذير",
  "Warning": "تحذير",
  "critical": "حرج",
  "CRITICAL": "حرج",
  "high": "مرتفع",
  "HIGH": "مرتفع",
  "info": "معلومة",
  "INFO": "معلومة",
  "detected": "موجود",
  "DETECTED": "موجود",
  "missing": "غير ظاهر",
  "MISSING": "غير ظاهر",
  "unknown": "غير مؤكد",
  "UNKNOWN": "غير مؤكد",
  "work": "عمل",
  "restricted": "محظورة",
  "highRisk": "مخاطر مرتفعة",
  "Awaiting safety measurements": "بانتظار أول قياس للسلامة",
  "GPS boundary uncertain": "حدود الموقع غير مؤكدة",
  "Inside high risk area": "داخل منطقة مخاطر مرتفعة",
  "Outside work area": "خارج منطقة العمل",
  "Restricted area entered": "دخول منطقة محظورة",
  "Restricted zone ahead": "منطقة محظورة أمامك",
  "Work zone entered": "دخول منطقة عمل",
  "High risk zone entered": "دخول منطقة مخاطر مرتفعة",
  "Outside saved zones": "خارج المناطق المحفوظة",
  "Location signal unavailable": "إشارة الموقع غير متاحة",
  "PPE check passed": "نجاح فحص المعدات",
  "PPE check failed": "فحص المعدات يحتاج مراجعة",
  "Notifications unavailable; in-app alerts remain active.":
      "الإشعارات غير متاحة؛ تنبيهات التطبيق تعمل.",
  "Notification permission unavailable.": "صلاحية الإشعارات غير متاحة.",
  "Could not save a zone event. Check device storage.":
      "تعذر حفظ حدث المنطقة. تحقق من مساحة الجهاز.",
  "Event saved without a snapshot.": "تم حفظ الحدث دون صورة.",
  "Event saved; device feedback unavailable.":
      "حُفظ الحدث؛ الصوت والاهتزاز غير متاحين.",
  "Snapshot could not be saved.": "تعذر حفظ اللقطة.",
  "ppe_scan": "فحص معدات",
  "ppe_violation": "مخالفة معدات",
  "zone_breach": "اختراق منطقة",
  "zone_entry": "دخول منطقة",
  "zone_proximity": "اقتراب من منطقة",
  "zone_exit": "خروج من منطقة",
};
String ar(String value) {
  if (_labels.containsKey(value)) return _labels[value]!;
  var result = value;
  for (final e
      in _labels.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length))) {
    if (e.key.length > 4) result = result.replaceAll(e.key, e.value);
  }
  result = result
      .replaceAll(' Missing', ' غير ظاهر')
      .replaceAll(' missing', ' غير ظاهر');
  result = result
      .replaceAll('NO-', 'غير ظاهر: ')
      .replaceAll('NO ', 'غير ظاهر: ');
  result = result
      .replaceAll('Inside ', 'داخل ')
      .replaceAll('Entered ', 'دخول ')
      .replaceAll(' m', ' م');
  return result;
}

class ArabicText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  const ArabicText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });
  @override
  Widget build(BuildContext context) => Text(
    ar(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
  );
}
