<#
Author: Sujithkumar.G.S              : Date: 26-01-2023


Enhancement and Improvements

1) Added logic to check third-party AV's installed on the device
2) Check secure boot is enabled
3) Updated update-form function to add more logics to show failed reasons and status
4) Increased the HTML frame size similar to Outlook Sign-in Window.



References:
https://learn.microsoft.com/en-us/answers/questions/339746/filtering-doesnt-seem-to-work-on-a-newer-intuneap
https://learn.microsoft.com/en-us/powershell/scripting/learn/ps101/07-working-with-wmi?view=powershell-7.2
https://github.com/MicrosoftDocs/memdocs/issues/2863

Prerequisite UI conditional messages:
- Before Run Check is selected, the five prerequisite result marks are blank.
- Each result mark reflects its corresponding check: antivirus, Secure Boot, ARM64, OS build, or Windows edition.
- If any prerequisite fails, the final status is marked red and the failure guidance is shown.
- If every prerequisite passes, the final status is marked green and the success message is shown.
- The existing prerequisite rules and registration workflow are unchanged by the UI layout updates.

Testing:

<#

#>

<#
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}
#>

# ONE-TIME ORGANIZATION SETUP: replace these three values, then save as UTF-8.
$global:TenantId = 'ff55f07c-badf-4755-8002-a37d94c58eb6'
$global:ClientId = '5fcd8e83-e567-435f-af57-5c4e4ec2819e'
$global:BackendUrl = 'https://prod-26.southindia.logic.azure.com:443/workflows/43b67a6c79b74413bc42d7a6fb181121/triggers/When_an_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_an_HTTP_request_is_received%2Frun&sv=1.0&sig=tkeEr5O3LJbEiN3jzet8RFgw7pYXwdwEUGkrDZ2KUJs'

foreach ($entry in @(@{ Name = 'TenantId'; Value = $global:TenantId }, @{ Name = 'ClientId'; Value = $global:ClientId })) {
    $parsedId = [Guid]::Empty
    if (-not [Guid]::TryParse($entry.Value, [ref]$parsedId) -or $parsedId -eq [Guid]::Empty) {
        throw "Configure $($entry.Name) at the top of this script. See README.md."
    }
}
$backendUri = $null
if (-not [Uri]::TryCreate($global:BackendUrl, [UriKind]::Absolute, [ref]$backendUri) -or $backendUri.Scheme -ne 'https') {
    throw 'Configure BackendUrl with the Logic App Request trigger HTTPS URL. See README.md.'
}
if ($env:OS -ne 'Windows_NT' -or $PSVersionTable.PSEdition -eq 'Core') {
    throw 'Run this script in Windows PowerShell 5.1 on Windows.'
}
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Start with powershell.exe -NoProfile -STA -File AutopilotRegistration.ps1.'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#regionstart Global Variable declaration

$global:Language = Get-WinUserLanguageList
$global:CurrentDate = Get-Date -Format G
$global:CurrectTimeZoneSet = Get-TimeZone
$global:WindowsEdition = (Get-CimInstance -class Win32_OperatingSystem).Caption
$global:slmgrResult = cscript c:\windows\system32\slmgr.vbs /dli
$global:OSBuildNumber = (Get-CimInstance -class Win32_OperatingSystem).BuildNumber
$global:psv = ($PSVersionTable).PSVersion
$global:authUrl = "https://login.microsoftonline.com/$($global:TenantId)"
$global:Get_AzureAD_SignedIn_User = "https://graph.microsoft.com/v1.0/me"
$global:dvcComputerName = $env:COMPUTERNAME
#$global:PublicIPAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip" -UseBasicParsing).content
$global:Model = (Get-CimInstance -class win32_computersystem).SystemFamily
$global:SKU = (Get-CimInstance -class win32_computersystem).SystemSKUNumber
$global:Bios = (Get-CimInstance -class win32_bios).version
$global:Manufacturer = (Get-CimInstance -class win32_computersystem).Manufacturer
$global:ITSupporter = $SignedUserName.userPrincipalName
$global:ActivationState = ((Get-CimInstance -Class "SoftwareLicensingService" -Verbose:$false).OA3xOriginalProductKeyDescription)
$global:ActivationInfo = (Get-CimInstance -class win32_computersystem).PrimaryOwnerName
[int]$global:SupportedBuildNumber = "22621"
$Global:LogFile = Join-Path $env:TEMP "AutopilotApp-$(Get-Date -Format yyyyMMdd-HHmmss).log"
$global:supportEmailAddress = "itservicedesk@contoso.com"
$global:IconBase64 = "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"
#endregion

function Write-AppLog {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR')] [string] $Level = 'INFO'
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $Global:LogFile -Value $line

    # OPTIONAL: if you have a status label/textbox on your main form, update it here
    if ($Global:lblStatus) {
        $Global:lblStatus.Text = $Message
        $Global:lblStatus.Refresh()
    }
}

function Fit-DialogToScreen {
    param([System.Windows.Forms.Form] $Form)
    $area = [System.Windows.Forms.Screen]::FromControl($Form).WorkingArea
    $Form.MinimumSize = New-Object System.Drawing.Size(0, 0)
    $Form.Size = New-Object System.Drawing.Size(
        [Math]::Min($Form.Width, [Math]::Max(1, $area.Width - 24)),
        [Math]::Min($Form.Height, [Math]::Max(1, $area.Height - 24))
    )
    $Form.Location = New-Object System.Drawing.Point(
        ($area.Left + [int](($area.Width - $Form.Width) / 2)),
        ($area.Top + [int](($area.Height - $Form.Height) / 2))
    )
}

Function Get-WindowsOSBuildNumber {
    # Convert Build Number to Integer
    $OSBuildNumberCheck = [int](Get-CimInstance -Class Win32_OperatingSystem).BuildNumber

 
    # Ensure Supported Build Number is Defined
    if (!$OSBuildNumberCheck) {
        Write-AppLog "Error: Supported Build Number is not set!" "INFO"
        return $false
    }

    # Compare OS Build Number
    if ($OSBuildNumberCheck -ge $global:SupportedBuildNumber) {
        return $true
    } else {
        return $false
    }
}

