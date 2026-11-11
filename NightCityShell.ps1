# ============================================================
#  NIGHT CITY OS // RED NETRUNNER EDITION  v7.0
#  WPF shell + Chromium (WebView2) + DeepSeek chat
# ------------------------------------------------------------
#  Run:         powershell.exe -STA -ExecutionPolicy Bypass -File .\NightCityShell.ps1
#  Shell mode:  add -Shell (topmost window + autostart)
#  Exit:        RETURN TO WINDOWS button, Alt+F4 or Ctrl+Shift+Q
# ============================================================
param(
    [switch]$Shell,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Continue'
$script:Version   = '7.0'
$script:AppTitle  = 'NIGHT CITY OS'

# ---------- paths ----------
$script:BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($script:BaseDir)) { $script:BaseDir = 'C:\NightCity' }
$script:DataDir = Join-Path $env:LOCALAPPDATA 'NightCity'
if (-not [string]::IsNullOrWhiteSpace($env:NIGHTCITY_DATA)) { $script:DataDir = $env:NIGHTCITY_DATA }
$script:LogDir  = Join-Path $script:DataDir 'logs'
$script:LogFile = Join-Path $script:LogDir 'shell.log'
$script:HomePath = Join-Path $script:DataDir 'home.html'

foreach ($d in @($script:DataDir, $script:LogDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        try { New-Item -ItemType Directory -Path $d -Force | Out-Null } catch {}
    }
}

function Write-NCLog {
    param([string]$Message)
    try {
        $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {}
}

Write-NCLog "=== start v$($script:Version) shell=$Shell selftest=$SelfTest ==="

# ---------- assemblies ----------
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName WindowsFormsIntegration
    Add-Type -AssemblyName Microsoft.VisualBasic
} catch {
    [System.Windows.MessageBox]::Show("Failed to load WPF/WinForms assemblies.`n`n$($_.Exception.Message)", $script:AppTitle, 'OK', 'Error') | Out-Null
    Write-NCLog "assembly load failed: $($_.Exception.Message)"
    exit 1
}

# ---------- WebView2 / Chromium ----------
$script:WebView2Available = $false
$script:LibDir = Join-Path $script:BaseDir 'lib'
$coreDll = Join-Path $script:LibDir 'Microsoft.Web.WebView2.Core.dll'
$wpfDll = Join-Path $script:LibDir 'Microsoft.Web.WebView2.Wpf.dll'
$loaderDll = Join-Path $script:LibDir 'WebView2Loader.dll'
if ((Test-Path -LiteralPath $coreDll) -and (Test-Path -LiteralPath $wpfDll) -and (Test-Path -LiteralPath $loaderDll)) {
    try {
        Add-Type -Name K32 -Namespace NC -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SetDllDirectory(string path);' -ErrorAction Stop
        [void][NC.K32]::SetDllDirectory($script:LibDir)
        Add-Type -Path $coreDll -ErrorAction Stop
        Add-Type -Path $wpfDll -ErrorAction Stop
        $script:WebView2Available = $true
        Write-NCLog 'WebView2 assemblies loaded'
    } catch {
        Write-NCLog "WebView2 load failed: $($_.Exception.Message)"
    }
}

# ---------- IE11 mode for the embedded browser ----------
function Enable-BrowserEmulation {
    $key = 'HKCU:\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION'
    try {
        if (-not (Test-Path $key)) { New-Item -Path $key -Force -ErrorAction Stop | Out-Null }
        foreach ($exe in @('powershell.exe', 'pwsh.exe')) {
            Set-ItemProperty -Path $key -Name $exe -Value 11001 -Type DWord -ErrorAction Stop
        }
        Write-NCLog 'IE emulation set (11001)'
    } catch {
        Write-NCLog "IE emulation failed: $($_.Exception.Message)"
    }
}
Enable-BrowserEmulation

# ============================================================
#  XAML
# ============================================================
$XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NIGHT CITY OS" WindowStyle="None" WindowState="Maximized"
        ResizeMode="NoResize" Background="#FF080609" ShowInTaskbar="True"
        FontFamily="Consolas" UseLayoutRounding="True"
        TextOptions.TextFormattingMode="Display">

<Window.Resources>
<Style x:Key="Nav" TargetType="Button">
    <Setter Property="Foreground" Value="#FFFF3545"/>
    <Setter Property="Background" Value="#DD10080C"/>
    <Setter Property="BorderBrush" Value="#FF79121F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="Padding" Value="10,7"/>
    <Setter Property="HorizontalContentAlignment" Value="Left"/>
    <Setter Property="Margin" Value="0,2"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter Property="Foreground" Value="#FFFFFFFF"/>
            <Setter Property="Background" Value="#33FF2638"/>
            <Setter Property="BorderBrush" Value="#FFFF2638"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
            <Setter Property="Background" Value="#55FF2638"/>
        </Trigger>
    </Style.Triggers>
</Style>
<Style x:Key="Action" TargetType="Button">
    <Setter Property="Foreground" Value="#FFFF4552"/>
    <Setter Property="Background" Value="#CC170A10"/>
    <Setter Property="BorderBrush" Value="#FFB51B2B"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="12,9"/>
    <Setter Property="Margin" Value="4"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter Property="Foreground" Value="#FFFFFFFF"/>
            <Setter Property="BorderBrush" Value="#FFFF2638"/>
            <Setter Property="Background" Value="#33FF2638"/>
        </Trigger>
    </Style.Triggers>
</Style>
<Style x:Key="Tile" TargetType="Button">
    <Setter Property="Foreground" Value="#FFFF4552"/>
    <Setter Property="Background" Value="#CC120A0E"/>
    <Setter Property="BorderBrush" Value="#FF64131D"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="Width" Value="196"/>
    <Setter Property="Height" Value="52"/>
    <Setter Property="Margin" Value="4"/>
    <Setter Property="Padding" Value="10,6"/>
    <Setter Property="HorizontalContentAlignment" Value="Left"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter Property="BorderBrush" Value="#FFFF2638"/>
            <Setter Property="Background" Value="#33FF2638"/>
        </Trigger>
    </Style.Triggers>
</Style>
<Style x:Key="ToolBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#FFFF4552"/>
    <Setter Property="Background" Value="#1A0A0E"/>
    <Setter Property="BorderBrush" Value="#FF79121F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontSize" Value="14"/>
    <Setter Property="Width" Value="34"/>
    <Setter Property="Height" Value="30"/>
    <Setter Property="Margin" Value="0,0,5,0"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter Property="Foreground" Value="#FFFFFFFF"/>
            <Setter Property="BorderBrush" Value="#FFFF2638"/>
            <Setter Property="Background" Value="#33FF2638"/>
        </Trigger>
    </Style.Triggers>
</Style>
<Style x:Key="Card" TargetType="Border">
    <Setter Property="Background" Value="#CC090609"/>
    <Setter Property="BorderBrush" Value="#FF79121F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="13"/>
</Style>
<Style x:Key="Field" TargetType="TextBox">
    <Setter Property="Background" Value="#080609"/>
    <Setter Property="Foreground" Value="#FFEFE2E3"/>
    <Setter Property="BorderBrush" Value="#FF79121F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="CaretBrush" Value="#FFFF2638"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="SelectionBrush" Value="#FFFF2638"/>
</Style>
</Window.Resources>

<Grid>
<Grid.RowDefinitions>
    <RowDefinition Height="48"/>
    <RowDefinition Height="*"/>
    <RowDefinition Height="42"/>
</Grid.RowDefinitions>

<!-- wallpaper -->
<Grid Grid.RowSpan="3">
    <Grid.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#FF080609" Offset="0"/>
            <GradientStop Color="#FF25070E" Offset="0.55"/>
            <GradientStop Color="#FF050508" Offset="1"/>
        </LinearGradientBrush>
    </Grid.Background>
    <Image x:Name="WallpaperImage" Stretch="UniformToFill" Opacity="1"/>
    <Rectangle Fill="#5E050007"/>
    <Rectangle Grid.RowSpan="3" IsHitTestVisible="False" Opacity="0.05">
        <Rectangle.Fill>
            <DrawingBrush TileMode="Tile" Viewport="0,0,4,4" ViewportUnits="Absolute">
                <DrawingBrush.Drawing>
                    <GeometryDrawing Brush="#FF000000">
                        <GeometryDrawing.Geometry>
                            <RectangleGeometry Rect="0,0,4,1"/>
                        </GeometryDrawing.Geometry>
                    </GeometryDrawing>
                </DrawingBrush.Drawing>
            </DrawingBrush>
        </Rectangle.Fill>
    </Rectangle>
</Grid>

<!-- ================= TOP BAR ================= -->
<Grid x:Name="TopBar" Grid.Row="0" Background="#EE080609">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="320"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="160"/>
        <ColumnDefinition Width="48"/>
        <ColumnDefinition Width="52"/>
    </Grid.ColumnDefinitions>

    <StackPanel VerticalAlignment="Center" Margin="18,0">
        <TextBlock Text="NIGHT CITY OS" Foreground="#FFFF2638" FontSize="20" FontWeight="Bold"/>
        <TextBlock Text="NETRUNNER ENVIRONMENT // 2077" Foreground="#FFB18B90" FontSize="9"/>
    </StackPanel>

    <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
        <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#FFFF2638" Margin="0,0,10,0">
            <Ellipse.Triggers>
                <EventTrigger RoutedEvent="Loaded">
                    <BeginStoryboard>
                        <Storyboard>
                            <DoubleAnimation Storyboard.TargetProperty="Opacity" From="1" To="0.2"
                                             Duration="0:0:1.1" AutoReverse="True" RepeatBehavior="Forever"/>
                        </Storyboard>
                    </BeginStoryboard>
                </EventTrigger>
            </Ellipse.Triggers>
        </Ellipse>
        <TextBlock Text="SYSTEM ONLINE // SECURE CONNECTION" Foreground="#FFE8D5D7" FontSize="12"/>
    </StackPanel>

    <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Center">
        <TextBlock x:Name="ClockTop" Text="00:00:00" Foreground="#FFFF3545"
                   FontSize="21" FontWeight="Bold" HorizontalAlignment="Center"/>
        <TextBlock x:Name="DateTop" Text="--" Foreground="#FFB18B90" FontSize="9" HorizontalAlignment="Center"/>
    </StackPanel>

    <Grid Grid.Column="3" VerticalAlignment="Center" HorizontalAlignment="Center">
        <Button x:Name="NotifyBtn" Style="{StaticResource ToolBtn}" Content="&#x25C9;" Width="34" Height="28" Margin="0" ToolTip="NOTIFICATIONS"/>
        <Border x:Name="NotifyBadge" Background="#FFFF2638" CornerRadius="8" Height="16" MinWidth="16"
                HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,-2,-4,0" Visibility="Collapsed">
            <TextBlock x:Name="NotifyBadgeText" Text="0" Foreground="#FF12060A" FontSize="9" FontWeight="Bold"
                       HorizontalAlignment="Center" VerticalAlignment="Center" Margin="3,0"/>
        </Border>
    </Grid>

    <Button x:Name="PowerBtn" Grid.Column="4" Style="{StaticResource ToolBtn}" Content="&#x2715;"
            Width="34" Height="28" Margin="0" ToolTip="EXIT SHELL"/>

    <Border Grid.ColumnSpan="5" BorderBrush="#FFFF2638" BorderThickness="0,0,0,1" VerticalAlignment="Bottom"/>
</Grid>

