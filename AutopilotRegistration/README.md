# Windows Autopilot Registration

Register newly purchased Windows laptops with Windows Autopilot using a PowerShell
script and an Azure Logic App.

This project is for organizations that buy laptops without an OEM or reseller
registering them in Autopilot. A supporter runs the tool on the new laptop, signs
in with a work account, and submits the device details. The Logic App imports the
device, checks its deployment-profile assignment, and emails the supporter with
the result. The supporter can then confirm the device is ready before handing it
to the employee.

The solution was first built in 2021 and has been updated since then. Each
organization uses its own tenant, app registration, and Logic App.

## How it works

1. The supporter starts the script during Windows setup (OOBE).
2. The script runs prerequisite checks and asks for a department and country.
3. The supporter signs in through the browser using an account in the configured tenant.
4. The script verifies the signed-in profile, collects the hardware hash, and sends
   the device details to the Logic App as JSON.
5. The Logic App imports the device into Autopilot and checks whether its deployment
   profile is assigned.
6. The supporter receives an email confirming readiness, or explaining a failure
   or pending result.

The script submits the information; the Logic App performs the registration.
A successful submission does not mean the device is ready. Wait for the email
confirming registration and profile assignment before handing over the laptop.

## Files

| File | Purpose |
|---|---|
| [AutopilotRegistration.ps1](AutopilotRegistration.ps1) | Windows checks, browser sign-in, hardware collection, and submission |
| [workflow.json](workflow.json) | Logic App workflow for import, status checks, and email notifications |

## Set up the Logic App

Do this once for your organization. You need an Azure subscription in your Intune
tenant, an active Intune license, and administrator access to grant permissions.

### Create the workflow

1. Create an Azure Logic App using the **Consumption** plan.
2. Under **Identity**, enable **System assigned** and save.
3. Create and authorize an **Office 365 Outlook** connection using your notification account.
4. Open [workflow.json](workflow.json). Under the outer
   `parameters.$connections.value.outlook` section, replace these placeholders:

   | Placeholder | Your value |
   |---|---|
   | YOUR_SUBSCRIPTION_ID | Azure subscription ID |
   | YOUR_AZURE_REGION | Region of the Outlook connection |
   | YOUR_RESOURCE_GROUP | Resource group containing the connection |
   | YOUR_OUTLOOK_CONNECTION_NAME | Name of the Outlook API connection |

5. Open the Logic App's **Code view**, paste the complete JSON, and save.
6. In the designer, confirm that the email actions use your authorized connection.

Consumption is billed by usage. The workflow does not create Intune groups or
assign deployment profiles. Set up your groups and profile assignments in Intune
so the imported device can receive its profile. The workflow monitors that assignment.

### Grant the managed identity permission

The Logic App uses its system-assigned identity for all three Graph HTTP actions.
No client secret is needed for those calls. Azure manages
the identity's credentials, but you still need to grant it permission once.

Assign the Microsoft Graph **application** permission:

```text
DeviceManagementServiceConfig.ReadWrite.All
```

This covers importing the device, reading import status, and reading deployment-profile
assignment status. `Device.Read.All` is not required for this workflow.

An authorized Entra administrator can run the following on an administration
workstation. These modules are not needed on the new laptop:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Applications -Scope CurrentUser
Connect-MgGraph -TenantId '<tenant-id>' -Scopes 'Application.Read.All','AppRoleAssignment.ReadWrite.All'

$identityId = '<Object (principal) ID from the Logic App Identity page>'
$graph = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$role = $graph.AppRoles | Where-Object {
    $_.Value -eq 'DeviceManagementServiceConfig.ReadWrite.All' -and
    $_.AllowedMemberTypes -contains 'Application'
}
if (-not $role) { throw 'Required Graph application role not found.' }

$existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $identityId -All |
    Where-Object { $_.ResourceId -eq $graph.Id -and $_.AppRoleId -eq $role.Id }
