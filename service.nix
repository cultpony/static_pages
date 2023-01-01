flake: { config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption;

  inherit (flake.packages.x86_64-linux) static-pages;

  cfg = config.services.static-pages;
in
{
  options = {
    services.static-pages = {
      enable = mkEnableOption ''
        Static-Pages for CULT PONY
      '';
    };
 };

  config = lib.mkIf cfg.enable {

    systemd.services.static-pages = {
      description = "Static Pages to Serve";

      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Restart = "on-failure";
        ExecStart = "${static-pages}/bin/static_pages";
        StateDirectory = "static-pages";
        StateDirectoryMode = "0750";

        CapabilityBoundingSet = [ "AF_NETLINK" "AF_INET" "AF_INET6" ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/" ];
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_NETLINK" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" "@pkey" ];
        UMask = "0027";
      };
    };
  };
}