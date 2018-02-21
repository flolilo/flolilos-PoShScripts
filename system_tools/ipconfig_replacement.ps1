#requires -version 3

<#
    .SYNOPSIS
        Just a test if one can replace ipconfig.
#>
[int]$UserVal = -1
while($UserVal -ne 0){
    [int]$UserVal = Read-Host "`r`nWhat do you want to do? 1 = ipconfig, 2 = ipconfig /flushdns, 0 = Exit"
    if($UserVal -eq 1){
        # TODO: proper working thing
        $bla = Get-NetIPConfiguration | Sort-Object InterfaceIndex
        #$bla.IPv4Address = $bla.IPv4Address.IPaddress
        #$bla.IPv6Address = $bla.IPv6Address.IPaddress
        $bla # | Select-Object -Property * -ExcludeProperty InterfaceIndex,InterfaceAlias
    }elseif($UserVal -eq 2){
        Clear-DnsClientCache
        Register-DnsClient
    }
    # TODO: /release
    # TODO: /renew
}
