# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication

# Install dotnet core with IIS module
mkdir \install
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://download.visualstudio.microsoft.com/download/pr/a9bb6d52-5f3f-4f95-90c2-084c499e4e33/eba3019b555bb9327079a0b1142cc5b2/dotnet-hosting-2.2.6-win.exe","c:\install\dotnet-hosting-2.2.6-win.exe")
C:\install\dotnet-hosting-2.2.6-win.exe /install /quiet

# Restart IIS to pickup PATH for dotnet
net stop was /y
net start w3svc

# Install app
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/tkubica12/dotnetcore-sqldb-tutorial/raw/master/linuxrelease-v1.tar","c:\install\linuxrelease-v1.tar")
cd \inetpub\wwwroot\
tar -xf c:\install\linuxrelease-v1.tar

# Configure app
c:\windows\system32\inetsrv\appcmd.exe set config "http://localhost" -section:system.webServer/aspNetCore /-"environmentVariables.[name='ASPNETCORE_ENVIRONMENT',value='Development']" /commit:apphost
c:\windows\system32\inetsrv\appcmd.exe set config "http://localhost" -section:system.webServer/aspNetCore /+"environmentVariables.[name='ASPNETCORE_ENVIRONMENT',value='Development']" /commit:apphost

# Restart IIS to pickup PATH for dotnet
net stop was /y
net start w3svc

# clean up
rm c:\install -r


