# im-bot-gateway PowerShell 部署脚本
# 使用方法: .\deploy.ps1 <服务器IP>

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerIP,
    
    [Parameter(Mandatory=$false)]
    [string]$User = "root",
    
    [Parameter(Mandatory=$false)]
    [int]$ServerPort = 22
)

# 颜色配置
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = if ($Type -eq "ERROR") { $Red } elseif ($Type -eq "WARN") { $Yellow } else { $Green }
    Write-Host "${Color}[$Timestamp] [$Type] $Message${Reset}"
}

function Test-Command {
    param([string]$Command)
    try { & $Command --version | Out-Null; return $true } catch { return $false }
}

# 主函数
function Start-Deployment {
    Write-Log "========================================" 
    Write-Log "  im-bot-gateway 自动化部署脚本"
    Write-Log "  操作系统: Windows 11"
    Write-Log "========================================" 
    
    # 检查参数
    if (-not $ServerIP) {
        Write-Log "请提供服务器IP地址" "ERROR"
        Write-Host "`n用法: .\deploy.ps1 <服务器IP>`n" -ForegroundColor Cyan
        Write-Host "示例:`n  .\deploy.ps1 192.168.1.100`n  .\deploy.ps1 user@192.168.1.100" -ForegroundColor Cyan
        return
    }
    
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $DeployTime = Get-Date -Format "yyyyMMdd_HHmm"
    
    Write-Log "[1/6] 检查构建环境..."
    
    # 检查Flutter
    if (-not (Test-Command "flutter")) {
        Write-Log "Flutter未安装，请先安装Flutter SDK" "ERROR"
        return
    }
    Write-Log "Flutter环境正常"
    
    # 检查SSH
    if (-not (Test-Command "ssh")) {
        Write-Log "SSH未安装，建议安装Git或OpenSSH" "WARN"
    }
    
    Write-Log "[2/6] 编译Android APK..."
    Set-Location "$ProjectRoot\app"
    
    Write-Host "`n正在获取依赖..." -ForegroundColor Cyan
    flutter pub get
    
    Write-Host "`n正在编译发布版本APK..." -ForegroundColor Cyan
    $BuildResult = flutter build apk --release 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "APK编译失败" "ERROR"
        Write-Host $BuildResult
        return
    }
    Write-Log "APK编译成功"
    
    Write-Log "[3/6] 准备部署文件..."
    
    # 打包服务端
    Set-Location "$ProjectRoot\server"
    $ServerTar = "$env:TEMP\server-deploy-$DeployTime.tar.gz"
    
    if (Get-Command "tar" -ErrorAction SilentlyContinue) {
        tar -czf $ServerTar -C src . ../package.json ../config.json 2>$null
    } else {
        # Windows没有tar，使用7zip或压缩
        Write-Log "tar命令不可用，请安装Git或7-Zip" "WARN"
    }
    
    # 创建临时部署目录
    $ScopedDir = "$env:TEMP\scoped_deploy_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Force -Path $ScopedDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$ScopedDir\apk" | Out-Null
    
    # 复制文件
    if (Test-Path $ServerTar) {
        Copy-Item $ServerTar $ScopedDir
        Write-Log "服务端代码已打包"
    }
    
    Copy-Item "$ProjectRoot\app\build\app\outputs\flutter-apk\app-release.apk" "$ScopedDir\apk\"
    Write-Log "APK已复制"
    
    Copy-Item "$ProjectRoot\deploy\scripts\server-deploy.sh" $ScopedDir
    Copy-Item "$ProjectRoot\deploy\config\ecosystem.config.js" $ScopedDir
    Write-Log "部署脚本已复制"
    
    Write-Log "[4/6] 上传文件到服务器..."
    
    Write-Host "`n正在上传到 $ServerIP..." -ForegroundColor Cyan
    $SCPResult = scp -r "$ScopedDir\*" "$User@$ServerIP`:/tmp/im-bot-deploy/"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "文件上传失败" "ERROR"
        # 清理
        Remove-Item -Recurse -Force $ScopedDir -ErrorAction SilentlyContinue
        Remove-Item $ServerTar -ErrorAction SilentlyContinue
        return
    }
    Write-Log "文件上传成功"
    
    Write-Log "[5/6] 执行远程部署..."
    
    Write-Host "`n正在执行远程部署..." -ForegroundColor Cyan
    $SSHSession = ssh -t "$User@$ServerIP" "cd /tmp/im-bot-deploy && bash server-deploy.sh"
    
    Write-Log "[6/6] 清理本地临时文件..."
    
    Remove-Item -Recurse -Force $ScopedDir -ErrorAction SilentlyContinue
    Remove-Item $ServerTar -ErrorAction SilentlyContinue
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  部署完成!" -ForegroundColor Green
    Write-Host "========================================" 
    Write-Host "`n后续步骤:" -ForegroundColor Cyan
    Write-Host "  1. 安装APK: adb install app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host "  2. 查看服务状态: ssh $User@$ServerIP 'pm2 status'" -ForegroundColor White
    Write-Host "  3. 查看日志: ssh $User@$ServerIP 'pm2 logs im-bot-gateway'" -ForegroundColor White
    Write-Host ""
}

# 运行部署
Start-Deployment