<!-- ================= MAIN AREA ================= -->
<Grid Grid.Row="1" Margin="12,10,12,8">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="220"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="250"/>
    </Grid.ColumnDefinitions>

    <!-- LEFT MENU -->
    <StackPanel x:Name="LeftNav" Grid.Column="0">
        <TextBlock Text="// MAINFRAME" Foreground="#FFFF3545" FontSize="11" Margin="8,2,0,8"/>
        <Button x:Name="NavOverview" Style="{StaticResource Nav}" Content="&#x25A6;   OVERVIEW"/>
        <Button x:Name="NavApps"     Style="{StaticResource Nav}" Content="&#x25A3;   APPLICATIONS"/>
        <Button x:Name="NavFiles"    Style="{StaticResource Nav}" Content="&#x25B0;   FILE MANAGER"/>
        <Button x:Name="NavBrowser"  Style="{StaticResource Nav}" Content="&#x25C9;   BROWSER"/>
        <Button x:Name="NavAI"       Style="{StaticResource Nav}" Content="&#x2726;   NEURAL LINK"/>
        <Button x:Name="NavNetwork"  Style="{StaticResource Nav}" Content="&#x25CE;   NETWORK"/>
        <Button x:Name="NavSystem"   Style="{StaticResource Nav}" Content="&#x25A4;   SYSTEM"/>
        <Button x:Name="NavTasks"    Style="{StaticResource Nav}" Content="&#x25A5;   TASKS"/>
        <Button x:Name="NavSecurity" Style="{StaticResource Nav}" Content="&#x26E8;   SECURITY"/>
        <Button x:Name="NavTerminal" Style="{StaticResource Nav}" Content="&gt;_   TERMINAL"/>
        <Button x:Name="NavNotify"   Style="{StaticResource Nav}" Content="&#x25C9;   NOTIFICATIONS"/>
        <Button x:Name="NavSettings" Style="{StaticResource Nav}" Content="&#x2699;   SETTINGS"/>

        <Border Style="{StaticResource Card}" Margin="0,16,0,0">
            <StackPanel>
                <TextBlock Text="SYSTEM STATUS" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold"/>
                <TextBlock x:Name="CpuText" Text="CPU      -- %" Foreground="#FFEFE2E3" FontSize="11" Margin="0,12,0,4"/>
                <ProgressBar x:Name="CpuBar" Height="5" Maximum="100" Foreground="#FFFF2638" Background="#FF351018" BorderThickness="0"/>
                <TextBlock x:Name="RamText" Text="RAM      -- %" Foreground="#FFEFE2E3" FontSize="11" Margin="0,10,0,4"/>
                <ProgressBar x:Name="RamBar" Height="5" Maximum="100" Foreground="#FFFF2638" Background="#FF351018" BorderThickness="0"/>
                <TextBlock x:Name="DiskText" Text="DISK C:  -- %" Foreground="#FFEFE2E3" FontSize="11" Margin="0,10,0,4"/>
                <ProgressBar x:Name="DiskBar" Height="5" Maximum="100" Foreground="#FFFF2638" Background="#FF351018" BorderThickness="0"/>
                <TextBlock x:Name="TempText" Text="TEMP     --" Foreground="#FFEFE2E3" FontSize="10" Margin="0,10,0,0"/>
                <TextBlock x:Name="UptimeText" Text="UPTIME   --" Foreground="#FFB18B90" FontSize="10" Margin="0,6,0,0"/>
            </StackPanel>
        </Border>
    </StackPanel>

    <!-- CENTER -->
    <Grid x:Name="CenterArea" Grid.Column="1" Margin="15,0">

        <!-- OVERVIEW -->
        <Grid x:Name="DashboardView">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="WELCOME BACK, NETRUNNER" Foreground="#FFFF2638" FontSize="12" FontWeight="Bold"/>
                <TextBlock Text="NIGHT CITY // OVERVIEW" Foreground="#FFF4E8E9" FontSize="27" FontWeight="Bold" Margin="0,4,0,0"/>
                <TextBlock Text="Your system. Your rules. Stay connected." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>

            <Border Grid.Row="1" Background="#4D080609" BorderBrush="#AAFF2638" BorderThickness="1" Margin="0,16,0,0" Padding="16">
                <Grid>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel>
                        <TextBlock Text="QUICK DEPLOY" Foreground="#FFFF3545" FontSize="13" FontWeight="Bold" Margin="0,0,0,10"/>
                        <WrapPanel>
                            <Button x:Name="OpenFileManager" Style="{StaticResource Action}" Content="&#x25B0; FILE MANAGER"/>
                            <Button x:Name="OpenBrowser" Style="{StaticResource Action}" Content="&#x25C9; BROWSER"/>
                            <Button x:Name="OpenTaskMgr" Style="{StaticResource Action}" Content="&#x25A5; TASK MANAGER"/>
                            <Button x:Name="OpenTerminal" Style="{StaticResource Action}" Content="&gt;_ TERMINAL"/>
                        </WrapPanel>

                        <TextBlock Text="ACTIVE MODULES" Foreground="#FFFF3545" FontSize="13" FontWeight="Bold" Margin="0,20,0,8"/>
                        <UniformGrid Columns="2">
                            <Border BorderBrush="#FF64131D" BorderThickness="1" Background="#9913090E" Padding="13" Margin="4">
                                <StackPanel>
                                    <TextBlock Text="LOCAL SYSTEM" Foreground="#FFB18B90" FontSize="10"/>
                                    <TextBlock Text="OPERATIONAL" Foreground="#FFFF3545" FontSize="18" FontWeight="Bold"/>
                                    <TextBlock Text="Windows shell bridge active" Foreground="#FFD6C5C8" FontSize="10"/>
                                </StackPanel>
                            </Border>
                            <Border BorderBrush="#FF64131D" BorderThickness="1" Background="#9913090E" Padding="13" Margin="4">
                                <StackPanel>
                                    <TextBlock Text="POWER SOURCE" Foreground="#FFB18B90" FontSize="10"/>
                                    <TextBlock x:Name="BatteryStatus" Text="AC POWER" Foreground="#FFFF3545" FontSize="18" FontWeight="Bold"/>
                                    <TextBlock x:Name="BatteryTime" Text="Plugged in" Foreground="#FFD6C5C8" FontSize="10"/>
                                </StackPanel>
                            </Border>
                            <Border BorderBrush="#FF64131D" BorderThickness="1" Background="#9913090E" Padding="13" Margin="4">
                                <StackPanel>
                                    <TextBlock Text="BROWSER ENGINE" Foreground="#FFB18B90" FontSize="10"/>
                                    <TextBlock x:Name="DashBrowser" Text="MSHTML // IE11" Foreground="#FFFF3545" FontSize="18" FontWeight="Bold"/>
                                    <TextBlock Text="Embedded net access" Foreground="#FFD6C5C8" FontSize="10"/>
                                </StackPanel>
                            </Border>
                            <Border BorderBrush="#FF64131D" BorderThickness="1" Background="#9913090E" Padding="13" Margin="4">
                                <StackPanel>
                                    <TextBlock Text="NET LINK" Foreground="#FFB18B90" FontSize="10"/>
                                    <TextBlock x:Name="DashNet" Text="--" Foreground="#FFFF3545" FontSize="18" FontWeight="Bold"/>
                                    <TextBlock Text="Local network state" Foreground="#FFD6C5C8" FontSize="10"/>
                                </StackPanel>
                            </Border>
                        </UniformGrid>

                        <TextBlock Text="TERMINAL FEED" Foreground="#FFFF3545" FontSize="13" FontWeight="Bold" Margin="0,20,0,8"/>
                        <Border Background="#CC050307" BorderBrush="#FF4A0F16" BorderThickness="1" Padding="12">
                            <TextBlock x:Name="FeedText" Foreground="#FFB18B90" FontSize="10" TextWrapping="Wrap"
                                       Text="&gt; boot sequence complete&#x0a;&gt; shell bridge mounted&#x0a;&gt; awaiting operator input_"/>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
                <TextBlock Text="NC // 2077" FontSize="64" FontWeight="Bold" Foreground="#14FF2638"
                           HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,8,2" IsHitTestVisible="False"/>
                </Grid>
            </Border>
        </Grid>

        <!-- APPLICATIONS -->
        <Grid x:Name="AppsView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="APPLICATIONS // DEPLOY" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Launch installed Windows tools and internal modules." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,14,0,0">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <WrapPanel x:Name="AppsPanel"/>
                </ScrollViewer>
            </Border>
        </Grid>

        <!-- FILE MANAGER -->
        <Grid x:Name="FilesView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="NIGHT CITY // FILE SYSTEM" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Local storage access. Double-click folders to enter." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>

            <Border Grid.Row="1" Background="#1A0A0E" BorderBrush="#FF79121F" BorderThickness="1" Padding="8" Margin="0,12,0,0">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal">
                        <Button x:Name="BtnBack" Style="{StaticResource ToolBtn}" Content="&#x2190;" ToolTip="BACK"/>
                        <Button x:Name="BtnUp" Style="{StaticResource ToolBtn}" Content="&#x2191;" ToolTip="UP"/>
                        <Button x:Name="BtnRefresh" Style="{StaticResource ToolBtn}" Content="&#x21BB;" ToolTip="REFRESH"/>
                    </StackPanel>
                    <Grid Grid.Column="1" Margin="8,0,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="PathBox" Style="{StaticResource Field}" Grid.Column="0"/>
                        <Button x:Name="BtnGo" Style="{StaticResource ToolBtn}" Content="GO" Width="46" Margin="5,0,0,0" Grid.Column="1"/>
                    </Grid>
                </Grid>
            </Border>

            <Border Grid.Row="2" BorderBrush="#FF79121F" BorderThickness="1" Background="#080609" Margin="0,0,0,0">
                <DataGrid x:Name="FileGrid" AutoGenerateColumns="False" IsReadOnly="True" Background="Transparent"
                          RowBackground="Transparent" AlternatingRowBackground="#11000000" Foreground="#FFEFE2E3"
                          GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#33FF2638"
                          HeadersVisibility="Column" BorderThickness="0" SelectionMode="Single"
                          CanUserAddRows="False" CanUserResizeRows="False" RowHeaderWidth="0">
                    <DataGrid.Resources>
                        <Style TargetType="DataGridColumnHeader">
                            <Setter Property="Background" Value="#1A0A0E"/>
                            <Setter Property="Foreground" Value="#FFFF3545"/>
                            <Setter Property="FontWeight" Value="Bold"/>
                            <Setter Property="Padding" Value="8,6"/>
                            <Setter Property="BorderBrush" Value="#FF79121F"/>
                            <Setter Property="BorderThickness" Value="0,0,1,1"/>
                        </Style>
                        <Style TargetType="DataGridCell">
                            <Setter Property="Padding" Value="8,6"/>
                            <Setter Property="BorderThickness" Value="0"/>
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="DataGridCell">
                                        <Border Padding="{TemplateBinding Padding}" Background="Transparent">
                                            <ContentPresenter VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                        <Style TargetType="DataGridRow">
                            <Setter Property="Background" Value="Transparent"/>
                            <Style.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="#22FF2638"/>
                                </Trigger>
                                <Trigger Property="IsSelected" Value="True">
                                    <Setter Property="Background" Value="#55FF2638"/>
                                </Trigger>
                            </Style.Triggers>
                        </Style>
                    </DataGrid.Resources>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="NAME" Binding="{Binding Name}" Width="*"/>
                        <DataGridTextColumn Header="MODIFIED" Binding="{Binding Date}" Width="145"/>
                        <DataGridTextColumn Header="TYPE" Binding="{Binding Type}" Width="110"/>
                        <DataGridTextColumn Header="SIZE" Binding="{Binding Size}" Width="115"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Border>

            <TextBlock x:Name="FileStatus" Grid.Row="3" Text="READY" Foreground="#FFB18B90" FontSize="10" Margin="2,5,0,0"/>
        </Grid>

        <!-- BROWSER -->
        <Grid x:Name="BrowserView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="NET // BROWSER" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Embedded net access. Local start page loads offline." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>

            <Border Grid.Row="1" Background="#1A0A0E" BorderBrush="#FF79121F" BorderThickness="1" Padding="8" Margin="0,12,0,0">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal">
                        <Button x:Name="BrowserBack" Style="{StaticResource ToolBtn}" Content="&#x2190;" ToolTip="BACK"/>
                        <Button x:Name="BrowserForward" Style="{StaticResource ToolBtn}" Content="&#x2192;" ToolTip="FORWARD"/>
                        <Button x:Name="BrowserRefresh" Style="{StaticResource ToolBtn}" Content="&#x21BB;" ToolTip="RELOAD"/>
                        <Button x:Name="BrowserHome" Style="{StaticResource ToolBtn}" Content="NC" Width="38" ToolTip="HOME"/>
                    </StackPanel>
                    <TextBox x:Name="BrowserAddress" Grid.Column="1" Style="{StaticResource Field}" Margin="7,0"/>
                    <StackPanel Grid.Column="2" Orientation="Horizontal">
                        <Button x:Name="BrowserGo" Style="{StaticResource ToolBtn}" Content="GO" Width="44" Margin="0"/>
                        <Button x:Name="BrowserExternal" Style="{StaticResource ToolBtn}" Content="&#x2197;" Width="34" Margin="5,0,0,0" ToolTip="OPEN IN DEFAULT BROWSER"/>
                        <Button x:Name="BrowserFullscreen" Style="{StaticResource ToolBtn}" Content="&#x26F6;" Width="34" Margin="5,0,0,0" ToolTip="FULLSCREEN (F11)"/>
                    </StackPanel>
                </Grid>
            </Border>

            <ProgressBar x:Name="BrowserProgress" Grid.Row="2" Height="3" Maximum="100" Minimum="0"
                         Foreground="#FFFF2638" Background="#22000000" BorderThickness="0" Value="0"/>

            <Border x:Name="BrowserSurface" Grid.Row="3" Background="#050308" BorderBrush="#FF79121F" BorderThickness="1,0,1,0"/>

            <Border Grid.Row="4" Background="#0D0508" BorderBrush="#FF79121F" BorderThickness="1,0,1,1" Padding="8,3">
                <Grid>
                    <TextBlock x:Name="BrowserStatus" Text="INITIALIZING ..." Foreground="#FFB18B90" FontSize="10"/>
                    <TextBlock x:Name="BrowserEngine" Text="ENGINE // MSHTML" Foreground="#FF79121F" FontSize="10" HorizontalAlignment="Right"/>
                </Grid>
            </Border>
        </Grid>

        <!-- NETWORK -->
        <Grid x:Name="NetworkView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="NETWORK // DIAGNOSTICS" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Interfaces, addresses and link state." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,14,0,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <StackPanel Orientation="Horizontal">
                        <Button x:Name="NetRefreshBtn" Style="{StaticResource Action}" Content="&#x21BB; REFRESH"/>
                        <Button x:Name="NetPingBtn" Style="{StaticResource Action}" Content="&#x25CE; PING 8.8.8.8"/>
                        <TextBlock x:Name="NetPingResult" Foreground="#FFFF3545" VerticalAlignment="Center" Margin="10,0,0,0" FontSize="11"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,10,0,0">
                        <TextBlock x:Name="NetInfo" Foreground="#FFD6C5C8" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap"/>
                    </ScrollViewer>
                </Grid>
            </Border>
        </Grid>

        <!-- SYSTEM -->
        <Grid x:Name="SystemView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="SYSTEM // CORE" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Hardware, OS and runtime information." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,14,0,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Button x:Name="SysRefreshBtn" Style="{StaticResource Action}" Content="&#x21BB; REFRESH" HorizontalAlignment="Left"/>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,10,0,0">
                        <TextBlock x:Name="SysInfo" Foreground="#FFD6C5C8" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap"/>
                    </ScrollViewer>
                </Grid>
            </Border>
        </Grid>

        <!-- SETTINGS -->
        <Grid x:Name="SettingsView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="SYSTEM // SETTINGS" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Shell, startup and diagnostics." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,14,0,0">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel>
                        <TextBlock Text="SHELL CONTROL" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold"/>
                        <WrapPanel Margin="0,10,0,0">
                            <Button x:Name="AutoStartBtn" Style="{StaticResource Action}" Content="AUTOSTART // ..." Width="190"/>
                            <Button x:Name="TopmostBtn" Style="{StaticResource Action}" Content="TOPMOST // ..." Width="170"/>
                            <Button x:Name="ExplorerBtn" Style="{StaticResource Action}" Content="&#x2197; START EXPLORER" Width="180"/>
                            <Button x:Name="RestartBtn" Style="{StaticResource Action}" Content="&#x21BB; RESTART SHELL" Width="170"/>
                            <Button x:Name="DesktopModeBtn" Style="{StaticResource Action}" Content="DESKTOP // ..." Width="200"/>
                            <Button x:Name="DesktopApplyBtn" Style="{StaticResource Action}" Content="APPLY NOW" Width="200"/>
                        </WrapPanel>

                        <StackPanel Orientation="Horizontal" Margin="0,14,0,0">
                            <TextBlock Text="LANGUAGE // ЯЗЫК" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
                            <TextBlock Text="EN" Foreground="#FFB18B90" FontSize="11" VerticalAlignment="Center" Margin="14,0,0,0"/>
                            <Slider x:Name="LangSlider" Width="90" Minimum="0" Maximum="1" TickFrequency="1"
                                    IsSnapToTickEnabled="True" Value="1" Margin="8,0" VerticalAlignment="Center"/>
                            <TextBlock Text="RU" Foreground="#FFB18B90" FontSize="11" VerticalAlignment="Center"/>
                        </StackPanel>

                        <TextBlock Text="PATHS" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold" Margin="0,20,0,0"/>
                        <WrapPanel Margin="0,10,0,0">
                            <Button x:Name="OpenFolderBtn" Style="{StaticResource Action}" Content="&#x25B0; NIGHT CITY FOLDER"/>
                            <Button x:Name="OpenLogBtn" Style="{StaticResource Action}" Content="&#x25A4; OPEN LOG"/>
                            <Button x:Name="OpenDataBtn" Style="{StaticResource Action}" Content="&#x25B0; DATA FOLDER"/>
                            <Button x:Name="SysControlBtn" Style="{StaticResource Action}" Content="&#x2699; SYSTEM CONTROL"/>
                        </WrapPanel>

                        <TextBlock Text="DIAGNOSTICS" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold" Margin="0,20,0,0"/>
                        <Border Background="#CC050307" BorderBrush="#FF4A0F16" BorderThickness="1" Padding="12" Margin="0,10,0,0">
                            <TextBlock x:Name="SettingsInfo" Foreground="#FFB18B90" FontFamily="Consolas" FontSize="10" TextWrapping="Wrap"/>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </Border>
        </Grid>

        <!-- NEURAL LINK -->
        <Grid x:Name="AIView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="NEURAL LINK // DEEPSEEK" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Cyberpunk chat terminal. Powered by the signed-in DeepSeek page." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Background="#0C0A06" BorderBrush="#FFFCEE0A" BorderThickness="1" Padding="7" Margin="0,12,0,0">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Ellipse Width="8" Height="8" Fill="#FFFCEE0A" Margin="0,0,9,0"/>
                        <TextBlock Text="DEEPSEEK UPLINK // NC-CHAT" Foreground="#FFFCEE0A" FontSize="11" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="AiChatToggle" Style="{StaticResource ToolBtn}" Content="PAGE" Width="54" ToolTip="SHOW PAGE / CHAT"/>
                        <Button x:Name="AiReload" Style="{StaticResource ToolBtn}" Content="&#x21BB;" ToolTip="RELOAD"/>
                        <Button x:Name="AiExternal" Style="{StaticResource ToolBtn}" Content="&#x2197;" Width="34" ToolTip="OPEN IN BROWSER"/>
                    </StackPanel>
                </Grid>
            </Border>
            <Border Grid.Row="2" Background="#FF0A0A0C" BorderBrush="#FFFCEE0A" BorderThickness="1,0,1,1">
                <Grid>
                    <Canvas x:Name="AiCanvas" ClipToBounds="True">
                        <Border x:Name="AiPageHost" Background="#050307" Width="1000" Height="800"
                                Canvas.Left="2000" Canvas.Top="0">
                            <Border x:Name="AiSurface" Background="#050307"/>
                        </Border>
                    </Canvas>
                    <Grid x:Name="ChatPanel">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <ScrollViewer x:Name="ChatScroll" VerticalScrollBarVisibility="Auto" Padding="14">
                            <StackPanel x:Name="ChatList"/>
                        </ScrollViewer>
                        <Border Grid.Row="1" BorderBrush="#44FCEE0A" BorderThickness="0,1,0,0" Padding="10">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="ChatInput" Background="#0A0A0C" Foreground="#FFF2E6C8"
                                         BorderBrush="#66FCEE0A" BorderThickness="1" Padding="8,6"
                                         FontFamily="Consolas" FontSize="12" CaretBrush="#FFFCEE0A"
                                         VerticalContentAlignment="Center"/>
                                <Button x:Name="ChatSend" Grid.Column="1" Style="{StaticResource ToolBtn}" Content="SEND"
                                        Width="64" Margin="8,0,0,0"/>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>
            </Border>
            <TextBlock x:Name="AiStatus" Grid.Row="3" Text="LINK READY // DEEPSEEK WEB" Foreground="#FF8A7A10"
                       FontSize="10" Margin="2,6,0,0"/>
        </Grid>

        <!-- TASK MANAGER -->
        <Grid x:Name="TasksView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="TASK MANAGER // PROCESSES" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Live process list. Select a row and end the task." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Background="#1A0A0E" BorderBrush="#FF79121F" BorderThickness="1" Padding="7" Margin="0,12,0,0">
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="TaskRefresh" Style="{StaticResource Action}" Content="&#x21BB; REFRESH"/>
                    <Button x:Name="TaskKill" Style="{StaticResource Action}" Content="&#x2715; END TASK"/>
                    <TextBlock x:Name="TaskSummary" Foreground="#FFB18B90" FontSize="11" VerticalAlignment="Center" Margin="10,0,0,0"/>
                </StackPanel>
            </Border>
            <Border Grid.Row="2" BorderBrush="#FF79121F" BorderThickness="1" Background="#080609" Margin="0,8,0,0">
                <DataGrid x:Name="TaskGrid" AutoGenerateColumns="False" IsReadOnly="True" Background="Transparent"
                          RowBackground="Transparent" AlternatingRowBackground="#11000000" Foreground="#FFEFE2E3"
                          GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#33FF2638"
                          HeadersVisibility="Column" BorderThickness="0" SelectionMode="Single"
                          CanUserAddRows="False" RowHeaderWidth="0">
                    <DataGrid.Resources>
                        <Style TargetType="DataGridColumnHeader">
                            <Setter Property="Background" Value="#1A0A0E"/>
                            <Setter Property="Foreground" Value="#FFFF3545"/>
                            <Setter Property="FontWeight" Value="Bold"/>
                            <Setter Property="Padding" Value="8,6"/>
                            <Setter Property="BorderBrush" Value="#FF79121F"/>
                            <Setter Property="BorderThickness" Value="0,0,1,1"/>
                        </Style>
                        <Style TargetType="DataGridCell">
                            <Setter Property="Padding" Value="8,5"/>
                            <Setter Property="BorderThickness" Value="0"/>
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="DataGridCell">
                                        <Border Padding="{TemplateBinding Padding}" Background="Transparent">
                                            <ContentPresenter VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                        <Style TargetType="DataGridRow">
                            <Setter Property="Background" Value="Transparent"/>
                            <Style.Triggers>
                                <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#22FF2638"/></Trigger>
                                <Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="#55FF2638"/></Trigger>
                            </Style.Triggers>
                        </Style>
                    </DataGrid.Resources>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="PROCESS" Binding="{Binding Name}" Width="*"/>
                        <DataGridTextColumn Header="PID" Binding="{Binding Pid}" Width="80"/>
                        <DataGridTextColumn Header="RAM MB" Binding="{Binding Ram}" Width="90"/>
                        <DataGridTextColumn Header="THREADS" Binding="{Binding Threads}" Width="90"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Border>
            <TextBlock x:Name="TaskStatus" Grid.Row="3" Text="READY" Foreground="#FFB18B90" FontSize="10" Margin="2,5,0,0"/>
        </Grid>

        <!-- SECURITY CENTER -->
        <Grid x:Name="SecurityView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="SECURITY CENTER" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Defender, firewall, UAC and boot protection." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Button x:Name="SecurityRefresh" Grid.Row="1" Style="{StaticResource Action}" Content="&#x21BB; REFRESH" HorizontalAlignment="Left" Margin="0,12,0,0"/>
            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,10,0,0">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="SecurityPanel"/>
                </ScrollViewer>
            </Border>
        </Grid>

        <!-- NOTIFICATIONS -->
        <Grid x:Name="NotificationsView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="NOTIFICATION CENTER" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Shell events and system notices." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,12,0,0">
                <Button x:Name="NotifClear" Style="{StaticResource Action}" Content="&#x2715; CLEAR ALL"/>
                <TextBlock x:Name="NotifCount" Foreground="#FFB18B90" FontSize="11" VerticalAlignment="Center" Margin="10,0,0,0"/>
            </StackPanel>
            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,10,0,0">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="NotifList"/>
                </ScrollViewer>
            </Border>
        </Grid>

        <!-- SYSTEM CONTROL -->
        <Grid x:Name="SystemControlView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="SYSTEM CONTROL" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="Windows tools and shell diagnostics." Foreground="#FFB18B90" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,12,0,0">
                <WrapPanel x:Name="SysControlButtons"/>
            </Border>
            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,10,0,0">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <TextBlock x:Name="SysControlInfo" Foreground="#FFD6C5C8" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap"/>
                </ScrollViewer>
            </Border>
        </Grid>

        <!-- EMBEDDED APP -->
        <Grid x:Name="AppView" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Border Background="#1A0A0E" BorderBrush="#FF79121F" BorderThickness="1" Padding="7" Margin="0,12,0,0">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="RUNNING // " Foreground="#FF79121F" FontSize="11" VerticalAlignment="Center"/>
                        <TextBlock x:Name="AppTitle" Text="PROGRAM" Foreground="#FFFF4552" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="AppDetach" Style="{StaticResource ToolBtn}" Content="&#x2197;" ToolTip="DETACH TO DESKTOP"/>
                        <Button x:Name="AppClose" Style="{StaticResource ToolBtn}" Content="&#x2715;" ToolTip="CLOSE PROGRAM"/>
                    </StackPanel>
                </Grid>
            </Border>
            <Border x:Name="AppSurface" Grid.Row="1" Background="#050308" BorderBrush="#FF79121F" BorderThickness="1,0,1,1"/>
            <TextBlock x:Name="AppStatus" Grid.Row="1" Text="NO PROGRAM" Foreground="#FF79121F" FontSize="10"
                       VerticalAlignment="Bottom" HorizontalAlignment="Left" Margin="8,0,0,6"/>
        </Grid>

    </Grid>

    <!-- RIGHT PANEL -->
    <StackPanel x:Name="RightPanel" Grid.Column="2">
        <Border Style="{StaticResource Card}">
            <StackPanel>
                <TextBlock x:Name="WeatherTitle" Text="WEATHER // VLADIVOSTOK" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold"/>
                <TextBlock x:Name="WeatherTemp" Text="--°C" Foreground="#FFF4E8E9" FontSize="26" FontWeight="Bold" Margin="0,6,0,0"/>
                <TextBlock x:Name="WeatherCond" Text="--" Foreground="#FFE9DADD" FontSize="11"/>
                <TextBlock x:Name="WeatherWind" Text="WIND --" Foreground="#FFB18B90" FontSize="10" Margin="0,4,0,0"/>
            </StackPanel>
        </Border>

        <Border Style="{StaticResource Card}" Margin="0,12,0,0">
            <StackPanel>
                <TextBlock Text="NETWORK STATUS" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold"/>
                <TextBlock x:Name="NetworkState" Text="CHECKING ..." Foreground="#FFE9DADD" FontSize="12" Margin="0,8,0,3"/>
                <TextBlock x:Name="IpText" Text="IP: unavailable" Foreground="#FFB18B90" FontSize="10" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <Border Style="{StaticResource Card}" Margin="0,12,0,0">
            <StackPanel>
                <TextBlock Text="POWER" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold"/>
                <TextBlock x:Name="RightBattery" Text="AC POWER" Foreground="#FFE9DADD" FontSize="12" Margin="0,8,0,3"/>
                <TextBlock x:Name="RightBatteryTime" Text="Desktop mode" Foreground="#FFB18B90" FontSize="10" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <Border Style="{StaticResource Card}" Margin="0,12,0,0">
            <StackPanel>
                <TextBlock Text="MODE" Foreground="#FFFF3545" FontSize="12" FontWeight="Bold"/>
                <TextBlock x:Name="ShellState" Text="SHELL // STANDBY" Foreground="#FFE9DADD" FontSize="12" Margin="0,8,0,0"/>
                <TextBlock Text="F11 fullscreen // Ctrl+Shift+Q quit" Foreground="#FFB18B90" FontSize="9" Margin="0,3,0,0"/>
            </StackPanel>
        </Border>

        <Button x:Name="ReturnWindows" Style="{StaticResource Action}" Content="&#x2197; RETURN TO WINDOWS" Margin="0,14,0,0" Height="40"/>
    </StackPanel>
</Grid>

