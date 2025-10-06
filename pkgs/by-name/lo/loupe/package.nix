{
  stdenv,
  lib,
  fetchurl,
  cargo,
  desktop-file-utils,
  itstool,
  meson,
  ninja,
  pkg-config,
  rustc,
  wrapGAppsHook4,
  gtk4,
  lcms2,
  libadwaita,
  libgweather,
  libseccomp,
  libglycin,
  glycin-loaders,
  gnome,
  common-updater-scripts,
  _experimental-update-script-combinators,
  rustPlatform,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "loupe";
  version = "49.rc";

  src = fetchurl {
    url = "mirror://gnome/sources/loupe/${lib.versions.major finalAttrs.version}/loupe-${finalAttrs.version}.tar.xz";
    hash = "sha256-7HSVdZH8tA9cTL9IoZJWLgMCw0OuHusF0DsmDYKIJdQ=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    name = "loupe-deps-${finalAttrs.version}";
    hash = "sha256-IywuPEFyLOwjIwK/P/z7Z6yami8nq7usLE1W23ElIjU=";
  };

  postPatch = ''
    substituteInPlace src/meson.build --replace-fail \
      "'src' / rust_target / meson.project_name()," \
      "'src' / '${stdenv.hostPlatform.rust.cargoShortTarget}' / rust_target / meson.project_name()," \
  '';

  nativeBuildInputs = [
    cargo
    desktop-file-utils
    itstool
    meson
    ninja
    pkg-config
    rustc
    rustPlatform.cargoSetupHook
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    lcms2
    libadwaita
    libgweather
    libseccomp
  ];

  preConfigure = ''
    # Dirty approach to add patches after cargoSetupPostUnpackHook
    # We should eventually use a cargo vendor patch hook instead
    pushd ../$(stripHash $cargoDeps)/glycin-3.*
      patch -p3 < ${libglycin.passthru.glycin3PathsPatch}
    popd
  '';

  preFixup = ''
    # Needed for the glycin crate to find loaders.
    # https://gitlab.gnome.org/sophie-h/glycin/-/blob/0.1.beta.2/glycin/src/config.rs#L44
    gappsWrapperArgs+=(
      --prefix XDG_DATA_DIRS : "${glycin-loaders}/share"
    )
  '';

  # For https://gitlab.gnome.org/GNOME/loupe/-/blob/0e6ddb0227ac4f1c55907f8b43eaef4bb1d3ce70/src/meson.build#L34-35
  env.CARGO_BUILD_TARGET = stdenv.hostPlatform.rust.rustcTargetSpec;

  passthru = {
    updateScript =
      let
        updateSource = gnome.updateScript {
          packageName = "loupe";
        };

        updateLockfile = {
          command = [
            "sh"
            "-c"
            ''
              PATH=${
                lib.makeBinPath [
                  common-updater-scripts
                ]
              }
              update-source-version loupe --ignore-same-version --source-key=cargoDeps.vendorStaging > /dev/null
            ''
          ];
          # Experimental feature: do not copy!
          supportedFeatures = [ "silent" ];
        };
      in
      _experimental-update-script-combinators.sequence [
        updateSource
        updateLockfile
      ];
  };

  meta = with lib; {
    homepage = "https://gitlab.gnome.org/GNOME/loupe";
    changelog = "https://gitlab.gnome.org/GNOME/loupe/-/blob/${finalAttrs.version}/NEWS?ref_type=tags";
    description = "Simple image viewer application written with GTK4 and Rust";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ jk ];
    teams = [ teams.gnome ];
    platforms = platforms.unix;
    mainProgram = "loupe";
  };
})
