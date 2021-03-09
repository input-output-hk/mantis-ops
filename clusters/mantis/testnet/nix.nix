{ ... }: {
  nix = {
    binaryCaches = [
      "https://vit-ops.cachix.org"
      "https://hydra.iohk.io"
      "https://hydra.mantis.ist"
    ];

    binaryCachePublicKeys = [
      "vit-ops.cachix.org-1:LY84nIKdW7g1cvhJ6LsupHmGtGcKAlUXo+l1KByoDho="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "hydra.mantis.ist-1:4LTe7Q+5pm8+HawKxvmn2Hx0E3NbkYjtf1oWv+eAmTo="
    ];
  };
}
