# Source from the normal distribution build. The caller sets UPDATER_ROOT.
UPDATE_SWIFT_FLAGS=()
UPDATE_SPM_FLAGS=()
if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    SPARKLE_DIR=$(python3 "$UPDATER_ROOT/prepare.py")
    UPDATE_SWIFT_FLAGS=(-D DIRECT_UPDATES -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks)
    UPDATE_SPM_FLAGS=(-Xswiftc -DDIRECT_UPDATES -Xswiftc -F -Xswiftc "$SPARKLE_DIR" -Xlinker -rpath -Xlinker @executable_path/../Frameworks)
fi
embed_updates() {
    if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
        python3 "$UPDATER_ROOT/configure.py" "$1" "$SPARKLE_DIR"
    fi
}
