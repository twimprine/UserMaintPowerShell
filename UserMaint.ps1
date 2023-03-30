######################
#
# Author: Thomas Wimprine
# Date: January 11, 2017 - Removed Company data and updated email to current 3/30/2023
# Email: thomas@thomaswimprine.com
#
# Description: HR creates the employee and student records in Banner and this exports a file, hourly. This script is to start the process of 
#    automating the user account creation process
#
# Created GitHub repository: https://github.com/twimprine/UserMaintPowershell
# Date: October 3, 2018
#################

Import-Module ActiveDirectory

<# 
	Jan 19, 2017 - Thomas Wimprine
	Variables for file locations and global settings. 
#>

$DataDirectory = "C:\temp\testing\"
#$DataDirectory = "\\fs.company.local\dfs\OracleExport\"
$HomeDirectoryPath = "\\fs.company.local\dfs\HomeDirectories\"
$HomeDirectoryDrive = "H"

<# 
	Jan 19, 2017 - Thomas Wimprine
	Import the data from the passed csv file
#>
function Import-UserData {
    param (
        [string]$FilePath,
        [string]$FileName
    )
	
    $CompleteFileName = "$FilePath$FileName"
    $NewUserData = Import-Csv $CompleteFileName -Delimiter ","
    return $NewUserData
}

<#
	Jan 19, 2017 - Thomas Wimprine
	Get the files from the directory and process them individually
	Because there are currently (Jan 2017) a lot of individual files with normally very few lines
	of data I am passing them individually to the Import-UserData function. 
#>
function Get-Files {
    param (
        [string]$DataDirectory
    )
	
    $DataFiles = Get-ChildItem $DataDirectory -Filter *.csv
    # $DataFiles
    return $DataFiles
}

<#
	Jan 19, 2017 - Thomas Wimprine
	If a user is found to exist I'm setting them to what they should be according to standards.
	This should eventually bring all user accounts into compliance as they are updated. There are 
	a lot of accounts that do not belong to the groups they should so this is adding them to the 
	standard groups and will eventually call the function for the individual departmental groups.
#>

function Update-Employee {
    param (
        $User
    )
	
    $HomeDirectory = "$HomeDirectoryPath\$SamAccountName"
    
    $UserObject = Get-ADUser -Identity $User.SamAccountName
    # Rename-ADObject -Identity $UserObject $User.Name
    if ($User.UserType -eq "Staff") {
        $Group = Get-ADGroup UG-CP-Staff
    }
    else {
        $Group = Get-ADGroup UG-CP-Faculty
    }

    Add-ADGroupMember -Identity $Group -Members $UserObject

    # Set Variables that don't like getting passed for some reason... 
    $Manager = Get-Manager($User)

    try {
        Set-ADUser -Identity $User.SamAccountName `
            -emailaddress $User.emailAddress `
            -EmployeeID $User.EmployeeID `
            -HomeDrive $HomeDirectoryDrive `
            -HomeDirectory $HomeDirectory `
            -Manager $Manager `
            -Department $User.Department `
            -Replace @{ employeeType = "Staff"; extensionAttribute1 = $User.extensionAttribute1; extensionAttribute15 = $User.extensionAttribute15 } `
            -PassThru
            #-Replace @{extensionAttribute1 = $User.extensionAttribute1} `
            #-Replace @{extensionAttribute15 = $User.extensionAttribute15} `
    }
    catch {
        Write-Host $_
    }
    Rename-ADObject -Identity $UserObject $User.Name
}

<#
	Jan 19, 2017 - Thomas Wimprine
	Students are very standard - this sets the proper group memberships
#>
function Add-StudentGroups {
    param (
        $User
    )
	
    $SamAccountName = $User.SamAccountName
    $UserObject = Get-ADUser $SamAccountName
	
    $StudentGroups = "UG-StudentBody", "UG-Students", "UG-XUStudents"
    foreach ($Group in $StudentGroups) {
        Add-ADGroupMember -Identity $Group -Members $UserObject
    }
}

<#
	Jan 19, 2017 - Thomas Wimprine
	This sets the student's email address and ID number - brings them all into compliance