if (-not $existing) {
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $identityId -BodyParameter @{
        principalId = $identityId
        resourceId = $graph.Id
        appRoleId = $role.Id
    }
}
Disconnect-MgGraph
```

On each Graph HTTP action, confirm these authentication settings:

- Authentication: **Managed identity**
- Managed identity: **System-assigned managed identity**
- Audience: **https://graph.microsoft.com**

The JSON already includes these settings for `Graph_import_Autopilot_device`,
`Poll_import_by_ID`, and `Poll_profile_by_device_ID`. The profile check uses the
Graph beta endpoint, so test it when updating the workflow.

### Customize the emails

Edit the defaults under `definition.parameters` in workflow.json before importing,
or set their values in the Logic App's workflow parameters.

| Setting | Purpose |
|---|---|
| NotificationSender | Mailbox used in the From field |
| SupportEmail | Fallback recipient if the submission has no supporter address |
| EmailGreeting | Defaults to “Dear supporter,” |
| EmailClosing | Defaults to “Regards,” followed by “Workplace” |
| EmailTemplates | Subject and body for each of the nine notification actions |

Notifications normally go to the `ITSupporter` address sent by the script. Each
message has a subject for its purpose, such as import failure, profile pending,
or device ready, and includes the serial number.

Replace the example email addresses before use. If the sender differs from the
Outlook connection account, grant that account the required Exchange **Send As**
permission. The Outlook connection needs its own mailbox authorization; enabling
managed identity for Graph HTTP calls does not authorize the email connector.

Email template text can contain HTML. Add dynamic fields in the email action itself;
expressions placed inside a template parameter are not evaluated recursively.
Use workflow run history for detailed error information. Teams notifications can
be added to the workflow if your organization prefers them.

### Copy the backend URL

Save the workflow, open **When an HTTP request is received**, and copy its
**HTTP POST URL**. This is the URL used by the Windows script, not the URL of an
outbound Graph action.

The generated URL contains a shared-access signature. Keep it and any configured
script or package private. Publish only placeholder values in GitHub. The Windows
script requires sign-in, but the workflow's signed request URL authorizes inbound
requests by possession of that URL. It does not independently verify the supporter's
Graph token. Managed identity authenticates the workflow's outbound Graph requests.

## Set up the PowerShell script

### Register the sign-in app

In Microsoft Entra admin center, create an app registration:

1. Name it **Windows Autopilot Registration App**.
2. Choose **Accounts in this organizational directory only**.
3. Under Authentication, add **Mobile and desktop applications** with redirect URI
   **http://localhost**.
4. Add **Microsoft Graph > Delegated > User.Read** and grant admin consent if your
   organization requires it.
5. Copy the **Application (client) ID** and **Directory (tenant) ID**.

The script uses browser-based **authorization code with PKCE**, not implicit grant.
It requests User.Read and the standard openid/profile sign-in scopes. It does not
need a client secret or permission to import devices. Those import permissions
belong to the Logic App's managed identity.

Single-tenant access follows your directory's policies, including guest access.
Use Enterprise Application user assignments if only certain supporters should run it.

### Enter the three values

Open AutopilotRegistration.ps1 in a text editor and replace the values near the top:

```powershell
$global:TenantId = 'YOUR-TENANT-ID'
$global:ClientId = 'YOUR-APPLICATION-CLIENT-ID'
$global:BackendUrl = 'YOUR-LOGIC-APP-HTTP-POST-URL'
```

Save as **UTF-8 with BOM**. The script also uses character expressions for check
marks to avoid encoding issues in Windows PowerShell.

This is a one-time setup. Keep the configured source with your administrators and
prepare the distribution method your organization approves.

### Change department and country choices

The list includes **Finance, HR, Marketing, Sales, Cloud Infra, and IT Operations**.
Edit `Get-DepartmentSelection` in the PowerShell script to use your own department
names, labels, or classifications. These choices do not change the sign-in tenant.

Country selection is sent as `groupTag` for your Intune group rules and deployment
profile assignments.

For the department or other classification, the PowerShell script only provides a
placeholder in the JSON payload, named `extentionAttribute1` (the existing field
spelling). It sends the selected label but does not attach it to a device attribute.

**The current Logic App does not set any Entra device extension attributes.**
You can extend it later with a step that finds the corresponding device and writes
the submitted label to an available `extensionAttribute1` through
`extensionAttribute15`. This is an optional addition for your own management needs,
not part of the supplied workflow. That step needs the appropriate Graph permissions
and must handle the device object becoming available after registration.

## Run on a new laptop

Use Windows PowerShell 5.1 on supported Windows 11 Pro, Enterprise, or Education,
with administrator rights, Internet access, Secure Boot, and an available browser.
The script needs an interactive Windows session, including OOBE; it is not designed
for WinPE or a background service. No PowerShell modules need installing on the laptop.

For direct script testing:

1. Put the configured script on a USB drive and connect the laptop to the network.
2. During OOBE, press **Shift+F10** (some keyboards also need Fn).
3. Run the following, replacing E: with the USB drive letter:

   ```cmd
   powershell.exe -NoProfile -STA -File "E:\AutopilotRegistration.ps1"
   ```

4. Run the checks, select the department and country, and sign in.
5. After submission, follow the restart prompt and wait for the backend email.

The script synchronizes time and prompts for a restart after submission. It does
not wait for profile assignment. Do not hand over the laptop until the backend
confirms readiness. Closing the browser leaves sign-in waiting until the ten-minute
timeout or until you stop the script.

## Distribute to supporters

For operational use, an organization can package its configured script as an EXE,
host it in its own Azure Blob Storage, and share a small batch launcher. The launcher
downloads an approved release over HTTPS, verifies it against a trusted hash or
publisher signature, runs it, waits for completion, and deletes the temporary file.
Report download or launch failures rather than hiding them. Cleanup may not finish
if the device loses power or a security product quarantines the file.

This keeps the configured PowerShell file out of the normal supporter download,
but it does not make the script or backend URL secret. EXE wrappers can be inspected,
and a launcher reveals its download location. Deleting a file is not secure erasure.
Protect Blob access and any signed download URLs. Do not publish organization-specific
credentials in the source repository.

Packaging, hosting, optional code signing, and security-policy approval belong to
the adopting organization. No EXE builder or download launcher is included here.
Defender, SmartScreen, Smart App Control, and company application policies may block
scripts or executables. Conversion to EXE does not guarantee acceptance, and signing
does not guarantee freedom from reputation warnings. Have the security team review
the release and arrange any approvals required. The script does not disable security
products or bypass execution policy.

## Display scaling and testing

The forms use DPI autoscaling and fit the monitor's available work area. The
prerequisite window starts compact and supports scrolling. The selection dialogs
also fit the screen. No x64-only native library is bundled, and ARM64 is not excluded.

Test your release on the actual Intel/AMD x64 and ARM64 devices you support, including
100%, 150%, and 200% scaling, small screens, and external monitors. Confirm that
Run Check and Submit stay reachable. PowerShell hosts can handle DPI differently.
Windows, ARM64, Azure deployment, and live email delivery have not been verified
from the development Mac.

The current script sets the antivirus check result to true at startup, so that
check is not enforced. Review this policy before deploying it in your organization.

Before rollout, test successful registration, profile pending, denied sign-in,
missing fields, backend errors, and email sender permissions. Check Intune and run
history before retrying a pending import to avoid unnecessary duplicate submissions.

## References

- [Desktop sign-in configuration](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-configuration)
- [Logic Apps managed identity](https://learn.microsoft.com/en-us/azure/logic-apps/authenticate-with-managed-identity)
- [Autopilot import API](https://learn.microsoft.com/en-us/graph/api/intune-enrollment-importedwindowsautopilotdeviceidentity-import?view=graph-rest-1.0)
- [Autopilot profile-status permissions](https://learn.microsoft.com/en-us/graph/api/intune-enrollment-windowsautopilotdeviceidentity-get?view=graph-rest-beta)
- [Office 365 Outlook connection](https://learn.microsoft.com/en-us/azure/connectors/connectors-create-api-office365-outlook)
- [Manual registration during OOBE](https://learn.microsoft.com/en-us/autopilot/add-devices)
- [SmartScreen and signing](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)
