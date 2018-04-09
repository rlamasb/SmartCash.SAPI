SmartCash Decentralised API 
=============================

**Requirements:**
* Ubuntu 16.04 LTS x64 server with at least 4GB of RAM (Vultr, DigitalOcean, Lightsail)
* Domain (or subdomain) with DNS A Records (@ and www) pointing to server for SSL certificate generation

## Mission

Decentralised API that handles SmartCash client signed transactions and will integrate seamlessly with InstantPay technology.

## Stack

- SQL Server
- .NET Core
- Nginx
- LetsEncrypt SSL
- UFW Firewall

## How it works

The main `install.sh` script will setup a SmartNode and the RPC API. For fast bootstrap it downloads `txindexstrap` and SQL `data`. Cron jobs will be setup to keep processes running and DB in sync with the blockchain. Firewall will only accept incoming HTTPS (secure) traffic.

## Installation

**The bash script must be run by `root` user and it is [SmartNode Script](https://github.com/SmartCash/smartnode) with SAPI flavor on top.**

#### Install SmartNode + SAPI:

```console
root@server:~$ wget https://rawgit.com/rlamasb/SmartCash.SAPI/master/Installer/install.sh
root@server:~$ bash install.sh
```

#### Update SAPI:

```console
root@server:~$ wget https://rawgit.com/rlamasb/SmartCash.SAPI/master/Installer/update-sapi.sh
root@server:~$ bash update-sapi.sh
```

## License

This software is released under the MIT license. See [the license file](LICENSE) for more details.