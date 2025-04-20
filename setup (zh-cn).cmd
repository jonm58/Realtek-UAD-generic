@echo off
@chcp 65001
@cd /d "%~dp0"
@set "ERRORLEVEL="
@CMD /C EXIT 0
@"%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system" >nul 2>&1
@if NOT "%ERRORLEVEL%"=="0" (
@powershell -Command Start-Process """%0""" -Verb runAs 2>nul
@exit
)
:--------------------------------------
@TITLE Realtek UAD 通用驱动程序设置
@IF NOT "%SAFEBOOT_OPTION%"=="" TITLE Realtek UAD 通用驱动程序设置 (安全模式恢复)

@rem 如果强制更新程序在启用声卡时将 Windows 重启到正常模式，只需擦除自动启动条目即可。
@IF "%SAFEBOOT_OPTION%"=="" IF EXIST assets\setupdone.ini (
@echo 安装已成功完成。
@echo.
@echo 将 Windows 恢复到正常启动状态...
@bcdedit /deletevalue {globalsettings} advancedoptions
@echo.
@pause
@GOTO ending
)

@echo 欢迎使用非官方 Realtek UAD 通用设置向导.
@echo 警告：此设置可能会自动重启电脑，请做好准备.
@echo.
@echo 如果 Windows 崩溃（BSOD/GSOD），请尽快启动到安全模式.
@echo 不要在安全模式下使用命令提示符，因为即使在安全模式下，它也不会加载设置自动启动所依赖的 shell.
@echo 设置后，进入安全模式非常简单，它会自动启动以恢复系统稳定性.
@echo.
@pause
@echo.
@IF NOT EXIST "assets\" md assets

@echo 启用 Windows script host...
@CMD /C EXIT 0
@REG QUERY "HKLM\SOFTWARE\Microsoft\Windows Script Host\Settings" /v "Enabled" /t REG_DWORD >nul 2>&1
@IF "%ERRORLEVEL%"=="0" REG DELETE "HKLM\SOFTWARE\Microsoft\Windows Script Host\Settings" /v "Enabled" /f
@echo.

@echo 创建设置自动启动项...
@call modules\autostart.cmd setup

@rem 获取初始的 Windows 待处理文件操作状态
@REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations>assets\prvregdmp.txt 2>&1

@echo 开始卸载 Realtek UAD 驱动程序...
@echo.
@IF "%SAFEBOOT_OPTION%"=="" (
@echo 停止 Windows 音频服务以降低重新启动的可能性...
@echo.
@net stop Audiosrv /y
@echo.
@echo Done.
@echo.
)
@call modules\uadserviceremove.cmd RtkAudUService64.exe

@rem 从驱动程序存储中清除 Realtek UAD 组件.
@CMD /C EXIT 0
@where /q devcon
@if NOT "%ERRORLEVEL%"=="0" echo Windows Device console - devcon.exe is required.&echo.&pause&GOTO ending
@IF "%SAFEBOOT_OPTION%"=="" (
@devcon /r disable =AudioProcessingObject "SWC\VEN_10EC&AID_0001"
@echo.
)
@devcon /r remove =AudioProcessingObject "SWC\VEN_10EC&AID_0001"
@echo.
@IF "%SAFEBOOT_OPTION%"=="" (
@devcon /r disable =SoftwareComponent "SWC\VEN_10EC&AID_0001"
@echo.
)
@devcon /r remove =SoftwareComponent "SWC\VEN_10EC&AID_0001"
@echo.
@IF "%SAFEBOOT_OPTION%"=="" (
@devcon /r disable =SoftwareComponent "SWC\VEN_10EC&HID_0001"
@echo.
)
@devcon /r remove =SoftwareComponent "SWC\VEN_10EC&HID_0001"
@echo.
@IF "%SAFEBOOT_OPTION%"=="" (
@devcon /r disable =SoftwareComponent "SWC\VEN_10EC&SID_0001"
@echo.
)
@devcon /r remove =SoftwareComponent "SWC\VEN_10EC&SID_0001"
@echo.
@IF "%SAFEBOOT_OPTION%"=="" (
@devcon /r disable =MEDIA "HDAUDIO\FUNC_01&VEN_10EC*" "INTELAUDIO\FUNC_01&VEN_10EC*"
@echo.
)
@devcon /r remove =MEDIA "HDAUDIO\FUNC_01&VEN_10EC*" "INTELAUDIO\FUNC_01&VEN_10EC*"
@echo.
@echo Removing generic Realtek UAD components...
@echo.
@call modules\deluadcomponent.cmd hdxrt.inf
@call modules\deluadcomponent.cmd hdxrtsst.inf
@call modules\deluadcomponent.cmd hdx_genericext_rtk.inf
@call modules\deluadcomponent.cmd GenericAudioExtRT.inf
@call modules\deluadcomponent.cmd realtekservice.inf
@call modules\deluadcomponent.cmd realtekhsa.inf
@call modules\deluadcomponent.cmd realtekapo.inf
@echo Done.
@echo.

