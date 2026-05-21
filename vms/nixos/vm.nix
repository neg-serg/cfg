{ config, lib, ... }:

{
  disko.imageBuilder = {
    qcow2 = {
      name = "nixos.qcow2";
      size = "40G";
      format = "qcow2";
    };
  };
}
