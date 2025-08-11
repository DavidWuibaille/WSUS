function Remove-Package {
    param(
        [string]$KB
    )
 
    # Find matching package(s)
    $packages = Get-WindowsPackage -Online | Where-Object { $_.PackageName -match $KB }
 
    if($packages.Count -eq 0) {
        Write-Host "No packages found matching $KB."
        return
    }
 
    # Display found packages
    Write-Host "Packages found matching $KB"
    $packages | ForEach-Object { Write-Host $_.PackageName }
 
    # Uninstall packages
    foreach($package in $packages) {
        try {
            Write-Host "Uninstalling $($package.PackageName)..."
            Remove-WindowsPackage -Online -PackageName $package.PackageName -NoRestart -ErrorAction Stop
            Write-Host "$($package.PackageName) uninstalled successfully."
        } catch {
            Write-Error "Failed to uninstall $($package.PackageName). Error: $_"
        }
    }
 
    Write-Host "Please restart your computer."
}
 
# Example usage
Remove-Package -KB "KB4589210"