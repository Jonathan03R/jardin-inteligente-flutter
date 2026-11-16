$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$properties = Join-Path $PSScriptRoot 'android\key.properties'
$keystore = Join-Path $PSScriptRoot 'android\jardin-release.jks'
if ((Test-Path -LiteralPath $properties) -or (Test-Path -LiteralPath $keystore)) {
    Write-Host 'La firma ya existe. Conserva ambos archivos para futuras actualizaciones.'
    exit 0
}
$keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\keytool.exe' } else { 'keytool' }
$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$env:JARDIN_SIGN_PASSWORD = [Convert]::ToBase64String($bytes)
try {
    & $keytool -genkeypair -keystore $keystore -storetype JKS -alias jardin -keyalg RSA -keysize 3072 -validity 10000 -storepass:env JARDIN_SIGN_PASSWORD -keypass:env JARDIN_SIGN_PASSWORD -dname 'CN=Mi Jardin, OU=Aplicacion, O=Jardin Inteligente, C=PE'
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la firma.' }
    @("storePassword=$env:JARDIN_SIGN_PASSWORD", "keyPassword=$env:JARDIN_SIGN_PASSWORD", 'keyAlias=jardin', 'storeFile=jardin-release.jks') | Set-Content -LiteralPath $properties
} finally { Remove-Item Env:\JARDIN_SIGN_PASSWORD -ErrorAction SilentlyContinue }
Write-Host 'Firma creada. Guarda copia privada de android/key.properties y android/jardin-release.jks.'
