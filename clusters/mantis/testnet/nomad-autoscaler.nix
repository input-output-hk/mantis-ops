{ self, ... }: {
  imports = [ (self.inputs.bitte + /profiles/nomad/autoscaler.nix) ];
}
