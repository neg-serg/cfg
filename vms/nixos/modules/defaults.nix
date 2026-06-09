{ lib, ... }:

{
  # Minimal defaults — each module declares its own enable option
  _network.enable = lib.mkDefault true;
}
