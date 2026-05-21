{ config, lib, ... }:

let
  secretsFile = ../secrets/secrets.yaml.age;
in
{
  age.secrets = {
    all = {
      file = secretsFile;
      path = "/run/secrets/secrets.yaml";
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };
}
