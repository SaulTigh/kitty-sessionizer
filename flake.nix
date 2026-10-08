{
  description = "Pick projects and manage kitty sessions from terminal overlays";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runtimeInputs = with pkgs; [
            bat
            fd
            fzf
            gum
            tree
          ];
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "kitty-sessionizer";
            version = "0-unstable-${self.lastModifiedDate or "19700101"}";
            src = self;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            dontBuild = true;

            installPhase = ''
              runHook preInstall

              app="$out/share/kitty-sessionizer"
              mkdir -p "$app" "$out/bin"
              cp -R bin lib libexec "$app/"

              makeWrapper ${pkgs.zsh}/bin/zsh "$out/bin/kitty-sessionizer" \
                --add-flags "$app/bin/kitty-sessionizer" \
                --prefix PATH : ${nixpkgs.lib.makeBinPath runtimeInputs} \
                --set-default KS_FD ${pkgs.fd}/bin/fd \
                --set-default KS_FZF ${pkgs.fzf}/bin/fzf \
                --set-default KS_GIT git \
                --set-default KS_GUM ${pkgs.gum}/bin/gum \
                --set-default KS_KITTEN kitten \
                --set-default KS_TREE ${pkgs.tree}/bin/tree \
                --set-default KS_BAT ${pkgs.bat}/bin/bat \
                --set-default KS_EDITOR nvim

              runHook postInstall
            '';

            meta = {
              description = "Project picker and session manager for kitty";
              mainProgram = "kitty-sessionizer";
              platforms = systems;
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/kitty-sessionizer";
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
