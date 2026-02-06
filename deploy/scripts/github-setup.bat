@echo off
chcp 65001 >nul
echo ========================================
echo   GitHub 仓库创建和代码推送脚本
echo ========================================

echo.
echo [1/4] 创建GitHub仓库...

echo.
echo 请手动创建GitHub仓库:
echo   1. 访问: https://github.com/new
echo   2. Repository name: freshyx-bot
echo   3. Description: Freshyx Bot - IM通信网关
echo   4. 选择: Public
echo   5. 不要勾选 "Add a README file"
echo   6. 点击 "Create repository"
echo.
echo 创建完成后按任意键继续...
pause >nul

echo.
echo [2/4] 添加远程仓库...
echo.
set /p SERVER_IP="请输入你的服务器IP地址: "
echo.

git remote add origin git@github.com:freshyx724/freshyx-bot.git
echo [✓] 远程仓库已添加

echo.
echo [3/4] 推送代码到GitHub...
echo.
echo 首次推送需要验证GitHub SSH密钥...
echo.

git push -u origin master

echo.
echo [4/4] 配置部署脚本...

echo.
echo 更新服务器部署地址...
git remote set-url origin git@github.com:freshyx724/freshyx-bot.git

echo.
echo ========================================
echo   完成!
echo ========================================
echo.
echo 下一步:
echo 1. 访问 https://github.com/freshyx724/freshyx-bot 查看仓库
echo 2. 按照 deploy/README.md 进行服务器部署
echo.

pause