Function Get-WindowsEditionStatus {
             
    $EditionID = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name EditionID -ErrorAction SilentlyContinue

    if (($EditionID -match "Professional") -or ($EditionID -match "Enterprise") -or ($EditionID -match "EnterpriseEval") -or ($EditionID -match "ProfessionalEval")) {
        return $true
    } 
    else {
        return $false
    }
}

Function CheckThirdPartyAntivirus {

    # Check if Windows Defender service is running
    $DefenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue

    if ($DefenderService.Status -ne 'Running') {
        # If the Defender service is not running, assume a third-party AV is active
        return $false
    }

    try {
        # Get Defender's running mode
        $defenderMode = (Get-MpComputerStatus).AMRunningMode

        # Check if Defender is in Passive Mode, EDR Block Mode, or Not Running
        if ($defenderMode -eq "Passive Mode" -or $defenderMode -eq "EDR Block Mode" -or $defenderMode -eq "Not running") {
            return $false  # Third-party AV likely installed
        }

        # If Defender is in Normal mode, return true (Defender is active, no third-party AV)
        return $true

    } catch {
        # If Get-MpComputerStatus fails, assume Defender is disabled or another AV is installed
        return $false
    }
}

function CheckARM64Detected {
    $systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($systemInfo.SystemType -like "*ARM64*") {
        return $true
    } else {
        return $false
    }
}

function Get-SecureBootState {
    try {
        # Check Secure Boot state
        $SecureBootEnabled = Confirm-SecureBootUEFI
        if ($SecureBootEnabled) {
            return $true   # Secure Boot is enabled
        } else {
            return $false  # Secure Boot is disabled
        }
    } catch {
        # Return Non-UEFI for systems that do not support Secure Boot
        return "Non-UEFI"
    }
}

