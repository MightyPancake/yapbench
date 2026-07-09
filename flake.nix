{
  description = "yapbench";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gcc                 # C compiler
              nim                 # Nim compiler
              zig                 # Zig compiler
              (python3.withPackages (ps: [ ps.matplotlib ]))
              gnumake
            ];

            shellHook = ''
              echo "============================================"
              echo "  yapbench environment"
              echo "  Languages: C (gcc), Nim, Zig, YAP"
              echo "  Runner:    python3 run_bench.py"
              echo "============================================"
              echo "Note: YAP is not included as it is not available in nixpkgs. Please build it manually from repo."
            '';
          };
        }
      );
    };
}
