const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

// 1. Generate 2048x2048 Master Square Splash
const html2048 = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Aref+Ruqaa:wght@400;700&family=Orbitron:wght@600;700;800;900&family=Alexandria:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background-color: #000000;
    width: 2048px;
    height: 2048px;
    overflow: hidden;
    display: flex;
    justify-content: center;
    align-items: center;
    font-family: 'Aref Ruqaa', 'Alexandria', serif;
    user-select: none;
  }
  .container {
    position: relative;
    width: 2048px;
    height: 2048px;
    background: #000000;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  /* Ambient glow behind logo */
  .glow {
    position: absolute;
    width: 1200px;
    height: 1200px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.06) 0%, rgba(255, 255, 255, 0.015) 50%, rgba(0, 0, 0, 0) 72%);
    pointer-events: none;
  }
  svg {
    position: absolute;
    top: 0;
    left: 0;
    width: 2048px;
    height: 2048px;
  }
</style>
</head>
<body>
  <div class="container">
    <div class="glow"></div>

    <svg viewBox="0 0 2048 2048" width="2048" height="2048">
      <defs>
        <!-- Concentric Dark Gradient for Emblem Interior -->
        <radialGradient id="emblemBg" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#121218" stop-opacity="0.95"/>
          <stop offset="65%" stop-color="#08080E" stop-opacity="0.98"/>
          <stop offset="100%" stop-color="#000000" stop-opacity="1"/>
        </radialGradient>

        <!-- Glow Effects -->
        <filter id="softGlow" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="8" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>

        <filter id="ringGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="4" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>
      </defs>

      <!-- Central Circular Card (R=410px, Diameter=820px) -->
      <circle cx="1024" cy="1024" r="410" fill="url(#emblemBg)" stroke="#20202C" stroke-width="2.5" />

      <!-- Primary Outer Crisp White Ring -->
      <circle cx="1024" cy="1024" r="396" fill="none" stroke="#FFFFFF" stroke-width="5.5" filter="url(#ringGlow)" />

      <!-- Secondary Dashed Inner Accent Ring -->
      <circle cx="1024" cy="1024" r="372" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-dasharray="14 10" opacity="0.45" />

      <!-- Inner Precision Framing Ring -->
      <circle cx="1024" cy="1024" r="352" fill="none" stroke="#FFFFFF" stroke-width="1" opacity="0.25" />

      <!-- Cardinal Symmetry Tick Marks (0°, 90°, 180°, 270°) -->
      <line x1="1024" y1="608" x2="1024" y2="632" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />
      <line x1="1024" y1="1416" x2="1024" y2="1440" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />
      <line x1="608" y1="1024" x2="632" y2="1024" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />
      <line x1="1416" y1="1024" x2="1440" y2="1024" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />

      <!-- Diagonal Secondary Micro Ticks (45°, 135°, 225°, 315°) -->
      <circle cx="744" cy="744" r="4.5" fill="#FFFFFF" opacity="0.75" />
      <circle cx="1304" cy="744" r="4.5" fill="#FFFFFF" opacity="0.75" />
      <circle cx="744" cy="1304" r="4.5" fill="#FFFFFF" opacity="0.75" />
      <circle cx="1304" cy="1304" r="4.5" fill="#FFFFFF" opacity="0.75" />

      <!-- Sleek Modern Controller / Joystick Emblem at Top of Circle (Centered X=1024, Y=780) -->
      <g transform="translate(1024, 785)">
        <!-- Gamepad Outline -->
        <path d="M -65 -26 C -78 -26 -90 -14 -86 10 C -83 30 -68 44 -52 44 C -40 44 -32 32 -22 22 C -13 12 13 12 22 22 C 32 32 40 44 52 44 C 68 44 83 30 86 10 C 90 -14 78 -26 65 -26 C 36 -26 22 -12 0 -12 C -22 -12 -36 -26 -65 -26 Z"
              fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linejoin="round" filter="url(#softGlow)" />

        <!-- D-Pad Left -->
        <path d="M -54 -10 L -54 10 M -64 0 L -44 0" stroke="#FFFFFF" stroke-width="4.5" stroke-linecap="round" />

        <!-- Action Buttons Right (PlaySpot Symbol) -->
        <circle cx="54" cy="-9" r="4" fill="#FFFFFF" />
        <circle cx="45" cy="0" r="4" fill="#FFFFFF" />
        <circle cx="63" cy="0" r="4" fill="#FFFFFF" />
        <circle cx="54" cy="9" r="4" fill="#FFFFFF" />

        <!-- Center Spot Pin / Location Target Symbol -->
        <circle cx="0" cy="2" r="7.5" fill="none" stroke="#FFFFFF" stroke-width="2.8" />
        <circle cx="0" cy="2" r="2.8" fill="#FFFFFF" />
      </g>

      <!-- Ruq'ah Calligraphic Decorative Nib Flourishes -->
      <g fill="#FFFFFF" opacity="0.85">
        <path d="M 1012 840 L 1038 830 L 1028 845 Z" />
        <path d="M 1045 838 L 1060 832 L 1055 842 Z" />
      </g>

      <!-- Arabic Title "بلاي سبوت" in Authentic Ruq'ah Calligraphy -->
      <text x="1024" y="1020"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Aref Ruqaa', serif"
            font-weight="700"
            font-size="140px"
            fill="#FFFFFF"
            letter-spacing="2px"
            filter="url(#softGlow)">بلاي سبوت</text>

      <!-- Modern Spaced English Typography "PLAYSPOT" -->
      <text x="1024" y="1170"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Orbitron', sans-serif"
            font-weight="800"
            font-size="36px"
            fill="#FFFFFF"
            letter-spacing="16px">PLAYSPOT</text>

      <!-- Arabic Subtext / Tagline Below the Circle -->
      <text x="1024" y="1510"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Aref Ruqaa', serif"
            font-weight="400"
            font-size="34px"
            fill="#E0E0E0"
            letter-spacing="6px"
            opacity="0.95">احجز • العب • افوز</text>

      <!-- Subtle Decorative Outer Horizontal Accent Line Below Tagline -->
      <line x1="874" y1="1560" x2="1174" y2="1560" stroke="#FFFFFF" stroke-width="1.5" opacity="0.3" stroke-linecap="round" />
      <circle cx="1024" cy="1560" r="3.5" fill="#FFFFFF" opacity="0.8" />
    </svg>
  </div>
