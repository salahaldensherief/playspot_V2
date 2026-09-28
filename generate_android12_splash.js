const fs = require('fs');
const { execSync } = require('child_process');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const rawLogoPath = 'D:/playspot_V2/assets/images/Firefly.png';

// 1. Copy full Firefly logo for splash_logo.png
fs.copyFileSync(rawLogoPath, 'D:/playspot_V2/assets/images/splash_logo.png');

// 2. Generate larger Firefly logo for Android 12 circle mask (width: 80% of canvas)
const htmlAndroid12 = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background-color: #0A0A0F;
    width: 2048px;
    height: 2048px;
    overflow: hidden;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  img {
    width: 80%;
    height: auto;
    object-fit: contain;
  }
</style>
</head>
<body>
  <img src="file:///${rawLogoPath}" />
</body>
</html>`;

fs.writeFileSync('D:/playspot_V2/android12_splash.html', htmlAndroid12);

console.log('Rendering splash_logo_android12.png from Firefly.png (80% size)...');
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\assets\\images\\splash_logo_android12.png" --window-size=2048,2048 "file:///D:/playspot_V2/android12_splash.html"`);
fs.copyFileSync('D:/playspot_V2/assets/images/splash_logo_android12.png', 'D:/playspot_V2/assets/images/firefly_android12.png');

console.log('Running flutter_native_splash to regenerate native splash drawables...');
execSync(`E:\\flutter\\bin\\flutter.bat pub run flutter_native_splash:create`);

console.log('Successfully updated Android native splash with larger Firefly logo!');
