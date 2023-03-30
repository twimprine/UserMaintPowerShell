<# 
    Description:
        Need to create a test CSV for verifying operation of new user import

    Author:
        Thomas Wimprine
        twimprin@xula.edu

    Creation Date:
        October 3, 2018

    Notes:
        I plan on creating a lot of data with random functions - this will give me a lot 
        of unplanned data and potentionally errors with the data import that I can capture 
        and resolve. 

#>

# How many users are we going to test with?
$UsersToCreate = 100

function New-GivenName {
    $PotentialLength = 10
    $GivenName = -join ((65..90) + (97..122) | Get-Random -Count (Get-Random -Maximum $PotentialLength -Minimum 3) | ForEach-Object {[char]$_})
    $Givenname = $GivenName -replace " ", ""

    return $GivenName
}

function New-SurName {
    $PotentialLength = 20
    $SurName = -join ((65..90) + (97..122) | Get-Random -Count (Get-Random -Maximum $PotentialLength -Minimum 5) | ForEach-Object {[char]$_})
    $Surname = $Surname -replace " ", ""


    return $SurName
}

function Select-UserType {
    $UserTypes = "Student", "Staff", "Faculty"

    return Get-Random ($UserTypes)
}

function New-employeeID {
    $EmpID = "800" + [string](Get-Random -Minimum 100000 -Maximum 999999)

    return $EmpID
}

function New-Department {
    $PotentialLength = 30
    $Dept = -join ((65..90) + (97..122) | Get-Random -Count (Get-Random -Maximum $PotentialLength -Minimum 15) | ForEach-Object {[char]$_})

    return $Dept
}

function New-Title {
    $PotentialLength = 30
    $Title = -join ((65..90) + (97..122) | Get-Random -Count (Get-Random -Maximum $PotentialLength -Minimum 13) | ForEach-Object {[char]$_})

    return $Title
}

function New-StudentDept {
    $PotentialLength = 30
    $Dept = -join ((65..90) + (97..122) | Get-Random -Count (Get-Random -Maximum $PotentialLength -Minimum 15) | ForEach-Object {[char]$_})

    return $Dept
}

function Select-Manager {
    $Manager = Get-Random $Managers

    return $Manager.SamAccountName
}


# Get disabled users so we can test them as managers
# We only want to do this once not ever iteration of the loop
$Managers = Get-ADUser -filter {enabled -eq $false}

$Counter = 0
$NewUsers = @()
do {
    $Counter++

    # Populate our variables from functon outputs
    $XavierID               = New-employeeID
    $GivenName              = New-GivenName
    $SurName                = New-SurName
    $Manager                = Select-Manager
    $StudentDept            = New-StudentDept
    $EmployeeDept           = New-Department
    $extensionAttribute1    = New-Guid
    $EmployeeTitle          = New-Title
    $EmployeeID             = New-employeeID
    $Login                  = $GivenName.Substring(0,1) + $SurName
    $Email                  = $Login + "@xula.edu"
    $UserPricipalName       = $Login + "@xavier.xula.local"
    $UserAccountStatus      = "CREATE"
    $PrimaryUserType        = Select-UserType
    $GroupMembership        = $PrimaryUserType


    $UserObject = New-Object System.Management.Automation.PSObject 
        $UserObject | Add-Member -membertype NoteProperty -name "UserName" -value $Login
        $UserObject | Add-Member -MemberType NoteProperty -Name "FirstName" -Value $GivenName
        $UserObject | Add-Member -MemberType NoteProperty -Name "LastName" -Value $SurName
        $UserObject | Add-Member -MemberType NoteProperty -Name "XavierID" -Value $EmployeeID
        $UserObject | Add-Member -MemberType NoteProperty -Name "XavierEmailAddress" -Value $Email
        $UserObject | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $UserPricipalName
        $UserObject | Add-Member -MemberType NoteProperty -Name "UserAccountStatus" -Value $UserAccountStatus
        $UserObject | Add-Member -MemberType NoteProperty -Name "PrimaryUserType" -Value $PrimaryUserType
        $UserObject | Add-Member -MemberType NoteProperty -Name "OracleGUID" -Value $extensionAttribute1
        $UserObject | Add-Member -MemberType NoteProperty -Name "EmployeeDepartment" -Value $EmployeeDept
        $UserObject | Add-Member -MemberType NoteProperty -Name "GroupMembership" -Value $GroupMembership
        $UserObject | Add-Member -MemberType NoteProperty -Name "EmployeeTitle" -Value $EmployeeTitle
        $UserObject | Add-Member -MemberType NoteProperty -Name "StudentAcademicDepartment" -Value $StudentDept
        $UserObject | Add-Member -MemberType NoteProperty -Name "EmployeeManagerUserName" -Value $Manager 

    $NewUsers += $UserObject
} while ($UsersToCreate -gt $Counter)

$FileNameSuffix = (Get-Date).Hour + (get-date).Minute + (Get-Date).Second + (get-date).Millisecond
$FileNamePrefix = "TestData"

$FileName = $FileNamePrefix + (Get-Date).Hour + (get-date).Minute + (Get-Date).Second + (get-date).Millisecond + ".csv"

$NewUsers | Export-Csv "C:\temp\Testing\$FileName" -NoTypeInformation