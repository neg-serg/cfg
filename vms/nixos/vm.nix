{ config, lib, ... }:

{
  disko.imageBuilder = {
    qcow2 = {
      name = "nixos.qcow2";
      size = "60G";
      format = "qcow2";
    };
  };
}
