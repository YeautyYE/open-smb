@echo off 

::restart when the service is changed
set restartFlag=0

ver | find "5.0." > NUL &&  goto skipEnableSMB
ver | find "5.1." > NUL &&  goto skipEnableSMB
ver | find "5.2." > NUL &&  goto skipEnableSMB
ver | find "6.0." > NUL &&  goto skipEnableSMB
ver | find "6.1." > NUL &&  goto skipEnableSMB

::enable smb
echo 'check smb client'
Dism /online /Get-Features /format:table /English | find "SMB1Protocol-Client" | findstr "Enabled"
if %errorlevel% equ 0 (
  echo 'smb is ok'
) else (
  echo 'enable smb'
  Dism /online /Enable-Feature /FeatureName:"SMB1Protocol" /NoRestart
  Dism /online /Disable-Feature /FeatureName:"SMB1Protocol-Server" /NoRestart
  Dism /online /Disable-Feature /FeatureName:"SMB1Protocol-Deprecation" /NoRestart
  set restartFlag=1
)
:skipEnableSMB

::close the service at port 445
netstat -aon|findstr ":445"|findstr LISTENING || goto skipStopService

  echo 'check Browser'
  sc query Browser | find "STATE" | find "STOPPED" && goto skipStopBrowser
  echo 'stop Browser'
  sc stop Browser
  sc config Browser start= disabled 
  set restartFlag=1
  :skipStopBrowser

  echo 'check LanmanServe'
  sc query LanmanServer | find "STATE" | find "STOPPED" && goto skipStopLanmanServer
  echo 'stop LanmanServer'
  sc stop LanmanServer
  sc config LanmanServer start= disabled 
  set restartFlag=1
  :skipStopLanmanServer

:skipStopService

echo 'check ip helper'
::start ip helper
sc query iphlpsvc | find "STATE" | find "RUNNING" && goto skipIpHelper
echo 'start ip helper'
sc start iphlpsvc
sc config iphlpsvc start= auto
:skipIpHelper

::restart or open smb service
if %restartFlag% == 0 (
  goto proxyAndOpen
)

set /p restartNow='In order to start the smb lient of shut down related serices, it needs to be restarted. Do you want to restart now? (y/n) :'
echo %restartNow%
if %restartNow% == y (
  echo 'will restart in 3 seconds'
  shutdown -r -t 3
)
exit

:proxyAndOpen
echo 'start proxy'

::your smb host
set  /p smbHost="please input host of your smb:"
::your smb port
set /p smbPort="please input port of your smb:"

netsh interface portproxy delete v4tov4 listenport=445 listenaddress=127.0.0.1 
netsh interface portproxy add v4tov4 listenport=445 listenaddress=127.0.0.1 connectport=%smbPort% connectaddress=%smbHost%

echo 'open smb'
start \\127.0.0.1

