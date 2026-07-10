# คำสั่งสำหรับดาวน์โหลดและรันไฟล์ X.ps1 ผ่านลิงก์ใน PowerShell แบบบายพาส Execution Policy และขอสิทธิ์ Admin
# วิธีใช้งาน: เปลี่ยน "URL_TO_YOUR_SCRIPT" เป็นลิงก์ดิบ (Raw Link เช่น GitHub Raw หรือ Web Server ของคุณ)

# 1. คำสั่งสำหรับรันใน PowerShell (ต้องเปิดด้วยสิทธิ์ Administrator):
# irm "URL_TO_YOUR_SCRIPT" | iex

# 2. คำสั่งสั้นๆ สำหรับนำไปรันใน Command Prompt (CMD) หรือกล่อง Run (Win + R):
# powershell -ExecutionPolicy Bypass -Command "irm 'URL_TO_YOUR_SCRIPT' | iex"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "วิธีรันสคริปต์ผ่านลิงก์ใน PowerShell:" -ForegroundColor Yellow
Write-Host "irm `"https://your-server.com/X.ps1`" | iex" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