Function Get-PrerequisiteCheck {
    # Initialize Form
    $LocationSelectionForm = New-Object -TypeName System.Windows.Forms.Form
    $LocationSelectionForm.Text = "GS Autopilot Registration"
    $LocationSelectionForm.StartPosition = "CenterScreen"
    #$LocationSelectionForm.Icon = New-Object System.Drawing.Icon (New-Object System.IO.MemoryStream (,[System.Convert]::FromBase64String('')))
    $LocationSelectionForm.Icon = New-Object System.Drawing.Icon (New-Object System.IO.MemoryStream (,[System.Convert]::FromBase64String("$global:IconBase64")))

    # Build the prerequisite screen with DPI-aware, resizing layout containers.
    $LocationSelectionForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $LocationSelectionForm.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $LocationSelectionForm.ClientSize = New-Object System.Drawing.Size(620, 500)
    $LocationSelectionForm.MinimumSize = New-Object System.Drawing.Size(360, 300)

    $GroupBox = New-Object System.Windows.Forms.GroupBox
    $GroupBox.Text = "Prerequisite Check"
    $GroupBox.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $GroupBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $GroupBox.Margin = New-Object System.Windows.Forms.Padding(0)
    $GroupBox.Padding = New-Object System.Windows.Forms.Padding(10)

    $contentLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $contentLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $contentLayout.AutoScroll = $true
    $contentLayout.ColumnCount = 1
    $contentLayout.RowCount = 5
    $contentLayout.Padding = New-Object System.Windows.Forms.Padding(2)
    $contentLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null

    $NoteLabel = New-Object System.Windows.Forms.Label
    $NoteLabel.Text = "Click on Run Check to verify if this device meets the prerequisites for Autopilot registration. If all checks pass, you can proceed with registration. If any check fails, refer to the $([char]0x274C) marks for details and resolve the issues before retrying."
    $NoteLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Regular)
    $NoteLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $NoteLabel.AutoSize = $true
    $NoteLabel.Margin = New-Object System.Windows.Forms.Padding(8, 8, 8, 14)
    $NoteLabel.Padding = New-Object System.Windows.Forms.Padding(6)
    $NoteLabel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    [void]$contentLayout.Controls.Add($NoteLabel, 0, 0)

    $Checks = @(
        "Checking Third-Party Antivirus...",
        "Checking Secure Boot",
        #"Checking ARM64 Processor",
        "Checking OS Build Number",
        "Checking OS Edition"
    )
    $CheckLabels = @()
    $CheckMarks = @()
    $checksLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $checksLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $checksLayout.AutoSize = $true
    $checksLayout.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $checksLayout.ColumnCount = 2
    $checksLayout.RowCount = $Checks.Count
    $checksLayout.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
    $checksLayout.Padding = New-Object System.Windows.Forms.Padding(6)
    $checksLayout.CellBorderStyle = [System.Windows.Forms.TableLayoutPanelCellBorderStyle]::None
    $checksLayout.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $checksLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $checksLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null

    for ($i = 0; $i -lt $Checks.Count; $i++) {
        $checksLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Checks[$i]
        $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $label.Dock = [System.Windows.Forms.DockStyle]::Fill
        $label.AutoSize = $true
        $label.Margin = New-Object System.Windows.Forms.Padding(4, 5, 4, 5)

        $tickLabel = New-Object System.Windows.Forms.Label
        $tickLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $tickLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $tickLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $tickLabel.AutoSize = $true
        $tickLabel.Margin = New-Object System.Windows.Forms.Padding(2)

        [void]$checksLayout.Controls.Add($label, 0, $i)
        [void]$checksLayout.Controls.Add($tickLabel, 1, $i)
        $CheckLabels += $label
        $CheckMarks += $tickLabel
    }
    [void]$contentLayout.Controls.Add($checksLayout, 0, 1)

    $statusPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $statusPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statusPanel.AutoSize = $true
    $statusPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $statusPanel.WrapContents = $false
    $statusPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $statusPanel.Margin = New-Object System.Windows.Forms.Padding(4, 0, 4, 4)

    $FinalCheck = New-Object System.Windows.Forms.Label
    $FinalCheck.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $FinalCheck.ForeColor = "Blue"
    $FinalCheck.Text = "Prerequisite Checks Completed"
    $FinalCheck.AutoSize = $true
    $FinalCheck.Visible = $false
    $FinalCheck.Margin = New-Object System.Windows.Forms.Padding(0, 3, 8, 3)

    $FinalCheckTick = New-Object System.Windows.Forms.Label
    $FinalCheckTick.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $FinalCheckTick.AutoSize = $true
    $FinalCheckTick.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $FinalCheckTick.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 3)
    [void]$statusPanel.Controls.Add($FinalCheck)
    [void]$statusPanel.Controls.Add($FinalCheckTick)
    [void]$contentLayout.Controls.Add($statusPanel, 0, 2)

    $messagePanel = New-Object System.Windows.Forms.Panel
    $messagePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $messagePanel.Margin = New-Object System.Windows.Forms.Padding(4, 0, 4, 4)

    $FailMessage = New-Object System.Windows.Forms.Label
    $FailMessage.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $FailMessage.ForeColor = "Red"
    $FailMessage.AutoSize = $false
    $FailMessage.UseCompatibleTextRendering = $true
    $FailMessage.Padding = New-Object System.Windows.Forms.Padding(6)
    $FailMessage.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $FailMessage.Text = "Check the ones marked with $([char]0x274C) and rerun the tool. Without passing all prerequisites, you cannot register the device to Autopilot.`n`nCheck out this KB0014434 in ServiceNow for more info OR contact $($global:supportEmailAddress)."
    $FailMessage.Dock = [System.Windows.Forms.DockStyle]::Fill
    $FailMessage.Visible = $false

    $SuccessMessage = New-Object System.Windows.Forms.Label
    $SuccessMessage.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $SuccessMessage.ForeColor = "Green"
    $SuccessMessage.AutoSize = $false
    $SuccessMessage.UseCompatibleTextRendering = $true
    $SuccessMessage.Padding = New-Object System.Windows.Forms.Padding(6)
    $SuccessMessage.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $SuccessMessage.Text = "All prerequisites are met. Now in few seconds, it will proceed to location selection."
    $SuccessMessage.Dock = [System.Windows.Forms.DockStyle]::Fill
    $SuccessMessage.Visible = $false
    [void]$messagePanel.Controls.Add($FailMessage)
    [void]$messagePanel.Controls.Add($SuccessMessage)
    [void]$contentLayout.Controls.Add($messagePanel, 0, 3)

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttonPanel.AutoSize = $true
    $buttonPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $buttonPanel.WrapContents = $false
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
    $buttonPanel.Margin = New-Object System.Windows.Forms.Padding(0)

    $RunCheck = New-Object System.Windows.Forms.Button
    $RunCheck.Text = "Run Check"
    $RunCheck.Size = New-Object System.Drawing.Size(120, 35)
    $RunCheck.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $RunCheck.Anchor = [System.Windows.Forms.AnchorStyles]::None
    [void]$buttonPanel.Controls.Add($RunCheck)
    [void]$contentLayout.Controls.Add($buttonPanel, 0, 4)
    [void]$GroupBox.Controls.Add($contentLayout)
    [void]$LocationSelectionForm.Controls.Add($GroupBox)

    $RunCheck.Add_Click({
        $RunCheck.Enabled = $false
        $PrerequisiteStatus = Update-Form

        if ($PrerequisiteStatus -eq $true) {
                
 

                #$ProgressLabel.Text = "All prerequisites have been checked and are fulfilled. This window will close in 10 seconds. Please proceed..."
                #$ProgressBar.Value = 100
                #$ProgressLabel.ForeColor = "#008000"
                Start-Sleep -Seconds 10
                $LocationSelectionForm.Tag = $PrerequisiteStatus
                Start-Sleep -Seconds 10
                $LocationSelectionForm.Close()
               
            }
            Else {
                
                #$ProgressLabel.Text = "The prerequisite check $($PrerequisiteStatus.Result) due to $($PrerequisiteStatus.FailedConditions). For further questions and concerns contact ITS Workplace. Exiting in 20 seconds.."
                #$ProgressLabel.ForeColor = "#ff0000"
                #$LocationSelectionForm.Tag = $PrerequisiteStatus.Result
                Start-Sleep -Seconds 20
                $LocationSelectionForm.Tag = $PrerequisiteStatus
                $LocationSelectionForm.Close()
                #$CloseButton.DialogResult = [System.Windows.Forms.DialogResult]::Abort
                #$CloseButton.Enabled = $true
            }



    })

