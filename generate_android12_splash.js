const fs = require('fs');
const { execSync } = require('child_process');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const rawLogoPath = 'D:/playspot_V2/assets/6_extracted/apple-devices/AppIcon.appiconset/icon-ios-1024x1024.png';

// 1. Copy full 1024x1024 raw logo for iOS (full width)
fs.copyFileSync(rawLogoPath, 'D:/playspot_V2/assets/images/splash_logo.png');

// 2. Generate padded logo for Android 12 circle mask (width: 52% of canvas)
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
    width: 52%;
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

console.log('Rendering splash_logo_android12.png...');
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\assets\\images\\splash_logo_android12.png" --window-size=2048,2048 "file:///D:/playspot_V2/android12_splash.html"`);

console.log('Generated splash_logo.png for iOS and splash_logo_android12.png for Android 12!');