@IF EXIST oem.ini echo 移除 oem.ini 中指定的 OEM 专用 Realtek UAD 组件...
@IF EXIST oem.ini echo.
@setlocal EnableDelayedExpansion
@IF EXIST oem.ini FOR /F tokens^=^*^ eol^= %%a IN (oem.ini) do @(
set oemcomponent=%%a
IF /I NOT !oemcomponent:~-4!==.inf set oemcomponent=!oemcomponent!.inf
call modules\deluadcomponent.cmd !oemcomponent!
)
@endlocal
@IF EXIST oem.ini echo Done.
@IF EXIST oem.ini echo.

@IF "%SAFEBOOT_OPTION%"=="" (
@net start Audiosrv
@echo.
)
@echo 卸载驱动程序完成.
@echo.

@rem 安装驱动程序
@echo 删除自动启动项以防安装被拒绝...
@call modules\autostart.cmd remove
@IF NOT "%SAFEBOOT_OPTION%"=="" IF EXIST assets\mainsetupsystemcrash.ini (
@echo 警告：Windows 在主设置驱动程序初始化阶段崩溃.
@echo UAD 驱动程序安装已取消.
@echo.
@pause
@GOTO ending
)
@set /p install=您是否要安装非官方的最小 Realtek UAD 通用软件包？ (y/n):
@echo.
@IF /I NOT "%install%"=="y" GOTO ending

@echo 安装开始时恢复自动启动条目...
@call modules\autostart.cmd setup
@pnputil /add-driver *.inf /subdirs /reboot
@echo.
@echo 安装驱动程序完成
@echo.
@pause
@echo.

@rem 启动驱动程序 (这无法在安全模式下运行)
@IF "%SAFEBOOT_OPTION%"=="" (
@echo 启用 Windows 高级启动恢复菜单，以防出现严重问题...
@bcdedit /set {globalsettings} advancedoptions true
@echo.
@echo 1>assets\mainsetupsystemcrash.ini
@rem 在冒险启动驱动程序之前，等待 1 秒钟将崩溃标记写入磁盘.
@CHOICE /N /T 1 /C y /D y >nul 2>&1
@devcon /rescan
@echo.
@echo 让 Windows 用 20 秒钟加载 Realtek UAD 驱动程序...
@CHOICE /N /T 20 /C y /D y >nul 2>&1
@pause
@echo.
@rem 如果我们到了这里，那么一切就都没问题了.
@echo 将 Windows 恢复到正常启动状态...
@bcdedit /deletevalue {globalsettings} advancedoptions
@echo.
@del assets\mainsetupsystemcrash.ini
@rem 强制更新程序无法在安全模式下运行
@IF EXIST forceupdater\forceupdater.cmd IF EXIST Win64\Realtek\UpdatedCodec echo Creating force updater autostart entry...
@IF EXIST forceupdater\forceupdater.cmd IF EXIST Win64\Realtek\UpdatedCodec call modules\autostart.cmd forceupdater
)

@IF EXIST forceupdater\forceupdater.cmd IF EXIST Win64\Realtek\UpdatedCodec IF NOT "%SAFEBOOT_OPTION%"=="" (
@echo 警告：您已进入安全模式。强制更新程序无法运行，无法更新超出最新 WHQL 通用基础的驱动程序.
@echo.
)

@rem 检查是否需要重启
@rem 获取最终的 Windows 待处理文件操作状态
@REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations>assets\postregdmp.txt 2>&1
@FC /B assets\prvregdmp.txt assets\postregdmp.txt>NUL&&GOTO forceupdater
@IF EXIST assets\prvregdmp.txt del assets\prvregdmp.txt
@IF EXIST assets\postregdmp.txt del assets\postregdmp.txt
@echo 请注意 必须重新启动计算机才能完成驱动程序安装。继续之前请保存您的工作.
@echo.
@pause
@shutdown -r -t 0
@exit

:forceupdater
@IF EXIST assets\prvregdmp.txt del assets\prvregdmp.txt
@IF EXIST assets\postregdmp.txt del assets\postregdmp.txt
@pause
@rem 强制更新程序无法在安全模式下运行
@IF EXIST forceupdater\forceupdater.cmd IF EXIST Win64\Realtek\UpdatedCodec IF "%SAFEBOOT_OPTION%"=="" call forceupdater\forceupdater.cmd

:ending
@call modules\autostart.cmd remove >nul 2>&1
@IF EXIST assets RD /S /Q assets
