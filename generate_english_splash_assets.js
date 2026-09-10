const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const outputDirs = [
  'D:/playspot_V2/assets/images',
  'D:/playspot_V2/android/app/src/main/res/drawable',
  'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset'
];

outputDirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// 1. HTML Template for 2048x2048 Master Square Minimalist English Splash
const html2048 = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@600;700;800;900&family=Montserrat:wght@400;600;700;800&family=Rajdhani:wght@500;600;700&display=swap" rel="stylesheet">
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
    font-family: 'Orbitron', 'Montserrat', sans-serif;
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
  /* Ultra-subtle ambient glow */
  .glow {
    position: absolute;
    width: 1200px;
    height: 1200px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.05) 0%, rgba(255, 255, 255, 0.012) 48%, rgba(0, 0, 0, 0) 70%);
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
        <radialGradient id="cardGrad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#121218" stop-opacity="0.95"/>
          <stop offset="65%" stop-color="#08080D" stop-opacity="0.98"/>
          <stop offset="100%" stop-color="#000000" stop-opacity="1"/>
        </radialGradient>

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
      <circle cx="1024" cy="1024" r="410" fill="url(#cardGrad)" stroke="#1A1A24" stroke-width="2" />

      <!-- Outer Precision Crisp White Ring -->
      <circle cx="1024" cy="1024" r="396" fill="none" stroke="#FFFFFF" stroke-width="5" filter="url(#ringGlow)" />

      <!-- Secondary Inner Dashed Ring -->
      <circle cx="1024" cy="1024" r="372" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-dasharray="14 10" opacity="0.45" />

      <!-- Inner Precision Framing Ring -->
      <circle cx="1024" cy="1024" r="350" fill="none" stroke="#FFFFFF" stroke-width="1" opacity="0.2" />

      <!-- Cardinal Symmetry Ticks (0°, 90°, 180°, 270°) -->
      <line x1="1024" y1="608" x2="1024" y2="632" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />
      <line x1="1024" y1="1416" x2="1024" y2="1440" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />
      <line x1="608" y1="1024" x2="632" y2="1024" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />
      <line x1="1416" y1="1024" x2="1440" y2="1024" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" />

      <!-- Diagonal Symmetry Dots -->
      <circle cx="744" cy="744" r="4.5" fill="#FFFFFF" opacity="0.75" />
      <circle cx="1304" cy="744" r="4.5" fill="#FFFFFF" opacity="0.75" />
      <circle cx="744" cy="1304" r="4.5" fill="#FFFFFF" opacity="0.75" />
      <circle cx="1304" cy="1304" r="4.5" fill="#FFFFFF" opacity="0.75" />

      <!-- Sleek Minimalist Controller / Joystick Emblem (Centered X=1024, Y=820) -->
      <g transform="translate(1024, 825)">
        <!-- Gamepad Line Art Outline -->
        <path d="M -75 -28 C -90 -28 -105 -15 -100 12 C -96 34 -78 50 -58 50 C -44 50 -35 36 -25 24 C -15 13 15 13 25 24 C 35 36 44 50 58 50 C 78 50 96 34 100 12 C 105 -15 90 -28 75 -28 C 42 -28 26 -14 0 -14 C -26 -14 -42 -28 -75 -28 Z"
              fill="none" stroke="#FFFFFF" stroke-width="5.5" stroke-linejoin="round" filter="url(#softGlow)" />

        <!-- Left D-Pad -->
        <path d="M -62 -12 L -62 12 M -74 0 L -50 0" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />

        <!-- Right Action Buttons (Play/Spot geometry) -->
        <circle cx="62" cy="-10" r="4.5" fill="#FFFFFF" />
        <circle cx="52" cy="0" r="4.5" fill="#FFFFFF" />
        <circle cx="72" cy="0" r="4.5" fill="#FFFFFF" />
        <circle cx="62" cy="10" r="4.5" fill="#FFFFFF" />

        <!-- Central Spot Pin / Target Symbol -->
        <circle cx="0" cy="2" r="9" fill="none" stroke="#FFFFFF" stroke-width="3" />
        <circle cx="0" cy="2" r="3.2" fill="#FFFFFF" />
      </g>

      <!-- Main Brand Name "PLAYSPOT" in Sleek Modern English Typography -->
      <text x="1034" y="1070"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Orbitron', sans-serif"
            font-weight="900"
            font-size="68px"
            fill="#FFFFFF"
            letter-spacing="22px"
            filter="url(#softGlow)">PLAYSPOT</text>

      <!-- Subtext Tagline "GAMING & LOUNGES" -->
      <text x="1030" y="1155"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Rajdhani', sans-serif"
            font-weight="700"
            font-size="28px"
            fill="#D0D0D0"
            letter-spacing="14px"
            opacity="0.9">BOOK • PLAY • WIN</text>

      <!-- Outer Accent Divider Line below Circle -->
      <line x1="864" y1="1510" x2="1184" y2="1510" stroke="#FFFFFF" stroke-width="1.5" opacity="0.35" stroke-linecap="round" />
      <circle cx="1024" cy="1510" r="3.5" fill="#FFFFFF" opacity="0.8" />
    </svg>
  </div>
