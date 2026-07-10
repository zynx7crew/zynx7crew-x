if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณาเปิด PowerShell ด้วยสิทธิ์ Administrator (Ctrl + Shift + Enter)"
    Break
}

# 1. ปิดโหมดประหยัดพลังงาน USB (USB Selective Suspend) สาเหตุหลักที่ทำให้เมาส์ USB หลุด/ไม่เชื่อมต่อ
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea2879909 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
powercfg /SETACTIVE SCHEME_CURRENT | Out-Null

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

# 8. รีสตาร์ทระบบอัตโนมัติภายใน 5 วินาที
Start-Sleep -Seconds 5
shutdown -r -t 0
