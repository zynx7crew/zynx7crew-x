# กำหนดระบบเข้ารหัสของคอนโซลเป็น UTF-8 และโปรโตคอลความปลอดภัย TLS 1.2
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ปิดการแสดงแถบดาวน์โหลดเริ่มต้น เพื่อเร่งความเร็วการทำงานของ Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

# ปิดการแจ้งเตือน Error ทั่วไปเพื่อความลื่นไหล
$ErrorActionPreference = "SilentlyContinue"

# ตรวจสอบสิทธิ์ผู้ดูแลระบบ (Administrator)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณาเปิด PowerShell ด้วยสิทธิ์ Administrator (Run as Administrator)"
    Break
}

# ฟังก์ชันแสดงผลหลอดโหลดแบบภาษาอังกฤษ
function Show-ProgressBar {
    param (
        [int]$Percent,
        [string]$Status
    )
    $width = 25
    $done = [Math]::Floor(($Percent / 100) * $width)
    $left = $width - $done
    $bar = ("█" * $done) + ("░" * $left)
    Write-Host "`r  $Status [$bar] $Percent%  " -NoNewline -ForegroundColor Cyan
}

# เคลียร์หน้าจอให้สวยงามสะอาดตา
Clear-Host
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "            SYSTEM OPTIMIZER & LOADER" -ForegroundColor Yellow
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

# ขั้นที่ 1: ตรวจสอบและตั้งค่าระบบไฟ USB สำหรับทุกสเปคและโน๊ตบุ๊ค (ทั้งตอนเสียบสาย AC และใช้แบตเตอรี่ DC) (0% - 25%)
Show-ProgressBar 0 "Initializing system..."
Start-Sleep -Milliseconds 200

# ปิดโหมดประหยัดพลังงาน USB (ครอบคลุมทั้งตอนเสียบปลั๊ก AC และแบตเตอรี่ DC สำหรับโน๊ตบุ๊ค)
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null

# ตั้งค่าให้ CPU ทำงานเต็มประสิทธิภาพ (ไม่ให้ CPU โดนลดคลื่นความถี่บนโน๊ตบุ๊คตอนใช้แบตเตอรี่)
powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 2>$null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 2>$null

# ยืนยันการตั้งค่าแผนพลังงาน
powercfg /SETACTIVE SCHEME_CURRENT 2>$null

$USBEnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
if (Test-Path $USBEnumPath) {
    Get-ChildItem -Path $USBEnumPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}
Show-ProgressBar 25 "Optimizing hardware settings..."
Start-Sleep -Milliseconds 200

# ขั้นที่ 2: ตั้งค่าเมาส์และ Service (25% - 50%)
$MouseRegPath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MouseRegPath -Name "MouseSpeed" -Value "1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold1" -Value "6" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold2" -Value "10" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseSensitivity" -Value "10" -ErrorAction SilentlyContinue

$ServicesToFix = @("DeviceInstall", "hidserv")
foreach ($Service in $ServicesToFix) {
    Set-Service -Name $Service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $Service -ErrorAction SilentlyContinue
}
Show-ProgressBar 50 "Configuring system services..."
Start-Sleep -Milliseconds 200

# ขั้นที่ 3: รีเฟรชไดรเวอร์และสแกนอุปกรณ์ (50% - 70%)
$TargetDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {($_.Class -eq 'Mouse' -or $_.Class -eq 'USB') -and ($_.Status -ne 'OK' -or $_.Present -eq $false)}
foreach ($Device in $TargetDevices) {
    if ($Device.InstanceId) {
        pnputil /remove-device $Device.InstanceId /force | Out-Null
    }
}
pnputil /scan-devices | Out-Null
Show-ProgressBar 70 "Connecting to server..."
Start-Sleep -Milliseconds 200

# ขั้นที่ 4: จัดเตรียมโครงสร้างโฟลเดอร์สำหรับ GUI (เปลี่ยนจาก Temp เป็น ProgramData เพื่อป้องกันนโยบายความปลอดภัยบล็อกการรันสคริปต์ในบางเครื่อง) (70% - 85%)
Show-ProgressBar 80 "Deploying asset structure..."
$DestDir = "C:\ProgramData\ZynxOptimizer"
$DestLoader = "$DestDir\loader.exe"
$DestFont = "$DestDir\font\font-login\ST-SimpleSquare.ttf"
$DestConfig = "$DestDir\config\settings.lua"
$DestCloseBtn = "$DestDir\img\icon\close.png"

