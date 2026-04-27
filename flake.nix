{
  description = "typst2nix - Package Management and Tooling for Typst implemented in Nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    with flake-utils.lib;
    with nixpkgs.lib;
    with builtins;
    {
      lib = rec {
        copyDocumentApp =
          args:
          flake-utils.lib.mkApp {
            drv = copyDocumentScript args;
          };

        copyDocumentScript =
          {
            document,
            file ? "./pdf/out.pdf",
          }:
          pkgs.writeShellScriptBin "copy-document-${document.name or document.pname or "unknown"}" ''
            mkdir -p $(basename ${file})
            cp ${document} ${file}
          '';

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