#>
function Update-Student {
    param (
        $User
    )
		
    $TargetOU = Get-ADOrganizationalUnit "OU=Student Body,OU=EndUser Administration,DC=domain,DC=company,DC=local"
    
    # Posershell options hate NULL fields so we need to populate this with something to prevent errors
    if ($User.StudentAcademicDepartment) {
        $StudentAcademicDepartment = $User.StudentAcademicDepartment
    } else {
        $StudentAcademicDepartment = "Not Defined"
    }


    try {
            Set-ADUser -Identity $User.SamAccountName `
                -EmailAddress $User.emailAddress `
                -EmployeeID $User.EmployeeID `
                -Description "Student" `
                -Department $StudentAcademicDepartment `
                -Replace @{ employeeType = "Student"; extensionAttribute1 = $User.extensionAttribute1; extensionAttribute15 = $User.extensionAttribute15 }

    }
    catch {
        Write-Host $_
    }

    # Because we possibly changed the object we get it again to make sure we have the 
    #   proper object reference
    $CurrentUserObject = Get-ADUser -Identity $User.SamAccountName
    Move-ADObject -Identity $CurrentUserObject -TargetPath $TargetOU
    $CurrentUserObject = Get-ADUser -Identity $User.SamAccountName
    Rename-ADObject -Identity $CurrentUserObject $User.Name
    Add-StudentGroups($User)
}

<#
	Jan 19, 2017 - Thomas Wimprine
	Does a search in AD for the user object if it's found it will update the student
	if the object is not found it will create the user with the basic settings then update 
	the student with the standard settings
#>
function Create-Student {
    param (
        $User
    )
	
    try {
        Get-ADUser -Identity $User.SamAccountName
        # Write-Host $User.SamAccountName "already exists"
        Update-Student $User
    }
    catch
    [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        $TargetOU = Get-ADOrganizationalUnit "OU=Student Body,OU=EndUser Administration,DC=domain,DC=company,DC=local"
        try {
            New-ADUser $User.SamAccountName `
                -DisplayName $User.DisplayName `
                -EmployeeID $User.EmployeeID `
                -EmailAddress $User.emailAddress `
                -GivenName $User.GivenName `
                -Surname $User.Surname `
                -UserPrincipalName $User.UserPrincipalName `
                -Enabled $true `
                -OtherAttributes @{ employeeType = "Student"; extensionAttribute1 = $User.extensionAttribute1; extensionAttribute15 = $User.extensionAttribute15 }  `
                -AccountPassword (ConvertTo-SecureString -AsPlainText $User.PasswordText -Force) `
                -Description "Student" `
                -Department $Department
        }
        catch {
            Write-Host $_
        }
        $UserObject = Get-ADUser -Identity $User.SamAccountName
        Move-ADObject -Identity $UserObject -TargetPath $TargetOU
        $UserObject = Get-ADUser -Identity $User.SamAccountName
        Rename-ADObject -Identity $UserObject $User.Name
        Add-StudentGroups($User)
    }
}