Function Update-Form {
    $Status = $true

    Try {
        Start-Sleep -Seconds 3 # Initial delay for smooth effect

        # Checking & Updating Tick/Cross Marks (With Delays)
        if ($global:AVCheck -eq $false) {
            $CheckMarks[0].Text = "$([char]0x274C)"
            $CheckMarks[0].ForeColor = "Red"
            $Status = $false
        } else {
            $CheckMarks[0].Text = "$([char]0x2714)"
            $CheckMarks[0].ForeColor = "Green"
        }

        Start-Sleep -Seconds 1

        if ($global:SecureBoot -eq $true) {
            $CheckMarks[1].Text = "$([char]0x2714)"
            $CheckMarks[1].ForeColor = "Green"
        } else {
            $CheckMarks[1].Text = "$([char]0x274C)"
            $CheckMarks[1].ForeColor = "Red"
            $Status = $false
        }
        <#
        Start-Sleep -Seconds 1

        if ($global:CheckARM64Detected -eq $true) {
            $CheckMarks[2].Text = "$([char]0x274C)"
            $CheckMarks[2].ForeColor = "Red"
            $Status = $false
        } else {
            $CheckMarks[2].Text = "$([char]0x2714)"
            $CheckMarks[2].ForeColor = "Green"
        }
        #>
        Start-Sleep -Seconds 1

        if ($global:MSWindowsOSBuildCheck -eq $true) {
            $CheckMarks[2].Text = "$([char]0x2714)"
            $CheckMarks[2].ForeColor = "Green"
        } else {
            $CheckMarks[2].Text = "$([char]0x274C)"
            $CheckMarks[2].ForeColor = "Red"
            $Status = $false
        }

        Start-Sleep -Seconds 1

        if ($global:WindowsEditionCheck -eq $false) {
            $CheckMarks[3].Text = "$([char]0x274C)"
            $CheckMarks[3].ForeColor = "Red"
            $Status = $false
        } else {
            $CheckMarks[3].Text = "$([char]0x2714)"
            $CheckMarks[3].ForeColor = "Green"
        }

        Start-Sleep -Seconds 1

        # Show Final Check Mark
        if ($CheckMarks.Text -contains "$([char]0x274C)") {
            $FinalCheck.Visible = $true
            $FinalCheckTick.Text = "$([char]0x274C)"
            $FinalCheckTick.ForeColor = "Red"
            $FailMessage.Visible = $true
        } else {
            $FinalCheck.Visible = $true
            $FinalCheckTick.Text = "$([char]0x2714)"
            $FinalCheckTick.ForeColor = "Green"
            $FailMessage.Visible = $false
            $SuccessMessage.Visible = $true
        }

        $FinalCheck.Text = "Prerequisite Checks Completed"

    } Catch {
        Write-AppLog $_ ERROR
    }

    return $Status
}

    # Run after WinForms has applied DPI scaling; fit the actual monitor work area.
    $LocationSelectionForm.Add_Shown({
        $workArea = [System.Windows.Forms.Screen]::FromControl($LocationSelectionForm).WorkingArea
        $maximumWidth = [Math]::Max(1, $workArea.Width - 24)
        $maximumHeight = [Math]::Max(1, $workArea.Height - 24)
        $LocationSelectionForm.MinimumSize = New-Object System.Drawing.Size(0, 0)
        $LocationSelectionForm.Size = New-Object System.Drawing.Size(
            [Math]::Min($LocationSelectionForm.Width, $maximumWidth),
            [Math]::Min($LocationSelectionForm.Height, $maximumHeight)
        )
        $LocationSelectionForm.MinimumSize = New-Object System.Drawing.Size(
            [Math]::Min(360, $LocationSelectionForm.Width),
            [Math]::Min(300, $LocationSelectionForm.Height)
        )
        $LocationSelectionForm.Location = New-Object System.Drawing.Point(
            ($workArea.Left + [int](($workArea.Width - $LocationSelectionForm.Width) / 2)),
            ($workArea.Top + [int](($workArea.Height - $LocationSelectionForm.Height) / 2))
        )
    })
    $LocationSelectionForm.ShowDialog() > $null
    return $LocationSelectionForm.Tag
 }

Function Set-WinUserLanguage {

    
    
    if ($($global:Language.LanguageTag) -eq "en-US" ) {
        Write-AppLog "Existing WinUser Language already in $($Language.LanguageTag)" "INFO"
        return $true
    }
    else {
    
        try {
            $Language.Add("en-US")
            Set-WinUserLanguageList -LanguageList $Language -Force
           Write-AppLog "The WinUser Language is set to:$($Language.LanguageTag)." "INFO"
            return $true
        }
        catch {
             Write-AppLog $_ "WARN"
        }
    }
}




