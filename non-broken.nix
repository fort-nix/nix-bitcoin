# This file filters out all the broken packages from your package set.
# It's what gets built by CI, so if you correctly mark broken packages as
# broken your CI will not try to build them and the non-broken packages will
# be added to the cache.
{ pkgs ? import <nixpkgs> {} }:

let filterSet =
      (f: g: s: builtins.listToAttrs
        (map
          (n: { name = n; value = builtins.getAttr n s; })
          (builtins.filter
            (n: f n && g (builtins.getAttr n s))
            (builtins.attrNames s)
          )
        )
      );
in filterSet
     (n: !(n=="lib"||n=="overlays"||n=="modules")) # filter out non-packages
     (p: (builtins.isAttrs p)
       && !(
             (builtins.hasAttr "meta" p)
             && (builtins.hasAttr "broken" p.meta)
             && (p.meta.broken)
           )
     )
     (import ./default.nix { inherit pkgs; })

