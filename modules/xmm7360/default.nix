{ config, pkgs, lib, ... }:

let
  cfg = config.xmm7360;

  inherit (lib) mkEnableOption mkIf mkOption types;

  xmm7360Package =
    if cfg.package != null then
      cfg.package
    else
      pkgs.callPackage ../../pkgs/xmm7360-pci {
        kernel = config.boot.kernelPackages.kernel;
      };

  xmm7360ConfigFile =
    pkgs.writeText "xmm7360.ini" (lib.generators.toKeyValue { } cfg.config);
in {
  options.xmm7360 = {
    enable = mkEnableOption "support for the Fibocom L850-GL (Intel XMM7360) WWAN modem";

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Start the modem configuration service on boot.";
    };

    config = mkOption {
      type = with types; attrsOf (oneOf [ bool int str ]);
      default = { };
      example = {
        apn = "3gnet";
        nodefaultroute = false;
        noresolv = true;
      };
      description = ''
        xmm7360.ini configuration written as a flat attribute set. Supported
        keys are the arguments of `open_xdatachannel.py` (e.g. `apn`,
        `nodefaultroute`, `metric`, `ip-fetch-timeout`, `noresolv`, `dbus`).
        `apn` is required.
      '';
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Kernel module package of XMM7360-PCI to use. If left as `null`, the
        package is built automatically for the kernel selected by
        `boot.kernelPackages`.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.config ? apn;
      message = ''
        xmm7360.config must contain an `apn` attribute, e.g.
        `xmm7360.config.apn = "your.apn.here";`.
      '';
    }];

    boot.extraModulePackages = [ xmm7360Package ];

    # The in-tree `iosm` driver claims the same PCI device (8086:7360) and
    # would prevent the out-of-tree `xmm7360` driver from binding to it.
    boot.blacklistedKernelModules = [ "iosm" ];

    # The driver has no power management support: the modem powers off during
    # suspend and must be reconfigured when the machine resumes.
    powerManagement.resumeCommands = ''
      ${pkgs.systemd}/bin/systemctl --no-block try-restart xmm7360.service
    '';

    systemd.services.xmm7360 = let
      inherit (pkgs) kmod;
      preStartScript = pkgs.writeShellScript "xmm7360-prestart" ''
        ${kmod}/bin/modprobe xmm7360 || true
      '';
      postStopScript = pkgs.writeShellScript "xmm7360-poststop" ''
        ${kmod}/bin/rmmod xmm7360 || true
      '';
    in {
      wantedBy = lib.optionals cfg.autoStart [ "multi-user.target" ];
      description = "Configuration service for the Fibocom L850-GL modem";
      # Wait a bit so the freshly inserted device is fully up before probing.
      script = ''
        sleep 10
        ${xmm7360Package}/bin/open_xdatachannel.py -c ${xmm7360ConfigFile}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "1min 30s";
        ExecStartPre = preStartScript;
        ExecStopPost = postStopScript;
        Restart = "on-failure";
      };
    };
  };
}
