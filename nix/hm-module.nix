self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.kitty-sessionizer;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  expandHome =
    path:
    if path == "~" then
      config.home.homeDirectory
    else if lib.hasPrefix "~/" path then
      config.home.homeDirectory + lib.removePrefix "~" path
    else
      path;

  env = lib.filterAttrs (_: value: value != null) (
    {
      KS_SEARCH_PATH =
        if cfg.searchPaths == null then null else lib.concatMapStringsSep ":" expandHome cfg.searchPaths;
      KS_DEPTH = if cfg.depth == null then null else toString cfg.depth;
      KS_EDITOR = cfg.editor;
      KS_SESSION_DIR = cfg.sessionDir;
      KS_TEMPLATE = cfg.template;
    }
    // lib.mapAttrs (_: toString) cfg.environment
  );

  wrapped =
    if env == { } then
      cfg.package
    else
      pkgs.symlinkJoin {
        name = "kitty-sessionizer-configured";
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/kitty-sessionizer" \
            ${lib.concatStringsSep " " (
              lib.mapAttrsToList (name: value: "--set-default ${name} ${lib.escapeShellArg value}") env
            )}
        '';
        meta.mainProgram = "kitty-sessionizer";
      };

  bin = lib.getExe wrapped;

  overlay = title: action: ''launch --type=overlay --title "${title}" ${bin} ${action}'';
  background = action: "remote_control_script ${bin} ${action}";

  actions = {
    open = overlay "Project Selector" "open";
    delete = overlay "Delete Sessions" "delete";
    clone = overlay "Clone Repository" "clone";
    prev = background "prev";
    next = background "next";
  };

  keyOption =
    action: default:
    mkOption {
      type = types.nullOr types.str;
      inherit default;
      description = "kitty key that runs `kitty-sessionizer ${action}`. Set to null to skip it.";
    };
in
{
  options.programs.kitty-sessionizer = {
    enable = mkEnableOption "kitty-sessionizer";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "kitty-sessionizer.packages.\${system}.default";
      description = "The kitty-sessionizer package to wrap.";
    };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = wrapped;
      description = "The package with the configured environment applied.";
    };

    searchPaths = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      example = [
        "~/workspace/personal"
        "~/.config"
      ];
      description = ''
        Directories to search for projects, in picker order. A leading `~`
        expands to the home directory. Sets `KS_SEARCH_PATH`.
      '';
    };

    depth = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Depth to search below each search path. Sets `KS_DEPTH`.";
    };

    editor = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "hx";
      description = "Editor that opens a selected file. Sets `KS_EDITOR`.";
    };

    sessionDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Directory for generated session files. Sets `KS_SESSION_DIR`.";
    };

    template = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Template for new session files. Sets `KS_TEMPLATE`.";
    };

    environment = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
        ]
      );
      default = { };
      example = {
        KS_GUM_WIDTH = 80;
        KS_SESSION_NAME_SEP = "_";
      };
      description = ''
        Other variables from `lib/config.zsh`. A value here wins over the
        options above.
      '';
    };

    kitty = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to add the key bindings to `programs.kitty`.";
      };

      keys = {
        open = keyOption "open" "alt+shift+p";
        delete = keyOption "delete" "alt+shift+d";
        clone = keyOption "clone" "alt+shift+c";
        prev = keyOption "prev" "alt+shift+[";
        next = keyOption "next" "alt+shift+]";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ wrapped ];

    programs.kitty.keybindings = mkIf cfg.kitty.enable (
      lib.mapAttrs' (action: key: lib.nameValuePair key actions.${action}) (
        lib.filterAttrs (_: key: key != null) cfg.kitty.keys
      )
    );
  };
}
