{ config, pkgs, lib, ... }:

let
  cfg = config._dev;
in
{
  options._dev.enable = lib.mkEnableOption "Development tools and language servers";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core dev tools
      gnumake
      binutils
      gcc
      pkg-config
      autoconf
      automake
      libtool
      flex
      bison
      cmake
      ninja
      meson
      patchelf
      sbctl

      # Version control
      git
      jujutsu
      subversion
      git-lfs

      # Languages
      clang
      gdb
      lldb
      valgrind
      openblas
      nodejs
      python3
      pipx
      uv
      ruby
      lua5_3
      luaPackages.fennel

      # Language servers
      lua-language-server
      cmake-language-server

      # Editors
      neovim
      helix

      # Linting and formatting
      shellcheck
      shfmt
      ruff
      yamllint
      taplo

      # Docker-free container tools
      podman
      skopeo
      nerdctl
      distrobox

      # Tools
      just
      direnv
      pre-commit
      delta
      difftastic
      tig
      ripgrep
      fd
      eza
      bat
      jq
      yq-go
      tree-sitter
    ];

    # Python toolchain
    environment.variables.PIP_REQUIRE_VIRTUALENV = "false";
  };
}
