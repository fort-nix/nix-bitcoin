{ recommonmark, fetchFromGitHub }:

recommonmark.overridePythonAttrs (old: rec {
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "rtfd";
    repo = old.pname;
    rev = version;
    sha256 = "0kwm4smxbgq0c0ybkxfvlgrfb3gq9amdw94141jyykk9mmz38379";
  };
})
