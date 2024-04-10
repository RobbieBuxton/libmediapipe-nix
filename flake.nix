{
  description = "A very basic flake with Python, NumPy, OpenCV, and Bazel";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }:
    let
      # Abstract the platform specification for easier readability and maintenance
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      pythonEnv = pkgs.python3.withPackages (ps: [ ps.numpy ]);
    in
    {
      packages.x86_64-linux.default = pkgs.buildBazelPackage {
        name = "mediapipe-nix";
        src = pkgs.fetchFromGitHub {
          owner = "google";
          repo = "mediapipe";
          rev = "v0.8.11";
          sha256 = "sha256-2lBDxTMTPU5pXcJMKA9jtFprizG9e6qB8g7HEeXZ8E8=";
        };
        bazelTargets = [ "//mediapipe/c:mediapipe" ];
        bazel = pkgs.bazel_5;

        nativeBuildInputs = [
          pythonEnv
          pkgs.opencv
          pkgs.perl
        ];

        removeRulesCC = false;

        bazelFlags = [
          "--define MEDIAPIPE_DISABLE_GPU=1"
        ];

        PYTHON_BIN_PATH = pythonEnv.interpreter;
        OPENCV_DIR = pkgs.opencv;

        postPatch = ''
          rm -f .bazelversion
          cp -r ${self}/c mediapipe/c
          
          LINE=$(grep -n linux_opencv WORKSPACE | cut -d : -f1)
          LINE=$(($LINE + 2))
          sed -i ""$LINE"s;\"/usr\";\"$OPENCV_DIR\";" WORKSPACE

          sed -i 's;#"include/opencv4/opencv2/\*\*/\*.h\*";"include/opencv4/opencv2/\*\*/\*.h\*";g' third_party/opencv_linux.BUILD
          sed -i 's;#"include/opencv4/";"include/opencv4/";g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_core.so;'"$OPENCV_DIR"'/lib/libopencv_core.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_calib3d.so;'"$OPENCV_DIR"'/lib/libopencv_calib3d.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_features2d.so;'"$OPENCV_DIR"'/lib/libopencv_features2d.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_highgui.so;'"$OPENCV_DIR"'/lib/libopencv_highgui.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_imgcodecs.so;'"$OPENCV_DIR"'/lib/libopencv_imgcodecs.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_imgproc.so;'"$OPENCV_DIR"'/lib/libopencv_imgproc.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_video.so;'"$OPENCV_DIR"'/lib/libopencv_video.so;g' third_party/opencv_linux.BUILD
          sed -i 's;-l:libopencv_videoio.so;'"$OPENCV_DIR"'/lib/libopencv_videoio.so;g' third_party/opencv_linux.BUILD

        '';
        fetchAttrs.sha256 = "sha256-XIwZ0bd5P0dZQkJX2lZkJfR+lafagQg1vXi9G2HgEB8=";

        #Fixes build issue
        preBuild = ''
          export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wformat"
        '';

        buildAttrs.installPhase = ''
          ls
          mkdir -p $out
          mkdir -p $out/lib
          mkdir -p $out/include
          cp bazel-bin/mediapipe/c/libmediapipe.so "$out/lib"
          cp mediapipe/c/mediapipe.h "$out/include"

          for DIR in bazel-bin/mediapipe/modules/*; do
            MODULE=$(basename "$DIR")
            mkdir -p "$out/data/mediapipe/modules/$MODULE"

            for FILE in "$DIR"/*.binarypb; do
              cp "$FILE" "$out/data/mediapipe/modules/$MODULE/$(basename "$FILE")"
            done

            for FILE in "$DIR"/*.tflite; do
              cp "$FILE" "$out/data/mediapipe/modules/$MODULE/$(basename "$FILE")"
            done
          done
        '';
      };
    };
}
