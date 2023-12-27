%define teaname DeviceRole
%define major 1.1

Name: tcl-device_role
Version: %major
Release: alt1
BuildArch: noarch

Summary: DeviceRole library, standardized drivers for devices
Group: System/Libraries
Source: %name-%version.tar
License: Unknown

Requires: tcl

%description
tcl-device_role -- DeviceRole library, standardized drivers for devices
%prep
%setup -q

%install
mkdir -p %buildroot/%_tcldatadir/%teaname
install -m644 *.tcl %buildroot/%_tcldatadir/%teaname
for d in r_*; do
  mkdir -p %buildroot/%_tcldatadir/%teaname/$d
  install -m644 $d/*.tcl %buildroot/%_tcldatadir/%teaname/$d
done

%files
%dir %_tcldatadir/%teaname
%_tcldatadir/%teaname/*

%changelog
* Wed Dec 27 2023 Vladislav Zavjalov <slazav@altlinux.org> 1.1-alt1
New version, remove some unused features, rearrange code:
- Rewrite and improve Keysight/Agilent/HP generators support
- All drivers moved to seperate files
- TK Widget for gauge role
- remove gauge2 role
- remove conf_* methods
- remove lock/unlock commands (not useful with device2 server)
- change lock-in interface: no set_* commands, get returns X,Y,status
- use only new Device2 interface
- Keep dev_name, dev_chan, dev_id, dev_model, dev_opts, dev_info in the base class

* Mon Nov 27 2023 Vladislav Zavjalov <slazav@altlinux.org> 1.0-alt1
- v1.0. Start versioning, it was a long modification history before this