<!-- ================= BOTTOM BAR ================= -->
<Grid x:Name="BottomBar" Grid.Row="2" Background="#F0080609">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="10,0">
        <Button x:Name="StartButton" Style="{StaticResource Action}" Content="NC" FontSize="17" FontWeight="Bold" Padding="10,2" Height="30"/>
        <TextBlock Text="NIGHT CITY // NETRUNNER" Foreground="#FFFF3545" VerticalAlignment="Center" Margin="10,0" FontSize="10"/>
        <TextBlock x:Name="ViewLabel" Text="DASHBOARD" Foreground="#FFB18B90" VerticalAlignment="Center" FontSize="10"/>
    </StackPanel>
    <Border Grid.ColumnSpan="3" BorderBrush="#FFFF2638" BorderThickness="0,1,0,0" VerticalAlignment="Top"/>
</Grid>

<!-- toast -->
<Border x:Name="ToastPanel" Grid.RowSpan="3" Background="#F20A060A" BorderBrush="#FFFF2638" BorderThickness="1"
        HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,18,58" Padding="14,10" MaxWidth="360"
        Opacity="0" IsHitTestVisible="False">
    <Border.RenderTransform>
        <TranslateTransform x:Name="ToastShift" X="0" Y="10"/>
    </Border.RenderTransform>
    <StackPanel>
        <TextBlock Text="SYSTEM NOTICE" Foreground="#FFFF2638" FontSize="10" FontWeight="Bold"/>
        <TextBlock x:Name="ToastText" Text="" Foreground="#FFE9DADD" FontSize="11" TextWrapping="Wrap" Margin="0,4,0,0"/>
    </StackPanel>
</Border>
</Grid>
</Window>
'@

