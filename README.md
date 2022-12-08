## Convenient python package source fetcher for nix
Tired of manually finding the right url and sha256 hash for a pypi package? This project makes your life easier while still providing the same reproducibility / security.

### What it does:
This package comes with a full copy of `url + sha256` for each python package ever published on pypi.org. It is updated on a 12h basis. Checkout the most recent commit if you need recently released packages from pypi. By importing this project you will download around 250 MB (1 GB uncompressed) of pypi metadata. Afterwards you can just fetch pypi sources within your nix expressions like this:
```nix
# pseudo example not including the necessary imports

buildPythonPackage {
  src = fetchPypi "requests" "2.22.0";
  ...
}
```
This is possible because combinations of name and version on pypi are unique. You will have the same reproducibility like when specifying the url and sha256 manually. You are not relying on pypi for integrity since all hashes for downloads are here in this project.

### What it doesn't
This project does not solve any dependency issues you might face during the build. You still need to manually specify build and runtime dependencies of the package via `buildInputs` and `propagatedBuildInputs`.
If you require a more fully-fledged solution for building python environments, take a look at [mach-nix](https://github.com/DavHau/mach-nix).

### Full usage example
The following expression will fetch the source tarball for requests 2.22.0
```nix
let
  commit = "73de0e330fd611769c192e98c11afc2d846d822b";  # from: Mon Apr 27 2020
  fetchPypi = import (builtins.fetchTarball {
    name = "nix-pypi-fetcher";
    url = "https://github.com/DavHau/nix-pypi-fetcher/tarball/${commit}";
    # Hash obtained using `nix-prefetch-url --unpack <url>`
    sha256 = "1c06574aznhkzvricgy5xbkyfs33kpln7fb41h8ijhib60nharnp";
  });
in
fetchPypi "requests" "2.22.0"
```
