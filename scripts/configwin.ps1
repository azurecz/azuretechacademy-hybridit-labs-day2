Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Set-WebConfiguration system.webServer/security/authentication/anonymousAuthentication -PSPath IIS:\ -Location "Default Web Site" -Value @{enabled="False"}
Set-WebConfiguration system.webServer/security/authentication/windowsAuthentication -PSPath IIS:\ -Location "Default Web Site" -Value @{enabled="True"}