function Expand-UiScale {
    param([string]$Xaml, [double]$Scale)
    if ($Scale -lt 0.01 -or [math]::Abs($Scale - 1) -lt 0.02) { return $Xaml }
    $pattern = '(?<=\s)(FontSize|Padding|Margin|Width|Height|MinWidth|MaxWidth|MinHeight|MaxHeight)="([0-9]+(?:\.[0-9]+)?(?:,[0-9]+(?:\.[0-9]+)?)*)"'
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $name = $m.Groups[1].Value
        $parts = $m.Groups[2].Value.Split(',')
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($p in $parts) {
            $v = [double]::Parse($p, [System.Globalization.CultureInfo]::InvariantCulture) * $Scale
            $out.Add(([math]::Round($v, 1)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
        }
        return $name + '="' + ($out -join ',') + '"'
    }
    return [regex]::Replace($Xaml, $pattern, $evaluator)
}

$script:UiScale = 1.0
try {
    if (-not [string]::IsNullOrWhiteSpace($env:NIGHTCITY_UI_SCALE)) {
        $script:UiScale = [double]::Parse($env:NIGHTCITY_UI_SCALE, [System.Globalization.CultureInfo]::InvariantCulture)
    } else {
        $script:UiScale = [System.Windows.SystemParameters]::PrimaryScreenWidth / 1280.0
    }
} catch {}
$script:UiScale = [math]::Round([math]::Max(0.75, [math]::Min(1.8, $script:UiScale)), 2)
$XAML = Expand-UiScale $XAML $script:UiScale

try {
    $Window = [System.Windows.Markup.XamlReader]::Parse($XAML)
} catch {
    Write-NCLog "XAML error: $($_.Exception.Message)"
    [System.Windows.MessageBox]::Show("XAML LOAD ERROR:`n`n$($_.Exception.Message)", $script:AppTitle, 'OK', 'Error') | Out-Null
    exit 1
}

function C {
    param([string]$Name)
    return $Window.FindName($Name)
}

# ---------- wallpaper ----------
$wallpaperPath = Join-Path $script:BaseDir 'NightCityWallpaper.png'
if ($script:WebView2Available) { try { (C 'DashBrowser').Text = 'CHROMIUM // READY' } catch {} }

if (Test-Path -LiteralPath $wallpaperPath) {
    try {
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.UriSource = New-Object System.Uri($wallpaperPath)
        $bmp.EndInit()
        $bmp.Freeze()
        (C 'WallpaperImage').Source = $bmp
    } catch {
        Write-NCLog "wallpaper failed: $($_.Exception.Message)"
    }
}

# ============================================================
#  BROWSER START PAGE
# ============================================================
$script:HomeHtml = @'
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>NC://HOME</title>
<style>
    html, body { margin:0; padding:0; height:100%; overflow:hidden; }
    body {
        background-color:#070509;
        background-image:
            radial-gradient(circle at 50% 118%, rgba(255,38,56,0.30) 0%, rgba(255,38,56,0.05) 40%, rgba(0,0,0,0) 66%),
            linear-gradient(180deg, #05040a 0%, #0d0509 55%, #1a0710 100%);
        color:#e9d9db; font-family:Consolas,'Lucida Console',monospace;
    }
    #grid {
        position:fixed; left:-20%; right:-20%; bottom:-6%; height:52%;
        background-image:
            repeating-linear-gradient(90deg, rgba(255,38,56,0.13) 0px, rgba(255,38,56,0.13) 1px, transparent 1px, transparent 88px),
            repeating-linear-gradient(0deg, rgba(255,38,56,0.10) 0px, rgba(255,38,56,0.10) 1px, transparent 1px, transparent 44px);
        transform:perspective(420px) rotateX(66deg);
        transform-origin:50% 100%;
        -ms-transform:perspective(420px) rotateX(66deg);
        opacity:.55;
    }
    #scan {
        position:fixed; left:0; top:0; right:0; bottom:0; pointer-events:none;
        background-image:repeating-linear-gradient(0deg, rgba(0,0,0,0.22) 0px, rgba(0,0,0,0.22) 1px, transparent 1px, transparent 3px);
    }
    #vig {
        position:fixed; left:0; top:0; right:0; bottom:0; pointer-events:none;
        background-image:radial-gradient(ellipse at center, rgba(0,0,0,0) 45%, rgba(0,0,0,0.55) 100%);
    }
    .wrap { position:relative; width:900px; margin:0 auto; padding-top:44px; }
    .topline {
        font-size:11px; letter-spacing:3px; color:#8a6a6f;
        border-bottom:1px solid rgba(255,38,56,0.25); padding-bottom:10px;
    }
    .topline b { color:#ff2638; font-weight:normal; }
    .dot { display:inline-block; width:7px; height:7px; background:#ff2638; margin-right:8px; border-radius:50%;
           box-shadow:0 0 8px #ff2638; }
    .clock { float:right; color:#ff3545; letter-spacing:2px; }
    h1 {
        margin:36px 0 0 0; font-size:52px; letter-spacing:7px; font-weight:bold; color:#fff;
        text-shadow:0 0 12px rgba(255,38,56,0.85), 0 0 38px rgba(255,38,56,0.45);
        animation:flicker 7s infinite;
    }
    h1 span { color:#ff2638; }
    .sub { margin:6px 0 0 3px; font-size:11px; letter-spacing:6px; color:#ff5a66; }
    @keyframes flicker {
        0%, 96%, 100% { opacity:1; }
        96.5% { opacity:.6; }
        97% { opacity:1; }
        97.4% { opacity:.75; }
        97.8% { opacity:1; }
    }
    .search {
        position:relative; margin-top:30px; width:640px; height:50px; border:1px solid #ff2638;
        background:rgba(8,3,7,0.9); box-shadow:0 0 18px rgba(255,38,56,0.20), inset 0 0 22px rgba(255,38,56,0.06);
    }
    .search input {
        position:absolute; left:0; top:0; width:486px; height:48px; background:transparent; border:0; outline:none;
        color:#f2e4e6; font-family:Consolas,monospace; font-size:15px; padding:0 14px; letter-spacing:1px;
    }
    .search button {
        position:absolute; right:0; top:0; width:126px; height:48px; border:0; background:#ff2638; color:#100408;
        font-family:Consolas,monospace; font-size:13px; font-weight:bold; letter-spacing:2px; cursor:pointer;
    }
    .search button:hover { background:#ff4552; }
    table.tiles { width:900px; margin-top:30px; border-collapse:collapse; }
    table.tiles td { width:25%; padding:5px; vertical-align:top; }
    a.tile {
        display:block; height:64px; border:1px solid #4a121c; background:rgba(16,6,10,0.72);
        text-decoration:none; padding:9px 10px; box-sizing:border-box;
    }
    a.tile:hover { border-color:#ff2638; background:rgba(40,8,16,0.85); }
    .tile b { display:block; color:#ff4552; font-size:12px; letter-spacing:2px; font-weight:normal; white-space:nowrap; }
    .tile i { display:block; margin-top:8px; color:#7d5b60; font-size:9px; letter-spacing:1px; font-style:normal; }
    .console {
        margin-top:22px; border-left:2px solid #ff2638; background:rgba(10,3,6,0.75);
        padding:10px 12px; font-size:10px; color:#8a666b; line-height:1.9; letter-spacing:1px;
    }
    .console em { color:#ff4552; font-style:normal; }
    .cursor { color:#ff2638; }
    .foot { position:fixed; left:0; right:0; bottom:14px; text-align:center; font-size:9px; letter-spacing:3px; color:#5d3f44; }
</style>
</head>
<body>
<div id="grid"></div>
<div class="wrap">
    <div class="topline">
        <span class="dot"></span><b>NIGHT CITY NET</b> // SECURE GATEWAY
        <span class="clock" id="clock">--:--:--</span>
    </div>

    <h1>NIGHT CITY<span>//</span>NET</h1>
    <div class="sub">LOCAL TERMINAL // BROWSER ONLINE</div>

    <form class="search" action="https://www.bing.com/search" method="get">
        <input type="text" name="q" autocomplete="off" placeholder="search the net or type an address...">
        <button type="submit">JACK IN</button>
    </form>

    <table class="tiles">
        <tr>
            <td><a class="tile" href="https://www.bing.com"><b>BING</b><i>SEARCH NODE</i></a></td>
            <td><a class="tile" href="https://duckduckgo.com"><b>DUCKDUCKGO</b><i>PRIVATE NODE</i></a></td>
            <td><a class="tile" href="https://www.youtube.com"><b>YOUTUBE</b><i>MEDIA NODE</i></a></td>
            <td><a class="tile" href="https://github.com"><b>GITHUB</b><i>CODE NODE</i></a></td>
        </tr>
        <tr>
            <td><a class="tile" href="https://www.wikipedia.org"><b>WIKIPEDIA</b><i>DATA NODE</i></a></td>
            <td><a class="tile" href="https://www.reddit.com"><b>REDDIT</b><i>SOCIAL NODE</i></a></td>
            <td><a class="tile" href="https://stackoverflow.com"><b>STACK OVERFLOW</b><i>DEV NODE</i></a></td>
            <td><a class="tile" href="https://rutube.ru"><b>RUTUBE</b><i>VIDEO NODE</i></a></td>
        </tr>
    </table>

    <div class="console">
        <div>[ <span id="t1">--:--:--</span> ] uplink handshake ............... <em>ACCEPTED</em></div>
        <div>[ <span id="t2">--:--:--</span> ] route table ................... <em>LOCAL GATEWAY</em></div>
        <div>[ <span id="t3">--:--:--</span> ] netrunner session ............ <em>AWAITING INPUT</em><span class="cursor">_</span></div>
    </div>
</div>
<div class="foot">MSHTML ENGINE // IE11 COMPATIBILITY LAYER // SOME NODES MAY BE OFFLINE</div>
<div id="vig"></div>
<div id="scan"></div>
<script>
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function stamp() {
        var d = new Date();
        var s = pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
        var c = document.getElementById('clock');
        if (c) { c.innerHTML = s; }
        var ids = ['t1', 't2', 't3'];
        for (var i = 0; i < ids.length; i++) {
            var el = document.getElementById(ids[i]);
            if (el) { el.innerHTML = s; }
        }
    }
    stamp();
    setInterval(stamp, 1000);
</script>
</body>
</html>

'@

try {
    [System.IO.File]::WriteAllText($script:HomePath, $script:HomeHtml, (New-Object System.Text.UTF8Encoding($false)))
} catch {
    Write-NCLog "home.html write failed: $($_.Exception.Message)"
}
$script:HomeUrl = ([System.Uri]$script:HomePath).AbsoluteUri

# ============================================================
#  BROWSER
# ============================================================
$script:WebBrowser  = $null
$script:WebView    = $null
$script:BrowserReady = $false

function Format-BrowserAddress {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return 'nc://home' }
    if ($Url -eq $script:HomeUrl) { return 'nc://home' }
    if ($Url -eq 'about:blank') { return 'nc://home' }
    return $Url
}

function ConvertTo-BrowserUrl {
    param([string]$Text)
    $t = ''
    if ($Text) { $t = $Text.Trim() }
    if (-not $t) { return $script:HomeUrl }
    if ($t -in @('home', 'nc://home', 'nc:home', 'NC://HOME')) { return $script:HomeUrl }
    if ($t -match '^(?i)(https?|file|about):') { return $t }
    if ($t -match '^(?i)localhost(:\d+)?(/.*)?$') { return 'http://' + $t }
    if ($t -notmatch '\s' -and $t -match '^[^\s/]+\.[^\s/]{2,}(:\d+)?(/.*)?$') { return 'https://' + $t }
    return 'https://www.bing.com/search?q=' + [System.Uri]::EscapeDataString($t)
}

function Navigate-Browser {
    param([string]$Target)
    if (-not $script:BrowserReady) { Initialize-Browser }
    $url = ConvertTo-BrowserUrl $Target
    try {
        (C 'BrowserAddress').Text = Format-BrowserAddress $url
        if ($script:WebView) {
            $script:WebView.Source = [uri]$url
        } elseif ($script:WebBrowser) {
            $script:WebBrowser.Navigate($url)
        }
    } catch {
        (C 'BrowserStatus').Text = 'NAVIGATION FAILED'
        Write-NCLog "navigate failed: $($_.Exception.Message)"
    }
}

function Initialize-Browser {
    if ($script:BrowserReady) { return }
    if ($script:WebView2Available) {
        try {
            Initialize-WebView2Browser
            return
        } catch {
            Write-NCLog "WebView2 init failed: $($_.Exception.Message)"
            (C 'BrowserStatus').Text = 'WEBVIEW2 FAILED // FALLBACK TO MSHTML'
        }
    }
    Initialize-LegacyBrowser
}

function Initialize-WebView2Browser {
    (C 'BrowserStatus').Text = 'INITIALIZING CHROMIUM ...'
    $wv = New-Object Microsoft.Web.WebView2.Wpf.WebView2
    $props = New-Object Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties
    $folder = Join-Path $script:DataDir 'WebView2'
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    $props.UserDataFolder = $folder
    $wv.CreationProperties = $props
    $wv.DefaultBackgroundColor = [System.Drawing.Color]::FromArgb(255, 5, 3, 8)

    (C 'BrowserSurface').Child = $wv

    $wv.Add_NavigationStarting({
        param($s, $e)
        try {
            (C 'BrowserAddress').Text = Format-BrowserAddress $e.Uri
            (C 'BrowserStatus').Text = 'LINKING // ' + $e.Uri
            (C 'BrowserProgress').IsIndeterminate = $true
        } catch {}
    })

    $wv.Add_NavigationCompleted({
        param($s, $e)
        try {
            (C 'BrowserProgress').IsIndeterminate = $false
            (C 'BrowserProgress').Value = 100
            if ($e.IsSuccess) {
                (C 'BrowserStatus').Text = 'READY // ' + $e.HttpStatusCode
            } else {
                (C 'BrowserStatus').Text = 'LOAD FAILED // ' + $e.WebErrorStatus
            }
            (C 'BrowserAddress').Text = Format-BrowserAddress $s.Source
        } catch {}
    })

    $wv.Add_SourceChanged({
        param($s, $e)
        try { (C 'BrowserAddress').Text = Format-BrowserAddress $s.Source } catch {}
    })

    $wv.Add_CoreWebView2InitializationCompleted({
        param($s, $e)
        try {
            if ($e.IsSuccess) {
                $ver = $s.CoreWebView2.Environment.BrowserVersionString
                (C 'BrowserEngine').Text = 'ENGINE // CHROMIUM ' + $ver
                (C 'DashBrowser').Text = 'CHROMIUM // EDGE'
                Write-NCLog ('WebView2 ready ' + $ver)
                $s.CoreWebView2.add_ContainsFullScreenElementChanged({
                    param($core, $args)
                    try {
                        Set-VideoFullscreen ([bool]$core.ContainsFullScreenElement)
                    } catch {}
                })
            } else {
                (C 'BrowserStatus').Text = 'WEBVIEW2 FAILED // ' + $e.InitializationException.Message
                Write-NCLog ('WebView2 init error: ' + $e.InitializationException.Message)
            }
        } catch {}
    })

    $script:WebView = $wv
    $script:BrowserReady = $true
    (C 'BrowserStatus').Text = 'LOADING START PAGE ...'
    $wv.Source = [uri]$script:HomeUrl
    if (-not [string]::IsNullOrWhiteSpace($env:NIGHTCITY_BROWSER_URL)) {
        $wv.Source = [uri]$env:NIGHTCITY_BROWSER_URL
    }
}

function Initialize-LegacyBrowser {
    if ($script:BrowserReady) { return }
    (C 'BrowserStatus').Text = 'INITIALIZING MSHTML ...'
    try {
        $wfh = New-Object System.Windows.Forms.Integration.WindowsFormsHost
        $wfh.Background = [System.Windows.Media.Brushes]::Black

        $wb = New-Object System.Windows.Forms.WebBrowser
        $wb.ScriptErrorsSuppressed = $true
        $wb.IsWebBrowserContextMenuEnabled = $false
        $wb.AllowWebBrowserDrop = $false
        $wb.WebBrowserShortcutsEnabled = $true
        $wb.ScriptErrorsSuppressed = $true

        $wfh.Child = $wb
        (C 'BrowserSurface').Child = $wfh

        $wb.Add_Navigating({
            param($s, $e)
            try {
                $u = $e.Url.AbsoluteUri
                (C 'BrowserAddress').Text = Format-BrowserAddress $u
                (C 'BrowserStatus').Text = 'LINKING // ' + $u
                (C 'BrowserProgress').IsIndeterminate = $true
            } catch {}
        })

        $wb.Add_DocumentCompleted({
            param($s, $e)
            try {
                if ($e.Url.AbsoluteUri -ne $s.Url.AbsoluteUri) { return }
                (C 'BrowserProgress').IsIndeterminate = $false
                (C 'BrowserProgress').Value = 100
                (C 'BrowserStatus').Text = 'READY // DOCUMENT LOADED'
                (C 'BrowserAddress').Text = Format-BrowserAddress $s.Url.AbsoluteUri
                $mode = 0
                try { $mode = [int]$s.Document.DomDocument.documentMode } catch {}
                if ($mode -gt 0) { (C 'BrowserEngine').Text = "ENGINE // MSHTML IE$mode" }
            } catch {}
        })

        $wb.Add_NewWindow({
            param($s, $e)
            $e.Cancel = $true
            (C 'BrowserStatus').Text = 'POPUP BLOCKED'
        })

        $script:WebBrowser = $wb
        $script:BrowserReady = $true
        (C 'DashBrowser').Text = 'MSHTML // IE11'
        Navigate-Browser $script:HomeUrl
        Write-NCLog 'browser initialized'
    } catch {
        Write-NCLog "browser init failed: $($_.Exception.Message)"
        (C 'BrowserStatus').Text = 'BROWSER ENGINE FAILED // ' + $_.Exception.Message
    }
}


# ============================================================
#  FILE MANAGER
# ============================================================
$script:CurrentPath = 'C:\'
$script:History = New-Object System.Collections.Stack

function Load-Directory {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = 'C:\' }
    $Path = $Path.Trim('"').Trim()
    if (-not (Test-Path -LiteralPath $Path)) {
        (C 'FileStatus').Text = 'PATH NOT FOUND // ' + $Path
        return
    }
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if (-not $item.PSIsContainer) {
            Start-Process -FilePath $item.FullName
            return
        }
        $script:CurrentPath = $item.FullName
        (C 'PathBox').Text = $script:CurrentPath

        $rows = @(Get-ChildItem -LiteralPath $script:CurrentPath -Force -ErrorAction Stop | ForEach-Object {
            $isDir = $_.PSIsContainer
            [PSCustomObject]@{
                Name     = $_.Name
                Date     = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
                Type     = $(if ($isDir) { 'DIR' } elseif ($_.Extension) { $_.Extension.ToUpper() } else { 'FILE' })
                Size     = $(if ($isDir) {
                    ''
                } elseif ($_.Length -ge 1GB) {
                    '{0:N2} GB' -f ($_.Length / 1GB)
                } elseif ($_.Length -ge 1MB) {
                    '{0:N1} MB' -f ($_.Length / 1MB)
                } else {
                    '{0:N0} KB' -f ($_.Length / 1KB)
                })
                FullPath = $_.FullName
                IsDir    = $isDir
            }
        })

        $sorted = $rows | Sort-Object -Property @{ Expression = 'IsDir'; Descending = $true }, @{ Expression = 'Name'; Descending = $false }
        (C 'FileGrid').ItemsSource = @($sorted)
        (C 'FileStatus').Text = '{0} OBJECTS // {1}' -f $rows.Count, $script:CurrentPath
    } catch {
        (C 'FileStatus').Text = 'ACCESS DENIED // ' + $Path
        Write-NCLog "load dir failed: $($_.Exception.Message)"
    }
}

function Navigate-Files {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($script:CurrentPath)) { $script:History.Push($script:CurrentPath) }
    Load-Directory $Path
}

# ============================================================
#  APPLICATIONS
# ============================================================
$script:AppCatalog = @(
    @{ Label = 'FILE MANAGER';   Icon = [char]0x25B0; Target = 'view:FilesView';   Note = 'LOCAL DISKS' },
    @{ Label = 'BROWSER';        Icon = [char]0x25C9; Target = 'view:BrowserView'; Note = 'NET ACCESS' },
    @{ Label = 'NETWORK';        Icon = [char]0x25CE; Target = 'view:NetworkView'; Note = 'LINK STATE' },
    @{ Label = 'SYSTEM';         Icon = [char]0x25A4; Target = 'view:SystemView';  Note = 'HARDWARE' },
    @{ Label = 'TASK MANAGER';   Icon = [char]0x25A5; Target = 'taskmgr.exe';      Note = 'PROCESSES' },
    @{ Label = 'TERMINAL';       Icon = '>_';          Target = 'powershell.exe';   Note = 'POWERSHELL' },
    @{ Label = 'CMD';            Icon = '>';           Target = 'cmd.exe';          Note = 'COMMAND' },
    @{ Label = 'NOTEPAD';        Icon = [char]0x25A4; Target = 'notepad.exe';      Note = 'TEXT' },
    @{ Label = 'CALCULATOR';     Icon = '=';           Target = 'calc.exe';         Note = 'MATH' },
    @{ Label = 'EXPLORER';       Icon = [char]0x25A3; Target = 'explorer.exe';     Note = 'WINDOWS' },
    @{ Label = 'CONTROL PANEL';  Icon = [char]0x2699; Target = 'control.exe';      Note = 'SETTINGS' },
    @{ Label = 'DEVICE MANAGER'; Icon = [char]0x25A7; Target = 'mmc.exe'; Args = "$env:WINDIR\System32\devmgmt.msc"; Note = 'HARDWARE' },
    @{ Label = 'SERVICES';       Icon = [char]0x25A6; Target = 'mmc.exe'; Args = "$env:WINDIR\System32\services.msc"; Note = 'BACKGROUND' },
    @{ Label = 'EVENT VIEWER';   Icon = [char]0x25A9; Target = 'mmc.exe'; Args = "$env:WINDIR\System32\eventvwr.msc"; Note = 'LOGS' },
    @{ Label = 'SYSTEM CONTROL'; Icon = [char]0x2699; Target = 'view:SystemControlView'; Note = 'WINDOWS TOOLS' }
)

$script:AppsBuilt = $false

function Build-Apps {
    if ($script:AppsBuilt) { return }
    $panel = C 'AppsPanel'
    if (-not $panel) { return }
    $panel.Children.Clear()
    $style = $Window.Resources['Tile']
    foreach ($app in $script:AppCatalog) {
        $b = New-Object System.Windows.Controls.Button
        $b.Style = $style
        $b.Tag = $app
        $b.ToolTip = $app.Note
        $sp = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = ('{0}  {1}' -f $app.Icon, $app.Label)
        $t1.FontSize = 12
        $t1.Foreground = '#FFFF4552'
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = $app.Note
        $t2.FontSize = 9
        $t2.Margin = '0,3,0,0'
        $t2.Foreground = '#FF7D5B60'
        [void]$sp.Children.Add($t1)
        [void]$sp.Children.Add($t2)
        $b.Content = $sp
        $b.Add_Click({
            param($sender, $e)
            $a = $sender.Tag
            if ($a.Target -like 'view:*') { Show-View ($a.Target.Substring(5)) }
            else { Open-Target $a.Target $a.Args }
        })
        [void]$panel.Children.Add($b)
    }
    $script:AppsBuilt = $true
}

function Open-Target {
    param([string]$Target, [string]$Arguments)
    if ([string]::IsNullOrWhiteSpace($Target)) { return }
    Write-NCLog "launch: $Target $Arguments"
    $leaf = [IO.Path]::GetFileName($Target).ToLowerInvariant()
    if ($script:ExternalApps -contains $leaf) {
        Start-ExternalApp $Target $Arguments
    } else {
        Start-EmbeddedApp $Target $Arguments
    }
}

# ============================================================
#  VIEWS
# ============================================================
$script:NavMap = [ordered]@{
    DashboardView = 'NavOverview'
    AppsView      = 'NavApps'
    FilesView     = 'NavFiles'
    BrowserView   = 'NavBrowser'
    NetworkView   = 'NavNetwork'
    SystemView    = 'NavSystem'
    TasksView     = 'NavTasks'
    SecurityView  = 'NavSecurity'
    NotificationsView = 'NavNotify'
    SystemControlView = 'NavSettings'
    SettingsView  = 'NavSettings'
    AIView        = 'NavAI'
    AppView       = 'NavApps'
}

function Show-View {
    param([string]$Name)
    if (-not $script:NavMap.Contains($Name)) { return }
    if ($Name -ne 'AppView' -and $script:Embedded) { Detach-EmbeddedApp }
    if ($Name -ne 'AIView') { try { $script:ChatTimer.Stop() } catch {} }
    foreach ($v in $script:NavMap.Keys) {
        $view = C $v
        if ($view) { $view.Visibility = $(if ($v -eq $Name) { 'Visible' } else { 'Collapsed' }) }
    }
    foreach ($n in $script:NavMap.Values) {
        $b = C $n
        if ($b) {
            $b.Background = '#DD10080C'
            $b.Foreground = '#FFFF3545'
            $b.BorderBrush = '#FF79121F'
        }
    }
    $active = C $script:NavMap[$Name]
    if ($active) {
        $active.Background = '#33FF2638'
        $active.Foreground = '#FFFFFFFF'
        $active.BorderBrush = '#FFFF2638'
    }
    $label = $Name -replace 'View$', ''
    $label = [regex]::Replace($label, '([a-z])([A-Z])', '$1 $2')
    (C 'ViewLabel').Text = $label.ToUpper()

    switch ($Name) {
        'AppsView'     { Build-Apps }
        'FilesView'    { Load-Directory $script:CurrentPath }
        'BrowserView'  { Initialize-Browser }
        'AIView'       { Initialize-Ai; $script:ChatTimer.Start() }
        'NetworkView'  { Update-NetworkView }
        'SystemView'   { Update-SystemView }
        'TasksView'      { Update-TaskList }
        'SecurityView'   { Update-Security }
        'NotificationsView' { $script:Unread = 0; Update-NotifyBadge; Update-Notifications }
        'SystemControlView' { Update-SystemControl }
        'SettingsView' { Update-SettingsView }
    }
    if ($script:Lang -eq 'ru') { Translate-Node $Window $script:TrPairsRu }

    $targetView = C $Name
    if ($targetView) {
        try {
            $targetView.Opacity = 0
            $fade = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(160))
            $targetView.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
        } catch {}
    }
}

function Get-PrimaryIPv4 {
    try {
        foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
            if ($ni.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) { continue }
            foreach ($ua in $ni.GetIPProperties().UnicastAddresses) {
                if ($ua.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
                    -not $ua.Address.ToString().StartsWith('169.254.')) {
                    return $ua.Address.ToString()
                }
            }
        }
    } catch {}
    return $null
}

function Get-TempReadings {
    $cpu = $null
    $gpu = $null
    try {
        $zones = Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction Stop
        $vals = @()
        foreach ($z in $zones) {
            $v = [double]$z.Temperature
            $c = $v
            if ($v -gt 1000) { $c = ($v / 10.0) - 273.15 }
            elseif ($v -gt 150) { $c = $v - 273.15 }
            if ($c -gt 0 -and $c -lt 150) { $vals += $c }
        }
        if ($vals.Count -gt 0) { $cpu = ($vals | Measure-Object -Maximum).Maximum }
    } catch {
        try {
            $zones = Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
            $vals = @($zones | ForEach-Object { ($_.CurrentTemperature / 10.0) - 273.15 } |
                    Where-Object { $_ -gt 0 -and $_ -lt 150 })
            if ($vals.Count -gt 0) { $cpu = ($vals | Measure-Object -Maximum).Maximum }
        } catch {}
    }
    try {
        if (-not $script:NvsmiChecked) {
            $script:NvsmiPath = (Get-Command 'nvidia-smi.exe' -ErrorAction SilentlyContinue).Source
            $script:NvsmiChecked = $true
        }
        $smi = $script:NvsmiPath
        if ($smi) {
            $raw = @(& $smi '--query-gpu=temperature.gpu' '--format=csv,noheader,nounits' 2>$null)
            if ($raw.Count -gt 0 -and $raw[0] -match '(\d+)') { $gpu = [double]$Matches[1] }
        }
    } catch {}
    return @{ Cpu = $cpu; Gpu = $gpu }
}

# ============================================================
#  STATISTICS
# ============================================================
$script:StatsBusy = $false

function Update-Stats {
    if ($script:StatsBusy) { return }
    $script:StatsBusy = $true
    try {
        # CPU
        try {
            $cpu = [int][math]::Round((Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                    Measure-Object -Property LoadPercentage -Average).Average)
            (C 'CpuText').Text = 'CPU      {0} %' -f $cpu
            (C 'CpuBar').Value = $cpu
        } catch {}

        # RAM
        try {
            $total = 0
            $free = 0
            try {
                $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                $total = [double]$os.TotalVisibleMemorySize
                $free = [double]$os.FreePhysicalMemory
            } catch {
                $ci = [Microsoft.VisualBasic.Devices.ComputerInfo]::new()
                $total = [double]$ci.TotalPhysicalMemory / 1KB
                $free = [double]$ci.AvailablePhysicalMemory / 1KB
            }
            if ($total -gt 0) {
                $ram = [int][math]::Round((($total - $free) / $total) * 100)
                (C 'RamText').Text = 'RAM      {0} %' -f $ram
                (C 'RamBar').Value = $ram
            }
        } catch {}

        # disk C:
        try {
            $di = [System.IO.DriveInfo]::new('C')
            $used = $di.TotalSize - $di.AvailableFreeSpace
            $pct = [int][math]::Round(100 * $used / $di.TotalSize)
            (C 'DiskText').Text = 'DISK C:  {0} %' -f $pct
            (C 'DiskBar').Value = $pct
        } catch {}

        # uptime
        $up = [TimeSpan]::FromMilliseconds([Environment]::TickCount64)
        if ($script:Lang -eq 'ru') {
            (C 'UptimeText').Text = 'АПТАЙМ   {0}ч {1}м' -f [int]$up.TotalHours, $up.Minutes
        } else {
            (C 'UptimeText').Text = 'UPTIME   {0}h {1}m' -f [int]$up.TotalHours, $up.Minutes
        }

        # network
        try {
            $ip = Get-PrimaryIPv4
            if ($ip) {
                (C 'NetworkState').Text = [char]0x25CF + ' CONNECTED'
                (C 'IpText').Text = 'IP: ' + $ip
                (C 'DashNet').Text = 'ONLINE'
            } else {
                (C 'NetworkState').Text = 'NO ACTIVE ADDRESS'
                (C 'IpText').Text = 'IP: unavailable'
                (C 'DashNet').Text = 'OFFLINE'
            }
        } catch {}

        # power / battery
        try {
            $pwr = [System.Windows.Forms.SystemInformation]::PowerStatus
            $pct = [int]($pwr.BatteryLifePercent * 100)
            if ($pwr.BatteryChargeStatus -eq [System.Windows.Forms.BatteryChargeStatus]::NoSystemBattery) {
                (C 'BatteryStatus').Text = 'AC POWER'
                (C 'BatteryTime').Text = 'Desktop mode (no battery)'
                (C 'RightBattery').Text = 'AC POWER'
                (C 'RightBatteryTime').Text = 'Desktop mode (no battery)'
            } else {
                $state = $(if ($pwr.PowerLineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online) { 'AC / CHARGING' } else { 'ON BATTERY' })
                (C 'BatteryStatus').Text = '{0}% // {1}' -f $pct, $state
                (C 'RightBattery').Text = '{0}% // {1}' -f $pct, $state
                $note = 'Battery {0}%' -f $pct
                if ($pwr.BatteryLifeRemaining -gt 0) {
                    $note = $(if ($script:Lang -eq 'ru') { 'Осталось: {0}ч {1}м' } else { 'Time left: {0}h {1}m' }) -f [int]($pwr.BatteryLifeRemaining / 3600), [int](($pwr.BatteryLifeRemaining % 3600) / 60)
                }
                (C 'BatteryTime').Text = $note
                (C 'RightBatteryTime').Text = $note
            }
        } catch {}

        try {
            $temps = Get-TempReadings
            $cpuT = $temps.Cpu
            $gpuT = $temps.Gpu
            if ($null -ne $cpuT -or $null -ne $gpuT) {
                $c = $(if ($null -ne $cpuT) { [int][math]::Round($cpuT) } else { '--' })
                $g = $(if ($null -ne $gpuT) { [int][math]::Round($gpuT) } else { '--' })
                (C 'TempText').Text = 'TEMP     CPU {0}°C / GPU {1}°C' -f $c, $g
            } else {
                (C 'TempText').Text = 'TEMP     N/A (no sensor)'
            }
        } catch {}

        if ($script:Lang -eq 'ru') { Translate-Node $Window $script:TrPairsRu }
    } finally {
        $script:StatsBusy = $false
    }
}


if ($SelfTest) { $script:SelfTestStatsOk = $false }

# ============================================================
#  NETWORK / SYSTEM / SETTINGS
# ============================================================
function Update-NetworkView {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('HOST      ' + [Environment]::MachineName)
    [void]$sb.AppendLine('USER      ' + [Environment]::UserName)
    [void]$sb.AppendLine('')
    try {
        $nics = @([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
                Where-Object { $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback })
        $active = 0
        foreach ($ni in $nics) {
            $props = $ni.GetIPProperties()
            $ips = @($props.UnicastAddresses | Where-Object {
                    $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
                    -not $_.Address.ToString().StartsWith('169.254.') })
            $gw = @($props.GatewayAddresses | Where-Object { $_.Address -ne $null })
            if ($ips.Count -eq 0 -and $gw.Count -eq 0) { continue }
            $active++
            [void]$sb.AppendLine('INTERFACE ' + $ni.Name)
            [void]$sb.AppendLine('  TYPE    ' + $ni.NetworkInterfaceType)
            [void]$sb.AppendLine('  STATE   ' + $ni.OperationalStatus)
            $mac = $ni.GetPhysicalAddress().ToString()
            if ($mac) { [void]$sb.AppendLine('  MAC     ' + $mac) }
            foreach ($a in $ips) { [void]$sb.AppendLine('  IPV4    ' + $a.Address) }
            foreach ($g in $gw) { [void]$sb.AppendLine('  GATEWAY ' + $g.Address) }
            foreach ($d in $props.DnsAddresses) {
                if ($d.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                    [void]$sb.AppendLine('  DNS     ' + $d)
                }
            }
            [void]$sb.AppendLine('')
        }
        if ($active -eq 0) { [void]$sb.AppendLine('NO ACTIVE IPV4 INTERFACES') }
    } catch {
        [void]$sb.AppendLine('NETWORK INFO UNAVAILABLE: ' + $_.Exception.Message)
    }
    (C 'NetInfo').Text = $sb.ToString()
}


function Update-SystemView {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('NIGHT CITY OS      v' + $script:Version)
    [void]$sb.AppendLine('POWERSHELL         ' + $PSVersionTable.PSVersion.ToString())
    [void]$sb.AppendLine('OS ARCH            ' + $env:PROCESSOR_ARCHITECTURE)
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    [void]$sb.AppendLine('SCREEN             ' + $screen.Width + ' x ' + $screen.Height)
    [void]$sb.AppendLine('')
    try {
        $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        [void]$sb.AppendLine('OS                 ' + $key.ProductName)
        [void]$sb.AppendLine('VERSION            ' + $key.DisplayVersion + '  build ' + $key.CurrentBuild + '.' + $key.UBR)
        if ($key.InstallTime) {
            [void]$sb.AppendLine('INSTALLED          ' + ([datetime]::FromFileTime([int64]$key.InstallTime)).ToString('yyyy-MM-dd'))
        }
    } catch {
        [void]$sb.AppendLine('OS                 ' + [Environment]::OSVersion.VersionString)
    }
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        [void]$sb.AppendLine('CPU                ' + $cpu.Name.Trim())
        [void]$sb.AppendLine('CORES / THREADS    ' + $cpu.NumberOfCores + ' / ' + $cpu.NumberOfLogicalProcessors)
    } catch {
        try {
            $cpuName = (Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction Stop).ProcessorNameString
            [void]$sb.AppendLine('CPU                ' + $cpuName)
        } catch {}
    }
    try {
        $ci = [Microsoft.VisualBasic.Devices.ComputerInfo]::new()
        [void]$sb.AppendLine('RAM TOTAL          ' + ('{0:N1} GB' -f ($ci.TotalPhysicalMemory / 1GB)))
        [void]$sb.AppendLine('RAM FREE           ' + ('{0:N1} GB' -f ($ci.AvailablePhysicalMemory / 1GB)))
    } catch {}
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('LOGICAL DRIVES')
    try {
        foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
            if (-not $d.IsReady) { continue }
            [void]$sb.AppendLine(('  {0}  {1}  free {2:N1} GB / total {3:N1} GB' -f $d.Name, $d.DriveFormat, ($d.AvailableFreeSpace / 1GB), ($d.TotalSize / 1GB)))
        }
    } catch {}
    (C 'SysInfo').Text = $sb.ToString()
}


# ---------- desktop mode ----------
$script:DesktopKey = 'HKCU:\Software\NightCityOS'

function Test-DesktopMode {
    try {
        $v = (Get-ItemProperty -Path $script:DesktopKey -Name 'ReplaceDesktop' -ErrorAction Stop).ReplaceDesktop
        return ([int]$v -eq 1)
    } catch { return $false }
}

function Start-ShellWatchdog {
    try {
        $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $code = 'Start-Sleep -Seconds 30; if (-not (Get-Process -Id ' + $PID + ' -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }'
        Start-Process -FilePath $ps -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-Command', $code) -WindowStyle Hidden | Out-Null
    } catch {}
}

function Set-DesktopMode {
    param([bool]$On)
    try {
        if (-not (Test-Path $script:DesktopKey)) { New-Item -Path $script:DesktopKey -Force | Out-Null }
        Set-ItemProperty -Path $script:DesktopKey -Name 'ReplaceDesktop' -Value $(if ($On) { 1 } else { 0 }) -Type DWord
    } catch {}
    if ($On) {
        [void](Enable-Autostart)
        try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
        Start-ShellWatchdog
        Notify $(if ($script:Lang -eq 'ru') { 'РАБОЧИЙ СТОЛ // ОБОЛОЧКА NIGHT CITY' } else { 'DESKTOP // NIGHT CITY SHELL' })
    } else {
        Disable-Autostart
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            try { Start-Process explorer.exe } catch {}
        }
        Notify $(if ($script:Lang -eq 'ru') { 'РАБОЧИЙ СТОЛ // ВОЗВРАЩЁН WINDOWS' } else { 'DESKTOP // WINDOWS RESTORED' })
    }
}

# ---------- autostart ----------
$script:RunKey  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:RunName = 'NightCityShell'

function Test-Autostart {
    try {
        $item = Get-ItemProperty -Path $script:RunKey -Name $script:RunName -ErrorAction Stop
        $v = $item.PSObject.Properties[$script:RunName].Value
        return -not [string]::IsNullOrWhiteSpace($v)
    } catch { return $false }
}

function Enable-Autostart {
    $vbs = Join-Path $script:BaseDir 'NightCityShell.vbs'
    $value = 'wscript.exe //B "' + $vbs + '"'
    try {
        if (-not (Test-Path $script:RunKey)) { New-Item -Path $script:RunKey -Force | Out-Null }
        New-ItemProperty -Path $script:RunKey -Name $script:RunName -Value $value -PropertyType String -Force | Out-Null
        Write-NCLog 'autostart enabled'
        return $true
    } catch {
        Write-NCLog "autostart enable failed: $($_.Exception.Message)"
        return $false
    }
}

function Disable-Autostart {
    try {
        Remove-ItemProperty -Path $script:RunKey -Name $script:RunName -Force -ErrorAction Stop
        Write-NCLog 'autostart disabled'
    } catch {}
}

function Update-SettingsView {
    $ru = ($script:Lang -eq 'ru')
    $on = $(if ($ru) { 'ВКЛ' } else { 'ON' })
    $off = $(if ($ru) { 'ВЫКЛ' } else { 'OFF' })
    $auto = $(if (Test-Autostart) { $on } else { $off })
    (C 'AutoStartBtn').Content = $(if ($ru) { 'АВТОЗАПУСК // ' } else { 'AUTOSTART // ' }) + $auto
    (C 'TopmostBtn').Content = $(if ($ru) { 'ПОВЕРХ ВСЕХ // ' } else { 'TOPMOST // ' }) + $(if ($Window.Topmost) { $on } else { $off })
    $desk = $(if (Test-DesktopMode) { $(if ($ru) { 'НАШ' } else { 'OURS' }) } else { $(if ($ru) { 'СТАНДАРТНЫЙ' } else { 'STOCK' }) })
    (C 'DesktopModeBtn').Content = $(if ($ru) { 'РАБОЧИЙ СТОЛ // ' } else { 'DESKTOP // ' }) + $desk
    (C 'DesktopApplyBtn').Content = $(if ($ru) { 'ПРИМЕНИТЬ СЕЙЧАС' } else { 'APPLY NOW' })

    $engine = $(if ($script:WebView2Available) { 'Chromium / Edge WebView2' } else { 'MSHTML / IE11' })
    $mode = $(if ($Shell) { $(if ($ru) { 'ОБОЛОЧКА (поверх всех + автозапуск)' } else { 'SHELL (topmost + autostart)' }) } else { $(if ($ru) { 'ОКНО' } else { 'WINDOWED' }) })
    if ($ru) {
        $lines = @(
            ('NIGHT CITY OS  v' + $script:Version),
            ('КОРЕНЬ      ' + $script:BaseDir),
            ('ДАННЫЕ      ' + $script:DataDir),
            ('ЛОГ         ' + $script:LogFile),
            ('БРАУЗЕР     ' + $engine),
            'АВТОЗАПУСК  HKCU\...\Run\NightCityShell',
            ('РЕЖИМ       ' + $mode),
            ('МАСШТАБ     ' + $script:UiScale + 'x'),
            ('АВТОСТАРТ   ' + $auto)
        )
    } else {
        $lines = @(
            ('NIGHT CITY OS  v' + $script:Version),
            ('ROOT        ' + $script:BaseDir),
            ('DATA        ' + $script:DataDir),
            ('LOG         ' + $script:LogFile),
            ('BROWSER     ' + $engine),
            'STARTUP     HKCU\...\Run\NightCityShell',
            ('MODE        ' + $mode),
            ('UI SCALE    ' + $script:UiScale + 'x'),
            ('AUTOSTART   ' + $auto)
        )
    }
    (C 'SettingsInfo').Text = ($lines -join [Environment]::NewLine)
}


# ============================================================
#  CLOCK
# ============================================================
function Update-Clock {
    $now = [DateTime]::Now
    $top = C 'ClockTop'
    if ($top) { $top.Text = $now.ToString('HH:mm:ss') }
    $date = C 'DateTop'
    if ($date) {
        $cul = $(if ($script:Lang -eq 'ru') { [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU') } else { [System.Globalization.CultureInfo]::InvariantCulture })
        $date.Text = $now.ToString('ddd dd MMM yyyy', $cul).ToUpper()
    }
}

# ============================================================
#  IMMERSIVE / FULLSCREEN
# ============================================================
$script:Immersive = $false
$script:VideoFullscreen = $false

function Set-Immersive {
    param([bool]$On, [bool]$HideChrome = $false)

    if ($On -eq $script:Immersive) {
        if ($On -and $HideChrome) {
            try { (C 'BrowserView').RowDefinitions[0].Height = [System.Windows.GridLength]::new(0.0) } catch {}
            try { (C 'BrowserView').RowDefinitions[1].Height = [System.Windows.GridLength]::new(0.0) } catch {}
            try { (C 'BrowserView').RowDefinitions[4].Height = [System.Windows.GridLength]::new(0.0) } catch {}
        }
        return
    }

    if ($On) {
        $script:Immersive = $true
        (C 'TopBar').Visibility = 'Collapsed'
        (C 'LeftNav').Visibility = 'Collapsed'
        (C 'RightPanel').Visibility = 'Collapsed'
        (C 'BottomBar').Visibility = 'Collapsed'
        [System.Windows.Controls.Grid]::SetColumn((C 'CenterArea'), 0)
        [System.Windows.Controls.Grid]::SetColumnSpan((C 'CenterArea'), 3)
        (C 'CenterArea').Margin = '0'
        $Window.Topmost = $true
        try { (C 'BrowserView').RowDefinitions[0].Height = [System.Windows.GridLength]::new(0.0) } catch {}
        if ($HideChrome) {
            try { (C 'BrowserView').RowDefinitions[1].Height = [System.Windows.GridLength]::new(0.0) } catch {}
            try { (C 'BrowserView').RowDefinitions[4].Height = [System.Windows.GridLength]::new(0.0) } catch {}
        }
    } else {
        $script:Immersive = $false
        (C 'TopBar').Visibility = 'Visible'
        (C 'LeftNav').Visibility = 'Visible'
        (C 'RightPanel').Visibility = 'Visible'
        (C 'BottomBar').Visibility = 'Visible'
        [System.Windows.Controls.Grid]::SetColumn((C 'CenterArea'), 1)
        [System.Windows.Controls.Grid]::SetColumnSpan((C 'CenterArea'), 1)
        (C 'CenterArea').Margin = '15,0'
        $bv = C 'BrowserView'
        try {
            $bv.RowDefinitions[0].Height = [System.Windows.GridLength]::Auto
            $bv.RowDefinitions[1].Height = [System.Windows.GridLength]::Auto
            $bv.RowDefinitions[4].Height = [System.Windows.GridLength]::Auto
        } catch {}
    }
}

$script:MonitorFs = $false
$script:FsPrevTopmost = $false

function Enter-MonitorFullscreen {
    if ($script:MonitorFs) { return }
    $script:MonitorFs = $true
    $script:FsPrevTopmost = $Window.Topmost
    $Window.WindowState = 'Normal'
    $Window.Left = 0
    $Window.Top = 0
    $Window.Width = [System.Windows.SystemParameters]::PrimaryScreenWidth
    $Window.Height = [System.Windows.SystemParameters]::PrimaryScreenHeight
    $Window.Topmost = $true
}

function Exit-MonitorFullscreen {
    if (-not $script:MonitorFs) { return }
    $script:MonitorFs = $false
    $Window.WindowState = 'Maximized'
    $Window.Topmost = $script:FsPrevTopmost
}

function Set-VideoFullscreen {
    param([bool]$On)
    $script:VideoFullscreen = $On
    Set-Immersive $On $On
    if ($script:WebView -and $script:WebView.CoreWebView2) {
        try {
            if ($On) {
                $js = 'if(!document.getElementById("nc-fs-cover")){var s=document.createElement("style");s.id="nc-fs-cover";s.textContent="video{object-fit:cover!important}";document.documentElement.appendChild(s);}'
            } else {
                $js = 'var s=document.getElementById("nc-fs-cover");if(s){s.remove();}'
            }
            [void]$script:WebView.CoreWebView2.ExecuteScriptAsync($js)
        } catch {}
    }
}

# ============================================================
#  EMBEDDED PROGRAMS
# ============================================================
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NCWin {
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    [DllImport("user32.dll", SetLastError = true)] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", SetLastError = true)] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
'@

$script:GWL_STYLE = -16
$script:WS_CHILD = 0x40000000
$script:WS_POPUP = -2147483648
$script:WS_CAPTION = 0x00C00000
$script:WS_THICKFRAME = 0x00040000
$script:WS_SYSMENU = 0x00080000
$script:WS_MINIMIZEBOX = 0x00020000
$script:WS_MAXIMIZEBOX = 0x00010000
$script:ExternalApps = @('explorer.exe', 'control.exe', 'calc.exe')
$script:Embedded = $null
$script:AppHostReady = $false
$script:ReturnView = 'AppsView'

function Initialize-AppHost {
    if ($script:AppHostReady) { return }
    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::FromArgb(5, 3, 8)
    $wfh = New-Object System.Windows.Forms.Integration.WindowsFormsHost
    $wfh.Child = $panel
    (C 'AppSurface').Child = $wfh
    $panel.Add_SizeChanged({ Resize-EmbeddedApp })
    $script:AppPanel = $panel
    $script:AppHostReady = $true
}

function Resize-EmbeddedApp {
    if (-not $script:Embedded) { return }
    try {
        $sz = $script:AppPanel.ClientSize
        if ($sz.Width -gt 0 -and $sz.Height -gt 0) {
            [void][NCWin]::MoveWindow($script:Embedded.Hwnd, 0, 0, $sz.Width, $sz.Height, $true)
        }
    } catch {}
}

function Embed-Window {
    param($Process, [IntPtr]$Hwnd)
    try {
        $style = [NCWin]::GetWindowLong($Hwnd, $script:GWL_STYLE)
        $style = (($style -band (-bnot $script:WS_POPUP)) -bor $script:WS_CHILD) -band (-bnot $script:WS_CAPTION) -band (-bnot $script:WS_THICKFRAME)
        [void][NCWin]::SetWindowLong($Hwnd, $script:GWL_STYLE, [int]$style)
        [void][NCWin]::SetParent($Hwnd, $script:AppPanel.Handle)
        $sz = $script:AppPanel.ClientSize
        [void][NCWin]::MoveWindow($Hwnd, 0, 0, $sz.Width, $sz.Height, $true)
        [void][NCWin]::ShowWindow($Hwnd, 5)
        $script:Embedded = @{ Proc = $Process; Hwnd = $Hwnd }
        (C 'AppStatus').Text = 'ATTACHED // PID ' + $Process.Id
        $script:EmbedTimer.Start()
    } catch {
        (C 'AppStatus').Text = 'EMBED FAILED // ' + $_.Exception.Message
        Write-NCLog "embed failed: $($_.Exception.Message)"
    }
}

function Start-EmbeddedApp {
    param([string]$Target, [string]$Arguments)
    if ($script:Embedded) { Detach-EmbeddedApp }
    Initialize-AppHost
    (C 'AppTitle').Text = [IO.Path]::GetFileNameWithoutExtension($Target).ToUpper()
    (C 'AppStatus').Text = 'ATTACHING WINDOW ...'
    Show-View 'AppView'
    try {
        if ([string]::IsNullOrWhiteSpace($Arguments)) {
            $proc = Start-Process -FilePath $Target -PassThru
        } else {
            $proc = Start-Process -FilePath $Target -ArgumentList $Arguments -PassThru
        }
    } catch {
        (C 'AppStatus').Text = 'LAUNCH FAILED // ' + $_.Exception.Message
        return
    }
    $script:AttachInfo = @{ Proc = $proc; Deadline = (Get-Date).AddSeconds(8) }
    $script:AttachTimer.Start()
}

function Detach-EmbeddedApp {
    if (-not $script:Embedded) { return }
    $h = $script:Embedded.Hwnd
    try {
        [void][NCWin]::ShowWindow($h, 0)
        $style = [NCWin]::GetWindowLong($h, $script:GWL_STYLE)
        $style = (($style -band (-bnot $script:WS_CHILD)) -bor $script:WS_POPUP -bor $script:WS_CAPTION -bor $script:WS_THICKFRAME -bor $script:WS_SYSMENU -bor $script:WS_MINIMIZEBOX -bor $script:WS_MAXIMIZEBOX)
        [void][NCWin]::SetWindowLong($h, $script:GWL_STYLE, [int]$style)
        [void][NCWin]::SetParent($h, [IntPtr]::Zero)
        [void][NCWin]::MoveWindow($h, 140, 100, 1100, 700, $true)
        [void][NCWin]::ShowWindow($h, 5)
        [void][NCWin]::SetForegroundWindow($h)
    } catch {}
    $script:Embedded = $null
    try { $script:EmbedTimer.Stop() } catch {}
}

function Close-EmbeddedApp {
    if (-not $script:Embedded) { return }
    $h = $script:Embedded.Hwnd
    $p = $script:Embedded.Proc
    try { [void][NCWin]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) } catch {}
    try { if (-not $p.WaitForExit(1500)) { $p.Kill() } } catch {}
    $script:Embedded = $null
    try { $script:EmbedTimer.Stop() } catch {}
}

function Start-ExternalApp {
    param([string]$Target, [string]$Arguments)
    try {
        if ($Arguments) { Start-Process -FilePath $Target -ArgumentList $Arguments | Out-Null }
        else { Start-Process -FilePath $Target | Out-Null }
        try { Notify ('LAUNCH // ' + [IO.Path]::GetFileNameWithoutExtension($Target).ToUpper()) } catch {}
        if ($Shell) { $Window.Topmost = $false }
        (C 'ViewLabel').Text = 'EXTERNAL APP // ALT+TAB'
    } catch {
        Write-NCLog "external launch failed: $($_.Exception.Message)"
    }
}

$script:AttachTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:AttachTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:AttachTimer.Add_Tick({
    $info = $script:AttachInfo
    if (-not $info) { $script:AttachTimer.Stop(); return }
    $proc = $info.Proc
    if ($proc.HasExited) {
        $script:AttachTimer.Stop()
        $script:AttachInfo = $null
        (C 'AppStatus').Text = 'PROCESS EXITED'
        Show-View $script:ReturnView
        return
    }
    try { $proc.Refresh() } catch {}
    $hwnd = $proc.MainWindowHandle
    if ($hwnd -ne [IntPtr]::Zero) {
        $script:AttachTimer.Stop()
        $script:AttachInfo = $null
        Embed-Window $proc $hwnd
        return
    }
    if ((Get-Date) -gt $info.Deadline) {
        $script:AttachTimer.Stop()
        $script:AttachInfo = $null
        (C 'AppStatus').Text = 'NO EMBEDDABLE WINDOW // OPENED ON DESKTOP'
        Write-NCLog 'embed timeout'
        Show-View $script:ReturnView
    }
})

$script:EmbedTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:EmbedTimer.Interval = [TimeSpan]::FromMilliseconds(800)
$script:EmbedTimer.Add_Tick({
    if (-not $script:Embedded) { $script:EmbedTimer.Stop(); return }
    if ($script:Embedded.Proc.HasExited) {
        $script:Embedded = $null
        $script:EmbedTimer.Stop()
        Show-View $script:ReturnView
    }
})

# ============================================================
#  NEURAL LINK // DEEPSEEK CHAT
# ============================================================
$script:AiWebView = $null
$script:ChatMode = $true
$script:ChatAwaiting = $false
$script:ChatAssistantBlock = $null
$script:ChatTask = $null
$script:ChatReady = $false
$script:ChatSentAt = $null

$script:ChatJs = @'
(function () {
  if (window.__nc) { return; }
  window.__nc = { last: "", pending: "" };
  function inputEl() {
    var el = document.querySelector("textarea");
    if (el) { return el; }
    var eds = document.querySelectorAll("[contenteditable=true]");
    if (eds.length) { return eds[eds.length - 1]; }
    return null;
  }
  function fire(el, name) { el.dispatchEvent(new Event(name, { bubbles: true })); }
  function visible(el) { var r = el.getBoundingClientRect(); return r.width > 3 && r.height > 3; }
  function findSend(el) {
    var nodes = document.querySelectorAll("[role=button],button");
    var ir = el.getBoundingClientRect();
    var best = null;
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (!visible(n)) { continue; }
      var cls = n.className;
      if (cls && cls.baseVal !== undefined) { cls = cls.baseVal; }
      cls = String(cls || "");
      var r = n.getBoundingClientRect();
      if (Math.abs((r.top + r.height / 2) - (ir.top + ir.height / 2)) > 90) { continue; }
      if (/ds-button--primary|ds-button--filled/.test(cls) && !/iconLabel/.test(cls)) { return n; }
      if (/send|отправ|submit/i.test(cls)) { return n; }
      if (r.left > ir.right - 80) { best = n; }
    }
    return best;
  }
  function pressEnter(el) {
    var o = { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true, cancelable: true };
    el.dispatchEvent(new KeyboardEvent("keydown", o));
    el.dispatchEvent(new KeyboardEvent("keypress", o));
    el.dispatchEvent(new KeyboardEvent("keyup", o));
  }
  window.__nc.send = function (text) {
    var el = inputEl();
    if (!el) { return "no-input"; }
    window.__nc.pending = text;
    el.focus();
    try {
      if (el.tagName === "TEXTAREA") {
        var setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
        setter.call(el, "");
        fire(el, "input");
        setter.call(el, text);
        fire(el, "input");
        fire(el, "change");
      } else {
        document.execCommand("selectAll", false, null);
        document.execCommand("insertText", false, text);
        fire(el, "input");
      }
    } catch (e) { return "err"; }
    setTimeout(function () {
      var btn = findSend(el);
      if (btn) { btn.click(); }
      pressEnter(el);
      setTimeout(function () {
        var left = (el.value !== undefined ? el.value : el.innerText) || "";
        if (left.trim() === String(window.__nc.pending).trim()) {
          var f = el.closest ? el.closest("form") : null;
          if (f && f.requestSubmit) { f.requestSubmit(); }
        }
      }, 600);
    }, 300);
    return "queued";
  };
  window.__nc.debug = function () {
    var el = inputEl();
    return JSON.stringify({ ta: !!el, send: !!(el && findSend(el)) });
  };
  window.__nc.poll = function () {
    var out = [];
    var nodes = document.querySelectorAll(".ds-markdown, [class*=ds-markdown], [class*=markdown]");
    if (nodes.length) {
      var t = (nodes[nodes.length - 1].innerText || "").trim();
      if (t && t !== window.__nc.last) { window.__nc.last = t; out.push({ evt: "assistant", text: t }); }
    }
    return out;
  };
})()
'@
function Set-ChatMode {
    param([bool]$Chat)
    $script:ChatMode = $Chat
    $host = C 'AiPageHost'
    if ($Chat) {
        (C 'ChatPanel').Visibility = 'Visible'
        $host.Width = 1000
        $host.Height = 800
        [System.Windows.Controls.Canvas]::SetLeft($host, 2000)
        [System.Windows.Controls.Canvas]::SetTop($host, 0)
        (C 'AiChatToggle').Content = 'PAGE'
    } else {
        (C 'ChatPanel').Visibility = 'Collapsed'
        $canvas = C 'AiCanvas'
        $host.Width = [math]::Max(640, $canvas.ActualWidth)
        $host.Height = [math]::Max(480, $canvas.ActualHeight)
        [System.Windows.Controls.Canvas]::SetLeft($host, 0)
        [System.Windows.Controls.Canvas]::SetTop($host, 0)
        (C 'AiChatToggle').Content = 'CHAT'
    }
}

function Add-ChatMessage {
    param([string]$Text, [bool]$User)
    $border = New-Object System.Windows.Controls.Border
    $border.Background = $(if ($User) { '#CC1A1406' } else { '#CC06141A' })
    $border.BorderBrush = $(if ($User) { '#FFFCEE0A' } else { '#FF00F0FF' })
    $border.BorderThickness = '3,0,0,0'
    $border.Padding = '12,8'
    $border.Margin = '0,0,0,12'
    $border.MaxWidth = 680
    $border.HorizontalAlignment = $(if ($User) { 'Right' } else { 'Left' })

    $stack = New-Object System.Windows.Controls.StackPanel
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $(if ($User) { 'NETRUNNER' } else { 'NC-AI' })
    $label.FontSize = 9
    $label.FontFamily = 'Consolas'
    $label.Foreground = $(if ($User) { '#FFFCEE0A' } else { '#FF00F0FF' })
    $label.Margin = '0,0,0,5'
    [void]$stack.Children.Add($label)

    $body = New-Object System.Windows.Controls.TextBlock
    $body.Text = $Text
    $body.TextWrapping = 'Wrap'
    $body.FontFamily = 'Consolas'
    $body.FontSize = 12
    $body.Foreground = '#FFF2F2F2'
    [void]$stack.Children.Add($body)

    $border.Child = $stack
    [void](C 'ChatList').Children.Add($border)
    (C 'ChatScroll').ScrollToEnd()
    return $body
}

function Send-Chat {
    param([string]$Text)
    $t = ''
    if ($Text) { $t = $Text.Trim() }
    if (-not $t) { return }
    (C 'ChatInput').Text = ''
    if (-not ($script:AiWebView -and $script:AiWebView.CoreWebView2)) {
        (C 'AiStatus').Text = 'LINK OFFLINE'
        return
    }
    [void](Add-ChatMessage $t $true)
    $script:ChatAwaiting = $true
    $script:ChatSentAt = Get-Date
    $script:ChatAssistantBlock = $null
    (C 'AiStatus').Text = 'TRANSMIT ...'
    $json = ConvertTo-Json $t -Compress
    [void]$script:AiWebView.CoreWebView2.ExecuteScriptAsync('window.__nc ? window.__nc.send(' + $json + ') : "no-bridge"')
}

function Initialize-Ai {
    if ($script:AiWebView) { return }
    if (-not $script:WebView2Available) {
        (C 'AiStatus').Text = 'WEBVIEW2 MISSING // lib folder required'
        return
    }
    try {
        $wv = New-Object Microsoft.Web.WebView2.Wpf.WebView2
        $props = New-Object Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties
        $folder = Join-Path $script:DataDir 'WebView2AI'
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        $props.UserDataFolder = $folder
        $props.AdditionalBrowserArguments = '--disable-background-timer-throttling --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-features=IntensiveWakeUpThrottling,CalculateNativeWinOcclusion'
        $wv.CreationProperties = $props
        $wv.DefaultBackgroundColor = [System.Drawing.Color]::FromArgb(255, 5, 3, 7)
        (C 'AiSurface').Child = $wv

        $wv.Add_NavigationCompleted({
            param($s, $e)
            try {
                if ($e.IsSuccess) {
                    (C 'AiStatus').Text = 'ONLINE // DEEPSEEK CHAT'
                    [void]$s.CoreWebView2.ExecuteScriptAsync($script:ChatJs)
                } else {
                    (C 'AiStatus').Text = 'LINK ERROR // ' + $e.WebErrorStatus
                }
            } catch {}
        })
        $wv.Add_CoreWebView2InitializationCompleted({
            param($s, $e)
            try {
                if ($e.IsSuccess) {
                    try { $s.CoreWebView2.Profile.PreferredColorScheme = [Microsoft.Web.WebView2.Core.CoreWebView2PreferredColorScheme]::Dark } catch {}
                    Write-NCLog 'DeepSeek chat ready'
                } else {
                    (C 'AiStatus').Text = 'INIT FAILED // ' + $e.InitializationException.Message
                }
            } catch {}
        })

        $script:AiWebView = $wv
        $g1 = $(if ($script:Lang -eq 'ru') { 'СВЯЗЬ УСТАНОВЛЕНА // ЯДРО DEEPSEEK' } else { 'LINK ESTABLISHED // DEEPSEEK WEB CORE' })
        $g2 = $(if ($script:Lang -eq 'ru') { 'Введите сообщение — ответ придёт прямо в чат. PAGE нужен только для входа в аккаунт.' } else { 'Type a message - the answer comes straight to the chat. PAGE is only for signing in.' })
        [void](Add-ChatMessage $g1 $false)
        [void](Add-ChatMessage $g2 $false)
        $target = 'https://chat.deepseek.com/'
        if (-not [string]::IsNullOrWhiteSpace($env:NIGHTCITY_AI_URL)) { $target = $env:NIGHTCITY_AI_URL }
        $wv.Source = [uri]$target
        Write-NCLog 'DeepSeek chat opened'
    } catch {
        (C 'AiStatus').Text = 'DEEPSEEK LINK FAILED // ' + $_.Exception.Message
        Write-NCLog "DeepSeek link failed: $($_.Exception.Message)"
    }
}

$script:ChatTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ChatTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:ChatTimer.Add_Tick({
    if (-not $script:AiWebView -or -not $script:AiWebView.CoreWebView2) { return }
    if ($script:ChatAwaiting -and $script:ChatSentAt -and ((Get-Date) - $script:ChatSentAt).TotalSeconds -gt 20) {
        (C 'AiStatus').Text = 'NO RESPONSE // CHECK LOGIN'
    }
    if ($script:ChatTask -and -not $script:ChatTask.IsCompleted) { return }
    if ($script:ChatTask) {
        $raw = $null
        try { $raw = $script:ChatTask.Result } catch {}
        $script:ChatTask = $null
        if ($raw) {
            try {
                $inner = ConvertFrom-Json $raw
                if ($inner -is [string]) { $events = ConvertFrom-Json $inner } else { $events = $inner }
                foreach ($ev in @($events)) {
                    if ($ev.evt -eq 'assistant' -and $ev.text) {
                        if ($script:ChatAwaiting -or -not $script:ChatAssistantBlock) {
                            $script:ChatAssistantBlock = Add-ChatMessage $ev.text $false
                            $script:ChatAwaiting = $false
                        } else {
                            $script:ChatAssistantBlock.Text = $ev.text
                        }
                        (C 'ChatScroll').ScrollToEnd()
                        (C 'AiStatus').Text = 'LINK ACTIVE // DEEPSEEK'
                    }
                }
            } catch {}
        }
    }
    try {
        if ($script:ChatAwaiting) {
            [void]$script:AiWebView.CoreWebView2.ExecuteScriptAsync('window.dispatchEvent(new Event("focus"));document.body.offsetHeight;')
        }
        $script:ChatTask = $script:AiWebView.CoreWebView2.ExecuteScriptAsync('JSON.stringify(window.__nc ? window.__nc.poll() : [])')
    } catch {}
})

# ============================================================
#  LOCALIZATION + WEATHER
# ============================================================
$script:Lang = 'ru'
$script:LangReady = $false
$script:Tr = [ordered]@{
    'NETRUNNER ENVIRONMENT // 2077' = 'ОКРУЖЕНИЕ НЕТРАННЕРА // 2077'
    'SYSTEM ONLINE // SECURE CONNECTION' = 'СИСТЕМА ОНЛАЙН // ЗАЩИЩЕННОЕ СОЕДИНЕНИЕ'
    '// MAINFRAME' = '// МЕЙНФРЕЙМ'
    'NIGHT CITY // OVERVIEW' = 'NIGHT CITY // ОБЗОР'
    'WELCOME BACK, NETRUNNER' = 'С ВОЗВРАЩЕНИЕМ, НЕТРАННЕР'
    'Your system. Your rules. Stay connected.' = 'Твоя система. Твои правила. Оставайся на связи.'
    'QUICK DEPLOY' = 'БЫСТРЫЙ ЗАПУСК'
    'ACTIVE MODULES' = 'АКТИВНЫЕ МОДУЛИ'
    'LOCAL SYSTEM' = 'ЛОКАЛЬНАЯ СИСТЕМА'
    'Windows shell bridge active' = 'Мост оболочки Windows активен'
    'POWER SOURCE' = 'ПИТАНИЕ'
    'OPERATIONAL' = 'РАБОТАЕТ'
    'ON BATTERY' = 'ОТ БАТАРЕИ'
    'AC / CHARGING' = 'СЕТЬ / ЗАРЯДКА'
    'CHARGING' = 'ЗАРЯДКА'
    'Time left' = 'Осталось'
    'Battery' = 'Батарея'
    'AC POWER' = 'СЕТЬ 220В'
    'Plugged in' = 'Подключено'
    'BROWSER ENGINE' = 'ДВИЖОК БРАУЗЕРА'
    'Embedded net access' = 'Встроенный доступ в сеть'
    'NET LINK' = 'СЕТЬ'
    'Local network state' = 'Состояние сети'
    'TERMINAL FEED' = 'ЛЕНТА ТЕРМИНАЛА'
    'boot sequence complete' = 'загрузка завершена'
    'shell bridge mounted' = 'мост оболочки смонтирован'
    'awaiting operator input_' = 'ожидание ввода оператора_'
    'NETWORK STATUS' = 'СОСТОЯНИЕ СЕТИ'
    'CHECKING ...' = 'ПРОВЕРКА ...'
    'IP: unavailable' = 'IP: нет данных'
    'Desktop mode (no battery)' = 'Режим ПК (без батареи)'
    'Desktop mode' = 'Режим ПК'
    'SHELL // STANDBY' = 'ОБОЛОЧКА // ОЖИДАНИЕ'
    'SHELL // ACTIVE' = 'ОБОЛОЧКА // АКТИВНА'
    'F11 fullscreen // Ctrl+Shift+Q quit' = 'F11 полный экран // Ctrl+Shift+Q выход'
    'RETURN TO WINDOWS' = 'ВЕРНУТЬСЯ В WINDOWS'
    'APPLICATIONS // DEPLOY' = 'ПРИЛОЖЕНИЯ // ЗАПУСК'
    'NIGHT CITY // FILE SYSTEM' = 'NIGHT CITY // ФАЙЛЫ'
    'Local storage access. Double-click folders to enter.' = 'Доступ к дискам. Двойной клик — войти в папку.'
    'NET // BROWSER' = 'СЕТЬ // БРАУЗЕР'
    'Embedded net access. Local start page loads offline.' = 'Встроенный браузер. Стартовая страница работает офлайн.'
    'NETWORK // DIAGNOSTICS' = 'СЕТЬ // ДИАГНОСТИКА'
    'Interfaces, addresses and link state.' = 'Интерфейсы, адреса и состояние связи.'
    'PING 8.8.8.8' = 'ПИНГ 8.8.8.8'
    'SYSTEM // CORE' = 'СИСТЕМА // ЯДРО'
    'Hardware, OS and runtime information.' = 'Железо, ОС и среда выполнения.'
    'SYSTEM // SETTINGS' = 'СИСТЕМА // НАСТРОЙКИ'
    'Shell, startup and diagnostics.' = 'Оболочка, автозапуск и диагностика.'
    'SHELL CONTROL' = 'УПРАВЛЕНИЕ ОБОЛОЧКОЙ'
    'AUTOSTART' = 'АВТОЗАПУСК'
    'TOPMOST' = 'ПОВЕРХ ВСЕХ'
    'START EXPLORER' = 'ЗАПУСТИТЬ EXPLORER'
    'RESTART SHELL' = 'ПЕРЕЗАПУСК ОБОЛОЧКИ'
    'DESKTOP' = 'РАБОЧИЙ СТОЛ'
    'NIGHT CITY FOLDER' = 'ПАПКА NIGHT CITY'
    'OPEN LOG' = 'ОТКРЫТЬ ЛОГ'
    'DATA FOLDER' = 'ПАПКА ДАННЫХ'
    'PATHS' = 'ПУТИ'
    'DIAGNOSTICS' = 'ДИАГНОСТИКА'
    'NEURAL LINK // DEEPSEEK' = 'НЕЙРОСВЯЗЬ // DEEPSEEK'
    'Cyberpunk chat terminal. Powered by the signed-in DeepSeek page.' = 'Терминал в стиле Cyberpunk. Работает через страницу DeepSeek.'
    'DEEPSEEK UPLINK // NC-CHAT' = 'КАНАЛ DEEPSEEK // NC-ЧАТ'
    'LINK ESTABLISHED // DEEPSEEK WEB CORE' = 'СВЯЗЬ УСТАНОВЛЕНА // ЯДРО DEEPSEEK'
    'Type a message. If there is no reply - press PAGE, sign in to DeepSeek, then press CHAT.' = 'Введите сообщение. Если ответа нет — откройте СТРАНИЦУ, войдите в DeepSeek, затем вернитесь в ЧАТ.'
    'DETACH TO DESKTOP' = 'ОТКРЕПИТЬ'
    'CLOSE PROGRAM' = 'ЗАКРЫТЬ'
    'NO PROGRAM' = 'НЕТ ПРОГРАММЫ'
    'EXIT SHELL' = 'ВЫХОД'
    'FULLSCREEN (F11)' = 'ПОЛНЫЙ ЭКРАН (F11)'
    'OPEN IN BROWSER' = 'ОТКРЫТЬ В БРАУЗЕРЕ'
    'OPEN IN DEFAULT BROWSER' = 'ОТКРЫТЬ В БРАУЗЕРЕ'
    'SHOW PAGE / CHAT' = 'СТРАНИЦА / ЧАТ'
    'RELOAD' = 'ОБНОВИТЬ'
    'REFRESH' = 'ОБНОВИТЬ'
    'BACK' = 'НАЗАД'
    'FORWARD' = 'ВПЕРЁД'
    'HOME' = 'ДОМОЙ'
    'OVERVIEW' = 'ОБЗОР'
    'APPLICATIONS' = 'ПРИЛОЖЕНИЯ'
    'FILE MANAGER' = 'ПРОВОДНИК'
    'BROWSER' = 'БРАУЗЕР'
    'NEURAL LINK' = 'НЕЙРОСВЯЗЬ'
    'NETWORK' = 'СЕТЬ'
    'SYSTEM' = 'СИСТЕМА'
    'SETTINGS' = 'НАСТРОЙКИ'
    'SYSTEM STATUS' = 'СОСТОЯНИЕ СИСТЕМЫ'
    'TASK MANAGER' = 'ДИСПЕТЧЕР ЗАДАЧ'
    'TERMINAL' = 'ТЕРМИНАЛ'
    'POWER' = 'ПИТАНИЕ'
    'MODE' = 'РЕЖИМ'
    'DASHBOARD' = 'ОБЗОР'
    'OBJECTS' = 'ОБЪЕКТОВ'
    'ACCESS DENIED' = 'ДОСТУП ЗАПРЕЩЁН'
    'PATH NOT FOUND' = 'ПУТЬ НЕ НАЙДЕН'
    'LAUNCH FAILED' = 'ОШИБКА ЗАПУСКА'
    'NAVIGATION FAILED' = 'ОШИБКА ПЕРЕХОДА'
    'NO ACTIVE ADDRESS' = 'НЕТ АКТИВНОГО АДРЕСА'
    'CONNECTED' = 'ПОДКЛЮЧЕНО'
    'OFFLINE' = 'ОФЛАЙН'
    'ONLINE' = 'ОНЛАЙН'
    'CHROMIUM // READY' = 'CHROMIUM // ГОТОВ'
    'NO RESPONSE // CHECK LOGIN' = 'НЕТ ОТВЕТА // ПРОВЕРЬТЕ ВХОД'
    'STREAMING VIA PAGE ...' = 'ПОТОК ЧЕРЕЗ СТРАНИЦУ ...'
    'LINK OFFLINE' = 'СВЯЗЬ ОФЛАЙН'
    'TRANSMIT ...' = 'ПЕРЕДАЧА ...'
    'LINK ACTIVE // DEEPSEEK' = 'СВЯЗЬ АКТИВНА // DEEPSEEK'
    'ONLINE // DEEPSEEK CHAT' = 'ОНЛАЙН // ЧАТ DEEPSEEK'
    'LINK READY // DEEPSEEK WEB' = 'СВЯЗЬ ГОТОВА // DEEPSEEK'
    'LINK ERROR' = 'ОШИБКА СВЯЗИ'
    'WEATHER // VLADIVOSTOK' = 'ПОГОДА // ВЛАДИВОСТОК'
    'N/A (no sensor)' = 'Н/Д (нет датчика)'
    'SHELL' = 'ОБОЛОЧКА'
    'WINDOWED' = 'ОКНО'
    'TASKS' = 'ЗАДАЧИ'
    'SECURITY' = 'БЕЗОПАСНОСТЬ'
    'NOTIFICATIONS' = 'УВЕДОМЛЕНИЯ'
    'TASK MANAGER // PROCESSES' = 'ДИСПЕТЧЕР ЗАДАЧ // ПРОЦЕССЫ'
    'Live process list. Select a row and end the task.' = 'Список процессов. Выберите строку и снимите задачу.'
    'PROCESS' = 'ПРОЦЕСС'
    'RAM MB' = 'ПАМЯТЬ МБ'
    'THREADS' = 'ПОТОКИ'
    'END TASK' = 'СНЯТЬ ЗАДАЧУ'
    'SECURITY CENTER' = 'ЦЕНТР БЕЗОПАСНОСТИ'
    'Defender, firewall, UAC and boot protection.' = 'Defender, брандмауэр, UAC и защита загрузки.'
    'NOTIFICATION CENTER' = 'ЦЕНТР УВЕДОМЛЕНИЙ'
    'Shell events and system notices.' = 'События оболочки и системные уведомления.'
    'CLEAR ALL' = 'ОЧИСТИТЬ ВСЁ'
    'NO NOTIFICATIONS' = 'НЕТ УВЕДОМЛЕНИЙ'
    'SYSTEM CONTROL' = 'УПРАВЛЕНИЕ СИСТЕМОЙ'
    'CONTROL PANEL' = 'ПАНЕЛЬ УПРАВЛЕНИЯ'
    'DEVICE MANAGER' = 'ДИСПЕТЧЕР УСТРОЙСТВ'
    'SERVICES' = 'СЛУЖБЫ'
    'EVENT VIEWER' = 'ПРОСМОТР СОБЫТИЙ'
    'WINDOWS UPDATE' = 'ОБНОВЛЕНИЕ WINDOWS'
    'POWER OPTIONS' = 'ЭЛЕКТРОПИТАНИЕ'
    'STORAGE' = 'ХРАНИЛИЩЕ'
    'Windows tools and shell diagnostics.' = 'Инструменты Windows и диагностика оболочки.'
    'SYSTEM NOTICE' = 'СИСТЕМНОЕ УВЕДОМЛЕНИЕ'
    'NO DATA' = 'НЕТ ДАННЫХ'
    'ENABLED' = 'ВКЛЮЧЁН'
    'DISABLED' = 'ОТКЛЮЧЁН'
    'RUNNING' = 'ЗАПУЩЕНО'
}
$script:TrPairsRu = @($script:Tr.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending | ForEach-Object { , @($_.Key, $_.Value) })
$script:TrPairsEn = @($script:Tr.GetEnumerator() | Sort-Object { $_.Value.Length } -Descending | ForEach-Object { , @($_.Value, $_.Key) })

function T {
    param([string]$Text)
    if ($script:Lang -eq 'ru' -and $Text -and $script:Tr.Contains($Text)) { return $script:Tr[$Text] }
    return $Text
}

function Translate-Text {
    param([string]$Text, $Pairs)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    foreach ($p in $Pairs) {
        if ($Text.Contains($p[0])) { $Text = $Text.Replace($p[0], $p[1]) }
    }
    return $Text
}

$script:TrSkip = @('ChatList', 'FileGrid', 'AiOutput', 'ChatInput', 'AiInput', 'BrowserAddress', 'PathBox', 'AiSurface', 'AiPageHost', 'AppSurface')

function Translate-Node {
    param($Node, $Pairs)
    if ($null -eq $Node) { return }
    if ($Node -is [System.Windows.FrameworkElement] -and $script:TrSkip -contains $Node.Name) { return }

    if ($Node -is [System.Windows.Controls.TextBlock]) {
        $Node.Text = Translate-Text $Node.Text $Pairs
    } elseif ($Node -is [System.Windows.Controls.Button]) {
        if ($Node.Content -is [string]) { $Node.Content = Translate-Text $Node.Content $Pairs }
        if ($Node.ToolTip -is [string]) { $Node.ToolTip = Translate-Text $Node.ToolTip $Pairs }
    } elseif ($Node -is [System.Windows.Window]) {
        $Node.Title = Translate-Text $Node.Title $Pairs
    }

    $dep = $Node -as [System.Windows.DependencyObject]
    if ($dep) {
        foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($dep)) {
            Translate-Node $child $Pairs
        }
    }
}

function Apply-Language {
    param([string]$Lang)
    $script:Lang = $Lang
    $pairs = $(if ($Lang -eq 'ru') { $script:TrPairsRu } else { $script:TrPairsEn })
    Translate-Node $Window $pairs
    $script:LangReady = $false
    try { (C 'LangSlider').Value = $(if ($Lang -eq 'ru') { 1 } else { 0 }) } catch {}
    $script:LangReady = $true
    try { Update-Weather } catch {}
    try { Update-SettingsView } catch {}
    try {
        if (-not (Test-Path $script:DesktopKey)) { New-Item -Path $script:DesktopKey -Force | Out-Null }
        Set-ItemProperty -Path $script:DesktopKey -Name 'Language' -Value $Lang -Type String
    } catch {}
}

function Get-WeatherDesc {
    param([int]$Code, [string]$Lang)
    $ru = $Lang -eq 'ru'
    if ($Code -eq 0) { return $(if ($ru) { 'Ясно' } else { 'Clear' }) }
    if ($Code -le 2) { return $(if ($ru) { 'Малооблачно' } else { 'Mostly clear' }) }
    if ($Code -eq 3) { return $(if ($ru) { 'Облачно' } else { 'Overcast' }) }
    if ($Code -eq 45 -or $Code -eq 48) { return $(if ($ru) { 'Туман' } else { 'Fog' }) }
    if ($Code -ge 51 -and $Code -le 57) { return $(if ($ru) { 'Морось' } else { 'Drizzle' }) }
    if ($Code -ge 61 -and $Code -le 67) { return $(if ($ru) { 'Дождь' } else { 'Rain' }) }
    if ($Code -ge 71 -and $Code -le 77) { return $(if ($ru) { 'Снег' } else { 'Snow' }) }
    if ($Code -ge 80 -and $Code -le 82) { return $(if ($ru) { 'Ливень' } else { 'Showers' }) }
    if ($Code -ge 85 -and $Code -le 86) { return $(if ($ru) { 'Снегопад' } else { 'Snow showers' }) }
    if ($Code -ge 95) { return $(if ($ru) { 'Гроза' } else { 'Thunderstorm' }) }
    return $(if ($ru) { 'Н/Д' } else { 'N/A' })
}

function Update-Weather {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $u = 'https://api.open-meteo.com/v1/forecast?latitude=43.1155&longitude=131.8855&current=temperature_2m,weather_code,wind_speed_10m&timezone=Asia%2FVladivostok'
        $w = Invoke-RestMethod -Uri $u -TimeoutSec 15
        $temp = [math]::Round([double]$w.current.temperature_2m)
        $wind = [math]::Round([double]$w.current.wind_speed_10m, 1)
        $desc = Get-WeatherDesc ([int]$w.current.weather_code) $script:Lang
        (C 'WeatherTitle').Text = $(if ($script:Lang -eq 'ru') { 'ПОГОДА // ВЛАДИВОСТОК' } else { 'WEATHER // VLADIVOSTOK' })
        (C 'WeatherTemp').Text = "$temp°C"
        (C 'WeatherCond').Text = $desc
        (C 'WeatherWind').Text = $(if ($script:Lang -eq 'ru') { "ВЕТЕР $wind м/с" } else { "WIND $wind m/s" })
    } catch {
        (C 'WeatherCond').Text = $(if ($script:Lang -eq 'ru') { 'НЕТ ДАННЫХ' } else { 'NO DATA' })
        (C 'WeatherWind').Text = ''
    }
}

$script:WeatherTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:WeatherTimer.Interval = [TimeSpan]::FromMinutes(15)
$script:WeatherTimer.Add_Tick({ Update-Weather })

# ============================================================
#  NOTIFICATIONS / TASKS / SECURITY / SYSTEM CONTROL
# ============================================================
$script:Notifications = New-Object System.Collections.ArrayList
$script:Unread = 0

$script:ToastTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ToastTimer.Interval = [TimeSpan]::FromSeconds(4)
$script:ToastTimer.Add_Tick({
    $script:ToastTimer.Stop()
    try {
        $panel = C 'ToastPanel'
        $a = New-Object System.Windows.Media.Animation.DoubleAnimation(1, 0, [TimeSpan]::FromMilliseconds(220))
        $panel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $a)
    } catch {}
})

function Show-Toast {
    param([string]$Text)
    try {
        (C 'ToastText').Text = $Text
        $panel = C 'ToastPanel'
        $panel.Opacity = 0
        $shift = C 'ToastShift'
        $shift.Y = 12
        $a1 = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(200))
        $panel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $a1)
        $a2 = New-Object System.Windows.Media.Animation.DoubleAnimation(12, 0, [TimeSpan]::FromMilliseconds(220))
        $shift.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $a2)
        $script:ToastTimer.Stop()
        $script:ToastTimer.Start()
    } catch {}
}

function Update-NotifyBadge {
    try {
        if ($script:Unread -gt 0) {
            (C 'NotifyBadgeText').Text = [string]$script:Unread
            (C 'NotifyBadge').Visibility = 'Visible'
        } else {
            (C 'NotifyBadge').Visibility = 'Collapsed'
        }
    } catch {}
}

function Notify {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    [void]$script:Notifications.Insert(0, @{ Time = (Get-Date); Text = $Text })
    while ($script:Notifications.Count -gt 50) { $script:Notifications.RemoveAt($script:Notifications.Count - 1) }
    $script:Unread++
    Update-NotifyBadge
    Show-Toast $Text
    try { if ((C 'NotificationsView').Visibility -eq 'Visible') { Update-Notifications } } catch {}
}

function Update-Notifications {
    $panel = C 'NotifList'
    if (-not $panel) { return }
    $panel.Children.Clear()
    (C 'NotifCount').Text = [string]$script:Notifications.Count
    if ($script:Notifications.Count -eq 0) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = $(if ($script:Lang -eq 'ru') { 'НЕТ УВЕДОМЛЕНИЙ' } else { 'NO NOTIFICATIONS' })
        $empty.Foreground = '#FF7A5A60'
        $empty.FontSize = 12
        [void]$panel.Children.Add($empty)
        return
    }
    foreach ($n in $script:Notifications) {
        $b = New-Object System.Windows.Controls.Border
        $b.Background = '#CC0A0609'
        $b.BorderBrush = '#FF4A0F16'
        $b.BorderThickness = '1'
        $b.Padding = '10,8'
        $b.Margin = '0,0,0,6'
        $sp = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = $n.Time.ToString('HH:mm:ss')
        $t1.Foreground = '#FFFF3545'
        $t1.FontSize = 9
        $t1.FontFamily = 'Consolas'
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = $n.Text
        $t2.Foreground = '#FFE9DADD'
        $t2.FontSize = 11
        $t2.TextWrapping = 'Wrap'
        $t2.Margin = '0,3,0,0'
        [void]$sp.Children.Add($t1)
        [void]$sp.Children.Add($t2)
        $b.Child = $sp
        [void]$panel.Children.Add($b)
    }
}

