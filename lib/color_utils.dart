import 'dart:math';

class HSL {
  final double h; // 0..360
  final double s; // 0..1
  final double l; // 0..1

  HSL({required this.h, required this.s, required this.l});
}

HSL rgbToHsl(double r, double g, double b) {
  final maxv = max(r, max(g, b));
  final minv = min(r, min(g, b));
  
  double h = 0;
  final l = (maxv + minv) / 2;
  double s = 0;

  if (maxv == minv) {
    h = 0;
    s = 0;
  } else {
    final d = maxv - minv;
    s = l > 0.5 ? d / (2 - maxv - minv) : d / (maxv + minv);
    
    if (maxv == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (maxv == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6;
  }
  
  return HSL(h: h * 360, s: s, l: l);
}

bool isNeutral(double r, double g, double b) {
  const tol = 0.08;
  
  if ((r - 1).abs() < tol && (g - 1).abs() < tol && (b - 1).abs() < tol) {
    return true;
  }
  
  if (r.abs() < tol && g.abs() < tol && b.abs() < tol) {
    return true;
  }
  
  if ((r - g).abs() < tol && (r - b).abs() < tol && (g - b).abs() < tol) {
    return true;
  }
  
  return false;
}

bool isVibrant(HSL hsl) {
  return hsl.s > 0.5 && hsl.l > 0.3 && hsl.l < 0.8;
}

bool isPastel(HSL hsl) {
  return hsl.s < 0.5 && hsl.l > 0.7;
}

bool isDark(HSL hsl) {
  return hsl.l < 0.3;
}

bool isLight(HSL hsl) {
  return hsl.l > 0.7;
}

enum ColorHarmony {
  complementary,
  analogous,
  triadic,
  splitComplementary,
  tetradic,
  monochromatic,
}

ColorHarmony? detectHarmony(double hue1, double hue2) {
  final dh = min((hue1 - hue2).abs(), 360 - (hue1 - hue2).abs());
  
  if (dh < 15) return ColorHarmony.monochromatic;
  if (dh > 165 && dh < 195) return ColorHarmony.complementary;
  if (dh < 45) return ColorHarmony.analogous;
  if (dh > 105 && dh < 135) return ColorHarmony.triadic;
  
  return null; // Pas d'harmonie claire
}

bool isWarm(double hue) {
  // Warm = [315..360) U [0..180)
  return hue >= 315 || hue < 180;
}

double colorPairScore({
  required (double, double, double) c1,
  required (double, double, double) c2,
  required double p1,
  required double p2,
}) {
  final hsl1 = rgbToHsl(c1.$1, c1.$2, c1.$3);
  final hsl2 = rgbToHsl(c2.$1, c2.$2, c2.$3);
  
  final dh = min((hsl1.h - hsl2.h).abs(), 360 - (hsl1.h - hsl2.h).abs());
  final ds = (hsl1.s - hsl2.s).abs();
  final dl = (hsl1.l - hsl2.l).abs();
  
  final vibrant1 = isVibrant(hsl1);
  final vibrant2 = isVibrant(hsl2);
  final pastel1 = isPastel(hsl1);
  final pastel2 = isPastel(hsl2);
  final dark1 = isDark(hsl1);
  final dark2 = isDark(hsl2);
  final light1 = isLight(hsl1);
  final light2 = isLight(hsl2);
  
  final harmony = detectHarmony(hsl1.h, hsl2.h);
  
  double score = 0.0;
  
  final isRed1 = (hsl1.h < 15 || hsl1.h > 345) && hsl1.s > 0.4;
  final isGreen1 = (hsl1.h > 90 && hsl1.h < 150) && hsl1.s > 0.4;
  final isRed2 = (hsl2.h < 15 || hsl2.h > 345) && hsl2.s > 0.4;
  final isGreen2 = (hsl2.h > 90 && hsl2.h < 150) && hsl2.s > 0.4;
  
  if ((isRed1 && isGreen2) || (isGreen1 && isRed2)) {
    score += 80;
  }
  
  final isOrange1 = (hsl1.h > 15 && hsl1.h < 45) && hsl1.s > 0.6;
  final isPurple1 = (hsl1.h > 270 && hsl1.h < 315) && hsl1.s > 0.5;
  final isOrange2 = (hsl2.h > 15 && hsl2.h < 45) && hsl2.s > 0.6;
  final isPurple2 = (hsl2.h > 270 && hsl2.h < 315) && hsl2.s > 0.5;
  
  if ((isOrange1 && isPurple2) || (isPurple1 && isOrange2)) {
    score += 70;
  }
  
  if (harmony == ColorHarmony.complementary) {
    score -= 30;
  } else if (harmony == ColorHarmony.analogous) {
    score -= 25;
  } else if (harmony == ColorHarmony.triadic) {
    score -= 20;
  } else if (harmony == ColorHarmony.monochromatic) {
    score -= 35;
  }
  
  if (vibrant1 && vibrant2) {
    if (harmony == null) {
      score += 40;
    } else {
      score += 10;
    }
  }
  
  if (pastel1 && pastel2) {
    score -= 15;
  }
  
  if (dark1 && dark2) {
    score += 5;
  }
  
  if (light1 && light2) {
    score += 5;
  }
  
  if (dl > 0.4) {
    score -= 10;
  }
  
  final warm1 = isWarm(hsl1.h);
  final warm2 = isWarm(hsl2.h);
  if (warm1 != warm2 && harmony == null) {
    score += 15;
  }
  
  if (harmony == null) {
    if (dh > 45 && dh < 165) {
      score += dh * 0.3;
    }
  }
  
  if (ds > 0.5 && hsl1.s > 0.2 && hsl2.s > 0.2) {
    score += ds * 20;
  }
  
  final propFactor = sqrt((p1 + p2) / 2.0);
  
  if ((hsl1.l < 0.15 && hsl1.s < 0.1) || (hsl2.l < 0.15 && hsl2.s < 0.1)) {
    score -= 20;
  }
  
  if ((hsl1.l > 0.85 && hsl1.s < 0.1) || (hsl2.l > 0.85 && hsl2.s < 0.1)) {
    score -= 20;
  }
  
  if ((hsl1.h > 200 && hsl1.h < 240 && hsl1.s > 0.3 && hsl1.l > 0.3 && hsl1.l < 0.6) ||
      (hsl2.h > 200 && hsl2.h < 240 && hsl2.s > 0.3 && hsl2.l > 0.3 && hsl2.l < 0.6)) {
    score -= 15;
  }
  
  return max(0, score * propFactor);
}
