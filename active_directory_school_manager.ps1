<#
Active Directory School Manager
Ez a PowerShell szkript a magyar iskolák Active Directory rendszerének kezelésére szolgál, lehetővé téve a diákok rendszerezését és az évfolyamok léptetését.

Copyright (C) 2024 Parancsmester

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

$Global:ConfigFile = "ad_school_manager_config"
$Global:Grades = 7..12
$Global:Classes = @("A", "B", "C")
$Global:OtherClass = "D"
$Global:OtherClassFrom = 9
$Global:HomeDrive = "S:"

# Konfiguráció
function loadConfig {
    try {
        $cont = Get-Content $Global:ConfigFile -ErrorAction Stop
    } catch {
        Write-Warning "Nem található a konfigurációs fájl! Állítsd be a konfigurációt!"
        return
    }
    foreach ($i in $cont){
        $variableName = $i.split("=")[0]
        $value = $i.split("=",2)[1]
        if ($variableName -eq "OURoot") {
            $dc1, $dc2 = $Global:Domain.Split(".")
            $parts = $value -split "\\"
            [System.Array]::Reverse($parts)
            $value = "$(($parts | ForEach-Object { "OU=$_"}) -Join ','),DC=$dc1,DC=$dc2"
        }
        Set-Variable -Name $variableName -Value $value -Scope global
    }
}
function setConfig {
    try {
        [void](New-Item -Path . -Name $Global:ConfigFile -ItemType "file" -Value "" -ErrorAction SilentlyContinue)
        Clear-Content -Path $Global:ConfigFile
    } catch {}
    askConfig "Domain: (pl. iskola.hu)" "Domain"
    askConfig "Szervernév: (pl. DC1)" "ServerName"
    askConfig "Gyökérmappa: (pl. C:\DIAKOK)" "RootFolder"
    askConfig "Megosztott gyökérmappa: (pl. DIAKOK)" "SharedRootFolder"
    askConfig "Csoport: (pl. Diak)" "UserGroup"
    askConfig "Gyökér OU az 'Active Directory: Felhasználók és számítógépek' ablakban (elérési út formában írd be, pl. DIAKOK vagy VALAMI\DIAKOK)" "OURoot"
    askConfig "Alapértelmezett jelszó: (pl. 12345678)" "DefaultPassword"
    loadConfig
}
function askConfig ($text, $variableName) {
    "$variableName=$(Read-Host $text)" | Out-File -FilePath $Global:ConfigFile -Append
}


