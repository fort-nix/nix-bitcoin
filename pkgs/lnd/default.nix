{ lnd, fetchpatch }:

lnd.overrideAttrs (_: {
  patches = [
    (fetchpatch {
      # https://github.com/lightningnetwork/lnd/pull/7672
      name = "fix-PKCS8-cert-key-support";
      url = "https://github.com/lightningnetwork/lnd/pull/7672.patch";
      hash = "sha256-j9EirxyNi48DGzLuHcZ36LrFlbJLXrE8L+1TYh5Yznk=";
    })
  ];
})
