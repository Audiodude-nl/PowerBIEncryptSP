#
#  This script updates or creates a SQL datasource on the gateway server
#  Uses parts of the PowerBI C# SDK
#  You need to build the DLL file before running this script.
#  You need to make sure the service principal has WORKING credentials.
#  If you can create the datasource in the portal of powerbi, you can create it with this as well.
#




#
#  Install PowerBIMgmt module
#

if (-NOT (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
    Write-Host "Module MicrosoftPowerBIMgmt needs to be installed."
    install-module MicrosoftPowerBIMgmt -Confirm:$False -Force
}
try{
    import-module -Name MicrosoftPowerBIMgmt
}catch {
    write-host ("Import module failed.")
    exit 1
}

#
# Login to PowerBI 
#
# This needs to happen with a USER account that has a PowerBI LICENCE !!!
#
try{
    Connect-PowerBIServiceAccount                
}catch{
    Write-Host ("Failed to logon to powerBI")
    exit 1
}


#
# Load the DLL so we can use the encryption 
#
try{
    Write-Host ("Load DLL into memory")
    Add-Type -Path .\PowerBIEncryptSP.dll -ErrorAction SilentlyContinue
}catch{
    Write-Host ("Failed to load the DLL")
    exit 1
}


#
# Create PowerBI authorization headers
#
function createPowerBiHeaders {
    $token = Get-PowerBIAccessToken -AsString
    $headers = @{
        Accept        = "application/json"
        Authorization = $token
        "Content-Type" = "application/json"
    }
    return $headers
}


#
#  My environment loads the secret from an Azure Keyvault, where the secret name is the same as the service principal name. 
#  If your environment is NOT using Azure/Key Vaults, replace $ClientSecret with a string containing the secret. 
#

function updateDataSourceCredentials{
    param (
        [Parameter(Mandatory = $true)][string]$dataSourceName,           # Name of the Datasource on PowerBI
        [Parameter(Mandatory = $true)][string]$gatewayName,              # Name of the gateway server (Not the cluster name !)
        [Parameter(Mandatory = $true)][string]$ApplicationName ,         # Service Principal name that is to be used for authentication. (Access rights on the SQL server needs to be done before you create the datasource.)
        [Parameter(Mandatory = $true)][string]$tennantId,                # tenant Id
        [Parameter(Mandatory = $true)][string]$keyVaultName              # Name of the Key Vault containing the secret
    )
    Write-Host ("Get the new Client Secret from Keyvault")
    # Credentials for the Datasource
    $ServicePrincipalId = (Get-AzADApplication -DisplayName $ApplicationName).AppId
    $ClientSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $ApplicationName -AsPlainText
    Write-Host ("Create headers for requests")
    # Get a powerBI token and create a header we can use to authenticate
    $headers = createPowerBiHeaders
    # Get all gateways and get the Id of the gateway which name we specified
    Write-Host ("Get all gateways")
    $gateways = Invoke-PowerBIRestMethod `
                    -Url "https://api.powerbi.com/v1.0/myorg/gateways" `
                    -Method GET ` | ConvertFrom-Json   

    $GatewayId = ($gateways.value | Where-Object name -eq $gatewayName).id
    Write-Host ("Get the specific gateway")
    # Get the gateway
    $gw = Invoke-PowerBIRestMethod `
                    -Url "https://api.powerbi.com/v1.0/myorg/gateways/$GatewayId" `
                    -Method GET ` | ConvertFrom-Json                

    # On-Prem Gateway exponent and modulus
    $gatewayExponent = $gw.publicKey.exponent
    $gatewayModulus = $gw.publicKey.modulus
    Write-Host ("Get all datasources")

    #check if Datasource exists:
    $uri = 'https://api.powerbi.com/v2.0/myorg/me/gatewayClusters/'+$GatewayId+'/datasources'
    $result = Invoke-RestMethod -Headers $headers -Method GET -Uri $uri 
    $datasource = $result.value | Where-Object datasourceName -eq $dataSourceName 

    # Exit if datasource does not exist.
    if ($datasource.Count -eq 0 ){
        Write-Host("Datasource does not exist !!")  
        exit 1
    }

    Write-Host("Updating credentials for : " + $dataSourceName)
    # update the datasource
    $uri = 'https://api.powerbi.com/v2.0/myorg/me/gatewayClusters/' + $GatewayId + '/datasources/' + $datasource.id + '/credentials'

    #
    #  This is the important bit : Creating the encrypted credentials using the gateway modulator and Exponent
    #
    # The PowerBI SDK unfortunately is really old. 4.2 was using Microsoft.REST which is depreciated. So this one uses NET8.0 
    # and I've stripped it from all other functionality. Although I left other authentication methods in.

    $gatewayKeyObj = [PowerBIEncryptSP.Models.GatewayPublicKey]::new($GatewayExponent, $GatewayModulus)
    $credentialsEncryptor = [PowerBIEncryptSP.Extensions.AsymmetricKeyEncryptor]::new($gatewayKeyObj)
    $CredentialData = [PowerBIEncryptSP.Models.Credentials.ServicePrincipalCredentials]::new($tennantId,$ServicePrincipalId,$ClientSecret)
    $credentialDetails = [PowerBIEncryptSP.Models.CredentialDetails]::new($CredentialData,[PowerBIEncryptSP.Models.PrivacyLevel]::Organizational,[PowerBIEncryptSP.Models.EncryptedConnection]::Encrypted,$credentialsEncryptor)

    #
    # Create the body of the Post API call.
    #
    $Body = @{
        "credentialDetails" = @{
            $GatewayId = @{
                "CredentialType" = "ServicePrincipal"
                "credentials" = $credentialDetails.Credentials
                "EncryptedConnection" =  "Any"
                "encryptionAlgorithm" = "RSA-OAEP"
                "PrivacyLevel" = "Organizational"
                "skipTestConnection" = $false
            }
        }
    } | ConvertTo-Json

    Write-Host ("Do actual update")
    try{
        $result = Invoke-RestMethod -Headers $headers -Method PATCH -Uri $uri -Body $Body
    }catch{
        $MyError = $_
    }
    #
    # We are using ondemand SQL pools which unfortunately give issues at first try, so I try again.. :-)
    #
    if ($MyError -match 'The SQL pool is warming up' ){
        Write-Host ('Retrying - SQL pools is not awake.')
        try{
            Start-Sleep -Seconds 60
            $result = Invoke-RestMethod -Headers $headers -Method PATCH -Uri $uri -Body $Body
        }catch{
            Write-Host ("Update Faild")
            exit 1
        }
    }
    Write-Host ("Update done !")
}

function createDataSourceCredentials{
    param (
        [Parameter(Mandatory = $true)][string]$server,                   # FQDN of the SQL server Example :  'mySynapseSQLserver-ondemand.sql.azuresynapse.net'
        [Parameter(Mandatory = $true)][string]$database,                 # Database name 
        [Parameter(Mandatory = $true)][string]$dataSourceName,           # Name of the Datasource on PowerBI
        [Parameter(Mandatory = $true)][string]$gatewayName,              # Name of the gateway server (Not the cluster name !)
        [Parameter(Mandatory = $true)][string]$ApplicationName ,         # Service Principal name that is to be used for authentication. (Access rights on the SQL server needs to be done before you create the datasource.)
        [Parameter(Mandatory = $true)][string]$tennantId,                # tenant Id
        [Parameter(Mandatory = $true)][string]$keyVaultName              # Name of the Key Vault containing the secret
    )

    # Credentials for the Datasource
    $ServicePrincipalId = (Get-AzADApplication -DisplayName $ApplicationName).AppId
    $ClientSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $ApplicationName -AsPlainText

    # Get a powerBI token and create a header we can use to authenticate
    $headers = createPowerBiHeaders
    # Get all gateways and get the Id of the gateway which name we specified
    $gateways = Invoke-PowerBIRestMethod `
                    -Url "https://api.powerbi.com/v1.0/myorg/gateways" `
                    -Method GET ` | ConvertFrom-Json   

    $GatewayId = ($gateways.value | Where-Object name -eq $gatewayName).id

    # Get the gateway
    $gw = Invoke-PowerBIRestMethod `
                    -Url "https://api.powerbi.com/v1.0/myorg/gateways/$GatewayId" `
                    -Method GET ` | ConvertFrom-Json                

    # On-Prem Gateway exponent and modulus
    $gatewayExponent = $gw.publicKey.exponent
    $gatewayModulus = $gw.publicKey.modulus

    # Add-Type -Path .\azure.identity\1.14.0\lib\netstandard2.0\Azure.Identity.dll         # Maybe not required ????
    # Add-Type -Path .\newtonsoft.json\13.0.1\lib\netstandard2.0\Newtonsoft.Json.dll       # Maybe not required ????
    Add-Type -Path .\PowerBIEncryptSP.dll -ErrorAction SilentlyContinue

    #check if Datasource exists:
    $uri = 'https://api.powerbi.com/v2.0/myorg/me/gatewayClusters/'+$GatewayId+'/datasources'
    $result = Invoke-RestMethod -Headers $headers -Method GET -Uri $uri 
    $datasource = $result.value | Where-Object datasourceName -eq $dataSourceName 

    # update or create ?
    if ($datasource.Count -eq 0 ){
        Write-Host("Creating new datasource for : ")
        # create a new datasource
        $gatewayKeyObj = [PowerBIEncryptSP.Models.GatewayPublicKey]::new($GatewayExponent, $GatewayModulus)
        $credentialsEncryptor = [PowerBIEncryptSP.Extensions.AsymmetricKeyEncryptor]::new($gatewayKeyObj)
        $CredentialData = [PowerBIEncryptSP.Models.Credentials.ServicePrincipalCredentials]::new($tennantId,$ServicePrincipalId,$ClientSecret)
        $credentialDetails = [PowerBIEncryptSP.Models.CredentialDetails]::new($CredentialData,[PowerBIEncryptSP.Models.PrivacyLevel]::Organizational,[PowerBIEncryptSP.Models.EncryptedConnection]::Encrypted,$credentialsEncryptor)

        $uri = ("https://api.powerbi.com/v2.0/myorg/me/gatewayClusters/"+$GatewayId+"/datasources")

        $Body = @{
            "datasourceType"= "Sql"
            "referenceDatasource" = $false
            "connectionDetails"= ('{"server":"'+$server+'","database":"'+$database+'"}')
            "datasourceName"= $dataSourceName
            "credentialDetails" = @{
                $GatewayId = @{
                    "CredentialType" = "ServicePrincipal"
                    "credentials" = $credentialDetails.Credentials
                    "EncryptedConnection" =  "Any"
                    "encryptionAlgorithm" = "RSA-OAEP"
                    "PrivacyLevel" = "Organizational"
                }
            }
        } | ConvertTo-Json

        $result = Invoke-RestMethod -Headers $headers -Method POST -Uri $uri -Body $Body
    }
    return $result
}