function Get-AccessTokenForSupporters {
    [CmdletBinding()]
    param(
        [string] $ClientId = $global:clientId,
        [string] $Authority = $global:authUrl,
        [string[]] $Scopes = @('User.Read'),
        [ValidateRange(1, 30)] [int] $TimeoutMinutes = 10
    )

    if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($Authority)) {
        throw 'The publisher client ID and Microsoft sign-in authority must be configured.'
    }
    $Authority = $Authority.TrimEnd('/')
    $scopesToRequest = @($Scopes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($scopesToRequest.Count -eq 0) { throw 'At least one delegated scope is required.' }
    if ($scopesToRequest -notcontains 'openid') { $scopesToRequest += 'openid' }
    if ($scopesToRequest -notcontains 'profile') { $scopesToRequest += 'profile' }

    # Authorization code with PKCE; no client secret or embedded browser.
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object byte[] 32
        $rng.GetBytes($bytes)
        $state = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $rng.GetBytes($bytes)
        $codeVerifier = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
    finally { $rng.Dispose() }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $challenge = $sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($codeVerifier))
        $codeChallenge = [Convert]::ToBase64String($challenge).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
    finally { $sha256.Dispose() }

    $portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try {
        $portProbe.Start()
        $port = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port
    }
    finally { $portProbe.Stop() }
    $redirectUri = "http://localhost:$port/"
    $query = @{
        client_id = $ClientId
        response_type = 'code'
        redirect_uri = $redirectUri
        response_mode = 'query'
        scope = ($scopesToRequest -join ' ')
        prompt = 'select_account'
        state = $state
        code_challenge = $codeChallenge
        code_challenge_method = 'S256'
    }
    $queryString = ($query.GetEnumerator() | ForEach-Object {
        '{0}={1}' -f [Uri]::EscapeDataString([string]$_.Key), [Uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
    $authorizeUri = "$Authority/oauth2/v2.0/authorize?$queryString"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($redirectUri)
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    $authorizationCode = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        $listener.Start()
        Write-Host 'Opening your browser for Microsoft sign-in. Complete sign-in there; registration will continue automatically.'
        Start-Process -FilePath $authorizeUri -ErrorAction Stop
        $deadline = [DateTime]::UtcNow.AddMinutes($TimeoutMinutes)
        while (-not $authorizationCode) {
            $pending = $listener.BeginGetContext($null, $null)
            try {
                while (-not $pending.AsyncWaitHandle.WaitOne(100)) {
                    [System.Windows.Forms.Application]::DoEvents()
                    if ([DateTime]::UtcNow -ge $deadline) {
                        throw "Sign-in timed out after $TimeoutMinutes minutes. Run registration again."
                    }
                }
                $context = $listener.EndGetContext($pending)
            }
            finally { $pending.AsyncWaitHandle.Close() }
            $response = $context.Response
            $page = '<html><body><h2>Sign-in could not be verified.</h2><p>Return to the registration script.</p></body></html>'
            try {
                # Ignore unrelated browser requests such as favicon.ico.
                if ($context.Request.Url.AbsolutePath -ne '/') {
                    $response.StatusCode = 404
                    continue
                }
                if ($context.Request.QueryString['state'] -cne $state) {
                    $response.StatusCode = 400
                    throw 'The sign-in callback state did not match. Registration stopped.'
                }
                $oauthError = $context.Request.QueryString['error']
                if ($oauthError) {
                    $response.StatusCode = 400
                    throw "Microsoft sign-in failed: $oauthError. $($context.Request.QueryString['error_description'])"
                }
                $authorizationCode = $context.Request.QueryString['code']
                if ([string]::IsNullOrWhiteSpace($authorizationCode)) {
                    $response.StatusCode = 400
                    throw 'No authorization code was received. Registration stopped.'
                }
                $response.StatusCode = 200
                $page = '<html><body><h2>Sign-in response received</h2><p>You can close this tab and return to Autopilot Registration.</p></body></html>'
            }
            finally {
                try {
                    $pageBytes = [System.Text.Encoding]::UTF8.GetBytes($page)
                    $response.ContentType = 'text/html; charset=utf-8'
                    $response.ContentLength64 = $pageBytes.Length
                    $response.OutputStream.Write($pageBytes, 0, $pageBytes.Length)
                }
                finally { $response.Close() }
            }
        }
        $tokenResponse = Invoke-RestMethod -Method Post -Uri "$Authority/oauth2/v2.0/token" -Body @{
            grant_type = 'authorization_code'
            client_id = $ClientId
            code = $authorizationCode
            redirect_uri = $redirectUri
            code_verifier = $codeVerifier
        } -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30 -ErrorAction Stop
        if (-not $tokenResponse.access_token) { throw 'Microsoft did not return an access token.' }
        return [pscustomobject]@{
            IsTokenExist = $true
            token_type = $tokenResponse.token_type
            scope = $tokenResponse.scope
            expires_in = $tokenResponse.expires_in
            expires_on = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + [int]$tokenResponse.expires_in
            access_token = $tokenResponse.access_token
        }
    }
    finally {
        $listener.Close()
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
    }
}


Function Get-AzureADgroupLocationcomparison {

    $AzureADTableComparisontoadddevicetoappro = @(
        @{Location = "DE"; Country = "Germany" },
        @{Location = "LK"; Country = "Sri Lanka" },
        @{Location = "UA"; Country = "Ukraine" },
        @{Location = "IN"; Country = "India" },
        @{Location = "US"; Country = "United States" },
        @{Location = "PH"; Country = "Philippines" },
        @{Location = "CH"; Country = "Switzerland" },
        @{Location = "CO"; Country = "Colombia" },
        @{Location = "BR"; Country = "Brazil" },
        @{Location = "FR"; Country = "France" },
        @{Location = "MX"; Country = "Mexico" },
        @{Location = "NL"; Country = "Netherlands" },
        @{Location = "IE"; Country = "Ireland" },
        @{Location = "RO"; Country = "Romania" },
        @{Location = "BG"; Country = "Bulgaria" },
        @{Location = "MY"; Country = "Malaysia" },
        @{Location = "NZ"; Country = "New Zealand" },
        @{Location = "KZ"; Country = "Kazakhstan" },
        @{Location = "PL"; Country = "Poland" },
        @{Location = "NO"; Country = "Norway" },
        @{Location = "RS"; Country = "Serbia" },
        @{Location = "AT"; Country = "Austria" },
        @{Location = "CN"; Country = "China" },
        @{Location = "GB"; Country = "United Kingdom" },
        @{Location = "CL"; Country = "Chile" },
        @{Location = "AU"; Country = "Australia" },
        @{Location = "UY"; Country = "Uruguay" },
        @{Location = "JP"; Country = "Japan" },
        @{Location = "SI"; Country = "Slovenia" },
        @{Location = "FI"; Country = "Finland" },
        @{Location = "CR"; Country = "Costa Rica" },
        @{Location = "AE"; Country = "United Arab Emirates" },
        @{Location = "TR"; Country = "Turkey" },
        @{Location = "RU"; Country = "Russia" },
        @{Location = "PE"; Country = "Peru" },
        @{Location = "CA"; Country = "Canada" },
        @{Location = "ID"; Country = "Indonesia" },
        @{Location = "ES"; Country = "Spain" },
        @{Location = "BO"; Country = "Bolivia" },
        @{Location = "IT"; Country = "Italy" },
        @{Location = "HK"; Country = "Hong Kong" },
        @{Location = "HU"; Country = "Hungary" },
        @{Location = "SG"; Country = "Singapore" },
        @{Location = "TH"; Country = "Thailand" },
        @{Location = "KR"; Country = "Korea" },
        @{Location = "TW"; Country = "Taiwan" },
        @{Location = "VN"; Country = "Vietnam" },
        @{Location = "BE"; Country = "Belgium" },
        @{Location = "CZ"; Country = "Czechia" },
        @{Location = "SE"; Country = "Sweden" },
        @{Location = "SK"; Country = "Slovakia" },
        @{Location = "ZA"; Country = "South Africa" },
        @{Location = "AR"; Country = "Argentina" },
        @{Location = "DO"; Country = "Dominican Republic" },
        @{Location = "EC"; Country = "Ecuador" },
        @{Location = "HN"; Country = "Honduras" },
        @{Location = "JM"; Country = "Jamaica" },
        @{Location = "PA"; Country = "Panama" },
        @{Location = "PR"; Country = "Puerto Rico" },
        @{Location = "SV"; Country = "El Salvador" },
        @{Location = "TT"; Country = "Trinidad and Tobago" },
        @{Location = "GT"; Country = "Guatemala" },
        @{Location = "LU"; Country = "Luxembourg" },
        @{Location = "DK"; Country = "Denmark" },

        # Newly added based on your pasted list:
        @{Location = "EG"; Country = "Egypt" },
        @{Location = "EE"; Country = "Estonia" },
        @{Location = "GR"; Country = "Greece" },
        @{Location = "IS"; Country = "Iceland" },
        @{Location = "IL"; Country = "Israel" },
        @{Location = "JO"; Country = "Jordan" },
        @{Location = "KE"; Country = "Kenya" },
        @{Location = "LV"; Country = "Latvia" },
        @{Location = "LB"; Country = "Lebanon" },
        @{Location = "LT"; Country = "Lithuania" },
        @{Location = "MU"; Country = "Mauritius" },
        @{Location = "ME"; Country = "Montenegro" },
        @{Location = "MK"; Country = "North Macedonia" },
        @{Location = "PK"; Country = "Pakistan" },
        @{Location = "PT"; Country = "Portugal" },
        @{Location = "QA"; Country = "Qatar" },
        @{Location = "SA"; Country = "Saudi Arabia" }
    ) | ForEach-Object { New-Object object | Add-Member -NotePropertyMembers $_ -PassThru }

    return $AzureADTableComparisontoadddevicetoappro
}

Function Get-DepartmentSelection {
    @('Finance', 'HR', 'Marketing', 'Sales', 'Cloud Infra', 'IT Operations') |
        ForEach-Object { [pscustomobject]@{ DepartmentName = $_ } }
}

Function Get-LocationSelection {

       
    Add-Type -assembly System.Windows.Forms


    #########################################################################################################

    $main_form = New-Object System.Windows.Forms.Form
    $main_form.Text = 'Country Selection'
    $main_form.ClientSize = New-Object System.Drawing.Size(380, 190)
    $main_form.MinimumSize = New-Object System.Drawing.Size(340, 210)
    $main_form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $main_form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $main_form.StartPosition = 'CenterScreen'
    $main_form.ShowIcon = $false

    #########################################################################################################

    $Label3 = New-Object System.Windows.Forms.Label

    $Label3.Text = "Select the country using the dropdown below"

    $Label3.TabIndex = [System.Int32]5

    $Label3.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Label3.AutoSize = $true
    $Label3.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)



    ###########################################################################################################################


    $ComboBox = New-Object System.Windows.Forms.ComboBox

    $ComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    $SelectionItems = Get-AzureADgroupLocationcomparison | Sort-Object -Property Country

    $Location_var = @()

    Foreach ($SelectionItem in $SelectionItems) {

        $Location_var += $ComboBox.Items.Add($SelectionItem.Country);

    }

    $ComboBox.TabIndex = [System.Int32]6

    $ComboBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComboBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
    $ComboBox.Add_SelectedIndexChanged({ $Button.Enabled = $true })

    ##########################################################################################################################

    $Button = New-Object System.Windows.Forms.Button

    $Button.Size = New-Object System.Drawing.Size(120, 32)
    $Button.Anchor = [System.Windows.Forms.AnchorStyles]::None

    $Button.TabIndex = [System.Int32]1

    $Button.Text = "Submit"

    $Button.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $Button.Enabled = $false

    $Button.Add_Click({ CheckforCombo })

    $main_form.AcceptButton = $Button

    $selectionLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $selectionLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $selectionLayout.Padding = New-Object System.Windows.Forms.Padding(18, 16, 18, 12)
    $selectionLayout.AutoScroll = $true
    $selectionLayout.ColumnCount = 1
    $selectionLayout.RowCount = 3
    $selectionLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $selectionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $selectionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $selectionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    [void]$selectionLayout.Controls.Add($Label3, 0, 0)
    [void]$selectionLayout.Controls.Add($ComboBox, 0, 1)
    [void]$selectionLayout.Controls.Add($Button, 0, 2)
    [void]$main_form.Controls.Add($selectionLayout)


    #########################################################################################################################


    Function CheckforCombo {
        if ($ComboBox.selectedItem.Length -ne 0) {
            $ComboBox.Enabled = $true
        }
        else {
            $ComboBox.Enabled = $false
        }
    }


    #####################################################################################################################




    $main_form.Add_Shown({ Fit-DialogToScreen -Form $main_form })
    $result = $main_form.ShowDialog()


    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {

        if (!$($ComboBox.selectedItem)) {

        }

        else {
            $location = Get-AzureADgroupLocationcomparison | where-object { $_.Country -eq $($ComboBox.selectedItem) }
            return $Location.Location
        }
    }


}

