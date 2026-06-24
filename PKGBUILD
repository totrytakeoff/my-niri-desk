pkgname=my-niri-desk
pkgver=0.2.0
pkgrel=2
pkgdesc="Opinionated niri + QuickShell desktop preset"
arch=('x86_64')
url="https://github.com/totrytakeoff/my-niri-desk"
license=('custom')
options=('!debug')
depends=(
  'niri'
  'quickshell'
  'qt6-5compat'
  'qt6-wayland'
  'xwayland-satellite'
  'wayscrollshot-bin'
  'fcitx5'
  'fcitx5-chinese-addons'
  'pipewire'
  'wireplumber'
  'networkmanager'
  'bluez'
  'bluez-utils'
  'wl-clipboard'
  'cliphist'
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
  'wtype: inject Ctrl+V into native Wayland apps from clipboard history'
  'xdotool: inject Ctrl+V into X11 and some XWayland apps from clipboard history'
)
install="${pkgname}.install"
source=()
sha256sums=()

package() {
  install -dm755 "${pkgdir}/usr/bin"
  install -dm755 "${pkgdir}/usr/share/${pkgname}"
  install -dm755 "${pkgdir}/usr/share/doc/${pkgname}"

  install -m755 "${startdir}/scripts/my-niri-desk-apply" "${pkgdir}/usr/bin/my-niri-desk-apply"
  install -m755 "${startdir}/scripts/configure-desktop-oomd.sh" "${pkgdir}/usr/bin/configure-desktop-oomd"
  ln -s "/usr/share/${pkgname}/skel/.config/my-desk/bin/desk-run" "${pkgdir}/usr/bin/desk-run"

  cp -a "${startdir}/payload/skel" "${pkgdir}/usr/share/${pkgname}/"
  find "${pkgdir}/usr/share/${pkgname}/skel" -type d -exec chmod 755 {} +
  find "${pkgdir}/usr/share/${pkgname}/skel" -type f -exec chmod 644 {} +
  find "${pkgdir}/usr/share/${pkgname}/skel/.config/my-desk" -type f -exec chmod 755 {} +

  cat > "${pkgdir}/usr/share/doc/${pkgname}/README.packaging" <<'EOF'
This package installs:
- /usr/bin/my-niri-desk-apply
- /usr/bin/configure-desktop-oomd
- /usr/bin/desk-run
- /usr/share/my-niri-desk/skel

Apply the desktop preset for the current user with:
  my-niri-desk-apply

Apply the desktop oomd policy with:
  sudo configure-desktop-oomd --apply

Default wallpapers are shipped in:
  ~/.config/wallpaper
EOF
}
