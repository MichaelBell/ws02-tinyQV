{
  nixConfig = {
    extra-substituters = [
      "https://nix-cache.fossi-foundation.org"
    ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  inputs = {
    librelane.url = "github:librelane/librelane/dev";
  };

  outputs =
    {
      self,
      librelane,
      ...
    }:
    let
      nix-eda = librelane.inputs.nix-eda;
      devshell = librelane.inputs.devshell;
      nixpkgs = nix-eda.inputs.nixpkgs;
      lib = nixpkgs.lib;
    in
    {
      # Outputs
      legacyPackages = nix-eda.forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            nix-eda.overlays.default
            devshell.overlays.default
            librelane.overlays.default

            (final: prev: {
              iverilog = prev.iverilog.overrideAttrs (old: {
                version = "fix-decl-after-use";

                src = prev.fetchFromGitHub {
                  owner = "MichaelBell";
                  repo = "iverilog";

                  # commit containing the fix you need
                  rev = "fbac730f5062ccee37345d87a7995b7594d52cd8";

                  hash = "sha256-Jd77iW5sJarIrcfkKySUMgXMDZhH5vf/XW9YqpuQ+94=";
                };
              });
              python3 = prev.python3.override {
                packageOverrides = pyFinal: pyPrev: {
                  riscvmodel = pyPrev.buildPythonPackage rec {
                    pname = "riscv-model";
                    version = "0.6.6";

                    src = pyPrev.fetchPypi {
                      inherit pname version;
                      hash = "sha256-3/8DW3XtNt4zqZ+V8QmGl74wjUxxYamUB7gt8i/VTWk=";
                    };

                    format = "setuptools";

                    nativeBuildInputs = with pyPrev; [
                      setuptools
                      setuptools-scm
                    ];

                    doCheck = false;
                  };
                };
              };
            })
          ];
        }
      );

      packages = nix-eda.forAllSystems (system: {
        inherit (self.legacyPackages.${system}.python3.pkgs) ;
      });

      devShells = nix-eda.forAllSystems (
        system:
        let
          pkgs = (self.legacyPackages.${system});
          callPackage = lib.callPackageWith pkgs;
        in
        {
          default = pkgs.librelane-shell.override ({
            extra-packages = with pkgs; [
              # Utilities
              gnumake
              gnugrep
              gawk

              # Simulation
              iverilog
              verilator

              # Waveform viewing
              gtkwave
              surfer
            ];

            extra-python-packages =
              ps: with ps; [
                # Verification
                cocotb
                riscvmodel

                # For KLayout Python DRC runner
                docopt

                # For logo generation
                pillow
              ];
          });
        }
      );
    };
}