function Update-TaskList {
    try {
        $rows = @(Get-Process -ErrorAction Stop | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 80 | ForEach-Object {
                [PSCustomObject]@{
                    Name    = $_.ProcessName
                    Pid     = $_.Id
                    Ram     = [int][math]::Round($_.WorkingSet64 / 1MB)
                    Threads = $_.Threads.Count
                }
            })
        (C 'TaskGrid').ItemsSource = $rows
        try {
            $g = C 'TaskGrid'
            $g.Columns[0].Header = T 'PROCESS'
            $g.Columns[1].Header = 'PID'
            $g.Columns[2].Header = T 'RAM MB'
            $g.Columns[3].Header = T 'THREADS'
        } catch {}
        $total = [int]([math]::Round((Get-Process | Measure-Object WorkingSet64 -Sum).Sum / 1MB))
        (C 'TaskSummary').Text = "$($rows.Count) / $total MB"
        (C 'TaskStatus').Text = $(if ($script:Lang -eq 'ru') { 'ОБНОВЛЕНО ' + (Get-Date).ToString('HH:mm:ss') } else { 'UPDATED ' + (Get-Date).ToString('HH:mm:ss') })
    } catch {
        (C 'TaskStatus').Text = 'ERROR // ' + $_.Exception.Message
    }
}

