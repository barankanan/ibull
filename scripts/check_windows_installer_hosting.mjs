import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import process from 'node:process';

const cwd = process.cwd();
const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '..');
const installerPath = path.join(
  repoRoot,
  'local_print_bridge',
  'windows',
  'dist',
  'installer',
  'IbulPrintBridgeSetup.exe',
);

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function hasDownloads404Rewrite(hosting) {
  const rewrites = Array.isArray(hosting?.rewrites) ? hosting.rewrites : [];
  return rewrites.some(
    (entry) =>
      entry &&
      typeof entry === 'object' &&
      entry.source === '/downloads/**' &&
      entry.destination === '/downloads/__not_found__',
  );
}

function resolveConfig(arg) {
  const configPath = path.resolve(cwd, arg);
  if (!fs.existsSync(configPath)) {
    throw new Error(`Firebase config not found: ${configPath}`);
  }
  const json = loadJson(configPath);
  const hosting = json.hosting;
  if (!hosting || typeof hosting.public !== 'string' || hosting.public.trim() === '') {
    throw new Error(`Missing hosting.public in ${configPath}`);
  }
  const publicDir = path.resolve(path.dirname(configPath), hosting.public);
  const hostedInstallerPath = path.join(publicDir, 'downloads', 'IbulPrintBridgeSetup.exe');
  return {
    configPath,
    hosting,
    publicDir,
    hostedInstallerPath,
  };
}

const args = process.argv.slice(2);
const configArgs = args.length > 0 ? args : ['firebase.json'];

console.log(`Installer artifact: ${installerPath}`);
if (!fs.existsSync(installerPath)) {
  console.error('FAIL: Windows installer artifact is missing.');
  process.exit(1);
}

const installerStats = fs.statSync(installerPath);
console.log(`Installer size: ${installerStats.size} bytes`);

let failed = false;

for (const configArg of configArgs) {
  const resolved = resolveConfig(configArg);
  console.log('');
  console.log(`Config: ${resolved.configPath}`);
  console.log(`Public dir: ${resolved.publicDir}`);
  console.log(`Hosted installer path: ${resolved.hostedInstallerPath}`);

  if (!fs.existsSync(resolved.publicDir)) {
    console.error('FAIL: Hosting public directory does not exist.');
    failed = true;
    continue;
  }

  if (!fs.existsSync(resolved.hostedInstallerPath)) {
    if (hasDownloads404Rewrite(resolved.hosting)) {
      console.error(
        'FAIL: Hosted installer is missing. This deploy would 404 because /downloads/** is reserved and missing files are routed to /downloads/__not_found__.',
      );
    } else {
      console.error('FAIL: Hosted installer is missing from the Firebase public directory.');
    }
    failed = true;
    continue;
  }

  const hostedStats = fs.statSync(resolved.hostedInstallerPath);
  console.log(`Hosted installer size: ${hostedStats.size} bytes`);
  if (hostedStats.size !== installerStats.size) {
    console.error('FAIL: Hosted installer size does not match the built installer artifact.');
    failed = true;
  }
}

if (failed) {
  process.exit(1);
}

console.log('');
console.log('PASS: Windows installer artifact is staged in every checked Firebase Hosting public directory.');
