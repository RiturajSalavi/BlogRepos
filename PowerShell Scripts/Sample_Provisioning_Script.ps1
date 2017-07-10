Param(
  [string]$azureSubscription,
  [string]$resourceLocation,  #eg. eastasia
  [string]$envName #eg. Dev
)

Write-Host "Subscription: $azureSubscription"
Write-Host "Location: $resourceLocation"
Write-Host "Environment: $envName"

$fakeRun = $true #Whether to actually create Azure resources or not
$projectName = "YourProjectName"

#Worker code

#Include the helper script
. ".\Provisioning_Helpers.ps1"

if ($fakeRun -eq $true)
{
    Write-Host "Running in fake mode." -foreground "yellow"
}
else
{
    Install-AzureRM-IfRequired
    Initiate-Azure-Login
    Select-Subscription $azureSubscription
}

echo "Starting resource provisioning..."

$resGroupName = Create-ResourceGroup


#Create SQL Server and database

$sqlServerAdmin = "myadmin"
$sqlServerAdminPassword = "Myp@ssw0rd"
$dbUser = "myuser"
$dbUserPassword = "Myp@ssw0rd"

$sqlServerName = Create-SqlServer $sqlServerAdmin $sqlServerAdminPassword "startIP" "endIP"
$sysDbName = Create-SqlDatabase "PrimaryDB"
$sysDbConnectionString = Generate-SqlConnectionString $sysDbName $dbUser $dbUserPassword

#Create Redis Cache
$redisConnectionString = Create-RedisCache

#Create the app service plan
$aspName = Create-WebAppServicePlan


#Create the web app and configure app settings
$connectionStrings = @{}
$connectionStrings["DataContext"] = @{ Type="SQLServer"; Value=$sysDbConnectionString }
$connectionStrings["RedisCache"] = @{ Type="Custom"; Value=$redisConnectionString }

$appSettings = @{}
$appSettings["SampleAppSetting1"] = "True"
$appSettings["SampleAppSetting2"] = "Dummy"

$appInsightsKey = Create-AppInsights "PortalInsights"
$appSettings["ApplicationInsights:InstrumentationKey"] = $appInsightsKey

Create-WebApp "PortalWeb" -appSettings $appSettings -connectionStrings $connectionStrings


#Create storage account and related resources

$storageAccountName = Create-StorageAccount

$containerList = @{"blobcont1" = "public"; "blobcont2" = "private"}
Create-BlobContainers $storageAccountName $containerList

$storageTables = @("StorageTable1", "StorageTable2")
Create-StorageTables $storageAccountName $storageTables

#Create ServiceBus namespace and related resources
$serviceBusNamespace = Create-ServiceBusNamespace

$serviceBusQueues = @("q1", "q2")
Create-ServiceBusQueues $serviceBusNamespace $serviceBusQueues


echo "Done."