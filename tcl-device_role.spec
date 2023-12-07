%define teaname DeviceRole
%define major 1.0

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
* Mon Nov 27 2023 Vladislav Zavjalov <slazav@altlinux.org> 1.0-alt1
- v1.0. Start versioning, it was a long modification history before this


