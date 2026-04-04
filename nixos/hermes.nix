# Hermes runs the gateway inside Docker only. Nothing here grants the Hermes *process* root
# on the NixOS host: `services.hermes-agent` keeps the host identity as `user` below, state
# under /var/lib/hermes is owned by that user, and systemd only drives `docker` (normal for
# Docker). Root UID/GID and `docker exec -u root` apply *inside the container* (namespaced).
# Your login user runs the host `hermes` script (non-root); it merely invokes the Docker CLI.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.hermes-agent;
  # Path inside the OCI container
  containerWorkDir =
    if lib.hasPrefix "${cfg.stateDir}/" cfg.workingDirectory then
      "/data/${lib.removePrefix "${cfg.stateDir}/" cfg.workingDirectory}"
    else
      cfg.workingDirectory;

  # Host `hermes` → `docker exec` as *container* hermes user. HERMES_HOME stays /data/.hermes.
  hermes = pkgs.writeShellScriptBin "hermes" ''
    set -euo pipefail
    exec ${pkgs.docker}/bin/docker exec -it \
      -u hermes \
      -e HERMES_HOME=/data/.hermes \
      -e MESSAGING_CWD=${containerWorkDir} \
      -w "${containerWorkDir}" \
      hermes-agent \
      /data/current-package/bin/hermes "$@"
  '';
in
{
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    settings = {
      model = {
        provider = "openai-codex";
        base_url = "https://chatgpt.com/backend-api/codex";
        default = "gpt-5.4-mini";
      };

      toolsets = [ "hermes-cli" ];

      agent = {
        max_turns = 90;
        tool_use_enforcement = "auto";
        system_prompt = "You are a technical expert. Provide detailed, accurate technical information.";
      };

      terminal = {
        backend = "local";
        cwd = ".";
        timeout = 180;
      };

      compression = {
        enabled = true;
        threshold = 0.5;
        target_ratio = 0.2;
        protect_last_n = 20;
        summary_model = "";
        summary_provider = "auto";
        summary_base_url = null;
      };

      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
        memory_char_limit = 2200;
        user_char_limit = 1375;
      };

      display = {
        compact = false;
        personality = "technical";
        resume_display = "full";
        busy_input_mode = "interrupt";
        bell_on_complete = false;
        show_reasoning = true;
        streaming = true;
        inline_diffs = true;
        show_cost = false;
        skin = "default";
        tool_progress_command = true;
        tool_preview_length = 80;
        tool_progress = "all";
      };

      stt = {
        enabled = true;
        provider = "openai";
        openai = {
          model = "whisper-1";
        };
      };

      discord = {
        require_mention = false;
        auto_thread = false;
        reactions = true;
      };

      security = {
        redact_secrets = true;
        tirith_enabled = true;
        tirith_path = "tirith";
        tirith_timeout = 5;
        tirith_fail_open = true;
        website_blocklist = {
          enabled = false;
          domains = [];
          shared_files = [];
        };
      };

      cron.wrap_response = true;
      _config_version = 11;
      session_reset = {
        mode = "both";
        idle_minutes = 1440;
        at_hour = 4;
      };
    };

    environmentFiles = [ config.sops.secrets.hermes_env.path ];
    authFile = config.sops.secrets.hermes_auth.path;

    addToSystemPackages = false;
  };

  # Native (non-OCI) deployments: point the host CLI at the service state dir.
  environment.variables.HERMES_HOME = lib.mkIf (!cfg.container.enable) "${cfg.stateDir}/.hermes";
  environment.systemPackages = lib.mkIf cfg.container.enable [ hermes ];
}
