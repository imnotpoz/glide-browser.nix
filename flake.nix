{
  description = "flake for glide-browser";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
        );
    in
    {
      packages = forAllSystems (
        {
          system,
          pkgs,
          ...
        }:
        let
          desktopItem = pkgs.makeDesktopItem {
            name = "glide-browser";
            desktopName = "Glide Browser";
            comment = "Extensible and keyboard-focused web browser built on Firefox";
            exec = "glide";
            icon = "glide-browser";
            categories = [ "Network" "WebBrowser" ];
          };

          glide-browser = pkgs.stdenv.mkDerivation rec {
            pname = "glide-browser";
            version = "0.1.56a";

            src =
              let
                sources = {
                  "x86_64-linux" = pkgs.fetchurl {
                    url = "https://github.com/glide-browser/glide/releases/download/${version}/glide.linux-x86_64.tar.xz";
                    sha256 = "0b231ajfwzy7zqip0ijax1n69rx1w4fj5r74r9ga50fi4c63vzpn";
                  };
                  "aarch64-linux" = pkgs.fetchurl {
                    url = "https://github.com/glide-browser/glide/releases/download/${version}/glide.linux-aarch64.tar.xz";
                    sha256 = "00r32xfgah4rnwklmgdas07jrxpxpfcnsh60n92krj5wbn2gm74c";
                  };
                  "x86_64-darwin" = pkgs.fetchurl {
                    url = "https://github.com/glide-browser/glide/releases/download/${version}/glide.macos-x86_64.dmg";
                    sha256 = "095pxgk6jv9v073bifhx8ragk5r1zg73fdc6rh9qfpw1zxz6597q";
                  };
                  "aarch64-darwin" = pkgs.fetchurl {
                    url = "https://github.com/glide-browser/glide/releases/download/${version}/glide.macos-aarch64.dmg";
                    sha256 = "0ryx2fhw2a6jggz3b8x6i3hnpvbik8dvq3ppwpwh7gfw9iripczy";
                  };
                };
              in
              sources.${system};

            # patch stoled from https://git.pyrox.dev/pyrox/nix/src/branch/main/packages/glide-browser-bin/package.nix

            nativeBuildInputs =
              with pkgs;
              [
                autoPatchelfHook
                patchelfUnstable
                wrapGAppsHook3
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.undmg ];

            buildInputs =
              with pkgs;
              pkgs.lib.optionals pkgs.stdenv.isLinux [
                alsa-lib
                dbus-glib
                gtk3
                xorg.libXtst
              ];

            runtimeDependencies =
              with pkgs;
              pkgs.lib.optionals pkgs.stdenv.isLinux [
                curl
                libva
                pciutils
              ];

            appendRunpaths = pkgs.lib.optionals pkgs.stdenv.isLinux [ "${pkgs.pipewire}/lib" ];

            patchelfFlags = [ "--no-clobber-old-sections" ];

            sourceRoot = ".";

            installPhase =
              if pkgs.stdenv.isLinux then
                ''
                  runHook preInstall

                  mkdir -p $out/bin $out/lib/glide
                  cp -r glide/* $out/lib/glide/
                  chmod +x $out/lib/glide/glide

                  for size in 16 32 48 64 128; do
                    dir=$out/share/icons/hicolor/''${size}x''${size}/apps
                    mkdir -p $dir
                    cp glide/browser/chrome/icons/default/default$size.png $dir/glide-browser.png
                  done

                  ln -s ${desktopItem}/share/applications $out/share/

                  runHook postInstall
                ''
              else
                ''
                  mkdir -p $out/Applications
                  cp -r Glide.app $out/Applications/
                '';

            postInstall = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              ln -s $out/lib/glide/glide $out/bin/glide
              ln -s $out/bin/glide $out/bin/glide-browser
            '';

            meta = {
              description = "Glide Browser";
              homepage = "https://github.com/glide-browser/glide";
              platforms = [
                "x86_64-linux"
                "aarch64-linux"
                "x86_64-darwin"
                "aarch64-darwin"
              ];
            };
          };
        in
        {
          inherit glide-browser;
          default = glide-browser;
        }
      );
    };
}
