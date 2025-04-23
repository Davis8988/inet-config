
# inet-config

PowerShell script to configure DNS settings on Windows.

## Features

- Add a DNS server to a network interface
- Optionally set a DNS suffix
- Supports silent and interactive modes
- Validates changes after applying

## Usage

```powershell
.\inet-config.ps1 -DnsToAdd "11.0.118.6" -Interface "Ethernet0" -AutoConfirm
```

## Author

David Yair [E030331]
