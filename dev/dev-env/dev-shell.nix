pkgs:

pkgs.mkShell {
  shellHook = ''
    # A known rev from the master branch to test whether `nix develop`
    # is called inside the nix-bitcoin repo
    rev=5cafafd02777919c10e559b5686237fdefe920c2
    if git cat-file -e $rev &>/dev/null; then
      root=$(git rev-parse --show-toplevel)
      export PATH=$root/test:$root/helper:$PATH
    else
      echo 'Error: `nix develop` must be called inside the nix-bitcoin repo.'
      exit 1
    fi
  '';
}
