<#
.Synopsis
   Install PostgreSQL on Windows from a binaries zipfile as published by EDB  

.EXAMPLE
   Extract the latest release zip to 'C:\Postgres' and create/start a 'Postgres' named Windows service:
   Install-Postgres-On-Windows.ps1 -ArchiveFileName postgresql-16.1-1-windows-x64-binaries.zip

.EXAMPLE
   Download latest and install to 'C:\Postgres' and create/start a 'Postgres' named Windows service:
   Install-Postgres-On-Windows.ps1 -DownloadLatest

.EXAMPLE
   Extract the release zip named 'Latest.zip' to 'C:\Server\PostgreSQL' and create/start a 'PostgreSQL' named Windows service with the server listening on port 5433
   Add C:\Server\PostgreSQL\bin to the system PATH environment variable
   Also extracts pgAdmin 4 into the 'C:\Server\PostgreSQL\Admin' folder
   Install-Postgres-On-Windows.ps1 -ArchiveFileName Latest.zip -DestinationPath C:\Server\PostgreSQL -ServiceName PostgreSQL -ListenPort 5433 -UpdatePath -InstallPGAdmin

.NOTES
   Latest version is on GitHub: https://github.com/darianmiller/install-postgres-on-windows 
   Version 1.0 2024-02-03 Darian Miller
   MIT Licensed

.Parameter ArchiveFileName
    Specify full path of PostgreSQL binaries release zip filename (or use the DownloadLatest switch)

.Parameter DestinationPath
    Specify path to destination folder, defaults to 'C:\Postgres'

.Parameter ServiceName
    Specify the name of the Windows Service, defaults to 'Postgres'
    
.Parameter ListenPort
    Provide optional integer value to override the default port of 5432

.Parameter DownloadLatest
    Optional switch to download latest version from GitHub (can be used instead of specifying archive file)

.Parameter UpdatePath
    Optional switch to add the Postgres\bin folder to the PATH

.Parameter InstallPGAdmin
    Optional switch to also extract pgAdmin
#>

[CmdletBinding()]
param(
    [string]$ArchiveFileName,
    [string]$DestinationPath = "C:\Postgres",
    [string]$ServiceName = "Postgres",
    [int]$ListenPort = 5432,
    [switch]$DownloadLatest,
    [switch]$UpdatePath,
    [switch]$InstallPGAdmin
)


#Latest binary zipfiles are listed first, (usually) starting with Windows
#As of April 12, 2025, latest version is "postgresql-17.4-1-windows-x64-binaries.zip" (331MB)
#which correlates to:  https://sbp.enterprisedb.com/getfile.jsp?fileid=1259403

function Get-FirstMatchingDownloadHref {
    param()

    $releasesUri = "https://www.enterprisedb.com/download-postgresql-binaries"
    Write-Verbose "Fetching download page from '$releasesUri'"

    $response = Invoke-WebRequest -Uri $releasesUri
    $html = $response.Content

    # Normalize and split HTML
    $html = $html -replace '><', ">`n<"
    $htmlLines = $html -replace "`r", "" -split "`n"
    Write-Verbose ("Downloaded {0} lines of HTML content." -f $htmlLines.Length)

    $matches = @()

    for ($i = 0; $i -lt $htmlLines.Length; $i++) {
        $line = $htmlLines[$i]

        if ($line -match '<img[^>]+alt=["'']Windows\s*x86-64["'']') {
            Write-Verbose ("Found Windows x86-64 <img> on line {0}" -f $i)

            # Look backward to find the <a href=...> wrapping this image
            for ($j = 1; $j -le 6 -and ($i - $j) -ge 0; $j++) {
                $prevLine = $htmlLines[$i - $j]
                if ($prevLine -match '<a[^>]+href=["''](https://sbp\.enterprisedb\.com/getfile\.jsp\?fileid=\d+)["'']') {
                    $url = $matches[1]
                    Write-Verbose "Found link before image: $url"
					return $url
                }
            }
        }
    }
    return $null
}


function DownloadLatestReleaseFromEDB {

    $Result = ""
  
    Write-Host "- Attempting to download latest binary zip"
    $downloadUri = Get-FirstMatchingDownloadHref
  
    if ($downloadUri -ne $null) {
  
        Write-Verbose "- Latest Binaries zip from EDB determined to be: '$downloadUri'"
        Write-Host "- Downloading release zip"
  
        $Result = Join-Path -Path $([System.IO.Path]::GetTempPath()) -ChildPath "Postgres-Windows-Binaries.zip"
  
        Write-Verbose "Temporary file to be created: '$Result'"
  
        Invoke-WebRequest -Uri $downloadUri -Out $Result        
    }
    else {
  
        Throw "ERROR: Could not determine latest release' (Temporary EDB website issues or an update of this script is required)"
  
    }
  
    return $Result
}

function Unzip {
    param (
        [string]$ArchiveFileName,
        [string]$DestinationPath
    )
  
    Write-Host "- Extracting archive file '$ArchiveFileName' to '$DestinationPath'"
  
    #Not using powershell command as it does not offer --strip-components type functionality
    tar -xf "$ArchiveFileName" --strip-components=1 --exclude="./doc/*" --exclude="./include/*" --exclude="./StackBuilder/*" --exclude="./symbols/*" --exclude="./pgAdmin 4/*" -C "$DestinationPath\Server"
    if ($InstallPGAdmin) {
        tar -xf "$ArchiveFileName" --strip-components=2 -C "$DestinationPath\Admin" "pgsql/pgAdmin 4/"
    }
      
    if ($LASTEXITCODE -ne 0) {
  
        throw "ERROR: Failed to extract '$ArchiveFileName', TAR exit code '$LASTEXITCODE'"
  
    } 
}

