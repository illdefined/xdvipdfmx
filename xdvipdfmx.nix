{
  lib,
  writeShellApplication,
  coreutils,
  texlive,
  ghostscript_headless,
  oxipng,
  qpdf,
  verapdf,
}:
let inherit (lib) escapeShellArg getExe getExe';
in writeShellApplication {
  name = "xdvipdfmx";
  runtimeInputs = [ coreutils ];

  derivationArgs = {
    pname = "xdvipdfmx-wrapper";
    version = "0";
    meta = {
      description = "Custom xdvipdfmx wrapper";
      platforms = lib.platforms.all;
      maintainers = with lib.maintainers; [ mvs ];
      license = lib.licenses.eupl12;
      priority = lib.meta.hiPrio;
    };
  };

  text = ''
    declare -i i=1 v=1

    xdvipdfmx=(${escapeShellArg (getExe' texlive.bin.core.dvipdfmx "xdvipdfmx")}
      -z 0  # Disable output compression
    )

    gs=(${escapeShellArg (getExe ghostscript_headless)}
      -dPrinted=false  # Prefer screen annotations for thumbnails
      -dMaxBitmap=2147483647  # Increase maximum bitmap size
      -dBGPrint=true  # Enable parallel parsing and rendering
      -dNumRenderingThreads="$(nproc)"
      -sDEVICE=png16malpha  # 32‐bit RGBA PNG
      -dInterpolateControl=-1  # Enable pixel interpolation
      -dDownScaleFactor=8
      -r96  # 96 / 8 = 12 DPI resolution
    )

    oxipng=(${escapeShellArg (getExe oxipng)}
      -o max  # Maximum optimisation
      --strip safe  # Strip non‐essential meta‐data
      --alpha  # Permit alpha channel optimisation
      --zopfli  # Zopfli compressor
    )

    qpdf=(${escapeShellArg (getExe qpdf)}
      --warning-exit-0  # Exit with 0 status despite warnings
      --deterministic-id  # Produce deterministic document ID
      --compress-streams=y  # Compress PDF streams
      --decode-level=specialized  # Decode all losslessly compressed streams
      --recompress-flate  # Re‐compress streams
      --compression-level=9  # deflate compression level (ignored with Zopfli)
      --object-streams=generate  # Create object streams, compressing objects
      --newline-before-endstream  # Preserve newlines for PDF/A conformance
      --coalesce-contents  # Combine object streams
      --externalize-inline-images  #  Convert large inline images to regular ones
    )

    verapdf=(${escapeShellArg (getExe' verapdf "verapdf")}
      --defaultflavour 3u  # PDF/A-3u
      --format text
    )

    log() {
      if ((v >= $1)); then
        shift
        echo "xdvipdfmx-caoutchouc: $*" >&2
      fi
    }

    edo() {
      log 2 "$*"
      "$@"
    }

    log 3 "Invoked as: $0 $*"

    while ((i < $#)); do
      case "''${!i}" in
        (-o)  # Output file
          ((++i))
          out="''${!i}"
          ((++i))
          continue;;
        (-q)  # Quiet operation
          v=0;;
        (-v)  # Increase verbosity
          v+=1;;
        (-no-pdf)
          # No sense in continuing for non‐PDF output
          exec "''${xdvipdfmx[0]}" "$@";;
      esac

      xdvipdfmx+=("''${!i}")
      ((++i))
    done

    tmp="$(mktemp -d)"
    trap 'rm -f -r "$tmp"' EXIT

    if ((i <= $#)); then
      # Last argument is input DVI file
      dvi="''${!i}"
      log 3 "DVI input: $dvi"
      base="''${dvi%.*}"
      out="''${out-$base.pdf}"
    elif [[ -v out ]]; then
      log 3 "Reading DVI from standard input"
      base="''${out##*/}"
      base="''${out%.*}"
      base="$tmp/$base"
      dvi="$base.xdv"
      cat >"$dvi"
    else
      # No input or output provided
      exec "''${xdvipdfmx[0]}" "$@"
    fi

    log 3 "PDF output: $out"

    if ((v <= 0)); then
      oxipng+=(-q)
      qpdf+=(--no-warn)
      verapdf+=(--loglevel 0)
    fi

    if ((v <= 2)); then
      gs+=(-q)
    fi

    if ((v > 1)); then
      oxipng+=(-v)
      verapdf+=(--verbose)
    fi

    if ((v > 2)); then
      oxipng+=(-v)
      qpdf+=(--verbose)
      verapdf+=(--loglevel 4)
    fi

    # Path base for temporary files
    base="$tmp/''${base##*/}"

    log 1 "Producing intermediate PDF for thumbnail generation"
    edo "''${xdvipdfmx[@]}" -o "$base.pdf" "$dvi"

    log 1 "Generating PNG thumbnails"
    edo "''${gs[@]}" -o "$base.%d" "$base.pdf"
    rm -f "$base.pdf"

    log 1 "Optimising PNG thumbnails"
    edo "''${oxipng[@]}" "$base."[0-9]*

    log 1 "Producing final PDF with embedded thumbnails"
    TMPDIR="$tmp" \
    edo "''${xdvipdfmx[@]}" -t -o "$base.pdf" "$dvi"
    rm -f "$base."[0-9]*

    log 1 "Re‐compressing final PDF"
    edo "''${qpdf[@]}" "$base.pdf" "$out"

    if [[ "$out" != "-" ]]; then
      log 1 "Validating final PDF"
      edo "''${verapdf[@]}" "$out"
    else
      log 1 "Not validating final PDF"
    fi
  '';
}
