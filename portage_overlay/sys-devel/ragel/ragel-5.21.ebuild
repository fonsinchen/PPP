# Copyright 2007 Tobias Josefowitz
# Distributed under the terms of the GNU General Public License v2

inherit toolchain-funcs

IUSE=""
DESCRIPTION="compiler/parser compiler"
HOMEPAGE="http://www.cs.queensu.ca/~thurston/ragel/"
SRC_URI="${HOMEPAGE}${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="x86"

DEPEND="virtual/libc"

src_compile() {
    if [ -x ./configure  ]; then
        econf --prefix="${D}/usr"
    fi
    if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]; then
        emake || die "emake failed"
    fi
}

src_install() {
	make install || die
}