function Get-Manager {
    param ( 
        $User 
    )

    if ($User.EmpManager) {
        $Manager = Get-ADUser $User.EmpManager
    } else {
        $Manager = get-aduser 3786ea01 # Undefined user - This attribute cannot be null 
    }

    return $Manager
}
<#
Jan 19, 2017 - Thomas Wimprine
Similar to the create student - check for existance then updates 
#>
function Create-Employee {
    param (
        $User
    )
	
    # Check if the user currently exists
    try {
        Get-ADUser -Identity $User.SamAccountName
        Write-Host $User.DisplayName " already exists"
        Update-Employee $User
    }
    catch
    [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        $HomeDirectory = "$HomeDirectoryPath\$SamAccountName"
        $Manager = Get-Manager($User)
        New-ADUser $User.SamAccountName `
            -DisplayName $User.DisplayName `
            -EmployeeID $User.EmployeeID `
            -EmailAddress $User.emailAddress `
            -GivenName $User.GivenName `
            -Surname $User.Surname `
            -UserPrincipalName $User.UserPrincipalName `
            -Enabled $true `
            -AccountPassword (ConvertTo-SecureString -AsPlainText $User.PasswordText -Force) `
            -HomeDrive $HomeDirectoryDrive `
            -HomeDirectory $HomeDirectory `
            -OtherAttributes @{EmployeeType = "Staff"; extensionAttribute1 = $User.extensionAttribute1; extensionAttribute15 = $User.extensionAttribute15} `
            -Department $Department `
            -Manager $Manager
        #Set-ADAccountPassword -Identity $User.UserPrincipalName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $User.PasswordText -Force)
        # Add User to the Faculty or Staff group
        $UserObject = Get-ADUser -Identity $User.SamAccountName
        Rename-ADObject -Identity $UserObject $User.Name
        if ($User.UserType -eq "Staff") {
            $Group = Get-ADGroup UG-CP-Staff
        }
        else {
            $Group = Get-ADGroup UG-CP-Faculty
        }
        Add-ADGroupMember -Identity $Group -Members $UserObject
    }
}

<# 
Jan 19, 2017 - Thomas Wimprine
 Determines from the imported data if the user is a Student, Faculty or Staff and calles the 
 appropriate function.
 Using the UserAccountStatus field to determine if it's an new user, update, or termination
#> 
function Create-User {
    param (
        $User
    )
    foreach ($Object in $User) {
        # Determine if this is a student or employee
        if ($Object.UserType -eq "Student" -and $Object.UserAccountStatus -eq "CREATE") {
            Create-Student $Object
        }
        elseif ($Object.UserType -eq "Staff" -and $Object.UserAccountStatus -eq "CREATE") {
            Create-Employee $Object
        }
        elseif ($Object.UserType -eq "Faculty" -and $Object.UserAccountStatus -eq "CREATE") {
            Create-Employee $Object
        }
        else {
            break
        }
    }
}

function MoveDataFile {
    param ($File)
    # Jan 19, 2017 - Thomas Wimprine
    # I don't want to delete the files after they are processed so this moves them into 
    # a "Processed" directory so we can look and troublshoot later if needed. 
    $FileName = ($File.Name).TrimEnd(".csv")
    $NewFileName = $FileName + "_" + (Get-Date).Hour + (get-date).Minute + (Get-Date).Second + (get-date).Millisecond + ".csv"
    $Path = $DataDirectory + "Processed\" + $CurrentDate.Year + "\" + $CurrentDate.Month + "\" + $CurrentDate.Day + "\"
    # Move-Item -Path $DataDirectory\$File -Destination $Path\$NewFileName
    Move-Item -Path $DataDirectory\$File -Destination $Path\$NewFileName
}
function CheckPath {
    param ($File)
    # July 27, 2017
    # Updating file copy to seperate files by day - was too many files to keep track of in a single directory
    $CurrentDate = Get-Date
    $Path = $DataDirectory + "Processed\" + $CurrentDate.Year
    if (Test-Path -Path $Path) {
        $Path = $DataDirectory + "Processed\" + $CurrentDate.Year + "\" + $CurrentDate.Month
        if (Test-Path -Path $Path) {
            $Path = $DataDirectory + "Processed\" + $CurrentDate.Year + "\" + $CurrentDate.Month + "\" + $CurrentDate.Day
            if (Test-Path -Path $Path) {
                MoveDataFile($File)
            }
            else {
                
                New-Item -Path $Path -ItemType Directory
                CheckPath($File)
            }
        }
        else {
            
            New-Item -Path $Path -ItemType Directory
            CheckPath($File)
        }
    }
    else {
        
        New-Item -Path $Path -ItemType Directory
        CheckPath($File)
    }
}
<#
Jan 19, 2017 - Thomas Wimprine
Normalizes the imported data so the fields match the AD fields. 
#>
Get-Files $DataDirectory | ForEach-Object {
    $UserData = Import-UserData $DataDirectory $_
    # Call the create user functions
	
    $UserData | ForEach-Object {
        $UserObject = New-Object  System.Management.Automation.PSObject -Property @{
            DisplayName             = ($_.FirstName).Trim() + " " + ($_.LastName).Trim();
            PasswordText            = "Xav" + $_.CompanyID.Substring(4,5);
            SamAccountName          = ($_.UserName).Trim();
            EmployeeID              = ($_.CompanyID).Trim();
            emailAddress            = ($_.UserName).Trim() + "@company.edu"
            GivenName               = ($_.FirstName).Trim();
            Surname                 = ($_.LastName).Trim();
            Name                    = ($_.FirstName).Trim() + " " + ($_.LastName).Trim()
            UserPrincipalName       = ($_.UserPrincipalName).Trim();
            UserAccountStatus       = ($_.UserAccountStatus).Trim();
            UserType                = ($_.PrimaryUserType).Trim();
            extensionAttribute1     = ($_.OracleGUID).Trim();
            Department              = ($_.EmployeeDepartment).Trim();
            EmployeeTitle           = ($_.EmployeeTitle).Trim();
            StudentDept             = ($_.StudentAcademicDepartment).Trim();
            EmpManager              = ($_.EmployeeManagerUserName).Trim();
            GroupMembership         = ($_.GroupMembership)
            extensionAttribute15    = "TRUE"    # Going to be used for Google Suite Sync Script
                                                # True = Update user in Google Suite

        }
        
        if (!$UserObject.UserAccountStatus) {
            $UserObject.UserAccountStatus = "CREATE"
            #$UserObject | Add-Member -MemberType NoteProperty -Name UserAccountStatus -Value CREATE
        }

        if (!$UserObject.extensionAttribute1) {
            $UserObject.extensionAttribute1 = "NULL"
        }
        
        try {
            # After the data has been imported and normalized we create/update the user 
            # I should probably call this function something else... 
            Create-User $UserObject
        }
        Catch {
            Write-Host "Error: $_"
        }
    }
    If (!(Test-Path $DataDirectory\Processed -PathType container)) {
        New-Item $DataDirectory\Processed -ItemType container
    }
    CheckPath($_)
}