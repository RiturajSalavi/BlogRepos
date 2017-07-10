# This script assumes following variables to be declared in the global scope.
# $fakeRun, $projectName, $envName, $resGroupName, $resourceLocation

function Install-AzureRM-IfRequired
{
    if (!(Get-Module -ListAvailable -Name AzureRM)) {
        Write-Host "AzureRM powershell module not installed. Installing... (you need admin priviledges for this)"
        Install-Module AzureRM
    }
}

function Initiate-Azure-Login
{
	Login-AzureRmAccount
}

function Select-Subscription
{
	param([string]$azureSubscription)
	
	Set-AzureRmContext -SubscriptionName $azureSubscription
}

function Generate-ResourceName
{
    param([string]$suffix)

    $name = "$($projectName)$($envName)$($suffix)"
    return $name
}

function Create-ResourceGroup
{
    $name = Generate-ResourceName "Resources"
    Write-Host "Creating ResourceGroup: $($name)"

    if ($fakeRun -eq $false)
    {
        $rg = New-AzureRmResourceGroup -Location $resourceLocation -Name $name -Force
    }

    return $name
}

function Create-WebAppServicePlan
{
    $name = Generate-ResourceName "ASP"
    Write-Host "Creating WebAppServicePlan (Free tier) : $($name)"

    if ($fakeRun -eq $false)
    {
        $asp = New-AzureRmAppServicePlan -ResourceGroupName $resGroupName -Name $name -location $resourceLocation -Tier "Free"
    }

    return $name
}

