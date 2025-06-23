final: prev: {
  # oxipng with Zopfli support
  oxipng = prev.oxipng.overrideAttrs (prevAttrs: {
    buildFeatures = prevAttrs.buildFeatures or [ ] ++ [ "zopfli" ];
  });

  # qpdf with Zopfli support
  qpdf = prev.qpdf.overrideAttrs (prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ final.makeBinaryWrapper ];
    buildInputs = prevAttrs.buildInputs or [ ] ++ [ final.zopfli ];
    cmakeFlags = prevAttrs.cmakeFlags or [ ] ++ [ "-DZOPFLI=ON" ];
    postInstall = prevAttrs.postInstall or "" + ''
      wrapProgram "$bin/bin/qpdf" --set-default QPDF_ZOPFLI force
    '';
  });
}
