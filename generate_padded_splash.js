const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const rawImgPath = 'D:/playspot_V2/assets/images/app_icon_raw.png';
if (!fs.existsSync(rawImgPath)) {
  fs.copyFileSync('D:/playspot_V2/assets/images/app_icon.png', rawImgPath);
}

// Create HTML template with 70% image width (giving 15% safe margin on left and right)
const htmlPadded = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background-color: #000000;
    width: 2048px;
    height: 2048px;
    display: flex;
    justify-content: center;
    align-items: center;
    overflow: hidden;
  }
  img {
    width: 68%;
    height: auto;
    object-fit: contain;
  }
</style>
</head>
<body>
  <img src="file:///${rawImgPath}" />
</body>
</html>`;

fs.writeFileSync('D:/playspot_V2/native_splash.html', htmlPadded);

console.log('Rendering padded native splash logo...');
execSync(`"${chromePath}" --headless --screenshot="D:\\playspot_V2\\android\\app\\src\\main\\res\\drawable\\splash_logo.png" --window-size=2048,2048 "file:///D:/playspot_V2/native_splash.html"`);

// Copy to all density folders
const src = 'D:/playspot_V2/android/app/src/main/res/drawable/splash_logo.png';
const dirs = [
  'android/app/src/main/res/drawable-nodpi',
  'android/app/src/main/res/drawable-xxxhdpi',
  'android/app/src/main/res/drawable-xxhdpi',
  'android/app/src/main/res/drawable-xhdpi',
  'android/app/src/main/res/drawable-hdpi',
  'android/app/src/main/res/drawable-mdpi'
];

dirs.forEach(d => {
  const targetDir = path.join('D:/playspot_V2', d);
  if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });
  fs.copyFileSync(src, path.join(targetDir, 'splash_logo.png'));
});

console.log('Successfully updated native splash logo with horizontal safe margins!');
