@echo off
echo ========================================
echo   GitHub Repository Setup Script
echo ========================================

echo.
echo [1/4] Create GitHub repository...

echo.
echo Please create GitHub repository manually:
echo   1. Visit: https://github.com/new
echo   2. Repository name: freshyx-bot
echo   3. Description: Freshyx Bot - IM Communication Gateway
echo   4. Select: Public
echo   5. DO NOT check "Add a README file"
echo   6. Click "Create repository"
echo.
echo After creation, press any key to continue...
pause >nul

echo.
echo [2/4] Add remote repository...
echo.

git remote add origin git@github.com:freshyx724/freshyx-bot.git
echo [OK] Remote repository added

echo.
echo [3/4] Push code to GitHub...
echo.
echo First push requires GitHub SSH key verification...
echo.

git push -u origin master

echo.
echo [4/4] Configure deployment scripts...
echo.
echo Update server deployment URL...

echo.
echo ========================================
echo   Done!
echo ========================================
echo.
echo Next steps:
echo 1. Visit https://github.com/freshyx724/freshyx-bot to view repository
echo 2. Follow deploy/README.md for server deployment
echo.

pause
