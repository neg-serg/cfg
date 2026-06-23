{ config, pkgs, lib, ... }:

let
  cfg = config._systemTuning;
in
{
  options._systemTuning.enable = lib.mkEnableOption "System tuning (fancontrol, ananicy-cpp, GPU profiles)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      lm_sensors  # fancontrol dependency
    ];

    # Fan control service
    systemd.services.fancontrol = {
      description = "Fan speed control";
      after = [ "lm_sensors.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = "${pkgs.lm_sensors}/bin/fancontrol";
      };
    };

    # Ananicy-cpp — CPU I/O scheduler (auto-nice daemon)
    systemd.services.ananicy-cpp = {
      description = "Ananicy C++ auto-nice daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        ExecStart = "${pkgs.ananicy-cpp}/bin/ananicy-cpp";
      };
    };

    # GPU power profile (AMD)
    systemd.services.gpu-power-profile = {
      description = "AMD GPU power profile";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'echo manual > /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null || true'";
      };
    };
  };
}