Function Get-DepartmentDetails {

       
    Add-Type -assembly System.Windows.Forms


    #########################################################################################################

    $main_form = New-Object System.Windows.Forms.Form
    $main_form.Text = 'Select the department'
    $main_form.ClientSize = New-Object System.Drawing.Size(380, 190)
    $main_form.MinimumSize = New-Object System.Drawing.Size(340, 210)
    $main_form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $main_form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $main_form.StartPosition = 'CenterScreen'
    $main_form.ShowIcon = $false

    #########################################################################################################

    $Label3 = New-Object System.Windows.Forms.Label

    $Label3.Text = "Select the department using the dropdown below"

    $Label3.TabIndex = [System.Int32]5

    $Label3.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Label3.AutoSize = $true
    $Label3.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)



    ###########################################################################################################################


    $ComboBox = New-Object System.Windows.Forms.ComboBox

    $ComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    $SelectionItems = Get-DepartmentSelection | Sort-Object -Property DepartmentName

    $Location_var = @()

    Foreach ($SelectionItem in $SelectionItems) {

        $Location_var += $ComboBox.Items.Add($SelectionItem.DepartmentName);

    }

    $ComboBox.TabIndex = [System.Int32]6

    $ComboBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComboBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
    $ComboBox.Add_SelectedIndexChanged({ $Button.Enabled = $true })

    ##########################################################################################################################

    $Button = New-Object System.Windows.Forms.Button

    $Button.Size = New-Object System.Drawing.Size(120, 32)
    $Button.Anchor = [System.Windows.Forms.AnchorStyles]::None

    $Button.TabIndex = [System.Int32]1

    $Button.Text = "Submit"

    $Button.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $Button.Enabled = $false

    $Button.Add_Click({ CheckforCombo })

    $main_form.AcceptButton = $Button

    $selectionLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $selectionLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $selectionLayout.Padding = New-Object System.Windows.Forms.Padding(18, 16, 18, 12)
    $selectionLayout.AutoScroll = $true
    $selectionLayout.ColumnCount = 1
    $selectionLayout.RowCount = 3
    $selectionLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $selectionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $selectionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $selectionLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    [void]$selectionLayout.Controls.Add($Label3, 0, 0)
    [void]$selectionLayout.Controls.Add($ComboBox, 0, 1)
    [void]$selectionLayout.Controls.Add($Button, 0, 2)
    [void]$main_form.Controls.Add($selectionLayout)


    #########################################################################################################################


    Function CheckforCombo {
        if ($ComboBox.selectedItem.Length -ne 0) {
            $ComboBox.Enabled = $true
        }
        else {
            $ComboBox.Enabled = $false
        }
    }


    #####################################################################################################################




    $main_form.Add_Shown({ Fit-DialogToScreen -Form $main_form })
    $result = $main_form.ShowDialog()


    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {

        if (!$($ComboBox.selectedItem)) {

        }

        else {
            $location = Get-DepartmentSelection | where-object { $_.DepartmentName -eq $($ComboBox.selectedItem) }
            return $Location
        }
    }


}