# สร้างโฟลเดอร์ย่อยใน ProgramData
New-Item -ItemType Directory -Path "$DestDir\font\font-login" -Force > $null 2>&1
New-Item -ItemType Directory -Path "$DestDir\config" -Force > $null 2>&1
New-Item -ItemType Directory -Path "$DestDir\img\icon" -Force > $null 2>&1

# ตรวจสอบและดึงไฟล์ Font (ST-SimpleSquare.ttf)
$LocalFont = "C:\Users\Administrator\Desktop\A\font\font-login\ST-SimpleSquare.ttf"
$UrlFont = "https://raw.githubusercontent.com/zynx7crew/zynx7crew-x/main/font/font-login/ST-SimpleSquare.ttf"
if (Test-Path $LocalFont) {
    Copy-Item -Path $LocalFont -Destination $DestFont -Force
} else {
    Invoke-WebRequest -Uri $UrlFont -OutFile $DestFont -ErrorAction SilentlyContinue
}

# ตรวจสอบและดึงไฟล์ Config (settings.lua)
$LocalConfig = "C:\Users\Administrator\Desktop\A\bin\config\settings.lua"
$UrlConfig = "https://raw.githubusercontent.com/zynx7crew/zynx7crew-x/main/config/settings.lua"
if (Test-Path $LocalConfig) {
    Copy-Item -Path $LocalConfig -Destination $DestConfig -Force
} else {
    Invoke-WebRequest -Uri $UrlConfig -OutFile $DestConfig -ErrorAction SilentlyContinue
}

# ตรวจสอบและดึงไฟล์รูปภาพปุ่มปิด (close.png)
$LocalCloseBtn = "C:\Users\Administrator\Desktop\A\img\icon\close.png"
$UrlCloseBtn = "https://raw.githubusercontent.com/zynx7crew/zynx7crew-x/main/img/icon/close.png"
if (Test-Path $LocalCloseBtn) {
    Copy-Item -Path $LocalCloseBtn -Destination $DestCloseBtn -Force
} else {
    Invoke-WebRequest -Uri $UrlCloseBtn -OutFile $DestCloseBtn -ErrorAction SilentlyContinue
}

# ขั้นที่ 5: ดาวน์โหลดตัวเปิดหลัก loader.exe และจัดการความเข้ากันได้ของการแสดงผลหน้าจอ (DPI Scaling) (85% - 100%)
Show-ProgressBar 90 "Downloading program dependencies..."
$UrlLoader = "https://github.com/zynx7crew/zynx7crew-x/releases/download/v1.0.0/loader.exe"

# ตรวจสอบและปิด Process เก่าที่ค้าง
$Proc = Get-Process -Name "loader" -ErrorAction SilentlyContinue
if ($Proc) {
    Stop-Process -Name "loader" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

try {
    if (Test-Path $DestLoader) {
        Remove-Item -Path $DestLoader -Force -ErrorAction SilentlyContinue
    }
    
    # ดาวน์โหลดโปรแกรมหลัก
    Invoke-WebRequest -Uri $UrlLoader -OutFile $DestLoader -ErrorAction Stop
    Unblock-File -Path $DestLoader -ErrorAction SilentlyContinue
    
    # แก้ไข DPI Compatibility เพื่อรองรับการแสดงผลหน้าจอบนโน๊ตบุ๊คและจอภาพสเกลความละเอียดสูง (125%, 150%) ป้องกันไอคอนเบลอ/ปุ่มเยื้อง
    $CompatPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (Test-Path $CompatPath) {
        Set-ItemProperty -Path $CompatPath -Name $DestLoader -Value "~ HIGHDPIAWARE" -Force -ErrorAction SilentlyContinue
    }
    
    Show-ProgressBar 100 "System ready! Launching GUI..."
    
    # รันโปรแกรม GUI พร้อมกำหนด WorkingDirectory เพื่อให้อ้างอิงไฟล์ทั้งหมดได้ถูกต้อง
    Start-Process -FilePath $DestLoader -WorkingDirectory $DestDir -Verb RunAs
    
    # ปิดหน้าต่างลงทันที
    exit
}
catch {
    Write-Host ""
    Write-Host "  [x] Error: Check your internet connection." -ForegroundColor Red
}
