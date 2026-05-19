import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import process from 'node:process';

const cwd = process.cwd();
const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '..');
const installerPath = path.join(
  repoRoot,
  'build',
  'windows',
  'installer',
  'IbulSellerSetup.exe',
);
const sellerIssPath = path.join(repoRoot, 'windows', 'installer', 'IbulSellerSetup.iss');
const bridgeIssPath = path.join(
  repoRoot,
  'local_print_bridge',
  'windows',
  'installer',
  'IbulPrintBridgeSetup.iss',
);

function assertInstallerIssHiddenLaunch(issPath, label) {
  if (!fs.existsSync(issPath)) {
    throw new Error(`${label} ISS is missing: ${issPath}`);
  }
  const content = fs.readFileSync(issPath, 'utf8');
  const runSection = content.split('[Run]')[1]?.split(/\[/)[0] ?? '';
  if (!runSection.includes('IbulPrintBridge.exe')) {
    throw new Error(`${label} ISS must start IbulPrintBridge.exe directly in [Run].`);
  }
  if (!/powershell\.exe[\s\S]*runhidden/i.test(runSection)) {
    throw new Error(
      `${label} ISS must run installer health PowerShell with Flags: runhidden.`,
    );
  }
  if (!/WindowStyle Hidden/i.test(runSection)) {
    throw new Error(
      `${label} ISS must pass -WindowStyle Hidden to installer health PowerShell.`,
    );
  }
  const registrySection = content.split('[Registry]')[1]?.split(/\[/)[0] ?? '';
  if (/powershell\.exe|\.ps1/i.test(registrySection)) {
    throw new Error(
      `${label} ISS HKCU Run must point to IbulPrintBridge.exe, not PowerShell.`,
    );
  }
  console.log(`${label} ISS launch policy: OK (${path.basename(issPath)})`);
}
const stampPath = path.join(repoRoot, 'build', 'windows', 'seller_desktop_build_stamp.json');
const dartDefinePath = path.join(
  repoRoot,
  'build',
  'windows',
  'seller_desktop_dart_defines.json',
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
  const hostedInstallerPath = path.join(publicDir, 'downloads', 'IbulSellerSetup.exe');
  return {
    configPath,
    hosting,
    publicDir,
    hostedInstallerPath,
  };
}

function assertDartDefineFile() {
  if (!fs.existsSync(dartDefinePath)) {
    throw new Error(
      `Dart define file is missing (${dartDefinePath}). Run scripts/build_seller_desktop_windows.ps1 first.`,
    );
  }
  const parsed = loadJson(dartDefinePath);
  const url = typeof parsed.IBUL_SUPABASE_URL === 'string' ? parsed.IBUL_SUPABASE_URL.trim() : '';
  const anon =
    typeof parsed.IBUL_SUPABASE_ANON_KEY === 'string'
      ? parsed.IBUL_SUPABASE_ANON_KEY.trim()
      : '';
  if (!url || !anon) {
    throw new Error(
      'Dart define file is missing IBUL_SUPABASE_URL or IBUL_SUPABASE_ANON_KEY.',
    );
  }
  console.log(`Dart define file: ${dartDefinePath}`);
  console.log(`IBUL_SUPABASE_URL present: ${url.length > 0}`);
  console.log(`IBUL_SUPABASE_ANON_KEY present: ${anon.length > 0}`);
}

function assertBuildStamp(installerStats) {
  if (!fs.existsSync(stampPath)) {
    throw new Error(
      `Build stamp is missing (${stampPath}). A stale installer must not pass checks.`,
    );
  }
  const stamp = loadJson(stampPath);
  if (stamp.installerSize !== installerStats.size) {
    throw new Error(
      `Installer size (${installerStats.size}) does not match build stamp (${stamp.installerSize}). Rebuild required.`,
    );
  }
  const stampMtime = Date.parse(stamp.installerLastWriteUtc ?? '');
  if (!Number.isNaN(stampMtime) && installerStats.mtimeMs + 1000 < stampMtime) {
    throw new Error('Installer file is older than the latest successful build stamp.');
  }
  console.log(`Build stamp: ${stampPath}`);
  console.log(`Stamp builtAt: ${stamp.builtAt ?? '<missing>'}`);
}

const args = process.argv.slice(2);
const configArgs = args.length > 0 ? args : ['firebase.json'];

console.log(`Installer artifact: ${installerPath}`);
if (!fs.existsSync(installerPath)) {
  console.error('FAIL: Unified Windows installer artifact is missing.');
  console.error('Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\build_seller_desktop_windows.ps1');
  process.exit(1);
}

const installerStats = fs.statSync(installerPath);
console.log(`Installer size: ${installerStats.size} bytes`);

let failed = false;

try {
  assertDartDefineFile();
  assertBuildStamp(installerStats);
  assertInstallerIssHiddenLaunch(sellerIssPath, 'Seller');
  assertInstallerIssHiddenLaunch(bridgeIssPath, 'Bridge');
} catch (error) {
  console.error(`FAIL: ${error.message}`);
  failed = true;
}

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
console.log('PASS: Fresh IbulSellerSetup.exe is staged in every checked Firebase Hosting public directory.');