function Add-SecurityCard {
    param([string]$Title, [string]$Value, [string]$State)
    $color = $(switch ($State) {
            'ok' { '#FF39FF88' }
            'warn' { '#FFFFB020' }
            'bad' { '#FFFF2638' }
            default { '#FF7A5A60' }
        })
    $b = New-Object System.Windows.Controls.Border
    $b.Background = '#FF0B0608'
    $b.BorderBrush = '#FF79121F'
    $b.BorderThickness = '1'
    $b.Padding = '12,10'
    $b.Margin = '0,0,0,6'
    $g = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $g.ColumnDefinitions.Add($c1)
    $g.ColumnDefinitions.Add($c2)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Title
    $t.Foreground = '#FFB18B90'
    $t.FontSize = 11
    $v = New-Object System.Windows.Controls.TextBlock
    $v.Text = $Value
    $v.Foreground = $color
    $v.FontSize = 12
    $v.FontWeight = 'Bold'
    $v.Margin = '0,2,0,0'
    $sp = New-Object System.Windows.Controls.StackPanel
    [void]$sp.Children.Add($t)
    [void]$sp.Children.Add($v)
    [System.Windows.Controls.Grid]::SetColumn($sp, 0)
    [void]$g.Children.Add($sp)
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 8
    $dot.Height = 8
    $dot.Fill = $color
    $dot.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($dot, 1)
    [void]$g.Children.Add($dot)
    $b.Child = $g
    [void](C 'SecurityPanel').Children.Add($b)
}

