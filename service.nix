flake: { config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption types;

  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) static-pages;

  cfg = config.services.static-pages;
in
{
  options = {
    services.static-pages = {
      enable = mkEnableOption ''
        Static-Pages for CULT PONY
      '';

      package = mkOption {
        type = types.package;
        default = flake.packages.${pkgs.stdenv.hostPlatform.system}.default;
        description = ''
          The static_pages package to use
        '';
      };

      mainDomain = mkOption {
        type = types.str;
        default = "imprint.example.com";
        description = ''
          Primary Domain of the service
        '';
      };

      domains = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "imprint.example.com" "exmple.com" ];
        description = ''
          List of domains to configure Nginx for
        '';
      };

    };
  };

  config = lib.mkIf cfg.enable {

    services.nginx.virtualHosts.${cfg.mainDomain} = {
      serverName = cfg.mainDomain;
      serverAliases = cfg.domains;
      forceSSL = false;
      enableACME = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3077/";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };

    systemd.services.static-pages = {
      description = "Static Pages to Serve";

      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Restart = "on-failure";
        ExecStart = "${lib.getBin cfg.package}/bin/static_pages";
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