</body>
</html>`;

fs.writeFileSync('D:/playspot_V2/splash_2048.html', html2048);

// 2. Mobile Portrait Viewport HTML (1242 x 2688 px - iPhone 19.5:9 standard)
const htmlPortrait = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Aref+Ruqaa:wght@400;700&family=Orbitron:wght@600;700;800;900&family=Alexandria:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background-color: #000000;
    width: 1242px;
    height: 2688px;
    overflow: hidden;
    display: flex;
    justify-content: center;
    align-items: center;
    font-family: 'Aref Ruqaa', 'Alexandria', serif;
    user-select: none;
  }
  .container {
    position: relative;
    width: 1242px;
    height: 2688px;
    background: #000000;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  .glow {
    position: absolute;
    width: 900px;
    height: 900px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.06) 0%, rgba(255, 255, 255, 0.015) 50%, rgba(0, 0, 0, 0) 72%);
    pointer-events: none;
  }
  svg {
    position: absolute;
    top: 0;
    left: 0;
    width: 1242px;
    height: 2688px;
  }
</style>
</head>
<body>
  <div class="container">
    <div class="glow"></div>

    <svg viewBox="0 0 1242 2688" width="1242" height="2688">
      <defs>
        <radialGradient id="emblemBgMob" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#121218" stop-opacity="0.95"/>
          <stop offset="65%" stop-color="#08080E" stop-opacity="0.98"/>
          <stop offset="100%" stop-color="#000000" stop-opacity="1"/>
        </radialGradient>

        <filter id="softGlowMob" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="6" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>

        <filter id="ringGlowMob" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3.5" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>
      </defs>

      <!-- Central Circular Emblem (Center X=621, Y=1344) -->
      <circle cx="621" cy="1344" r="320" fill="url(#emblemBgMob)" stroke="#20202C" stroke-width="2" />
      <circle cx="621" cy="1344" r="308" fill="none" stroke="#FFFFFF" stroke-width="4.5" filter="url(#ringGlowMob)" />
      <circle cx="621" cy="1344" r="288" fill="none" stroke="#FFFFFF" stroke-width="1.5" stroke-dasharray="12 8" opacity="0.45" />
      <circle cx="621" cy="1344" r="272" fill="none" stroke="#FFFFFF" stroke-width="1" opacity="0.25" />

      <!-- Ticks -->
      <line x1="621" y1="1020" x2="621" y2="1040" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />
      <line x1="621" y1="1648" x2="621" y2="1668" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />
      <line x1="297" y1="1344" x2="317" y2="1344" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />
      <line x1="925" y1="1344" x2="945" y2="1344" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />

      <!-- Controller Emblem -->
      <g transform="translate(621, 1155)">
        <path d="M -50 -20 C -60 -20 -70 -10 -67 8 C -64 24 -52 35 -40 35 C -30 35 -24 25 -17 17 C -10 9 10 9 17 17 C 24 25 30 35 40 35 C 52 35 64 24 67 8 C 70 -10 60 -20 50 -20 C 28 -20 17 -10 0 -10 C -17 -10 -28 -20 -50 -20 Z"
              fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linejoin="round" filter="url(#softGlowMob)" />

        <path d="M -42 -8 L -42 8 M -50 0 L -34 0" stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round" />

        <circle cx="42" cy="-7" r="3" fill="#FFFFFF" />
        <circle cx="35" cy="0" r="3" fill="#FFFFFF" />
        <circle cx="49" cy="0" r="3" fill="#FFFFFF" />
        <circle cx="42" cy="7" r="3" fill="#FFFFFF" />

        <circle cx="0" cy="2" r="6" fill="none" stroke="#FFFFFF" stroke-width="2.2" />
        <circle cx="0" cy="2" r="2.2" fill="#FFFFFF" />
      </g>

      <!-- Ruq'ah Arabic Calligraphy -->
      <text x="621" y="1340"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Aref Ruqaa', serif"
            font-weight="700"
            font-size="110px"
            fill="#FFFFFF"
            letter-spacing="2px"
            filter="url(#softGlowMob)">بلاي سبوت</text>

      <!-- English Typography -->
      <text x="621" y="1460"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Orbitron', sans-serif"
            font-weight="800"
            font-size="28px"
            fill="#FFFFFF"
            letter-spacing="14px">PLAYSPOT</text>

      <!-- Tagline -->
      <text x="621" y="1730"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Aref Ruqaa', serif"
            font-weight="400"
            font-size="28px"
            fill="#E0E0E0"
            letter-spacing="5px"
            opacity="0.95">احجز • العب • افوز</text>

      <!-- Line Accent -->
      <line x1="501" y1="1770" x2="741" y2="1770" stroke="#FFFFFF" stroke-width="1.2" opacity="0.3" stroke-linecap="round" />
      <circle cx="621" cy="1770" r="3" fill="#FFFFFF" opacity="0.8" />
    </svg>
  </div>
</body>
</html>`;

fs.writeFileSync('D:/playspot_V2/splash_portrait.html', htmlPortrait);

console.log("Rendering Master 2048x2048 PNG...");
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\assets\\images\\splash_master_2048.png" --window-size=2048,2048 "file:///D:/playspot_V2/splash_2048.html"`);

console.log("Rendering Mobile Portrait 1242x2688 PNG...");
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\assets\\images\\splash_mobile_portrait_1242x2688.png" --window-size=1242,2688 "file:///D:/playspot_V2/splash_portrait.html"`);

// Copy to target locations in project
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/android/app/src/main/res/drawable/splash_logo.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/assets/images/app_icon.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/android/app/src/main/res/playstore-icon.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png');

console.log("All splash screen and app icon assets generated successfully!");
