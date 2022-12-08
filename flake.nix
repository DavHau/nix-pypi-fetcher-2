{
  description = "Convenient pypi fetcher for nix. Knows urls and hashes of all packages";

  inputs = {
    mach-nix.url = "mach-nix";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    mach-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inp:
    with builtins;
    with inp.nixpkgs.lib;
    let
      systems = ["x86_64-linux"];
      self = {
        lib.formatVersion = toInt (readFile ./FORMAT_VERSION);
      }
      // foldl' (a: b: recursiveUpdate a b) {} ( map ( system:
        let
          pkgs = inp.nixpkgs.legacyPackages."${system}";
          pyEnv = inp.mach-nix.lib."${system}".mkPython {
            requirements = ''
              requests
              bounded-pool-executor
            '';
            ignoreDataOutdated = true;
            python = "python39";
          };
          deps = [
            pyEnv
            pkgs.git
            pkgs.nixFlakes
          ];
          defaultVars = {
            PYTHONPATH = "${./updater}";
          };
          fixedVars = {};
          # defaultVars are only set if they are not already set
          # fixedVars are always set
          exports = ''
            ${concatStringsSep "\n" (mapAttrsToList (n: v: "export ${n}=\"${v}\"") fixedVars)}
            ${concatStringsSep "\n" (mapAttrsToList (n: v: "export ${n}=\"\${${n}:-${v}}\"") defaultVars)}
          '';
        in {

          # devShell to load all dependencies and environment variables
          devShell."${system}" = pkgs.mkShell {
            buildInputs = deps;
            shellHook = exports;
          };

          # apps to update the database
          # All apps assume that the current directory is a git checkout of this project
          apps."${system}" = rec {

            # update the pypi index
            update-urls.type = "app";
            update-urls.program = toString (pkgs.writeScript "update-wheel" ''
              #!/usr/bin/env bash
              ${exports}
              export WORKERS=10
              export EMAIL=$(git config --get user.email)
              ${pyEnv}/bin/python ${./updater}/crawl_urls.py ./pypi
            '');

            # job including git commit for executing in CI system
            job-urls.type = "app";
            job-urls.program = toString (pkgs.writeScript "job-urls" ''
              #!/usr/bin/env bash
              set -e
              set -x

              ${update-urls.program}

              # commit to git
              echo $(date +%s) > UNIX_TIMESTAMP
              git add pypi UNIX_TIMESTAMP
              git pull origin $(git rev-parse --abbrev-ref HEAD)
              git commit -m "$(date) - update sdist + wheel"
            '');
          };

          # This python interpreter can be used for debugging in IDEs
          # It will set all env variables during startup
          packages."${system}".pythonWithVariables = pkgs.writeScriptBin "python3" ''
            #!/usr/bin/env bash
            ${exports}
            ${pyEnv}/bin/python $@
          '';

        }) systems);
    in
      self;
}