function Update-Security {
    $sp = C 'SecurityPanel'
    if (-not $sp) { return }
    $sp.Background = '#FF070508'
    $sp.Children.Clear()
    $nd = $(if ($script:Lang -eq 'ru') { 'НЕТ ДАННЫХ' } else { 'NO DATA' })
    $on = $(if ($script:Lang -eq 'ru') { 'ВКЛЮЧЁН' } else { 'ENABLED' })
    $off = $(if ($script:Lang -eq 'ru') { 'ОТКЛЮЧЁН' } else { 'DISABLED' })

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        Add-SecurityCard 'DEFENDER // REAL-TIME' ($(if ($mp.RealTimeProtectionEnabled) { $on } else { $off })) $(if ($mp.RealTimeProtectionEnabled) { 'ok' } else { 'bad' })
        Add-SecurityCard 'DEFENDER // ANTIVIRUS' ($(if ($mp.AntivirusEnabled) { $on } else { $off })) $(if ($mp.AntivirusEnabled) { 'ok' } else { 'bad' })
    } catch {
        Add-SecurityCard 'DEFENDER' $nd 'unknown'
    }

    try {
        $fw = @(Get-NetFirewallProfile -ErrorAction Stop)
        $enabled = @($fw | Where-Object { $_.Enabled }).Count
        $state = $(if ($enabled -eq $fw.Count) { 'ok' } elseif ($enabled -gt 0) { 'warn' } else { 'bad' })
        Add-SecurityCard 'FIREWALL' ("$enabled / $($fw.Count)") $state
    } catch {
        Add-SecurityCard 'FIREWALL' $nd 'unknown'
    }

    try {
        $uac = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction Stop).EnableLUA
        Add-SecurityCard 'UAC' $(if ($uac -eq 1) { $on } else { $off }) $(if ($uac -eq 1) { 'ok' } else { 'bad' })
    } catch {
        Add-SecurityCard 'UAC' $nd 'unknown'
    }

    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        Add-SecurityCard 'SECURE BOOT' $(if ($sb) { $on } else { $off }) $(if ($sb) { 'ok' } else { 'warn' })
    } catch {
        Add-SecurityCard 'SECURE BOOT' $nd 'unknown'
    }

    try {
        $bl = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        $pct = $bl.ProtectionStatus
        Add-SecurityCard 'BITLOCKER // C:' ([string]$pct) $(if ($pct -eq 'On') { 'ok' } else { 'warn' })
    } catch {
        Add-SecurityCard 'BITLOCKER // C:' $nd 'unknown'
    }
}

function Update-SystemControl {
    $wrap = C 'SysControlButtons'
    $wrap.Children.Clear()
    $tools = @(
        @{ Label = 'TASK MANAGER'; Target = 'taskmgr.exe'; Args = '' },
        @{ Label = 'CONTROL PANEL'; Target = 'control.exe'; Args = '' },
        @{ Label = 'DEVICE MANAGER'; Target = 'mmc.exe'; Args = "$env:WINDIR\System32\devmgmt.msc" },
        @{ Label = 'SERVICES'; Target = 'mmc.exe'; Args = "$env:WINDIR\System32\services.msc" },
        @{ Label = 'EVENT VIEWER'; Target = 'mmc.exe'; Args = "$env:WINDIR\System32\eventvwr.msc" },
        @{ Label = 'WINDOWS UPDATE'; Target = 'ms-settings:windowsupdate'; Args = '' },
        @{ Label = 'POWER OPTIONS'; Target = 'control.exe'; Args = 'powercfg.cpl' },
        @{ Label = 'STORAGE'; Target = 'ms-settings:storagesense'; Args = '' }
    )
    foreach ($t in $tools) {
        $b = New-Object System.Windows.Controls.Button
        $b.Style = $Window.Resources['Action']
        $b.Content = $t.Label
        $b.Width = 170
        $b.Tag = $t
        $b.Add_Click({
            param($sender, $e)
            $x = $sender.Tag
            Open-Target $x.Target $x.Args
        })
        [void]$wrap.Children.Add($b)
    }
    $os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'N/A' }
    $ip = Get-PrimaryIPv4
    $lines = @(
        ('NIGHT CITY OS  ' + $script:Version),
        ('OS        ' + $os),
        ('ENGINE    ' + $(if ($script:WebView2Available) { 'Chromium / WebView2' } else { 'MSHTML' })),
        ('IP        ' + $(if ($ip) { $ip } else { 'N/A' })),
        ('UPTIME    ' + [int]([Environment]::TickCount64 / 3600000) + 'h'),
        ('SHELL     ' + $(if ($Shell) { 'ACTIVE' } else { 'WINDOWED' })),
        ('DESKTOP   ' + $(if (Test-DesktopMode) { 'OURS' } else { 'STOCK' }))
    )
    (C 'SysControlInfo').Text = ($lines -join [Environment]::NewLine)
}

# ============================================================
#  EVENT HANDLERS
# ============================================================
(C 'NavOverview').Add_Click({ Show-View 'DashboardView' })
(C 'NavApps').Add_Click({ Show-View 'AppsView' })
(C 'NavFiles').Add_Click({ Show-View 'FilesView' })
(C 'NavBrowser').Add_Click({ Show-View 'BrowserView' })
(C 'NavAI').Add_Click({ Show-View 'AIView' })
(C 'AiReload').Add_Click({
    try { if ($script:AiWebView -and $script:AiWebView.CoreWebView2) { $script:AiWebView.CoreWebView2.Reload() } } catch {}
})
(C 'AiExternal').Add_Click({ Start-Process 'https://chat.deepseek.com/' })
(C 'AiChatToggle').Add_Click({ Set-ChatMode (-not $script:ChatMode) })
(C 'ChatSend').Add_Click({ Send-Chat (C 'ChatInput').Text })
(C 'ChatInput').Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) { Send-Chat $sender.Text; $e.Handled = $true }
})

(C 'NavNetwork').Add_Click({ Show-View 'NetworkView' })
(C 'NavSystem').Add_Click({ Show-View 'SystemView' })
(C 'NavSettings').Add_Click({ Show-View 'SettingsView' })
(C 'NavTasks').Add_Click({ Show-View 'TasksView' })
(C 'NavSecurity').Add_Click({ Show-View 'SecurityView' })
(C 'NavNotify').Add_Click({ Show-View 'NotificationsView' })
(C 'NavTerminal').Add_Click({ Start-EmbeddedApp 'powershell.exe' '' })
(C 'NotifyBtn').Add_Click({ Show-View 'NotificationsView' })
(C 'TaskRefresh').Add_Click({ Update-TaskList })
(C 'TaskKill').Add_Click({
    $sel = $null
    try { $sel = (C 'TaskGrid').SelectedItem } catch {}
    if ($sel) {
        try { Stop-Process -Id $sel.Pid -Force -ErrorAction Stop; Notify ('KILLED: ' + $sel.Name) } catch { Notify ('KILL FAILED: ' + $sel.Name) }
        Update-TaskList
    }
})
(C 'SecurityRefresh').Add_Click({ Update-Security })
(C 'NotifClear').Add_Click({ $script:Notifications.Clear(); $script:Unread = 0; Update-NotifyBadge; Update-Notifications })

(C 'OpenFileManager').Add_Click({ Show-View 'FilesView' })
(C 'OpenBrowser').Add_Click({ Show-View 'BrowserView' })
(C 'OpenTaskMgr').Add_Click({ Open-Target 'taskmgr.exe' '' })
(C 'OpenTerminal').Add_Click({ Open-Target 'powershell.exe' '' })
(C 'StartButton').Add_Click({ Show-View 'AppsView' })
(C 'AppDetach').Add_Click({ Detach-EmbeddedApp; Show-View 'AppsView' })
(C 'AppClose').Add_Click({ Close-EmbeddedApp; Show-View 'AppsView' })

# files
(C 'BtnBack').Add_Click({
    if ($script:History.Count -gt 0) { Load-Directory $script:History.Pop() }
})
(C 'BtnUp').Add_Click({
    try {
        $parent = [System.IO.Directory]::GetParent($script:CurrentPath)
        if ($parent) { Navigate-Files $parent.FullName }
    } catch {}
})
(C 'BtnRefresh').Add_Click({ Load-Directory $script:CurrentPath })
(C 'BtnGo').Add_Click({ Navigate-Files (C 'PathBox').Text })
(C 'PathBox').Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) { Navigate-Files $sender.Text }
})
(C 'FileGrid').Add_MouseDoubleClick({
    param($sender, $e)
    $sel = $sender.SelectedItem
    if (-not $sel) { return }
    if ($sel.IsDir) { Navigate-Files $sel.FullPath }
    else { try { Start-Process -FilePath $sel.FullPath } catch {} }
})

# browser
(C 'BrowserGo').Add_Click({ Navigate-Browser (C 'BrowserAddress').Text })
(C 'BrowserAddress').Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) { Navigate-Browser $sender.Text }
})
(C 'BrowserAddress').Add_GotFocus({ param($sender, $e) $sender.SelectAll() })
(C 'BrowserBack').Add_Click({
    if ($script:WebView -and $script:WebView.CoreWebView2) {
        if ($script:WebView.CoreWebView2.CanGoBack) { $script:WebView.CoreWebView2.GoBack() }
    } elseif ($script:WebBrowser -and $script:WebBrowser.CanGoBack) {
        $script:WebBrowser.GoBack()
    }
})
(C 'BrowserForward').Add_Click({
    if ($script:WebView -and $script:WebView.CoreWebView2) {
        if ($script:WebView.CoreWebView2.CanGoForward) { $script:WebView.CoreWebView2.GoForward() }
    } elseif ($script:WebBrowser -and $script:WebBrowser.CanGoForward) {
        $script:WebBrowser.GoForward()
    }
})
(C 'BrowserRefresh').Add_Click({
    if ($script:WebView -and $script:WebView.CoreWebView2) { $script:WebView.CoreWebView2.Reload() }
    elseif ($script:WebBrowser) { $script:WebBrowser.Refresh() }
})
(C 'BrowserHome').Add_Click({ Navigate-Browser $script:HomeUrl })
(C 'BrowserFullscreen').Add_Click({
    if ($script:Immersive) { if (-not $script:VideoFullscreen) { Set-Immersive $false } }
    else { Set-Immersive $true }
})
(C 'BrowserExternal').Add_Click({
    try {
        $target = $null
        if ($script:WebView -and $script:WebView.Source) { $target = $script:WebView.Source.AbsoluteUri }
        elseif ($script:WebBrowser -and $script:WebBrowser.Url) { $target = $script:WebBrowser.Url.AbsoluteUri }
        if ($target) { Start-Process $target }
    } catch {}
})

# network / system
(C 'NetRefreshBtn').Add_Click({ Update-NetworkView })
(C 'NetPingBtn').Add_Click({
    (C 'NetPingResult').Text = 'PINGING ...'
    try {
        $ok = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction Stop
        if ($ok) { (C 'NetPingResult').Text = [char]0x25CF + ' ONLINE' }
        else { (C 'NetPingResult').Text = 'NO RESPONSE' }
    } catch {
        (C 'NetPingResult').Text = 'PING FAILED'
    }
})
(C 'SysRefreshBtn').Add_Click({ Update-SystemView })