function SetDefaultPort {
    param (
        [int] $ListenPort,
        [string] $DataDirectory 
    )
    $confFilePath = Join-Path $DataDirectory "postgresql.conf"

    if (Test-Path $confFilePath -PathType Leaf) {

        $confContent = Get-Content -Path $confFilePath 
        $portUpdated = $false

        for ($i = 0; $i -lt $confContent.Count; $i++) {
            $line = $confContent[$i]

            if ($line -match '^\s*#?\s*port\s*=\s*\d+') {

                $confContent[$i] = "port = $ListenPort"
                $portUpdated = $true
                Write-Host "Port number updated to $ListenPort"
                break 
            }
        }

        if ($portUpdated) {
            $confContent | Set-Content $confFilePath
            Write-Host "Saved changes to postgresql.conf"
        }
        else {
            Write-Host "Error: Port setting not found in postgresql.conf"
        }   
    }
    else {
        Write-Error "Error: postgresql.conf file not found in $DataDirectory"
    }
}  

  
$PG_SUPERUSER = "postgres"
$PG_SERVERHOME = "$DestinationPath\Server"
$PG_ADMINHOME = "$DestinationPath\Admin"
$PG_DATAHOME = "$DestinationPath\Data"


if (Test-Path $DestinationPath) {
    #Prevent accidental corruption of an existing instance
    Write-Host "PostgreSQL root folder already exists [$DestinationPath]"
    exit 101
}

Write-Verbose "- Creating installation directories within '$PG_SERVERHOME'"
New-Item -ItemType Directory -Path $PG_SERVERHOME | Out-Null
if ($InstallPGAdmin) {
    New-Item -ItemType Directory -Path $PG_ADMINHOME | Out-Null
}
#Note: do not auto-create the DATA folder - let InitDB create it so it can set proper permissions
#New-Item -ItemType Directory -Path $PG_DATAHOME | Out-Null


if ($DownloadLatest) {
    $tempFile = DownloadLatestReleaseFromEDB
    if ($tempFile -ne "") {
        try {
            Unzip -ArchiveFileName $tempFile -DestinationPath $DestinationPath
        }
        finally {
            if (Test-Path -Path $tempFile -PathType Leaf) {
  
                Write-Verbose "Removing Temporary downloaded file: '$tempFile'"
                Remove-Item $tempFile -Force
            }
        }
    }
}
else {    
    if ($ArchiveFileName -ne "") {
        Unzip -ArchiveFileName $ArchiveFileName -DestinationPath $DestinationPath
    }
    else {

        Throw "ArchiveName (or DownloadLatest switch) not specified"

    }
}


if ($UpdatePath) {
    $currentEnv = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)
    Write-Verbose "Current PATH: '$currentEnv'"
    if ($currentEnv -notlike "*$PG_SERVERHOME\bin*") {
        $newPath = "$currentEnv;$PG_SERVERHOME\bin"

        Write-Host "- Adding Postgres bin folder to system PATH: '$PG_SERVERHOME\bin'"
        Write-Verbose "New system PATH will be: '$newPath'"

        [Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::Machine)
    }
    else {

        Write-Verbose "Note: System PATH already contains '$PG_SERVERHOME\bin'"

    }
    $env:PATH += ";$PG_SERVERHOME\bin"
}


Write-Host "- Initializing a new Postgres database cluster using initdb"
Write-Host

# This command sets up the necessary directory structure and initializes the configuration files (like address/port/mem allocation)
# Databases within this cluster (root folder) share the same PostgreSQL server process (instance)
$env:TZ = "UTC"

#Workaround for Windows ownership issues - not needed if the data folder doesn't exist yet
#icacls "$PG_DATAHOME" /grant Everyone:F /T

Add-Content -Path temp_pgsql.pw -Value "postgres"
try {
    & "$PG_SERVERHOME\bin\initdb.exe" -D "$PG_DATAHOME" -E UTF8 -U "$PG_SUPERUSER" --locale=en_US.UTF-8 --pwfile=temp_pgsql.pw --no-instructions    
}
finally {
    Remove-Item -Path temp_pgsql.pw -Force
}

if ($ListenPort -ne 5432) {
    SetDefaultPort -ListenPort $ListenPort -DataDirectory $PG_DATAHOME
}


Write-Host
Write-Host "- Adding and starting a new Windows Service named: '$ServiceName'"
Write-Host

& "$PG_SERVERHOME\bin\pg_ctl.exe" register -N "$ServiceName" -U LocalSystem -D "$PG_DATAHOME"

#Note: PowerShell 7 is required for DelayedAuto option
#Set-Service -Name "PostgreSQL" -StartupType DelayedAuto
& "sc.exe" config "$ServiceName" start=delayed-auto

#All done - start up Postgres!
& "net" start "$ServiceName"
$serviceState = (Get-Service -Name $ServiceName).Status
if ($serviceState -ne "Running") {
    Throw "Failed to start $ServiceName service."
}

#toconsider: optionally set environment variables:
# PGHOST, PGPORT, PGPASSWORD, PGDATABASE, PGOPTIONS...
#[Environment]::SetEnvironmentVariable("PGDATA", "$PG_DATAHOME", [EnvironmentVariableTarget]::Machine)
#[Environment]::SetEnvironmentVariable("PGUSER", "$PG_SUPERUSER", [EnvironmentVariableTarget]::Machine)

#toconsider: Display version and exit, just for logging
#& "$PG_SERVERHOME\bin\initdb.exe" --version

#toconsider: List all available databases then exit, just for logging
# Note, will use current Windows username by default if -U xxx or --username=xxx not specified
# & "$PG_SERVERHOME\bin\psql" -p $ListenPort -U "$PG_SUPERUSER" -l

Write-Host "PostgreSQL installed!" -ForegroundColor Green