# netkit.nix — xmm7360

NixOS module and package for the [xmm7360-pci](https://github.com/xmm7360/xmm7360-pci)
driver for the Fibocom L850-GL / Intel XMM7360 WWAN modem (PCI ID `8086:7360`).

## Usage

Add this repository to your flake inputs and import the module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    netkit.url = "github:icebox-nix/netkit.nix";
  };

  outputs = { nixpkgs, netkit, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        netkit.nixosModule
        {
          netkit.xmm7360 = {
            enable = true;
            autoStart = true;
            config = {
              apn = "3gnet";        # required
              nodefaultroute = false;
              noresolv = true;
            };
          };
        }
      ];
    };
  };
}
```

By default the kernel module is built automatically against your configured
`boot.kernelPackages`. To use a specific package instead, set
`netkit.xmm7360.package`.

## Flake outputs

- `packages.x86_64-linux.xmm7360` (also `default`): the driver, built against
  nixpkgs' default `linux` kernel.
- `overlay`: adds `xmm7360-pci` to nixpkgs.
- `nixosModule`: the NixOS module described above.

## Options

- `netkit.xmm7360.enable` — enable the driver and configuration service.
- `netkit.xmm7360.autoStart` — start the service at boot (default `false`).
- `netkit.xmm7360.config` — flat attribute set written to `xmm7360.ini`.
  Supported keys are the `open_xdatachannel.py` arguments: `apn` (required),
  `nodefaultroute`, `metric`, `ip-fetch-timeout`, `noresolv`, `dbus`.
- `netkit.xmm7360.package` — override the kernel module package (defaults to a
  package built for your running kernel).
