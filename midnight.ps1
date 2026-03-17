#
    MIDNIGHT AUDITOR – COMPACT BLACKOUT
    -----------------------------------
    - Smaller UI Footprint
    - Pure BlackWhite HUD
    - Always On Top & Draggable
#

if ([Threading.Thread]CurrentThread.GetApartmentState() -ne 'STA') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -File $PSCommandPath
    exit
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms

# --- SESSION MEMORY ---
$GlobalSessionHistory = @()
$GlobalSessionClipboard = @()
$GlobalLastClipItem = 

$ClipTimer = New-Object System.Windows.Forms.Timer
$ClipTimer.Interval = 1000
$ClipTimer.Add_Tick({
    try {
        $current = [Windows.Forms.Clipboard]GetText()
        if ($current -and $current -ne $GlobalLastClipItem) {
            $GlobalLastClipItem = $current
            $GlobalSessionClipboard += [PSCustomObject]@{ Time = (Get-Date).ToString(HHmmss); Content = $current }
        }
    } catch {}
})
$ClipTimer.Start()

# --- UI DEFINITION (COMPACT) ---
$xaml = @
Window xmlns=httpschemas.microsoft.comwinfx2006xamlpresentation
        xmlnsx=httpschemas.microsoft.comwinfx2006xaml
        Title=Midnight Auditor Height=600 Width=1000 
        Background=Transparent WindowStartupLocation=CenterScreen
        AllowsTransparency=True WindowStyle=None Topmost=True
    Border Background=#050505 BorderBrush=#222 BorderThickness=1 CornerRadius=8
        Grid
            Grid.ColumnDefinitions
                ColumnDefinition Width=220
                ColumnDefinition Width=
            Grid.ColumnDefinitions

            Border Grid.Column=0 Background=Black BorderBrush=#222 BorderThickness=0,0,1,0
                StackPanel Margin=10
                    TextBlock Text=MIDNIGHT FontSize=24 Foreground=White FontWeight=Black Margin=0,30,0,5 HorizontalAlignment=Center
                    TextBlock Text=COMPACT AUDIT Foreground=#333 FontSize=9 FontWeight=Bold HorizontalAlignment=Center Margin=0,0,0,30
                    
                    Button Name=btnSys Content=SYSTEM Height=38 Margin=5 Background=#111 Foreground=#888 BorderBrush=#222
                    Button Name=btnApps Content=SOFTWARE Height=38 Margin=5 Background=#111 Foreground=#888 BorderBrush=#222
                    Button Name=btnHistory Content=HISTORY Height=38 Margin=5 Background=#111 Foreground=#888 BorderBrush=#222
                    Button Name=btnPF Content=STARTUPS Height=38 Margin=5 Background=#111 Foreground=#888 BorderBrush=#222
                    Button Name=btnClipboard Content=CLIPBOARD Height=38 Margin=5 Background=#111 Foreground=#888 BorderBrush=#222
                    Button Name=btnSecurity Content=SECURITY Height=38 Margin=5 Background=#111 Foreground=#888 BorderBrush=#222
                    
                    Button Name=btnExport Content=EXPORT Height=35 Margin=5,25,5,5 Background=White Foreground=Black FontWeight=Bold BorderThickness=0
                    Button Name=btnClose Content=CLOSE Height=35 Margin=5,5,5,5 Background=#111 Foreground=#555 BorderThickness=0
                StackPanel
            Border

            Grid Grid.Column=1 Margin=25
                Grid.RowDefinitions
                    RowDefinition Height=Auto
                    RowDefinition Height=
                Grid.RowDefinitions
                TextBlock Name=txtTitle Text=READY FontSize=32 Foreground=White Margin=0,0,0,20
                DataGrid Name=dgMain Grid.Row=1 Background=Transparent Foreground=White BorderThickness=0 
                          AlternatingRowBackground=#0A0A0A RowBackground=Black AutoGenerateColumns=True IsReadOnly=True
                          GridLinesVisibility=None SelectionMode=Single Focusable=True FontSize=12
                    DataGrid.ColumnHeaderStyle
                        Style TargetType=DataGridColumnHeader
                            Setter Property=Background Value=Black
                            Setter Property=Foreground Value=White
                            Setter Property=Padding Value=8,10
                            Setter Property=FontWeight Value=Bold
                            Setter Property=BorderThickness Value=0,0,0,1
                            Setter Property=BorderBrush Value=#222
                        Style
                    DataGrid.ColumnHeaderStyle
                DataGrid
            Grid
        Grid
    Border
