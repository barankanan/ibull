function Import-SellerDotEnv {
  param([string]$Path)
  if (!(Test-Path $Path)) {
    return
  }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) {
      return
    }
    $parts = $line.Split("=", 2)
    if ($parts.Length -ne 2) {
      return
    }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable($key))) {
      [System.Environment]::SetEnvironmentVariable($key, $value)
    }
  }
}

function Resolve-SellerReleaseConfigValue {
  param(
    [string]$Name,
    [string]$EnvFilePath
  )
  $fromEnv = [System.Environment]::GetEnvironmentVariable($Name)
  if (![string]::IsNullOrWhiteSpace($fromEnv)) {
    return $fromEnv.Trim()
  }
  Import-SellerDotEnv -Path $EnvFilePath
  $fromEnv = [System.Environment]::GetEnvironmentVariable($Name)
  if (![string]::IsNullOrWhiteSpace($fromEnv)) {
    return $fromEnv.Trim()
  }
  return $null
}

function Assert-SellerReleaseSupabaseConfig {
  param([string]$EnvFilePath)
  $missing = @()
  $url = Resolve-SellerReleaseConfigValue -Name "IBUL_SUPABASE_URL" -EnvFilePath $EnvFilePath
  $anon = Resolve-SellerReleaseConfigValue -Name "IBUL_SUPABASE_ANON_KEY" -EnvFilePath $EnvFilePath

  if ([string]::IsNullOrWhiteSpace($url)) {
    $missing += "IBUL_SUPABASE_URL"
  } else {
    [System.Environment]::SetEnvironmentVariable("IBUL_SUPABASE_URL", $url)
  }
  if ([string]::IsNullOrWhiteSpace($anon)) {
    $missing += "IBUL_SUPABASE_ANON_KEY"
  } else {
    [System.Environment]::SetEnvironmentVariable("IBUL_SUPABASE_ANON_KEY", $anon)
  }

  if ($missing.Count -gt 0) {
    throw "Supabase config missing for seller desktop release build."
  }
}

function Mask-SellerReleaseSecret {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return "<empty>"
  }
  if ($Value.Length -le 12) {
    return "***"
  }
  return "$($Value.Substring(0, 4))...$($Value.Substring($Value.Length - 4))"
}

function Write-TextFileUtf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )
  $utf8NoBom = $null
  try {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  } catch {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  }
  $directory = Split-Path -Parent $Path
  if (![string]::IsNullOrWhiteSpace($directory) -and !(Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Write-SellerDesktopDartDefineFile {
  param(
    [string]$ProjectRoot,
    [string[]]$OptionalKeys = @(
      "IBUL_GOOGLE_CLIENT_ID",
      "IBUL_GOOGLE_SERVER_CLIENT_ID",
      "IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL",
      "IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL",
      "IBUL_DISTRIBUTION_CHANNEL"
    )
  )

  $defines = [ordered]@{
    IBUL_SUPABASE_URL = [System.Environment]::GetEnvironmentVariable("IBUL_SUPABASE_URL")
    IBUL_SUPABASE_ANON_KEY = [System.Environment]::GetEnvironmentVariable("IBUL_SUPABASE_ANON_KEY")
  }

  foreach ($key in $OptionalKeys) {
    $value = [System.Environment]::GetEnvironmentVariable($key)
    if (![string]::IsNullOrWhiteSpace($value)) {
      $defines[$key] = $value.Trim()
    }
  }

  $outDir = Join-Path $ProjectRoot "build\windows"
  if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }
  $outPath = Join-Path $outDir "seller_desktop_dart_defines.json"
  $json = $defines | ConvertTo-Json -Compress
  Write-TextFileUtf8NoBom -Path $outPath -Content $json
  return $outPath
}

function Test-SellerDesktopDartDefineFile {
  param([string]$DartDefineFile)

  if (!(Test-Path $DartDefineFile)) {
    throw "Dart define file not found: $DartDefineFile"
  }

  $raw = [System.IO.File]::ReadAllText($DartDefineFile)
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Dart define file is empty: $DartDefineFile"
  }

  $parsed = $null
  try {
    $parsed = $raw | ConvertFrom-Json
  } catch {
    throw "Dart define file is not valid JSON: $DartDefineFile"
  }

  $url = $parsed.IBUL_SUPABASE_URL
  $anon = $parsed.IBUL_SUPABASE_ANON_KEY
  if ([string]::IsNullOrWhiteSpace($url)) {
    throw "Dart define file is missing IBUL_SUPABASE_URL."
  }
  if ([string]::IsNullOrWhiteSpace($anon)) {
    throw "Dart define file is missing IBUL_SUPABASE_ANON_KEY."
  }
}

function Test-SellerDesktopReleaseBinaryConfig {
  param(
    [string]$ExePath,
    [string]$SupabaseUrl
  )
  if (!(Test-Path $ExePath)) {
    throw "Release binary not found: $ExePath"
  }
  $uri = [Uri]$SupabaseUrl
  $needles = @(
    $uri.Host
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  $bytes = [System.IO.File]::ReadAllBytes($ExePath)
  $text = [System.Text.Encoding]::UTF8.GetString($bytes)
  foreach ($needle in $needles) {
    if ($text.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      throw "Release binary is missing embedded config marker: $needle"
    }
  }
}

function Write-SellerDesktopReleaseConfigLog {
  param([string]$DartDefineFile)
  Write-Host "Seller desktop release config:"
  Write-Host "  IBUL_SUPABASE_URL=$([System.Environment]::GetEnvironmentVariable('IBUL_SUPABASE_URL'))"
  Write-Host "  IBUL_SUPABASE_ANON_KEY=$(Mask-SellerReleaseSecret ([System.Environment]::GetEnvironmentVariable('IBUL_SUPABASE_ANON_KEY')))"
  Write-Host "  dart-define file: $DartDefineFile"
}

function Write-SellerDesktopBuildStamp {
  param(
    [string]$ProjectRoot,
    [string]$InstallerPath,
    [string]$DartDefineFile,
    [string]$ReleaseExePath
  )

  if (!(Test-Path $InstallerPath)) {
    throw "Installer not found for build stamp: $InstallerPath"
  }

  $installerInfo = Get-Item $InstallerPath
  $stamp = [ordered]@{
    builtAt = (Get-Date).ToUniversalTime().ToString("o")
    installerPath = $InstallerPath
    installerSize = $installerInfo.Length
    installerLastWriteUtc = $installerInfo.LastWriteTimeUtc.ToString("o")
    dartDefineFile = $DartDefineFile
    releaseExePath = $ReleaseExePath
  }

  $stampPath = Join-Path $ProjectRoot "build\windows\seller_desktop_build_stamp.json"
  $json = $stamp | ConvertTo-Json -Compress
  Write-TextFileUtf8NoBom -Path $stampPath -Content $json
  return $stampPath
}

function Remove-SellerDesktopBuildStamp {
  param([string]$ProjectRoot)
  $stampPath = Join-Path $ProjectRoot "build\windows\seller_desktop_build_stamp.json"
  if (Test-Path $stampPath) {
    Remove-Item $stampPath -Force
  }
}
