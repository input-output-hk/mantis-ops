{ ... }: {
  nix = {
    binaryCaches = [
      "https://vit-ops.cachix.org"
      "https://hydra.iohk.io"
    ];

    binaryCachePublicKeys = [
      "vit-ops.cachix.org-1:LY84nIKdW7g1cvhJ6LsupHmGtGcKAlUXo+l1KByoDho="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };
}