# settings
(C 'AutoStartBtn').Add_Click({
    if (Test-Autostart) { Disable-Autostart } else { [void](Enable-Autostart) }
    Update-SettingsView
})
(C 'TopmostBtn').Add_Click({
    $Window.Topmost = -not $Window.Topmost
    Update-SettingsView
})
(C 'ExplorerBtn').Add_Click({ Open-Target 'explorer.exe' '' })
(C 'LangSlider').Add_ValueChanged({
    param($sender, $e)
    if (-not $script:LangReady) { return }
    Apply-Language $(if ($sender.Value -ge 0.5) { 'ru' } else { 'en' })
})
(C 'DesktopApplyBtn').Add_Click({ Set-DesktopMode $true; Update-SettingsView })
(C 'DesktopModeBtn').Add_Click({
    if (Test-DesktopMode) { Set-DesktopMode $false } else { Set-DesktopMode $true }
    Update-SettingsView
})
(C 'RestartBtn').Add_Click({
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"' + (Join-Path $script:BaseDir 'NightCityShell.ps1') + '"'), '-Shell')
    } catch {}
    $script:ForceClose = $true
    $Window.Close()
})
(C 'OpenFolderBtn').Add_Click({ Open-Target 'explorer.exe' $script:BaseDir })
(C 'OpenLogBtn').Add_Click({ if (Test-Path $script:LogFile) { Open-Target 'notepad.exe' $script:LogFile } })
(C 'OpenDataBtn').Add_Click({ Open-Target 'explorer.exe' $script:DataDir })
(C 'SysControlBtn').Add_Click({ Show-View 'SystemControlView' })

# exit
(C 'ReturnWindows').Add_Click({
    Set-DesktopMode $false
    $script:ForceClose = $true
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    $Window.Close()
})
(C 'PowerBtn').Add_Click({ $Window.Close() })

# ============================================================
#  KEYBOARD / CLOSING
# ============================================================
$script:ForceClose = $false

$Window.Add_Loaded({
    if ($Shell -and (Test-DesktopMode)) {
        try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
        Start-ShellWatchdog
    }
})

$Window.Add_Activated({
    if ($Shell -and -not $script:Embedded) { $Window.Topmost = $true }
})

$Window.Add_PreviewKeyDown({
    param($sender, $e)
    $ctrl = [System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control
    $shift = [System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift
    if ($ctrl -and $shift -and $e.Key -eq [System.Windows.Input.Key]::Q) {
        $script:ForceClose = $true
        $Window.Close()
        return
    }
    if ($e.Key -eq [System.Windows.Input.Key]::Escape -and $script:Immersive -and -not $script:VideoFullscreen) {
        Set-Immersive $false
        $e.Handled = $true
        return
    }
    if ($ctrl -and $e.Key -eq [System.Windows.Input.Key]::L) {
        if ((C 'BrowserView').Visibility -eq 'Visible') { (C 'BrowserAddress').Focus() }
        $e.Handled = $true
        return
    }
    if ($e.Key -eq [System.Windows.Input.Key]::F5) {
        if ((C 'BrowserView').Visibility -eq 'Visible') {
            if ($script:WebView -and $script:WebView.CoreWebView2) { $script:WebView.CoreWebView2.Reload() }
            elseif ($script:WebBrowser) { $script:WebBrowser.Refresh() }
        }
        $e.Handled = $true
    }
})

$Window.Add_Closing({
    param($sender, $e)
    if ($script:ForceClose) { return }
    $r = [System.Windows.MessageBox]::Show($Window, 'Exit NIGHT CITY OS and return to Windows?', 'NIGHT CITY OS',
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($r -ne [System.Windows.MessageBoxResult]::Yes) { $e.Cancel = $true }
    else { $script:ForceClose = $true }
})

$Window.Add_Closed({
    try { $script:ClockTimer.Stop() } catch {}
    try { $script:StatsTimer.Stop() } catch {}
    try { Detach-EmbeddedApp } catch {}
    try { $script:KeyTimer.Stop() } catch {}
    try { $script:WeatherTimer.Stop() } catch {}
    try { $script:AttachTimer.Stop() } catch {}
    try { $script:EmbedTimer.Stop() } catch {}
    try { if ($script:WebView) { $script:WebView.Dispose() } } catch {}
    try { if ($script:WebBrowser) { $script:WebBrowser.Dispose() } } catch {}
    if ($Shell -and -not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        try { Start-Process explorer.exe } catch {}
    }
    Write-NCLog '=== exit ==='
})

# ============================================================
#  SHELL MODE / STARTUP
# ============================================================
if ($Shell) {
    $Window.Topmost = $true
    (C 'ShellState').Text = 'SHELL // ACTIVE'
    Write-NCLog 'shell mode active'
} else {
    (C 'ShellState').Text = 'SHELL // STANDBY'
}

$script:ClockTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ClockTimer.Interval = [TimeSpan]::FromSeconds(1)
$script:ClockTimer.Add_Tick({ Update-Clock })

$script:StatsTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:StatsTimer.Interval = [TimeSpan]::FromSeconds(10)
$script:StatsTimer.Add_Tick({ Update-Stats })

$script:F11Down = $false
$script:KeyTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:KeyTimer.Interval = [TimeSpan]::FromMilliseconds(120)
$script:KeyTimer.Add_Tick({
    try {
        $down = ([NCWin]::GetAsyncKeyState(0x7A) -band 0x8000) -ne 0
        if ($down -and -not $script:F11Down) {
            if ($script:Immersive) {
                if (-not $script:VideoFullscreen) { Set-Immersive $false }
            } else {
                Set-Immersive $true
            }
        }
        $script:F11Down = $down
    } catch {}
})

try {
    $savedLang = (Get-ItemProperty -Path 'HKCU:\Software\NightCityOS' -Name 'Language' -ErrorAction Stop).Language
    if ($savedLang -eq 'en' -or $savedLang -eq 'ru') { $script:Lang = $savedLang }
} catch {}
$script:LangReady = $false
try { (C 'LangSlider').Value = $(if ($script:Lang -eq 'ru') { 1 } else { 0 }) } catch {}
$script:LangReady = $true

Update-Clock
Update-Stats
Update-Weather
Show-View 'DashboardView'
if ($script:Lang -eq 'ru') { Translate-Node $Window $script:TrPairsRu }
Notify $(if ($script:Lang -eq 'ru') { 'СИСТЕМА ГОТОВА // ОБОЛОЧКА ОНЛАЙН' } else { 'SYSTEM READY // SHELL ONLINE' })
$script:ClockTimer.Start()
$script:StatsTimer.Start()
$script:KeyTimer.Start()
$script:WeatherTimer.Start()

# ============================================================
#  SELF-TEST (not used in normal run)
# ============================================================
function Save-WindowShot {
    param([string]$Path)
    try {
        $w = [int]$Window.ActualWidth
        $h = [int]$Window.ActualHeight
        if ($w -le 0 -or $h -le 0) { return $false }
        $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($Window)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [System.IO.File]::Create($Path)
        try { $enc.Save($fs) } finally { $fs.Close() }
        return $true
    } catch {
        Write-NCLog "shot failed: $($_.Exception.Message)"
        return $false
    }
}

function Save-ScreenShot {
    param([string]$Path)
    try {
        Add-Type -AssemblyName System.Drawing
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
        $g.Dispose()
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        return $true
    } catch {
        Write-NCLog "screen shot failed: $($_.Exception.Message)"
        return $false
    }
}

$script:ShotApiReady = $false
function Save-ControlShot {
    param($Control, [string]$Path)
    try {
        if (-not $script:ShotApiReady) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NCShotApi {
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint flags);
}
'@ -ErrorAction Stop
            $script:ShotApiReady = $true
        }
        $w = [int]$Control.Width
        $h = [int]$Control.Height
        if ($w -le 0 -or $h -le 0) { return $false }
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $hdc = $g.GetHdc()
        $ok = [NCShotApi]::PrintWindow($Control.Handle, $hdc, 2)
        $g.ReleaseHdc($hdc)
        $g.Dispose()
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        return $ok
    } catch {
        Write-NCLog "control shot failed: $($_.Exception.Message)"
        return $false
    }
}

if ($SelfTest) {
    $script:TestResults = New-Object System.Collections.ArrayList
    $script:TestStage = 0
    $shotDir = $env:NIGHTCITY_SHOT
    if ([string]::IsNullOrWhiteSpace($shotDir)) { $shotDir = $script:DataDir }

    $Window.WindowStyle = 'None'
    $Window.WindowState = 'Normal'
    $Window.Width = 1280
    $Window.Height = 720
    if ($env:NIGHTCITY_TEST_SIZE -match '^(\d+)x(\d+)$') {
        $Window.Width = [int]$Matches[1]
        $Window.Height = [int]$Matches[2]
    }
    $Window.Left = -4000
    $Window.Top = -4000
    if ($env:NIGHTCITY_VISUAL -eq '1') { $Window.Left = 0; $Window.Top = 0 }
    $Window.ShowInTaskbar = $false

    function Add-TestResult {
        param([string]$Text)
        [void]$script:TestResults.Add($Text)
    }

    $testTimer = New-Object System.Windows.Threading.DispatcherTimer
    $testTimer.Interval = [TimeSpan]::FromSeconds(1)
    $testTimer.Add_Tick({
        $script:TestStage++
        $stage = $script:TestStage

        switch ($stage) {
            2 {
                $script:ClockA = (C 'ClockTop').Text
                $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-dashboard.png')
                Add-TestResult ('SCREENSHOT-DASHBOARD ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
            }
            3 { Show-View 'BrowserView' }
            7 {
                if ($env:NIGHTCITY_BROWSER_URL -and $script:WebView -and $script:WebView.CoreWebView2) {
                    try {
                        $js = '(function(){var v=document.querySelector("video"); if(v){v.muted=true; v.play();} return !!v;})()'
                        $task = $script:WebView.CoreWebView2.ExecuteScriptAsync($js)
                        $deadline = (Get-Date).AddSeconds(6)
                        while (-not $task.IsCompleted -and (Get-Date) -lt $deadline) {
                            $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                            Start-Sleep -Milliseconds 50
                        }
                    } catch {}
                }
            }
            8 {
                $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-browser.png')
                Add-TestResult ('SCREENSHOT-BROWSER ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
                if ($script:WebBrowser) {
                    $ok = Save-ControlShot $script:WebBrowser (Join-Path $shotDir 'shot-web.png')
                    Add-TestResult ('SCREENSHOT-WEB ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
                } else {
                    Add-TestResult 'SCREENSHOT-WEB SKIP (chromium airspace)'
                }
                if ($env:NIGHTCITY_VISUAL -eq '1') {
                    $ok = Save-ScreenShot (Join-Path $shotDir 'shot-screen.png')
                    Add-TestResult ('SCREENSHOT-SCREEN ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
                }
            }
            9 {
                Show-View 'FilesView'
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                Start-Sleep -Milliseconds 200
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-files.png')
                Add-TestResult ('SCREENSHOT-FILES ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
            }
            10 {
                Show-View 'AppsView'
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                Start-Sleep -Milliseconds 200
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-apps.png')
                Add-TestResult ('SCREENSHOT-APPS ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
            }
            11 {
                Show-View 'NetworkView'
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                Start-Sleep -Milliseconds 200
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-network.png')
                Add-TestResult ('SCREENSHOT-NET ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
            }
            12 {
                Show-View 'SystemView'
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                Start-Sleep -Milliseconds 200
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-system.png')
                Add-TestResult ('SCREENSHOT-SYS ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
            }
            13 {
                Show-View 'SettingsView'
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                Start-Sleep -Milliseconds 200
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                $ok = Save-WindowShot (Join-Path $shotDir 'shot-settings.png')
                Add-TestResult ('SCREENSHOT-SET ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
            }
            14 {
                Start-EmbeddedApp 'notepad.exe' ''
            }
            16 {
                $embedded = $false
                try { $embedded = ($null -ne $script:Embedded) } catch {}
                Add-TestResult ('APP-EMBED ' + $(if ($embedded) { 'PASS' } else { 'FAIL' }))
                if ($env:NIGHTCITY_VISUAL -eq '1') {
                    $shotOk = Save-ScreenShot (Join-Path $shotDir 'shot-app.png')
                    Add-TestResult ('SCREENSHOT-APP ' + $(if ($shotOk) { 'PASS' } else { 'FAIL' }))
                }
                Add-TestResult ('APP-TITLE ' + (C 'AppTitle').Text + ' status=' + (C 'AppStatus').Text)
                try { Close-EmbeddedApp } catch {}
                Show-View 'AppsView'
            }
            17 {
                if ($env:NIGHTCITY_TEST_AI -eq '1') {
                    Show-View 'AIView'
                    if ($env:NIGHTCITY_TEST_AI_SEND -eq '1') {
                        $deadline0 = (Get-Date).AddSeconds(25)
                        $bridge = $false
                        while ((Get-Date) -lt $deadline0) {
                            $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                            Start-Sleep -Milliseconds 150
                            if (-not ($script:AiWebView -and $script:AiWebView.CoreWebView2)) { continue }
                            try {
                                $probe = $script:AiWebView.CoreWebView2.ExecuteScriptAsync('window.__nc ? 1 : 0')
                                $deadlineP = (Get-Date).AddSeconds(3)
                                while (-not $probe.IsCompleted -and (Get-Date) -lt $deadlineP) {
                                    $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                                    Start-Sleep -Milliseconds 50
                                }
                                if ($probe.IsCompleted -and $probe.Result -eq '1') { $bridge = $true; break }
                            } catch {}
                        }
                        Send-Chat 'ping'
                    }
                }
            }
            18 {
                if ($env:NIGHTCITY_TEST_AI -eq '1') {
                    $deadline = (Get-Date).AddSeconds(20)
                    while ((Get-Date) -lt $deadline) {
                        $t2 = ''
                        try { $t2 = $script:AiWebView.CoreWebView2.DocumentTitle } catch {}
                        if ($t2 -like '*DeepSeek*') { break }
                        $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                        Start-Sleep -Milliseconds 300
                    }
                }
                if ($env:NIGHTCITY_TEST_AI -eq '1' -and $env:NIGHTCITY_VISUAL -eq '1') {
                    Start-Sleep -Milliseconds 400
                    $shotAi = Save-ScreenShot (Join-Path $shotDir 'shot-ai.png')
                    Add-TestResult ('SCREENSHOT-AI ' + $(if ($shotAi) { 'PASS' } else { 'FAIL' }))
                }
                Set-Immersive $true
                $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                if ($env:NIGHTCITY_VISUAL -eq '1') {
                    $ok = Save-ScreenShot (Join-Path $shotDir 'shot-fullscreen.png')
                    Add-TestResult ('SCREENSHOT-FULLSCREEN ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
                }
                    Add-TestResult ('IMMERSIVE ' + $(if ($script:Immersive) { 'PASS' } else { 'FAIL' }))
                Set-Immersive $false
            }
            19 {
                $testTimer.Stop()
                try {
                    try {
                        Update-TaskList
                        Update-Security
                        Update-Notifications
                        Update-SystemControl
                        Add-TestResult 'NEW-VIEWS PASS'
                    } catch {
                        Add-TestResult ('NEW-VIEWS FAIL ' + $_.Exception.Message)
                    }
                    if ($env:NIGHTCITY_TEST_AI -eq '1') {
                        $deadline = (Get-Date).AddSeconds(20)
                        $aiTitle = ''
                        while ((Get-Date) -lt $deadline) {
                            try { $aiTitle = $script:AiWebView.CoreWebView2.DocumentTitle } catch { $aiTitle = '' }
                            if ($aiTitle -like '*DeepSeek*') { break }
                            $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                            Start-Sleep -Milliseconds 300
                        }
                        Add-TestResult ('AI-PAGE ' + $(if ($aiTitle) { 'PASS' } else { 'FAIL' }) + ' title=' + $aiTitle)
                        try {
                            $dbg = $script:AiWebView.CoreWebView2.ExecuteScriptAsync('window.__nc ? window.__nc.debug() : "no-bridge"')
                            $dd = (Get-Date).AddSeconds(5)
                            while (-not $dbg.IsCompleted -and (Get-Date) -lt $dd) {
                                $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                                Start-Sleep -Milliseconds 50
                            }
                            Add-TestResult ('AI-DOM ' + $dbg.Result)
                        } catch {}
                        if ($env:NIGHTCITY_TEST_AI_SEND -eq '1') {
                            $deadline2 = (Get-Date).AddSeconds(15)
                            while ((Get-Date) -lt $deadline2 -and (C 'ChatList').Children.Count -lt 4) {
                                $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                                Start-Sleep -Milliseconds 300
                            }
                            $bubbles = (C 'ChatList').Children.Count
                            Add-TestResult ('CHAT-REPLY ' + $(if ($bubbles -ge 4) { 'PASS' } else { 'FAIL' }) + ' bubbles=' + $bubbles)
                        }
                    }
                    $browserOk = $false
                    $title = ''
                    $textLen = 0
                    $engine = 'mshtml'
                    if ($script:WebView -and $script:WebView.CoreWebView2) {
                        $engine = 'chromium'
                        try { $title = $script:WebView.CoreWebView2.DocumentTitle } catch {}
                        try { $textLen = $script:WebView.CoreWebView2.Source.Length } catch {}
                        $browserOk = ($title.Length -gt 3)
                    } elseif ($script:WebBrowser -and $script:WebBrowser.Document) {
                        try { $title = $script:WebBrowser.DocumentTitle } catch {}
                        try { $textLen = $script:WebBrowser.Document.Body.InnerText.Length } catch {}
                        $browserOk = ($textLen -gt 40)
                    }
                    Add-TestResult ('CLOCK-TICK ' + $(if ((C 'ClockTop').Text -ne $script:ClockA) { 'PASS' } else { 'FAIL' }) + ' ' + $script:ClockA + ' -> ' + (C 'ClockTop').Text)
                    Add-TestResult ('BROWSER-LOAD ' + $(if ($browserOk) { 'PASS' } else { 'FAIL' }) + ' engine=' + $engine + ' title="' + $title + '" len=' + $textLen)

                    Show-View 'FilesView'
                    Start-Sleep -Milliseconds 400
                    $count = 0
                    try { $count = (C 'FileGrid').Items.Count } catch {}
                    Add-TestResult ('FILES-LIST ' + $(if ($count -gt 0) { 'PASS' } else { 'FAIL' }) + ' items=' + $count)

                    $apps = 0
                    try { $apps = (C 'AppsPanel').Children.Count } catch {}
                    Add-TestResult ('APPS-BUILD ' + $(if ($apps -gt 5) { 'PASS' } else { 'FAIL' }) + ' items=' + $apps)

                    if ($env:NIGHTCITY_SHOT_NEW -eq '1') {
                        foreach ($pair in @(@('TasksView', 'shot-tasks.png'), @('SecurityView', 'shot-security.png'), @('NotificationsView', 'shot-notifs.png'), @('SystemControlView', 'shot-sysctl.png'))) {
                            Show-View $pair[0]
                            $vv = C $pair[0]
                            try { $vv.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null); $vv.Opacity = 1 } catch {}
                            Start-Sleep -Milliseconds 120
                            $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                            [void](Save-WindowShot (Join-Path $shotDir $pair[1]))
                        }
                    }
                    Show-View 'DashboardView'
                    try { $dv = C 'DashboardView'; $dv.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null); $dv.Opacity = 1 } catch {}
                    Start-Sleep -Milliseconds 300
                    $Window.UpdateLayout(); $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
                    Add-TestResult ('UI-STATE label=' + (C 'ViewLabel').Text + ' dash=' + (C 'DashboardView').Visibility + ' set=' + (C 'SettingsView').Visibility + ' ovBg=' + (C 'NavOverview').Background.ToString() + ' setBg=' + (C 'NavSettings').Background.ToString())
                    $ok = Save-WindowShot (Join-Path $shotDir 'shot-final.png')
                    Add-TestResult ('SCREENSHOT-FINAL ' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
                } catch {
                    Add-TestResult ('SELFTEST-ERROR ' + $_.Exception.Message)
                }
                $script:ForceClose = $true
                $Window.Close()
            }
        }
    })
    $testTimer.Start()
}

$Window.ShowDialog() | Out-Null

if ($SelfTest) {
    foreach ($line in $script:TestResults) { Write-Output $line }
}
