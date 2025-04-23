class NetworkInterface {
    [string]$Name
    [string]$Description
    [string]$ConnectionProfileName

    NetworkInterface([string]$name, [string]$desc, [string]$profile) {
        $this.Name                  = $name
        $this.Description           = $desc
        $this.ConnectionProfileName = $profile
    }

    [string] ToString() {
        return "$($this.Name) ($($this.ConnectionProfileName) - $($this.Description))"
    }
}
