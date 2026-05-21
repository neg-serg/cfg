{ config, pkgs, lib, ... }:

let
  cfg = config._ai;
in
{
  options._ai.enable = lib.mkEnableOption "AI inference servers and tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # AI CLI tools
      yt-dlp
      gallery-dl
      # telethon bridge — via python3Packages.telethon
      (python3.withPackages (ps: with ps; [
        telethon
        openai
        huggingface-hub
      ]))
    ];

    # Ollama is managed as a container in containers.nix
    # llama.cpp — CPU-only in VM (GPU passthrough deferred)
    # T5 summarization — containerized
    # video-ai — requires GPU; deferred to GPU passthrough
    # image generation — uses free-tier APIs (proxypilot provides access)
  };
}