# Mappagenerálás
function generateFolders {
    $Global:Grades | ForEach-Object {
        [void](New-Item -Path "$Global:RootFolder\" -Name $_ -ItemType "directory" -ErrorAction SilentlyContinue)
        foreach ($class in $Global:Classes) {
            [void](New-Item -Path "$Global:RootFolder\$_" -Name $class -ItemType "directory" -ErrorAction SilentlyContinue)
        }
        if ($_ -gt ($Global:OtherClassFrom-1)) {
            [void](New-Item -Path "$Global:RootFolder\$_" -Name $Global:OtherClass -ItemType "directory" -ErrorAction SilentlyContinue)
        }
    }
    Read-Host "Generálás kész! TOVÁBB"
}


# Csoportgenerálás
function generateGroups {
    New-ADOrganizationalUnit -Name "Csoportok" -Path $Global:OURoot -ProtectedFromAccidentalDeletion $False -Confirm:$False
    New-ADGroup -Name $Global:UserGroup -SamAccountName $Global:UserGroup -GroupCategory Security -GroupScope Global -DisplayName $Global:UserGroup -Path "OU=Csoportok,$Global:OURoot"
    $Global:Grades | ForEach-Object {
        foreach ($class in $Global:Classes) {
            New-ADGroup -Name "$_.$class" -SamAccountName "$_.$class" -GroupCategory Security -GroupScope Global -DisplayName "$_.$class" -Path "OU=Csoportok,$Global:OURoot"
            [void](New-Item -Path "$Global:RootFolder\$_" -Name $class -ItemType "directory" -ErrorAction SilentlyContinue)
        }
        if ($_ -gt ($Global:OtherClassFrom-1)) {
            New-ADGroup -Name "$_.$Global:OtherClass" -SamAccountName "$_.$Global:OtherClass" -GroupCategory Security -GroupScope Global -DisplayName "$_.$Global:OtherClass" -Path "OU=Csoportok,$Global:OURoot"
        }
    }
    Read-Host "Generálás kész! TOVÁBB"
}


# OU generálás
function generateOU {
    $Global:Grades | ForEach-Object {
        New-ADOrganizationalUnit -Name $_ -Path $Global:OURoot -ProtectedFromAccidentalDeletion $False -Confirm:$False
        foreach ($class in $Global:Classes) {
            New-ADOrganizationalUnit -Name $class -Path "OU=$_,$Global:OURoot" -ProtectedFromAccidentalDeletion $False -Confirm:$False
        }
        if ($_ -gt ($Global:OtherClassFrom-1)) {
            New-ADOrganizationalUnit -Name $Global:OtherClass -Path "OU=$_,$Global:OURoot" -ProtectedFromAccidentalDeletion $False -Confirm:$False
        }
    }
    Read-Host "Generálás kész! TOVÁBB"
}


# Diák hozzáadása
function addSingleUser ($name, $class) {
    $firstname, $lastname = $name -split " ", 2
    $username = ($name -replace(" ", ".")).toLower()
    $class1, $class2 = $class.Split(".")
    # felhasználó hozzáadása
    $newuser = New-ADUser -Name $name -DisplayName $name -GivenName $lastname -Surname $firstname -SamAccountName $username -UserPrincipalName $username@$Global:Domain -AccountPassword (ConvertTo-SecureString $Global:DefaultPassword -AsPlainText -Force) -Path "OU=$class2,OU=$class1,$Global:OURoot" -Description $class -ChangePasswordAtLogon $true -HomeDirectory "\\$Global:ServerName\$Global:SharedRootFolder\$class1\$class2\$username" -HomeDrive $Global:HomeDrive -Enabled $true -PassThru
    # hozzáadás csoporthoz
    Add-ADGroupMember -Identity $Global:UserGroup -Members $newuser
    Add-ADGroupMember -Identity $class -Members $newuser
    # kezdőmappa létrehozása és jogosultságok beállítása
    $homeDir = New-Item -Path "$Global:RootFolder\$class1\$class2\" -Name $username -ItemType "directory" -ErrorAction SilentlyContinue
    $acl = Get-Acl $homeDir
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($newuser.SID, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($AccessRule)
    Set-Acl -Path $homeDir -AclObject $acl
}

function addUser {
    $class = Read-Host "Osztály (pl. 7.A)"
    Write-Host "Írd be a diákok neveit. Kilépéshez írj Enter-t."
    do {
        $inp = Read-Host "Név"
        if ($inp -eq "") {
            return
        }
        addSingleUser $inp $class.toUpper()
    } until ($inp -eq "")
}


# Diák jelszavának visszaállítása
function resetUserPassword {
    $user = Get-ADUser -Identity (Read-Host "Felhasználónév")
    Set-ADAccountPassword -Identity $user -NewPassword (ConvertTo-SecureString $Global:DefaultPassword -AsPlainText -Force) -Reset
    Set-ADUser -Identity $user -ChangePasswordAtLogon $true
    Read-Host "Visszaállítás kész! TOVÁBB"
}


# Diákok és mappáik törlése csoport alapján
function removeUserByGroup {
    $group = (Read-Host "Csoportnév ('*' = minden)").ToUpper()
    if ($group -eq "*") {
        $group = $Global:UserGroup
        Get-ChildItem -Path $Global:RootFolder -Recurse -Exclude ($Global:Grades+$Global:Classes+"D") | Remove-Item -Force -Recurse
    }
    $class1, $class2 = $group.Split(".")
    foreach ($user in Get-ADGroupMember -Identity $group -Recursive | Where-Object { $_.objectClass -eq 'user' }) {
        Remove-ADUser -Identity $user -Confirm:$false
        if ($group -ne $Global:UserGroup) {
            Remove-Item -Path "$Global:RootFolder\$class1\$class2\$($user.SamAccountName)" -Force
        }
        Write-Host "$($user.Name) törölve"
    }
    Read-Host "Törlés kész! TOVÁBB"
}


# Diák törlése név alapján
function removeUserByUsername {
    $user = Get-ADUser -Identity (Read-Host "Felhasználónév") -Properties "HomeDirectory"
    Remove-Item -Path $user.HomeDirectory -Force
    Remove-ADUser -Identity $user -Confirm:$false
    Read-Host "Törlés kész! TOVÁBB"
}


# Diákok léptetése
function rollUsers {
    # 12-es tanulók, mappáik, és szervezeti egységeik (OU) törlése
    Get-ChildItem -Path "$Global:RootFolder\$($Global:Grades[-1])" -Recurse | Remove-Item -Force -Recurse
    foreach($class in ($Global:Classes+$Global:OtherClass)) {
        foreach ($user in Get-ADGroupMember -Identity "$($Global:Grades[-1]).$class" -Recursive | Where-Object { $_.objectClass -eq 'user' }) {
            Remove-ADUser -Identity $user -Confirm:$false
        }
        Remove-ADObject -Identity "OU=$class,OU=$($Global:Grades[-1]),$Global:OURoot" -Confirm:$False
    }
    $Global:Grades[0..($Global:Grades.Length - 2)] | Sort-Object -Descending  | ForEach-Object {
        $o = $_
        # mappák áthelyezése
        Get-ChildItem -Path "$Global:RootFolder\$o" | ForEach-Object {
            Move-Item "$Global:RootFolder\$o\$_" "$Global:RootFolder\$($o+1)\$_"
        }
         # csoportok és szervezeti egységek (OU) áthelyezése, mappajogosultságok beállítása
        foreach($class in $Global:Classes) {
            foreach ($user in Get-ADGroupMember -Identity "$o.$class" -Recursive | Where-Object { $_.objectClass -eq 'user' }) {
                Remove-ADGroupMember -Identity "$o.$class" -Members $user -Confirm:$false
                Add-ADGroupMember -Identity "$($o+1).$class" -Members $user -Confirm:$false
                Set-ADUser -Identity $user -Description "$($o+1).$class" -HomeDirectory "\\$Global:ServerName\$Global:SharedRootFolder\$($o+1)\$class\$($user.SamAccountName)"
                $acl = Get-Acl "\\$Global:ServerName\$Global:SharedRootFolder\$($o+1)\$class\$($user.SamAccountName)"
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($user.SID, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.AddAccessRule($AccessRule)
                Set-Acl -Path "\\$Global:ServerName\$Global:SharedRootFolder\$($o+1)\$class\$($user.SamAccountName)" -AclObject $acl
            }
            Move-ADObject -Identity "OU=$class,OU=$o,$Global:OURoot" -TargetPath "OU=$($o+1),$Global:OURoot" -Confirm:$False
        }
        if ($o -gt ($Global:OtherClassFrom-1)) {
            foreach ($user in Get-ADGroupMember -Identity "$o.$Global:OtherClass" -Recursive | Where-Object { $_.objectClass -eq 'user' }) {
                Remove-ADGroupMember -Identity "$o.$Global:OtherClass" -Members $user -Confirm:$false
                Add-ADGroupMember -Identity "$($o+1).$Global:OtherClass" -Members $user -Confirm:$false
                Set-ADUser -Identity $user -Description "$($o+1).$Global:OtherClass" -HomeDirectory "\\$Global:ServerName\$Global:SharedRootFolder\$($o+1)\$Global:OtherClass\$($user.SamAccountName)"
                $acl = Get-Acl "\\$Global:ServerName\$Global:SharedRootFolder\$($o+1)\$Global:OtherClass\$($user.SamAccountName)"
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ("FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.AddAccessRule($AccessRule)
                Set-Acl -Path "\\$Global:ServerName\$Global:SharedRootFolder\$($o+1)\$Global:OtherClass\$($user.SamAccountName)" -AclObject $acl
            }
            Move-ADObject -Identity "OU=$Global:OtherClass,OU=$o,$Global:OURoot" -TargetPath "OU=$($o+1),$Global:OURoot" -Confirm:$False
        }
    }
    # 7-es mappák és szervezeti egységek (OU) létrehozása
    foreach ($class in $Global:Classes) {
        [void](New-Item -Path "\\$Global:ServerName\$Global:SharedRootFolder\$($Global:Grades[0])" -Name $class -ItemType "directory")
        New-ADOrganizationalUnit -Name $class -Path "OU=$($Global:Grades[0]),$Global:OURoot" -ProtectedFromAccidentalDeletion $False -Confirm:$False
    }
    # 9.D mappa és szervezeti egység (OU) létrehozása
    [void](New-Item -Path "\\$Global:ServerName\$Global:SharedRootFolder\$Global:OtherClassFrom" -Name $Global:OtherClass -ItemType "directory")
    New-ADOrganizationalUnit -Name $Global:OtherClass -Path "OU=$Global:OtherClassFrom,$Global:OURoot" -ProtectedFromAccidentalDeletion $False -Confirm:$False
    Read-Host "Léptetés kész! TOVÁBB"
}


function subMenu {
    do {
    $inp = Show-Menu @("Konfiguráció beállítása", "Mappák generálása", "Csoportok generálása", "Szervezeti egységek (OU) generálása", $(Get-MenuSeparator), "VISSZA") -ReturnIndex
    switch ($inp) {
        0 {
            InvokeWithClear{setConfig}
        } 1 {
            InvokeWithClear{generateFolders}
        } 2 {
            InvokeWithClear{generateGroups}
        } 3 {
            InvokeWithClear{generateOU}
        } 5 {
            return
        }
    }
    } until ($inp -eq 5 -or $null -eq $inp)
}


function InvokeWithClear ($action, $warn) {
    Clear-Host
    if ($warn) {
        Write-Warning "Biztosan ezt akarod csinálni?"
        if ((Read-Host "I/N").ToUpper() -eq "I") {
            Clear-Host
            & $action
        }
    } else {
        & $action
    }
    Clear-Host
}

# START
if (-not (Get-Module PSMenu -ListAvailable)){
    [void](Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false)
    Install-Module PSMenu -Force -Confirm:$false
}
loadConfig
do {
    $inp = Show-Menu @("Diákok hozzáadása", "Diák jelszavának visszaállítása", "Diákok felsőbb évfolyamba léptetése", "Diákok törlése csoport alapján", "Diák törlése név alapján", $(Get-MenuSeparator), "Almenü", "KILÉPÉS") -ReturnIndex
    switch ($inp) {
        0 {
            InvokeWithClear{addUser}
        } 1 {
            InvokeWithClear{resetUserPassword}
        } 2 {
            InvokeWithClear{rollUsers} ($true)
        } 3 {
            InvokeWithClear{removeUserByGroup} ($true)
        } 4 {
            InvokeWithClear{removeUserByUsername} ($true)
        } 6 {
            InvokeWithClear{subMenu}
        } 7 {
            return
        }
    }
} until ($inp -eq 7 -or $null -eq $inp)
# SIG # Begin signature block
# MIIFZwYJKoZIhvcNAQcCoIIFWDCCBVQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUegNzTgkdoym8aAU2gX9OpXlm
# FQKgggMEMIIDADCCAeigAwIBAgIQHDKrrGQjvrhD/vpL6DEnujANBgkqhkiG9w0B
# AQUFADAYMRYwFAYDVQQDDA1QYXJhbmNzbWVzdGVyMB4XDTI0MDgyNDEyMzYyNloX
# DTI1MDgyNDEyNTYyNlowGDEWMBQGA1UEAwwNUGFyYW5jc21lc3RlcjCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAMCu9a/4wjHudO0pUe8h4osfKpce6H4o
# 4IZhW8eoDm+DhOt2oMNz/d8WMev7a019J19Ov8REVLH5rr17riTpl4jL/9TO+G1b
# jUmYSiVeKvqB5hQMqYD3EveNlXmcXv/E8WqwkaxGhMzviz14twyMdxiphMztqnip
# zct3sZquULiryKvrSdhfmo0zdXsfBQ1yP/iDx/jL3EDvloH4o0sxniUtr3q5rhcx
# WNMBhUZowNsjSWkXD/jvWn2NzK00ik17tEmk5jj353krT8Iv1/QvIyXHfYqGZeZe
# 6nm97YXa7Jj2mysxxEVjm6g0UD/Maz2TXDLI+Zol7PMbZZdE05IVAxUCAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBS6l0lIQNQy1zXyWHuRgKZK12iuUzANBgkqhkiG9w0BAQUFAAOCAQEATBY05f4Q
# JqKAjpZxTqfs6Dc4r2LdTkPvS1w/kgSVlT3NP1PcUNrrtMwqQjdxBmrXTIU5To1F
# fv7H9TI2vEPonsdNlOdUQ0T8xQeKLuO+RWmbLzp2Xo4wQlkMBnlGvna0aHjWv6VC
# 0I1A0/u5TmepgsC5X+k75easf4987JH4CiA9n6iB68+QLk6U6Yl+b/n7oFt2zQu3
# YsFHXciVgKIPFQWU2Ey2Fvng+1RHQe/V9ys5pW3sPCEaIAS5Vza2oKpjxooi/RnZ
# k6oudlPALQnnG3u2fO9/Ft8B8VKQvdMiufSkUPjqxYhsqYw+wJwBhnEWtP2jqXJi
# qwvjsQX0U7ieSTGCAc0wggHJAgEBMCwwGDEWMBQGA1UEAwwNUGFyYW5jc21lc3Rl
# cgIQHDKrrGQjvrhD/vpL6DEnujAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEK
# MAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUBEvqN7W1kUpS0KC6
# 4QbANFYyToUwDQYJKoZIhvcNAQEBBQAEggEAeMeNSehsKi6jO9O0vsoDS/4HQ7eG
# q5qWBWdmnuci7cuVbDUZWqF7qSQHmw0YSs3wqlLkvJriZ5fk92IyNdajw0e59YId
# DBiYPqDdLi+5fJUjKvjM7guNcj9CQJsIVY51muj0qBjQreHVEQlmnrF5HAQN6gBR
# oOfDNToRfCLgeAUv3uOsssoe1KjNV5hRejMAIQkV9x1QJ4yU8sLIEuapfEVHzzN8
# ckyY+tqChpFupo9AogARbFj4098EkjhgHM9onmY7f164NIWFATUoSVE7lFhFWiu+
# JHIi1yrOXkJcUlUM76PLRvX28ZwtAC9rJpmn3yLqrJnekSGZfmvNBFAlPQ==
# SIG # End signature block