</body>
</html>`;

fs.writeFileSync('D:/playspot_V2/splash_english_2048.html', html2048);

// 2. Mobile Portrait 1242x2688 Template
const htmlPortrait = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@600;700;800;900&family=Montserrat:wght@400;600;700;800&family=Rajdhani:wght@500;600;700&display=swap" rel="stylesheet">
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
    font-family: 'Orbitron', 'Montserrat', sans-serif;
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
    background: radial-gradient(circle, rgba(255, 255, 255, 0.05) 0%, rgba(255, 255, 255, 0.012) 48%, rgba(0, 0, 0, 0) 70%);
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
        <radialGradient id="cardGradMob" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#121218" stop-opacity="0.95"/>
          <stop offset="65%" stop-color="#08080D" stop-opacity="0.98"/>
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

      <!-- Central Circular Card (Center X=621, Y=1344) -->
      <circle cx="621" cy="1344" r="320" fill="url(#cardGradMob)" stroke="#1A1A24" stroke-width="2" />
      <circle cx="621" cy="1344" r="308" fill="none" stroke="#FFFFFF" stroke-width="4.5" filter="url(#ringGlowMob)" />
      <circle cx="621" cy="1344" r="288" fill="none" stroke="#FFFFFF" stroke-width="1.5" stroke-dasharray="12 8" opacity="0.45" />
      <circle cx="621" cy="1344" r="270" fill="none" stroke="#FFFFFF" stroke-width="1" opacity="0.2" />

      <!-- Ticks -->
      <line x1="621" y1="1020" x2="621" y2="1040" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />
      <line x1="621" y1="1648" x2="621" y2="1668" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />
      <line x1="297" y1="1344" x2="317" y2="1344" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />
      <line x1="925" y1="1344" x2="945" y2="1344" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" />

      <!-- Emblem Icon -->
      <g transform="translate(621, 1190)">
        <path d="M -60 -22 C -72 -22 -84 -12 -80 10 C -77 27 -62 38 -46 38 C -35 38 -28 28 -20 19 C -12 10 12 10 20 19 C 28 28 35 38 46 38 C 62 38 77 27 80 10 C 84 -12 72 -22 60 -22 C 33 -22 20 -11 0 -11 C -20 -11 -33 -22 -60 -22 Z"
              fill="none" stroke="#FFFFFF" stroke-width="4.5" stroke-linejoin="round" filter="url(#softGlowMob)" />

        <path d="M -50 -9 L -50 9 M -59 0 L -41 0" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" />

        <circle cx="50" cy="-8" r="3.5" fill="#FFFFFF" />
        <circle cx="42" cy="0" r="3.5" fill="#FFFFFF" />
        <circle cx="58" cy="0" r="3.5" fill="#FFFFFF" />
        <circle cx="50" cy="8" r="3.5" fill="#FFFFFF" />

        <circle cx="0" cy="2" r="7" fill="none" stroke="#FFFFFF" stroke-width="2.5" />
        <circle cx="0" cy="2" r="2.5" fill="#FFFFFF" />
      </g>

      <!-- Modern English Title -->
      <text x="629" y="1380"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Orbitron', sans-serif"
            font-weight="900"
            font-size="52px"
            fill="#FFFFFF"
            letter-spacing="18px"
            filter="url(#softGlowMob)">PLAYSPOT</text>

      <!-- Subtext -->
      <text x="626" y="1448"
            text-anchor="middle"
            dominant-baseline="central"
            font-family="'Rajdhani', sans-serif"
            font-weight="700"
            font-size="22px"
            fill="#D0D0D0"
            letter-spacing="10px"
            opacity="0.9">BOOK • PLAY • WIN</text>

      <!-- Line Accent -->
      <line x1="491" y1="1720" x2="751" y2="1720" stroke="#FFFFFF" stroke-width="1.2" opacity="0.35" stroke-linecap="round" />
      <circle cx="621" cy="1720" r="3" fill="#FFFFFF" opacity="0.8" />
    </svg>
  </div>
</body>
</html>`;

fs.writeFileSync('D:/playspot_V2/splash_english_portrait.html', htmlPortrait);

console.log("Rendering Master Minimalist English 2048x2048 PNG...");
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\assets\\images\\splash_master_2048.png" --window-size=2048,2048 "file:///D:/playspot_V2/splash_english_2048.html"`);

console.log("Rendering Mobile Portrait 1242x2688 PNG...");
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\assets\\images\\splash_mobile_portrait_1242x2688.png" --window-size=1242,2688 "file:///D:/playspot_V2/splash_english_portrait.html"`);

// Copy to target locations in project
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/android/app/src/main/res/drawable/splash_logo.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png');
fs.copyFileSync('D:/playspot_V2/assets/images/splash_master_2048.png', 'D:/playspot_V2/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png');

console.log("Minimalist English Splash Assets generated successfully!");
