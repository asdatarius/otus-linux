### BASH
## Task
* Collect top 10 IP addesses ordered by request count
* Collect top 10 URI path chunks ordered by request count
* "ERROR" response codes ordered by request count
* "OK" response codes oredered by request count
* Report must be send by email
* Process only new lines

## Assumtions
* Log is rotated rarely in comparasion with monitoring. So if log was rotated, start monitoring from 0 offset. Extended support should be added if necessary.
* Treat empty lines as non valid information and skip it
* Count broken requests as "BINGO BONGO"
* Write to log only if file still the same

## Implementation
* All action happenes in 06-bash/asdatarius-log-alert.sh
* Vagrantfile starts with running timer, log-alert linked as sevice to /etc/systemd/system
* Alerts recepient by default is vagrant@localhost, so mail could be checked by `mail` commaind inside the box
* Trap could be removed, process should be controlled by systemd