Window
@

try {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]Load($reader)
} catch {
    [System.Windows.MessageBox]Show(Startup Error $($_.Exception.Message))
    exit
}

$dgMain = $window.FindName(dgMain)
$txtTitle = $window.FindName(txtTitle)
$GlobalLastKey = 
$GlobalLastIndex = -1

function Update-UI {
    param($Title,$Data)
    $txtTitle.Text = $Title
    $dgMain.ItemsSource = $null
    $dgMain.ItemsSource = $Data
    $GlobalLastIndex = -1
    [System.Windows.Forms.Application]DoEvents()
    $dgMain.Focus()  Out-Null
}

# --- KEYBOARD JUMP (R, S, T cycling) ---
$dgMain.Add_KeyDown({
    param($sender, $e)
    $key = $e.Key.ToString().ToUpper()
    if ($key.Length -ne 1) { return }
    $items = @($dgMain.ItemsSource)
    if ($items.Count -eq 0) { return }
    $matches = for ($i = 0; $i -lt $items.Count; $i++) {
        $val = ($items[$i].PSObject.Properties  Select-Object -First 1).Value.ToString()
        if ($val.ToUpper().StartsWith($key)) { $i }
    }
    if ($matches.Count -gt 0) {
        if ($key -eq $GlobalLastKey) { $GlobalLastIndex = ($GlobalLastIndex + 1) % $matches.Count }
        else { $GlobalLastKey = $key; $GlobalLastIndex = 0 }
        $dgMain.SelectedIndex = $matches[$GlobalLastIndex]
        $dgMain.ScrollIntoView($dgMain.SelectedItem)
    }
})

# --- MODULES ---
$actionSys = {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    Update-UI SYSTEM PROFILE @(
        [PSCustomObject]@{Item=OS;Value=$os.Caption}
        [PSCustomObject]@{Item=CPU;Value=$cpu.Name}
        [PSCustomObject]@{Item=RAM;Value=$([math]Round($os.TotalVisibleMemorySize1MB)) GB}
        [PSCustomObject]@{Item=Uptime;Value=$((Get-Date) - $os.LastBootUpTime)}
    )
}

$window.FindName(btnSys).Add_Click({ &$actionSys })
$window.FindName(btnApps).Add_Click({
    $apps = Get-ItemProperty HKLMSoftwareMicrosoftWindowsCurrentVersionUninstall -ErrorAction SilentlyContinue  Where DisplayName  Select DisplayName, Publisher  Sort DisplayName
    Update-UI SOFTWARE $apps
})
$window.FindName(btnHistory).Add_Click({
    $path = $envAPPDATAMicrosoftWindowsRecent
    $new = Get-ChildItem $path -ErrorAction SilentlyContinue  Select Name, LastWriteTime
    $GlobalSessionHistory = ($new + $GlobalSessionHistory)  Sort LastWriteTime -Descending  Select -Unique Name, LastWriteTime
    Update-UI FILE HISTORY $GlobalSessionHistory
})
$window.FindName(btnPF).Add_Click({
    if(Test-Path CWindowsPrefetch) {
        $pf = Get-ChildItem CWindowsPrefetch -Filter .pf  Select Name, LastWriteTime  Sort LastWriteTime -Descending
        Update-UI APP STARTUPS $pf
    }
})
$window.FindName(btnClipboard).Add_Click({ Update-UI CLIPBOARD $GlobalSessionClipboard })
$window.FindName(btnSecurity).Add_Click({
    $av = Get-CimInstance -Namespace rootSecurityCenter2 -Class AntiVirusProduct -ErrorAction SilentlyContinue
    Update-UI SECURITY @(
        [PSCustomObject]@{Check=AV;Status=if($av){$av.displayName}else{None}}
        [PSCustomObject]@{Check=Firewall;Status=(Get-NetFirewallProfile  Where Enabled -EQ True).Name -join , }
    )
})

$window.Add_MouseLeftButtonDown({ $this.DragMove() })
$window.FindName(btnClose).Add_Click({ $window.Close() })
$window.FindName(btnExport).Add_Click({
    if($dgMain.ItemsSource){
        $dgMain.ItemsSource  Export-Csv $envUSERPROFILEDesktopAudit_Report.csv -NoTypeInformation
        [System.Windows.MessageBox]Show(Exported to Desktop.)
    }
})

# --- STARTUP TRIGGER ---
$window.Add_Loaded({ &$actionSys })
$window.ShowDialog()  Out-Null