# ปิดการแสดงผลข้อผิดพลาดที่ไม่จำเป็น เพื่อป้องกันระบบค้างหรือขัดข้องระหว่างทำงาน
$ErrorActionPreference = "SilentlyContinue"

# ตรวจสอบสิทธิ์ Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณาเปิด PowerShell ด้วยสิทธิ์ Administrator (คลิกขวาเลือก Run as Administrator)"
    Break
}

# เคลียร์หน้าจอเพื่อความสะอาด
Clear-Host

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       กำลังเริ่มทำงานแก้ปัญหา USB & Mouse และดึงหน้า GUI" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. ปิดโหมดประหยัดพลังงาน USB (ซ่อนข้อความ Error ด้วย 2>$null เพื่อไม่ให้หน้าจอรก)
Write-Host "[1/7] กำลังตั้งค่าระบบพลังงานของ USB..." -ForegroundColor White
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETACTIVE SCHEME_CURRENT 2>$null

# 2. ปิดการประหยัดพลังงานใน Registry ของพอร์ต USB ทั้งหมด
Write-Host "[2/7] กำลังตั้งค่า Registry ป้องกันพอร์ต USB ตัดไฟ..." -ForegroundColor White
$USBEnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
if (Test-Path $USBEnumPath) {
    Get-ChildItem -Path $USBEnumPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}

# 3. คืนค่า Registry ของเมาส์ให้เป็นค่าเริ่มต้น
Write-Host "[3/7] กำลังรีเซ็ตการตั้งค่าเมาส์กลับเป็นค่าเริ่มต้น..." -ForegroundColor White
$MouseRegPath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MouseRegPath -Name "MouseSpeed" -Value "1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold1" -Value "6" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold2" -Value "10" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseSensitivity" -Value "10" -ErrorAction SilentlyContinue

# 4. ตั้งค่าบริการระบบที่เกี่ยวข้อง (ข้าม PlugPlay เพื่อป้องกันเครื่องค้างขณะทำรายการ)
Write-Host "[4/7] กำลังตั้งค่าและรีสตาร์ทบริการจัดการอุปกรณ์..." -ForegroundColor White
$ServicesToFix = @("DeviceInstall", "hidserv")
foreach ($Service in $ServicesToFix) {
    Set-Service -Name $Service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $Service -ErrorAction SilentlyContinue
}

# 5. ล้างประวัติไดรเวอร์ที่มีสถานะ Error หรือเชื่อมต่อไม่สมบูรณ์
Write-Host "[5/7] กำลังล้างข้อมูลไดรเวอร์ USB และเมาส์ที่ตรวจพบข้อผิดพลาด..." -ForegroundColor White
$TargetDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {($_.Class -eq 'Mouse' -or $_.Class -eq 'USB') -and ($_.Status -ne 'OK' -or $_.Present -eq $false)}
foreach ($Device in $TargetDevices) {
    if ($Device.InstanceId) {
        pnputil /remove-device $Device.InstanceId /force | Out-Null
    }
}

# 6. สแกนฮาร์ดแวร์ใหม่เพื่อรีเฟรชไดรเวอร์เมาส์ตัวที่สมบูรณ์ (ปลอดภัยกว่าการสั่งปิด/เปิด USB Root Hub ป้องกันไม่ให้เมาส์/คีย์บอร์ดค้าง)
Write-Host "[6/7] กำลังสแกนหาและติดตั้งอุปกรณ์เมาส์/คีย์บอร์ดใหม่..." -ForegroundColor White
pnputil /scan-devices | Out-Null

# 7. ดาวน์โหลดและแสดงหน้าจอโปรแกรม GUI (loader.exe)
Write-Host ""
Write-Host "[7/7] กำลังเชื่อมต่อกับ GitHub เพื่อดึงหน้าต่างโปรแกรมใช้งาน (loader.exe)..." -ForegroundColor Yellow

$Url = "https://github.com/zynx7crew/zynx7crew-x/releases/download/v1.0.0/loader.exe"
$DestPath = "$env:temp\loader.exe"

try {
    # เคลียร์ไฟล์เก่าออกก่อนดาวน์โหลดใหม่
    if (Test-Path $DestPath) {
        Remove-Item -Path $DestPath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "กำลังโหลดข้อมูลโปรแกรม..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $Url -OutFile $DestPath -ErrorAction Stop
    
    Write-Host ""
    Write-Host "🚀 ดาวน์โหลดสำเร็จ! กำลังเปิดหน้าต่างโปรแกรม GUI ให้ใช้งาน..." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    
    # รันโปรแกรม GUI ทันทีในสิทธิ์ Admin
    Start-Process -FilePath $DestPath -Verb RunAs
}
catch {
    Write-Host "❌ ดาวน์โหลดล้มเหลว: $_" -ForegroundColor Red
    Write-Host "โปรดตรวจสอบการเชื่อมต่ออินเทอร์เน็ต หรือสถานะไฟล์บนคลัง GitHub" -ForegroundColor Yellow
}
