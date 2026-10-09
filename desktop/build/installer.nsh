; Custom NSIS include script for Medha Windows Desktop
; Ensures clean uninstallation by:
; 1. Terminating any running Medha.exe or background worker instances
; 2. Ensuring all file locks are released before directory removal
; 3. Purging desktop & start menu shortcuts
; 4. Cleaning registry keys

!macro customUnInstall
    DetailPrint "Terminating any running Medha instances..."
    ; Force kill any running instances of Medha.exe to prevent file locks
    nsExec::Exec 'taskkill /F /IM Medha.exe /T'
    nsExec::Exec 'taskkill /F /IM medha-windows.exe /T'
    Sleep 1000

    DetailPrint "Cleaning up application shortcuts..."
    Delete "$DESKTOP\Medha.lnk"
    Delete "$SMPROGRAMS\Medha\Medha.lnk"
    RMDir /r "$SMPROGRAMS\Medha"

    DetailPrint "Removing registry entries..."
    DeleteRegKey HKCU "Software\Medha"
    DeleteRegKey HKLM "Software\Medha"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Medha"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Medha"

    DetailPrint "Releasing installation directory..."
!macroend

!macro customInstall
    DetailPrint "Configuring Medha application..."
!macroend
