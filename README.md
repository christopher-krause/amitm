# amitm

Automated Man-In-The-Middle

### Run:

```bash
git clone https://github.com/Chrikel/amitm.git
cd amitm;
./install_dependencies.sh
sudo ./mitm_arp_script.sh -h

Usage: ./mitm_arp_script.sh [-i|--interface] [-g|--gateway] [-n|--network] [-o|--output] [-m|--network-mask] [-p|--proxy-port] [-s|--secure-traffic]

Required:
	-i | --interface	interface		(Example: en0, wlan0)
	-g | --gateway		Gateway			(Example: 10.0.0.1, 192.168.0.1)
	-n | --network		Target network		(Example: 10.0.0.0, 192.168.0.0)

Optional:
	-o | --output		Output file		(Default: ./sniff_file_2016-02-19_19-45-03.flow)
	-m | --network-mask 	Network mask		(Default: 24)
	-p | --proxy-port 	Proxyport		(Default: 8080)
	-s | --secure-traffic	Get HTTPS traffic 	(Default: 0 [0 = false, 1 = true])

```

### Deps: 
- Homebrew
- nmap
- arpoison
- mitmproxy

Currently OSX only