function Create-AppInsights
{
    param([string]$insightsName)

    $name = Generate-ResourceName $insightsName
    Write-Host "Creating AppInsights : $($name)"

    $instrumentationKey = "dummykey"

    if ($fakeRun -eq $false)
    {
		#Application Insights only supports very few resource locations.
        $resource = New-AzureRmResource `
          -ResourceName $name `
          -ResourceGroupName $resGroupName `
          -Tag @{ applicationType = "web" } `
          -ResourceType "Microsoft.Insights/components" `
          -Location "East US" `
          -Properties @{"Application_Type"="web"} `
          -Force

        $instrumentationKey = $resource.Properties.InstrumentationKey
    }

    return $instrumentationKey
}

function Create-WebApp
{
    param([string]$app, [Hashtable]$appSettings, [Hashtable]$connectionStrings, [string]$customDomain)

    $name = Generate-ResourceName $app
    Write-Host "Creating WebApp : $($name)"

    if ($fakeRun -eq $false)
    {
        $webApp = New-AzureRmWebApp -ResourceGroupName $resGroupName -Name $name -Location $resourceLocation -AppServicePlan $aspName
        
        if ($appSettings -Or $connectionStrings)
        {
            $mergedAppSettings = Merge-HashTables $webApp.SiteConfig.AppSettings $appSettings
            $mergedConnectionStrings = Merge-HashTables $webApp.SiteConfig.ConnectionStrings $connectionStrings

			Write-Host $mergedAppSettings
			Write-Host $mergedConnectionStrings
			
            Write-Host "Updating appsettings and connection strings for $($name)..."
            Set-AzureRMWebApp -ResourceGroupName $resGroupName -Name $name -AppSettings $mergedAppSettings -ConnectionStrings $mergedConnectionStrings
        }
        
        Write-Host "Updating general webapp settings for $($name)..."
        Set-AzureRMWebApp -ResourceGroupName $resGroupName -Name $name -Use32BitWorkerProcess $True -PhpVersion "Off"
		
		if ($customDomain)
		{
			Write-Host "Updating custom domain for $($name)..."
			Set-AzureRMWebApp -ResourceGroupName $resGroupName -Name $name -HostNames @($customDomain, "$($name).azurewebsites.net")
		}
    }
}

function Merge-HashTables
{
    param($ht1, $ht2)

    if (!$ht1)
    {
        $ht1 = @{}
    }

    if (!$ht2)
    {
        $ht2 = @{}
    }

    $newHt = @{}
	ForEach ($kvp in $ht1.GetEnumerator()) {
		$newHt[$kvp.Name] = $kvp.Value
	}
    ForEach ($kvp in $ht2.GetEnumerator()) {
		$newHt[$kvp.Name] = $kvp.Value
	}

    return $newHt
}

function Create-SqlServer
{
	param([string]$sqlServerAdmin, [string]$sqlServerAdminPassword, [string]$ipStart, [string]$ipEnd)

    $name = Generate-ResourceName "Sql"
    $name = $name.ToLower()
    Write-Host "Creating SqlServer: $($name)"
    
    if ($fakeRun -eq $false)
    {
        $sqlSecurePassword = ConvertTo-SecureString -String $sqlServerAdminPassword -AsPlainText -Force
        $sqlServerCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlServerAdmin, $sqlSecurePassword
        $ss = New-AzureRmSqlServer -ResourceGroupName $resGroupName -Location $resourceLocation -ServerName $name -SqlAdministratorCredentials $sqlServerCreds
        $frule = New-AzureRmSqlServerFirewallRule -ResourceGroupName $resGroupName -ServerName $name -FirewallRuleName "MyFirewallRule" -StartIpAddress $ipStart -EndIpAddress $ipEnd
    }

    return $name
}

function Create-SqlDatabase
{
    param([string]$db)

    $name = Generate-ResourceName $db
    Write-Host "Creating Sql database (Basic tier) : $($name)"

    if ($fakeRun -eq $false)
    {
	    $db = New-AzureRmSqlDatabase -ResourceGroupName $resGroupName -ServerName $sqlServerName -DatabaseName $name -Edition "Basic" -CollationName "SQL_Latin1_General_CP1_CI_AS"
    }

    return $name
}

function Generate-SqlConnectionString
{
    param([string]$dbName,[string]$dbUserName,[string]$dbUserPassword)
    return "Data Source=tcp:$($sqlServerName).database.windows.net;Database=$($dbName);User ID=$($dbUserName);Password=$($dbUserPassword);multipleactiveresultsets=True;"
}

function Create-StorageAccount
{
    $name = Generate-ResourceName "storage"
    $name = $name.ToLower()

    Write-Host "Creating the Storage Account: $($name)"

    if ($fakeRun -eq $false)
    {
        $sa = New-AzureRmStorageAccount -ResourceGroupName $resGroupName -StorageAccountName $name -Location $resourceLocation -SkuName "Standard_LRS"
    }

    return $name
}

function Create-BlobContainers
{
    param($accountName,$blobContainers)

    $storageContext = $null
    if ($fakeRun -eq $false)
    {
        $storageContext = (Get-AzureRmStorageAccount -ResourceGroupName $resGroupName -Name $accountName).Context
    }

    foreach ($key in $blobContainers.Keys)
    {
        $containerName = $key
		$permission = $blobContainers[$key]
        Write-Host "Creating blob container: $containerName (Access: $permission)"

        if ($fakeRun -eq $false)
        {
            if ($permission -eq "private") {
    	        $sCont = New-AzureStorageContainer –Context $storageContext -Name $containerName -Permission Off
            }
            elseif ($permission -eq "public") {
    	        $sCont = New-AzureStorageContainer –Context $storageContext -Name $containerName -Permission Blob
            }
            elseif ($permission -eq "fullpublic") {
    	        $sCont = New-AzureStorageContainer –Context $storageContext -Name $containerName -Permission Container
            }
        }
    }
}

function Create-StorageTables
{
    param($accountName,$storageTableNames)

    $storageContext = $null
    if ($fakeRun -eq $false)
    {
        $storageContext = (Get-AzureRmStorageAccount -ResourceGroupName $resGroupName -Name $accountName).Context
    }

    foreach ($tableName in $storageTableNames)
    {
        Write-Host "Creating storage table: $($tableName)"

        if ($fakeRun -eq $false)
        {
            $sTable = New-AzureStorageTable –Context $storageContext –Name $tableName
        }
    }
}

function Create-ServiceBusNamespace
{
    $name = Generate-ResourceName "sbus"
    $name = $name.ToLower()

    Write-Host "Creating the ServiceBusNamespace: $($name) (Basic tier)"

    if ($fakeRun -eq $false)
    {
        $sb = New-AzureRmServiceBusNamespace -ResourceGroup $resGroupName -NamespaceName $name `
            -Location $resourceLocation `
            -SkuName "Basic"
    }

    return $name
}

function Create-ServiceBusQueues
{
    param($namespaceName,$queueNames)

    foreach ($qName in $queueNames)
    {
        Write-Host "Creating ServiceBus queue: $($qName)"

        if ($fakeRun -eq $false)
        {
            $sbq = New-AzureRmServiceBusQueue -ResourceGroup $resGroupName -NamespaceName $namespaceName `
                -QueueName $qName `
                -EnablePartitioning $false `
                -RequiresDuplicateDetection $false `
                -DefaultMessageTimeToLive "2.00:00:00" # 2 days
        }
    }
}

function Create-RedisCache
{
    $name = Generate-ResourceName "Redis"

    Write-Host "Creating RedisCache: $($name) (Basic 250MB)"

    $redisCacheConnectionString = "dummystring"

    if ($fakeRun -eq $false)
    {
        $redis = New-AzureRmRedisCache -ResourceGroup $resGroupName -Name $name -Location $resourceLocation `
            -Sku "Basic" -Size "250MB"
        $redisAccessKey = Get-AzureRmRedisCacheKey -ResourceGroupName $resGroupName -Name $name
        $redisCacheConnectionString = "$($reisCacheName).redis.cache.windows.net:6380,password=$($redisAccessKey.PrimaryKey),ssl=True,abortConnect=False"
    }

    return $redisCacheConnectionString
}