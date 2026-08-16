# Maintainer: danyuri <gratzyuri-glitch at users dot noreply dot github dot com>

pkgname=pkg-notify
pkgver=1.0.0
pkgrel=1
pkgdesc="Arch Linux package update notifier for pacman and AUR using systemd"
arch=('any')
url="https://github.com/gratzyuri-glitch/pkg-notify"
license=('MIT')
depends=('bash' 'pacman-contrib' 'libnotify' 'coreutils' 'util-linux' 'gawk')
optdepends=('paru: AUR helper (preferred if installed)'
            'yay: AUR helper (used if paru is not installed)')
source=("https://github.com/gratzyuri-glitch/pkg-notify/archive/v${pkgver}.tar.gz")
sha256sums=('REPLACE_WITH_UPDPKGSUMS')

package() {
    cd "$srcdir/$pkgname-$pkgver"

    install -Dm755 pkg-notify.sh "$pkgdir/usr/bin/pkg-notify"
    install -Dm644 pkg-notify.service "$pkgdir/usr/lib/systemd/user/pkg-notify.service"
    install -Dm644 pkg-notify.timer "$pkgdir/usr/lib/systemd/user/pkg-notify.timer"
    install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
