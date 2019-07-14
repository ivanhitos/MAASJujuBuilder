# Introduction:

Scripts that install a MAAS VM on a baremetal server, then install a juju client on the same VM and configure the basic setup, including bootstrapping a juju controller.


# Requirements:

- Internet connectivity to internet from host.
- Sudo permissions on the host.


# Installation:

```
git clone https://github.com/ivanhitos/MAASJujuBuilder.git

cd MAASJujuBuilder

chmod 700 mjb.sh

./mjb.sh --maas_ip "IPofMAAS" --dns "DNSSERVERS" --proxy "ProxyIP" --lpusername "LaunchPad UserID" --maas_password "Password for MAAS" \
--maas_startdhcp "FirstIPofDHCP" --maas_enddhcp "LastIPofDHCP"  --qemu_user "Qemu user for qemu+ssh"
```

Example without proxy:
```

./mjb.sh --maas_ip "192.168.122.3" --dns "192.168.122.1" --lpusername "ivanhitos" --maas_password "ubuntu" \
--maas_startdhcp "192.168.122.220" --maas_enddhcp "192.168.122.250" --qemu_user "ivan"
```

Example with proxy:
```

./mjb.sh --maas_ip "192.168.122.3" --dns "192.168.122.1" --proxy "squid.internal:3128"--lpusername "ivanhitos" --maas_password "ubuntu" \
--maas_startdhcp "192.168.122.220" --maas_enddhcp "192.168.122.250" --qemu_user "ivan"
```

# Description:

It will create a Bionic VM called MAAS1 on "IPofMAAS" with the latest stable version of MAAS from the Ubuntu archives, the default subnet is 192.168.122.0/24 and it cannot be changed for now. MAAS will be accessible on `http://IPofMAAS:5240/MAAS` User: Ubuntu, PASS: "Password for MAAS". 

It will bootstrap a Juju controller.



# Still to do:
- Add additional subnets and configure spaces.
- Import Juju bundles.
- Make more arguments optional
