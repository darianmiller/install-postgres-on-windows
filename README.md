# install-postgres-on-windows
PowerShell script to install [PostgreSQL](https://postgresql.org/) from a binary release zip on Windows.

- No dependencies
- MIT Licensed
- Download binary release zips from EDB: https://www.enterprisedb.com/download-postgresql-binaries
- Associated blog article can be found here: https://ideasawakened.com/post/2024-02-03-setup-postgresql-on-windows-from-zip

# Summary
You can simply run the script with the DownloadLatest switch (`Install-Postgres-On-Windows.ps1 -DownloadLatest`) and the latest release zip will be downloaded, then automatically installed to `C:\Postgres`, and you will end up with a new Windows Service named `Postgres` actively running and accepting all local connections on port 5432.  Alternately, manually download the latest release zip and provide it via the ArchiveFileName parameter. (`Install-Postgres-On-Windows.ps1 -ArchiveFileName postgresql-16.1-1-windows-x64-binaries.zip`)


# Parameters

Note: you need to provide at least one parameter as you must either specify the `ArchiveFileName` or the `DownloadLatest` switch.

## ArchiveFileName
This string parameter is the release zip to install (as previously downloaded from EDB.)  An example of the current latest release zip is `postgresql-16.1-1-windows-x64-binaries.zip` which is 330MB in size.

## DestinationPath
This optional string parameter is the path to unzip the binaries into and it defaults to `C:\Postgres` if not provided. In a full installation, there will be three child folders created: Admin, Data, and Server

## ServiceName
This optional string parameter is the name of the new Windows Service created.  If not provided, the ServiceName defaults to `Postgres`


## ListenPort
If specified, this optional integer parameter will override the default TCP port the server listens on which is [5432 by default](https://www.postgresql.org/docs/current/runtime-config-connection.html) as set in `postgresql.conf`

## DownloadLatest
If specified, this optional switch parameter overrides the ArchiveFileName and the latest release zip will be downloaded from EDB's website and installed.  Unfortunately there does not seem to be an API available for this, so the script currently resorts to web scraping (and may be prone to breakage if they alter the format of their site.)  The script will parse the files found on the [download-postgresql-binaries](https://www.enterprisedb.com/download-postgresql-binaries) page and pick the first one (as it will be the latest Windows installer.)  The file will be saved as `Postgres-Windows-Binaries.zip` within the TEMP folder and deleted once the installation is completed.

## UpdatePath
If this optional switch is specified, the script will update the PATH with the Postgres\bin folder (useful if you are running command line tools like psql.exe.)

## InstallPGAdmin
If this optional switch is specified, the script will create an Admin child folder and unzip the [pgAdmin 4](https://www.pgadmin.org/download/pgadmin-4-windows/) files.  Including this switch adds about 760MB worth of space and increases the installation time.  This is useful if you do not have pgAdmin or another tool like [HeidiSQL](https://www.heidisql.com/) already installed.

# Custom Settings

I have added a few common parameters to configure the instance, and more may be added in the future.  But, for now, these following settings were used for [initdb](https://www.postgresql.org/docs/current/app-initdb.html) during the initial installation process:

- The default [encoding](https://www.postgresql.org/docs/current/multibyte.html#MULTIBYTE-CHARSET-SUPPORTED) is set to `UTF8` with a [locale](https://www.postgresql.org/docs/current/locale.html) of `en_US.UTF-8`
- The folder used for the [database cluster](https://www.postgresql.org/docs/current/glossary.html#GLOSSARY-DB-CLUSTER) is set to `DestinationPath`\Data
- The new Windows Service created is set to `Automatic (Delayed Startup)` and the service is started during the installation process.
- The [bootstrap superuser](https://www.postgresql.org/docs/current/glossary.html#GLOSSARY-BOOTSTRAP-SUPERUSER) is named `postgres` and has `postgres` as its password
- The default [time zone](https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-TIMEZONES) is set to `UTC`

All settings not set by parameters, or listed above in Custom Settings, will utilize the Postgres default values, such as:
- The default [authentication method](https://www.postgresql.org/docs/current/auth-methods.html) is `trust` which is meant for local workstations, not multi-user servers.
- The default [max_connections](https://www.postgresql.org/docs/current/runtime-config-connection.html#GUC-MAX-CONNECTIONS) is set automatically by initdb and is typically set to `100`.

