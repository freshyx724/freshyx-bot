@echo off
chcp 65001 >nul
echo ========================================
echo   im-bot-gateway 自动化部署脚本
echo   本地环境: Windows 11
echo   目标服务器: Alibaba Cloud Linux
echo ========================================
echo.

REM 配置参数
set PROJECT_ROOT=%~dp0..
set SERVER_USER=root
set SERVER_HOST=
set SERVER_PORT=22
set LOCAL_BUILD_DIR=build\app\outputs\flutter-apk
set REMOTE_DIR=/opt/im-bot-gateway

REM 颜色定义
color 0A

REM 检查参数
if "%1"=="" (
    echo [错误] 请提供服务器IP地址
    echo 用法: deploy.bat ^<服务器IP^>
    echo.
    echo 示例:
    echo   deploy.bat 192.168.1.100
    echo   deploy.bat user@192.168.1.100
    exit /b 1
)

set SERVER_HOST=%1

echo [1/6] 检查构建环境...
echo.
if not exist "%PROJECT_ROOT%\app" (
    echo [错误] Flutter项目目录不存在
    exit /b 1
)

REM 检查Flutter
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [错误] Flutter未安装或不在PATH中
    exit /b 1
)
echo [✓] Flutter环境正常

REM 检查SSH
ssh -V >nul 2>&1
if errorlevel 1 (
    echo [警告] SSH客户端未找到，建议安装Git Bash或OpenSSH
)

echo.
echo [2/6] 编译Android APK...
echo.
cd "%PROJECT_ROOT%\app"

echo 正在获取依赖...
flutter pub get

echo 正在编译发布版本APK...
flutter build apk --release

if errorlevel 1 (
    echo [错误] APK编译失败
    exit /b 1
)

if not exist "%LOCAL_BUILD_DIR%\app-release.apk" (
    echo [错误] APK文件未找到
    exit /b 1
)
echo [✓] APK编译成功

echo.
echo [3/6] 准备部署文件...
echo.
set DEPLOY_TIME=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%
set DEPLOY_TIME=%DEPLOY_TIME: =0%

echo 部署时间: %DEPLOY_TIME%

REM 打包服务端
cd "%PROJECT_ROOT%\server"
tar -cvf "%TEMP%\server-deploy-%DEPLOY_TIME%.tar.gz" src package.json config.json 2>nul

if exist "%TEMP%\server-deploy-%DEPLOY_TIME%.tar.gz" (
    echo [✓] 服务端代码已打包
)

echo.
echo [4/6] 上传文件到服务器...
echo.
set SCOPED_ENV=%TEMP%\scoped_dir_%RANDOM%
mkdir "%SCOPED_ENV%" 2>nul

REM 复制服务端包
copy "%TEMP%\server-deploy-%DEPLOY_TIME%.tar.gz" "%SCOPED_ENV%\" >nul

REM 复制APK
mkdir "%SCOPED_ENV%\apk" 2>nul
copy "%LOCAL_BUILD_DIR%\app-release.apk" "%SCOPED_ENV%\apk\" >nul

REM 复制部署脚本
copy "%PROJECT_ROOT%\deploy\scripts\server-setup.sh" "%SCOPED_ENV%\" >nul
copy "%PROJECT_ROOT%\deploy\scripts\server-deploy.sh" "%SCOPED_ENV%\" >nul
copy "%PROJECT_ROOT%\deploy\config\ecosystem.config.js" "%SCOPED_ENV%\" >nul

echo 上传到 %SERVER_HOST%...
scp -r "%SCOPED_ENV%\*" %SERVER_USER%@%SERVER_HOST%:/tmp/im-bot-deploy/

if errorlevel 1 (
    echo [错误] 文件上传失败
    rmdir /s /q "%SCOPED_ENV%" 2>nul
    exit /b 1
)
echo [✓] 文件上传成功

echo.
echo [5/6] 执行远程部署...
echo.
ssh %SERVER_USER%@%SERVER_HOST% "cd /tmp/im-bot-deploy && bash server-deploy.sh"

echo.
echo [6/6] 清理本地临时文件...
echo.
rmdir /s /q "%SCOPED_ENV%" 2>nul
del "%TEMP%\server-deploy-%DEPLOY_TIME%.tar.gz" 2>nul

echo.
echo ========================================
echo   部署完成!
echo ========================================
echo.
echo 后续步骤:
echo 1. 在Android设备上安装 APK:
echo    adb install "%LOCAL_BUILD_DIR%\app-release.apk"
echo.
echo 2. 配置App服务器地址:
echo    修改 app/lib/services/websocket_service.dart 中的 serverUrl
echo.
echo 3. 查看服务器状态:
echo    ssh %SERVER_USER%@%SERVER_HOST% "pm2 status"
echo.
echo 4. 查看服务器日志:
echo    ssh %SERVER_USER%@%SERVER_HOST% "pm2 logs im-bot-gateway"
echo.

pause
