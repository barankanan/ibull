import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '..');

const sourcePath =
  process.env.IBUL_WINDOWS_INSTALLER_SOURCE ||
  path.join(
    repoRoot,
    'local_print_bridge',
    'windows',
    'dist',
    'installer',
    'IbulPrintBridgeSetup.exe',
  );

const publicDir =
  process.env.IBUL_HOSTING_PUBLIC_DIR || path.join(repoRoot, 'build', 'web');

const downloadsDir = path.join(publicDir, 'downloads');
const destPath = path.join(downloadsDir, 'IbulPrintBridgeSetup.exe');

function sha256(filePath) {
  const hash = crypto.createHash('sha256');
  const data = fs.readFileSync(filePath);
  hash.update(data);
  return hash.digest('hex');
}

console.log(`Source installer: ${sourcePath}`);
if (!fs.existsSync(sourcePath)) {
  console.error('FAIL: Windows installer artifact is missing.');
  console.error('Expected:', sourcePath);
  process.exit(1);
}

const srcStats = fs.statSync(sourcePath);
console.log(`Source size: ${srcStats.size} bytes`);
if (srcStats.size < 1_000_000) {
  console.error('FAIL: Installer is unexpectedly small (< 1MB).');
  process.exit(1);
}

if (!fs.existsSync(downloadsDir)) {
  fs.mkdirSync(downloadsDir, { recursive: true });
}

fs.copyFileSync(sourcePath, destPath);
const destStats = fs.statSync(destPath);
if (destStats.size !== srcStats.size) {
  console.error('FAIL: Copied installer size mismatch.');
  process.exit(1);
}

console.log(`Staged installer: ${destPath}`);
console.log(`SHA256: ${sha256(destPath)}`);
console.log('PASS: Installer staged for Firebase Hosting.');

