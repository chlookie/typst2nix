{
  description = "typst2nix - Package Management and Tooling for Typst implemented in Nix ";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      utils,
      ...
    }:
    with utils.lib;
    with nixpkgs.lib;
    with builtins;
    {
      lib = rec {
        # Control root with `src`, control the entry point with `main`
        buildTypstDoc =
          {
            pkgs,
            pname,
            version,
            src,
            main,
            ext ? "pdf",
            inputs ? { },
          }:
          let
            convertedInputs = foldr (a: b: a + " " + b) "" (
              mapAttrsToList (n: v: "--input " + n + "=" + v) inputs
            );
          in
          (pkgs.stdenv.mkDerivation rec {
            inherit pname version src;

            buildInputs = [
              (pkgs.typst.withPackages (extractDependencies {
                path = src;
              }))
            ];

            buildPhase = ''
              mkdir $out
              typst compile ${main} $out/${pname}.${ext} --root . ${convertedInputs}
            '';
          });

        # Extract dependencies of a typst document from source (including the dependencies of the dependencies)
        # extracted dependencies must be present in the registry at the moment.
        extractDependencies =
          {
            this ? null,
            path,
          }:
          registry:
          flatten (
            map (
              p: traceVerbose "[typst2nix] extracted dependency ${p.dep.name} from source" resolveDeps p.dep
            ) (extractDependencies' { inherit this path; } registry)
          );

        # Recursively collect all dependencies of a typst package
        resolveDeps =
          typstPkg:
          flatten (
            [ typstPkg ]
            ++ (map (
              p: traceVerbose "[typst2nix] found ${typstPkg.name} depends on ${p.name}" (resolveDeps p)
            ) typstPkg.passthru.typstDeps)
          );

        toPackageName = lst: "${elemAt lst 0}_${replaceStrings [ "." ] [ "_" ] (elemAt lst 1)}";

        # get dependencies of source on a specific package of a specific version using regex on each line.
        # regex for matching dependencies:
        # .*@[[:alnum:]]+/([[:alnum:]]+):([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+).*
        # returns
        # [
        #   "cetz"
        #   "0.4.0"
        # ]
        extractDependencies' =
          { this, path }:
          registry:
          let
            filtered = filter (p: hasSuffix ".typ" p) (filesystem.listFilesRecursive path);
          in
          filter (x: x.dep != this) (
            flatten (
              map (
                # for each typst source file path
                p:
                let
                  lines = splitString "\n" (readFile p);
                in
                map (l: {
                  dep =
                    let
                      dep' = match ".*@[[:alnum:]-]+/([[:alnum:]-]+):([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+).*" l;
                    in
                    if dep' != null then registry."${(toPackageName dep')}" else null;
                }) lines
              ) filtered
            )
          );
      };
    };
}
