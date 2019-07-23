param(
    [Parameter(Mandatory=$true)][String]$sqlServer,
    [Parameter(Mandatory=$true)][String]$sqlUsername,
    [Parameter(Mandatory=$true)][String]$sqlPassword
    )

# Configure app
c:\windows\system32\inetsrv\appcmd.exe set config "http://localhost" -section:system.webServer/aspNetCore /-"environmentVariables.[name='ASPNETCORE_ENVIRONMENT']" /commit:apphost
c:\windows\system32\inetsrv\appcmd.exe set config "http://localhost" -section:system.webServer/aspNetCore /+"environmentVariables.[name='ASPNETCORE_ENVIRONMENT',value='Development']" /commit:apphost

# Configure sql
$connstr = "Server=tcp:$sqlServer,1433;Initial Catalog=todo;Persist Security Info=False;User ID=$sqlUsername;Password=$sqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
c:\windows\system32\inetsrv\appcmd.exe set config "http://localhost" -section:system.webServer/aspNetCore /-"environmentVariables.[name='SQLCONNSTR_mojeDB']" /commit:apphost
c:\windows\system32\inetsrv\appcmd.exe set config "http://localhost" -section:system.webServer/aspNetCore /+"environmentVariables.[name='SQLCONNSTR_mojeDB',value='$connstr']" /commit:apphost