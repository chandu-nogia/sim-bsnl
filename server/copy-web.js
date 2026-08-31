'use strict';

const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', 'build', 'web');
const dest = path.join(__dirname, '..', 'cf-assets');

function copyDir(from, to) {
  fs.mkdirSync(to, { recursive: true });
  for (const name of fs.readdirSync(from)) {
    const a = path.join(from, name);
    const b = path.join(to, name);
    if (fs.statSync(a).isDirectory()) copyDir(a, b);
    else fs.copyFileSync(a, b);
  }
}

if (fs.existsSync(path.join(src, 'index.html'))) {
  fs.rmSync(dest, { recursive: true, force: true });
  copyDir(src, dest);
  console.log('Copied Flutter build → cf-assets/');
} else {
  console.log('No Flutter build yet — cf-assets stub page deploy hogi. Run: flutter build web --release');
}