Function Get-GUIDetails {

    try {

        $User_Location = Get-LocationSelection

    }
    catch {

        Write-AppLog $_ "ERROR"
    }

      

    if ($User_Location) {
        $Object = New-Object PSObject -Property @{
            Location = $User_Location
        }
       
        return $Object
    }
    else {
        #[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
        #[System.Windows.Forms.MessageBox]::Show("$_ The location value submitted was empty. Please run the import tool again. ", 'ERROR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}        

Function Push-Devicedetails {

    $DepartmentSelection = Get-DepartmentDetails
    $SelectedDepartment = $DepartmentSelection.DepartmentName
    Start-Sleep -Seconds 3
    $Data_Collected_GUI = Get-GUIDetails
    $Data_Collected_GUI_Location = $Data_Collected_GUI.Location
        

    if (($Data_Collected_GUI_Location) -and ($SelectedDepartment)) {


        # Set the user language to en-US when needed.
        try {
            Set-WinUserLanguage
        }
        catch {
           Write-AppLog $_ "ERROR"
        }


        if (!$global:SupportedBuildNumber) {

            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
            [System.Windows.Forms.MessageBox]::Show("$_ The current windows edition is not supported! Please upgrade the windows to professional and try again. ", 'ERROR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)

            exit
        }
    else {
    

            if (($($global:OSBuildNumber) -ge "22621") -and ($Data_Collected_GUI_Location) -and ($SelectedDepartment)) {
                Write-AppLog "The device OS Product Name is:$($global:WindowsEdition)." INFO
                Write-AppLog "The device OS build version is:$($global:OSBuildNumber) and it is supported." INFO
                Write-AppLog "The powershell version on this device is: $($global:psv)." INFO


       
                # Require tenant-specific browser sign-in and verify the supporter before collecting hardware data.
  
                $SignedUserName = $null
                $tokenResponse = Get-AccessTokenForSupporters

                $authHeader = @{
                    'Content-Type'  = 'application/json'
                    'Authorization' = "Bearer " + $tokenResponse.access_token
                    'ExpiresOn'     = $tokenResponse.expires_on
                }

                try {
                    $SignedUserName = Invoke-RestMethod -Method Get -Uri $($global:Get_AzureAD_SignedIn_User) -Headers $authHeader -TimeoutSec 30 -ErrorAction Stop
                    if (-not $SignedUserName.id -or [string]::IsNullOrWhiteSpace($SignedUserName.userPrincipalName)) {
                        throw 'The signed-in supporter profile is incomplete.'
                    }
                    $User = $SignedUserName.userPrincipalName
                    Write-AppLog "Signed In User: $User" INFO
                }
                catch {
                    Write-AppLog 'Could not verify the signed-in supporter with Microsoft Graph. Submission stopped.' ERROR
                    throw 'Supporter verification failed. No device data was submitted.'
                } 

                # Collect data from the device

                if (($null -ne $SignedUserName) -and ($null -ne $tokenResponse)) {


                    $global:DeviceHashData = [string](Get-CimInstance -Namespace 'root/cimv2/mdm/dmmap' -ClassName 'MDM_DevDetail_Ext01' -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction Stop).DeviceHardwareData
                    $global:SerialNumber = [string](Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber
                    $global:ProductKey = [string](Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey
                    $global:DeviceHashData = $global:DeviceHashData.Trim()
                    $global:SerialNumber = $global:SerialNumber.Trim()
                    $global:ProductKey = $global:ProductKey.Trim()

                    if (($global:SerialNumber) -and ($global:DeviceHashData)) {

                        $hash = New-Object PSObject -Property @{
                            groupTag                  = if ($Data_Collected_GUI_Location) { "$($Data_Collected_GUI_Location)" } else { "" }
                            serialNumber              = "$($global:SerialNumber)"
                            productKey                = if ($global:ProductKey) { "$($global:ProductKey)" } else { "" }
                            hardwareIdentifier        = "$($global:DeviceHashData)"
                            assignedUserPrincipalName = if ($Data_Collected_GUI_UPN) { "$($Data_Collected_GUI_UPN)" } else { "" }
                            deviceName                = if ($global:dvcComputerName) { "$($global:dvcComputerName)" } else { "" }
                            PublicIP                  = if ($global:PublicIPAddress) { "$($global:PublicIPAddress)" } else { "" }
                            OsBuildNumber             = if ($global:OSBuildNumber) { "$($global:OSBuildNumber)" } else { "" }
                            SKU                       = if ($global:SKU) { "$($global:SKU)" } else { "" }
                            Model                     = if ($global:Model) { "$($global:Model)" } else { "" }
                            BiosName                  = "$($global:Bios)"
                            Manufacturer              = "$($global:Manufacturer)"
                            WindowsEdition            = "$($global:WindowsEdition)"
                            CurrentSystemDate         = "$($global:CurrentDate)"
                            ActivationState           = "$($global:ActivationState)"
                            ActivationInfo            = "$($global:ActivationInfo)"
                            CurrectTimeZone           = "$($global:CurrectTimeZoneSet.DisplayName)"
                            ITSupporter               = "$($SignedUserName.userPrincipalName)"
                            extentionAttribute1       = "$($SelectedDepartment)"

                        }
   
                        $collectedResults = $hash | select-object groupTag, Model, serialNumber, productKey, hardwareIdentifier, deviceName, PublicIP, assignedUserPrincipalName, SKU, OsBuildNumber, CurrentSystemDate, CurrectTimeZone, BiosName, ActivationState, ActivationInfo, WindowsEdition, Manufacturer, ITSupporter, extentionAttribute1
                        $collectedJson = ConvertTo-Json -InputObject $collectedResults
   
                        # Post Call to Logic Apps     
                        $Header = @{ message = "$dvcComputerName" }
                        

                
                        try {
                            $submissionUri = $null
                            if ([string]::IsNullOrWhiteSpace($global:BackendUrl)) {
                                throw 'BackendUrl is empty. Configure the Logic App Request trigger URL before submitting device data.'
                            }
                            if (-not [Uri]::TryCreate($global:BackendUrl, [UriKind]::Absolute, [ref]$submissionUri) -or $submissionUri.Scheme -ne 'https') {
                                throw 'BackendUrl must be a valid HTTPS URL.'
                            }
                            Invoke-RestMethod -Method POST -Uri $global:BackendUrl -Body $collectedJson -Headers $Header -ContentType 'application/json' -TimeoutSec 60 -ErrorAction Stop | Out-Null
                        }
                        catch {
                            # Do not log the request URL: flow URLs can contain secret signatures.
                            $submissionFailure = 'Device submission failed. Check the flow configuration, network, and flow run history.'
                            if ([string]::IsNullOrWhiteSpace($global:BackendUrl)) {
                                $submissionFailure = 'Sign-in succeeded, but BackendUrl is empty. Configure the Logic App Request trigger URL before submitting device data.'
                            }
                            elseif ($submissionUri -and $submissionUri.Scheme -ne 'https') {
                                $submissionFailure = 'Sign-in succeeded, but BackendUrl must use HTTPS.'
                            }
                            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                                $submissionFailure += " HTTP status: $([int]$_.Exception.Response.StatusCode)."
                            }
                            Write-AppLog $submissionFailure ERROR
                            [void][System.Windows.Forms.MessageBox]::Show($submissionFailure, 'Device submission failed', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                            return
                        }

                        try {
                            Start-ScheduledTask -TaskName "ForceSynchronizeTime" -TaskPath "\Microsoft\Windows\Time Synchronization" -Verbose
                            start-Sleep -Seconds 10
                            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
                            [System.Windows.Forms.MessageBox]::Show("Device data submitted successfully. The serial number is: $SerialNumber. Check your backend workflow for import confirmation.", 'Information', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                            $CheckTimeSyncService = Get-Service -Name W32Time
                            if ($CheckTimeSyncService.Status -eq "Running") {
                                w32tm /resync /force  
                            }
                            else {

                                Start-Service -Name W32Time -Verbose
                                Start-sleep -Seconds 5
                                w32tm /resync /force  
                            }
                            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
                            [System.Windows.Forms.MessageBox]::Show("The device will restart after you click OK.", 'Information', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                            shutdown /r /t 2
                        }

                        catch {
    
                            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
                            Write-AppLog 'Device data was submitted, but a post-submission operation failed. Check time synchronization and restart manually.' WARN
                            [System.Windows.Forms.MessageBox]::Show("Device data was submitted, but time synchronization or restart could not complete. Check the backend before retrying submission.", 'Post-submission warning', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)

                        }

                    }


                    else {
                        [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
                        [System.Windows.Forms.MessageBox]::Show("Required hardware information was not available for import. Be sure to run the application as administrator.", 'ERROR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    }

                }

                else {
                    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
                    [System.Windows.Forms.MessageBox]::Show("You're not authenticated. Please run the application again and sign in.", 'ERROR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)

                }
            }
            else {
                #write-warning "This device Windows OS build number $OSBuildNumber NOT supported: it should be minimum [18363] which is 1909'. Ref:https://docs.microsoft.com/en-us/windows/release-health/release-information"
                [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
                [System.Windows.Forms.MessageBox]::Show("The device OS build number is:$OSBuildNumber and its NOT supported. It should be minimum [18363] which is 1909. Please update the windows version to alteast 1909 and then try again.'. Ref:https://docs.microsoft.com/en-us/windows/release-health/release-information", 'ERROR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }

    }

    else {

        [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
        [System.Windows.Forms.MessageBox]::Show("The location value submitted was empty. Please run the import tool again.", 'ERROR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$global:MSWindowsOSBuildCheck = Get-WindowsOSBuildNumber
$global:WindowsEditionCheck = Get-WindowsEditionStatus
$global:AVCheck = $true
#CheckThirdPartyAntivirus
$global:SecureBoot = Get-SecureBootState
$global:CheckARM64Detected = $false

$result = Get-PrerequisiteCheck

<#
$global:AVCheck = $true
$global:SecureBoot = $true
$global:CheckARM64Detected = $false
$global:WindowsEditionCheck = $true
$result = Get-PrerequisiteCheck
#>

if (($result -eq $true)) {

    Push-Devicedetails

}
else {

    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')

    [System.Windows.Forms.MessageBox]::Show(
        "This device does not meet the requirement to register. Contact ITS for support...",
        'Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}