final: prev: rec {
  copyTypstDocumentApp =
    args:
    let
      drv = copyTypstDocumentScript args;
      exePath = drv.passthru.exePath or "/bin/${drv.pname or drv.name}";
    in
    {
      type = "app";
      program = "${drv}${exePath}";
    };

  copyTypstDocumentScript =
    {
      document,
      path ? "./pdf/${document.name or document.pname or "out"}.pdf",
    }:
    prev.writeShellScriptBin "copy-document-${document.name or document.pname or "unknown"}" ''
      mkdir -p $(dirname ${path})
      cp --force ${document} ${path}
    '';
}
