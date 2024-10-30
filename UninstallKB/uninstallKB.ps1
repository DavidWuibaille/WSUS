# Importer le module PSWindowsUpdate
Import-Module PSWindowsUpdate

# Définir le numéro de KB à désinstaller
$kbNumber = "KB5028952"

try {
    # Obtenir la liste des mises à jour installées
    $installedUpdates = Get-WUList -IsInstalled

    # Rechercher la mise à jour spécifique
    $updateToUninstall = $installedUpdates | Where-Object {$_.KB -eq $kbNumber}

    # Vérifier si la mise à jour est installée
    if ($updateToUninstall) {
        # Désinstaller la mise à jour
        Write-Host "Tentative de désinstallation de la mise à jour $kbNumber..."
        Get-WUUninstall -KBArticleID $kbNumber -Confirm:$false -NoRestart
        Write-Host "La mise à jour $kbNumber a été désinstallée avec succès."
    } else {
        Write-Host "La mise à jour $kbNumber n'a pas été trouvée sur ce système."
    }
} catch {
    # Gestion des erreurs
    Write-Host "Une erreur s'est produite lors de la désinstallation de la mise à jour $kbNumber."
    Write-Host "Détails de l'erreur : $_.Exception.Message"
}
