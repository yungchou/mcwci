<# 
Microsoft Cloud Workshop: BCDR
.File Name
 - ASRRunBookWEB.ps1

.What calls this script?
 - This is an Azure Automation Runbook used for Failing over and Failing Back the Web Servers Region to Region.
 
 - Azure Site Recovery is required for this to function properly as it relies on the context,
   of the failover type passed.

.What does this script do?  
 - When there is a Failover from Primary to Secondary the RecoveryPlanContext.FailoverDirection property 
   is set to: "PrimaryToSecondary".
 
 - The WebVMs that failover to the Secondary Site will be added to the Backend Pool of the External Load Balancer.

 - When there is a Failback from Secondary to Primary the RecoveryPlanContext.FailoverDirection property 
   is set to: "SecondaryToPrimary".
 
 - The WebVMs that failback to the Primary Site will be added to the Backend Pool of the External Load Balancer.

#>
workflow ASRWEBFailover
{
    param ( 
        [parameter(Mandatory=$false)] 
        [Object]$RecoveryPlanContext 
    ) 
    $connectionName = "AzureRunAsConnection" 
	    
Try 
 {
    #Logging in to Azure...

    "Logging in to Azure..."
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection 
     Add-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

    "Selecting Azure subscription..."
    Select-AzSubscription -SubscriptionId $Conn.SubscriptionID -TenantId $Conn.tenantid 
 }
Catch
 {
      $ErrorMessage = 'Login to Azure subscription failed.'
      $ErrorMessage += " `n"
      $ErrorMessage += 'Error: '
      $ErrorMessage += $_
      Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
 }
	
    $RPVariable = Get-AutomationVariable -Name $RecoveryPlanContext.RecoveryPlanName
    $RPVariable = $RPVariable | convertfrom-json
	
	"Configurations used by this Runbook for the Failover..."
    Write-Output $RPVariable

	"Determining if Failover or Failback..."
	Write-Output $RecoveryPlanContext.FailoverDirection
	
	"Configuring Script based on Direction of Failover..."
    if ($RecoveryPlanContext.FailoverDirection -eq "PrimaryToSecondary") { 
		

        InlineScript {
            $RP = $Using:RPVariable
			$LBNAME   = $RP.SecondarySiteWebLBName
			$VNETNAME = $RP.SecondarySiteVNetName
			$SUBNETNAME = $RP.SecondarySiteWebSubnetName
			$VNETRG   = $RP.SecondarySiteRG
			$WebVM1RG = $RP.SecondarySiteRG
			$WebVM2RG = $RP.SecondarySiteRG

			Write-Output "Adding WebVMs to the External Loadbalancer at the Secondary Site..."
			$vnet = Get-AzVirtualNetwork -Name $VNETNAME -ResourceGroupName $VNETRG
			$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SUBNETNAME -VirtualNetwork $vnet
			$loadBalancer = Get-AzLoadBalancer -Name $LBNAME -ResourceGroupName $VNETRG
			$WebVM1NIC = Get-AzNetworkInterface -ResourceGroupName $WebVM1RG | Where-Object {$_.Name -like 'WebVM1*'}
			$WebVM1NIC | Set-AzNetworkInterfaceIpConfig -Name $WebVM1NIC.IpConfigurations[0].Name -LoadBalancerBackendAddressPoolId $loadBalancer.BackendAddressPools.id -SubnetId $subnet.id
			$WebVM1NIC | Set-AzNetworkInterface
			$WebVM2NIC = Get-AzNetworkInterface -ResourceGroupName $WebVM2RG | Where-Object {$_.Name -like 'WebVM2*'}
			$WebVM2NIC | Set-AzNetworkInterfaceIpConfig -Name $WebVM2NIC.IpConfigurations[0].Name -LoadBalancerBackendAddressPoolId $loadBalancer.BackendAddressPools.id -SubnetId $subnet.id
			$WebVM2NIC | Set-AzNetworkInterface
			Write-output "The WebVMs have been added to the External Loadbalancer at the Secondary Site..."

		}
    }
    else {
       
        InlineScript {
            $RP = $Using:RPVariable
			$LBNAME   = $RP.PrimarySiteWebLBName
			$VNETNAME = $RP.PrimarySiteVNetName
			$SUBNETNAME = $RP.PrimarySiteWebSubnetName
			$VNETRG   = $RP.PrimarySiteRG
			$WebVM1RG = $RP.PrimarySiteRG
			$WebVM2RG = $RP.PrimarySiteRG

			Write-Output "Adding WebVMs to the External Loadbalancer at the Primary Site..."
			$vnet = Get-AzVirtualNetwork -Name $VNETNAME -ResourceGroupName $VNETRG
			$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SUBNETNAME -VirtualNetwork $vnet
			$loadBalancer = Get-AzLoadBalancer -Name $LBNAME -ResourceGroupName $VNETRG
			$WebVM1NIC = Get-AzNetworkInterface -ResourceGroupName $WebVM1RG | Where-Object {$_.Name -like 'WebVM1*'}
			$WebVM1NIC | Set-AzNetworkInterfaceIpConfig -Name $WebVM1NIC.IpConfigurations[0].Name -LoadBalancerBackendAddressPoolId $loadBalancer.BackendAddressPools.id -SubnetId $subnet.id
			$WebVM1NIC | Set-AzNetworkInterface
			$WebVM2NIC = Get-AzNetworkInterface -ResourceGroupName $WebVM2RG | Where-Object {$_.Name -like 'WebVM2*'}
			$WebVM2NIC | Set-AzNetworkInterfaceIpConfig -Name $WebVM2NIC.IpConfigurations[0].Name -LoadBalancerBackendAddressPoolId $loadBalancer.BackendAddressPools.id -SubnetId $subnet.id
			$WebVM2NIC | Set-AzNetworkInterface
			Write-output "The WebVMs have been added to the External Loadbalancer at the Primary Site......"

		}
    }
}
