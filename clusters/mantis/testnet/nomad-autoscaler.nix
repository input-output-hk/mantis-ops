{ self, config, lib, ... }:
let
  eachASG = lib.flip lib.mapAttrs config.cluster.autoscalingGroups;
in {
  imports = [ (self.inputs.bitte + /profiles/nomad/autoscaler.nix) ];

  services.nomad-autoscaler.policies = eachASG (name: asg: {
    min = 10;
    max = 20;

    policy.check = {
      mem_allocated_percentage.strategy.target-value.target = 70.0;
      cpu_allocated_percentage.strategy.target-value.target = 70.0;
    };
  });
}
