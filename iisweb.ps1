#ps1_sysnative
Import-Module WebAdministration
$ErrorActionPreference = 'Stop'
#eventlog
New-EventLog -LogName AppDeploylog -Source openstack_heat, JobDone, Remark
function ExecRetry($command, $maxRetryCount = 10, $retryInterval=2)
{
    $currErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $retryCount = 0
    while ($true)
    {
        try
        {
            & $command
            break
        }
        catch [System.Exception]
        {
            $retryCount++
            if ($retryCount -ge $maxRetryCount)
            {
                $ErrorActionPreference = $currErrorActionPreference
                throw
            }
            else
            {
                Write-EventLog -LogName AppDeploylog -Source openstack_heat -EntryType Information -EventId 1 -Message $_.Exception
                Start-Sleep $retryInterval
            }
        }
    }
    $ErrorActionPreference = $currErrorActionPreference
}
#set web root path
ExecRetry {
  New-Item c:\wwwroot -type directory
}
#place project
ExecRetry {
  $projectdir = "$ENV:Temp\projectname.rar"
  $projecturl = "appurl"
  (new-object System.Net.WebClient).DownloadFile($projecturl, $projectdir)
  $zippath = "C:\Program Files\7-Zip\7z.exe"
  & $zippath x $projectdir -oC:\wwwroot -y -aos
  del $projectdir
}
#enable .netframework x64 iaspi&cgi
ExecRetry {
  $frameworkPath = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll"
  Set-WebConfiguration "/system.webServer/security/isapiCgiRestriction/add[@path='$frameworkPath']/@allowed" -value 'True' -PSPath:IIS:\
}
#new web item
ExecRetry {
  New-Item iis:\Sites\projectname -bindings @{protocol="http";bindingInformation="*:appport:"} -physicalPath C:\wwwroot
  New-Item iis:\AppPools\projectname
  Set-ItemProperty iis:\AppPools\projectname managedRuntimeVersion v4.0 
  Set-ItemProperty iis:\AppPools\projectname ManagedPipelineMode 1
  New-Item IIS:\Sites\projectname\projectname -type Application -physicalpath C:\wwwroot\projectname
  Set-ItemProperty IIS:\Sites\projectname -name applicationPool -value projectname
  Set-ItemProperty IIS:\Sites\projectname\projectname -name applicationPool -value projectname
  Set-Location IIS:
  Start-WebSite -name "projectname"
}