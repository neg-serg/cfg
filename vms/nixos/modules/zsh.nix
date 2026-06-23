{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    
    # Default shell for users
    shellAliases = {
      ls = "eza";
      ll = "eza -la";
      cat = "bat";
      grep = "rg";
      find = "fd";
    };

    ohMyZsh = {
      enable = true;
      plugins = [ "git" "sudo" "colored-man-pages" "command-not-found" ];
    };
  };

  # Make zsh the default shell
  users.defaultUserShell = pkgs.zsh;
  users.users.neg.shell = pkgs.zsh;

    # Zoxide (smart cd) — shell integration
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # Source zinit before user config (provides 'zi' function for p10k)
    programs.zsh.interactiveShellInit = ''
      source ${pkgs.zinit}/share/zinit/zinit.zsh
    '';

    environment.systemPackages = with pkgs; [
      # Shell tools already in packages.nix
      # Additional shell enhancements
      oh-my-posh
      zinit
      zsh-powerlevel10k  # p10k theme from nixpkgs (fallback if zi network fails)
    ];

  # Zsh completions
  environment.pathsToLink = [ "/share/zsh" ];
}
