pkgname=my-niri-desk
pkgver=0.1.0
pkgrel=1
pkgdesc="Opinionated niri + QuickShell desktop preset with bundled wayscrollshot"
arch=('x86_64')
url="https://github.com/yourname/my-niri-desk"
license=('custom')
options=('!debug')
depends=(
  'niri'
  'quickshell'
  'qt6-5compat'
  'qt6-wayland'
  'xwayland-satellite'
  'fcitx5'
  'fcitx5-chinese-addons'
  'pipewire'
  'wireplumber'
  'networkmanager'
  'bluez'
  'bluez-utils'
  'wl-clipboard'
  'grim'
  'slurp'
  'hyprpicker'
  'python'
  'python-psutil'
  'awww'
  'matugen'
  'imagemagick'
  'satty'
  'tesseract'
  'tesseract-data-chi_sim'
  'tesseract-data-eng'
  'ffmpeg'
  'wf-recorder'
  'libnotify'
  'hyprlock'
  'upower'
  'ttf-material-symbols-variable'
  'otf-font-awesome'
  'ttf-jetbrains-mono-nerd'
  'adwaita-icon-theme'
  'network-manager-applet'
  'blueman'
  'gnome-control-center'
  'kitty'
  'fuzzel'
  'nautilus'
  'nm-connection-editor'
  'pavucontrol'
  'power-profiles-daemon'
)
optdepends=(
  'playerctl: better media control integration'
  'cava: audio visualizer for lyrics/media panels'
  'noto-fonts-cjk: fallback CJK font set'
)
makedepends=(
  'cargo'
  'git'
)
install="${pkgname}.install"
source=(
  "wayscrollshot::git+https://github.com/jswysnemc/wayscrollshot.git"
)
sha256sums=('SKIP')

build() {
  cd "${srcdir}/wayscrollshot"
  cargo build --release
}

package() {
  install -dm755 "${pkgdir}/usr/bin"
  install -dm755 "${pkgdir}/usr/share/${pkgname}"
  install -dm755 "${pkgdir}/usr/share/doc/${pkgname}"

  install -m755 "${srcdir}/wayscrollshot/target/release/wayscrollshot" "${pkgdir}/usr/bin/wayscrollshot"
  install -m755 "${startdir}/scripts/my-niri-desk-apply" "${pkgdir}/usr/bin/my-niri-desk-apply"

  cp -a "${startdir}/payload/skel" "${pkgdir}/usr/share/${pkgname}/"
  find "${pkgdir}/usr/share/${pkgname}/skel" -type d -exec chmod 755 {} +
  find "${pkgdir}/usr/share/${pkgname}/skel" -type f -exec chmod 644 {} +
  find "${pkgdir}/usr/share/${pkgname}/skel/.config/niri/scripts" "${pkgdir}/usr/share/${pkgname}/skel/.config/quickshell/scripts" -type f -exec chmod 755 {} +

  cat > "${pkgdir}/usr/share/doc/${pkgname}/README.packaging" <<'EOF'
This package installs:
- /usr/bin/wayscrollshot
- /usr/bin/my-niri-desk-apply
- /usr/share/my-niri-desk/skel

Apply the desktop preset for the current user with:
  my-niri-desk-apply

Default wallpapers are shipped in:
  ~/.config/wallpaper
EOF
}
