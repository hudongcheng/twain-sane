#!/bin/sh

DSTNAME=TWAIN-SANE-Interface
DSTVERSION=3.4

SDKVERSION=$1

if   [ "$SDKVERSION" = "10.9" ]; then
    MACOSX_DEPLOYMENT_TARGET=10.9
    MACOSX_DEPLOYMENT_TARGETX1=10.10
elif [ "$SDKVERSION" = "10.10" ]; then
    MACOSX_DEPLOYMENT_TARGET=10.10
    MACOSX_DEPLOYMENT_TARGETX1=10.11
else
    SDKVERSION=
    MACOSX_DEPLOYMENT_TARGET=default
    echo "Warning: No valid Deployment Target specified."
    echo "         Possible targets are: 10.9 and 10.10"
    echo "         The software will be built for the MacOSX version and"
    echo "         architecture currently running."
fi

[ -n "$SDKVERSION" ] && NEXT_ROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${SDKVERSION}.sdk
[ -n "$NEXT_ROOT"  ] && SDK_NEXT_ROOT=/usr/local/Developer/SDKs/MacOSX${SDKVERSION}.sdk

if [ -n "$NEXT_ROOT" ] && [ ! -e "$NEXT_ROOT" ]; then
    echo "Error: SDK build requested, but SDK build not installed."
    exit 1
fi

if [ ! -f $SDK_NEXT_ROOT/usr/local/lib/libintl.a ] ; then
    if [ -n "$SDKVERSION" ]; then
	echo "Error: You should install the gettext $SDKVERSION SDK package before"
	echo "       building $DSTNAME using the MacOSX $SDKVERSION SDK."
    else
	echo "Error: You should install the gettext package before building $DSTNAME."
    fi
    exit 1
fi

if [ ! -f $SDK_NEXT_ROOT/usr/local/lib/libusb.dylib ] ; then
    if [ -n "$SDKVERSION" ]; then
	echo "Error: You should install the libusb $SDKVERSION SDK package before"
	echo "       building $DSTNAME using the MacOSX $SDKVERSION SDK."
    else
	echo "Error: You should install the libusb package before building $DSTNAME."
    fi
    exit 1
fi

if [ ! -f $SDK_NEXT_ROOT/usr/local/lib/libsane.dylib ] ; then
    if [ -n "$SDKVERSION" ]; then
	echo "Error: You should install the sane-backends $SDKVERSION SDK package before"
	echo "       building $DSTNAME using the MacOSX $SDKVERSION SDK."
    else
	echo "Error: You should install the sane-backends package before building $DSTNAME."
    fi
    exit 1
fi

SRCDIR=`pwd`/src
BUILD=/tmp/$DSTNAME.build
DSTROOT=/tmp/$DSTNAME.dst

[ -e $BUILD ]   && (      rm -rf $BUILD   || exit 1 )
[ -e $DSTROOT ] && ( sudo rm -rf $DSTROOT || exit 1 )

cp -pr $SRCDIR $BUILD

(
    cd $BUILD

    ./Info.sh > Info.plist

    if   [ "$MACOSX_DEPLOYMENT_TARGET" = "10.9" ]; then
	xcodebuild -project SANE.ds.10.9.xcodeproj -configuration Release \
	    install DSTROOT=$DSTROOT
    elif [ "$MACOSX_DEPLOYMENT_TARGET" = "10.10" ]; then
	xcodebuild -project SANE.ds.10.10.xcodeproj -configuration Release \
	    install DSTROOT=$DSTROOT
    else
	xcodebuild -project SANE.ds.xcodeproj -configuration Release \
	    install DSTROOT=$DSTROOT
    fi
)

rm -rf $BUILD

sudo chown -Rh root:admin $DSTROOT
sudo chmod -R 775 $DSTROOT
sudo chmod 1775 $DSTROOT

PKG=`pwd`/../PKGS/$MACOSX_DEPLOYMENT_TARGET/$DSTNAME.pkg
[ -e $PKG ]        && ( rm -rf $PKG        || exit 1 )
[ -e $PKG.tar.gz ] && ( rm -rf $PKG.tar.gz || exit 1 )
mkdir -p ../PKGS/$MACOSX_DEPLOYMENT_TARGET

RESOURCEDIR=/tmp/$DSTNAME.resources
[ -e $RESOURCEDIR ] && ( rm -rf $RESOURCEDIR || exit 1 )
mkdir -p $RESOURCEDIR

(
    cd pkg/Resources
    for d in `find . -type d` ; do
	mkdir -p $RESOURCEDIR/$d
    done
    for f in `find . -type f -a ! -name .DS_Store -a ! -name '*.gif'` ; do
	sed -e s/@MACOSX_DEPLOYMENT_TARGET@/$MACOSX_DEPLOYMENT_TARGET/g \
	    -e s/@MACOSX_DEPLOYMENT_TARGETX1@/$MACOSX_DEPLOYMENT_TARGETX1/g \
	    -e s/@DSTVERSION@/$DSTVERSION/g \
	    < $f > $RESOURCEDIR/$f
    done
    cp -p *.gif $RESOURCEDIR
)

#  Remove the installation check if we don't use SDK
if [ -z "$SDKVERSION" ]; then
    sed '/<installation-check/,/<\/installation-check/d' \
	< $RESOURCEDIR/distribution.xml > $RESOURCEDIR/distribution.xml.tmp
    mv $RESOURCEDIR/distribution.xml.tmp $RESOURCEDIR/distribution.xml
fi

pkgbuild --root $DSTROOT --ownership recommended \
    --identifier se.ellert.twain-sane --version $DSTVERSION \
    /tmp/TWAIN-SANE-Interface.pkg

productbuild --distribution $RESOURCEDIR/distribution.xml \
    --identifier se.ellert.twain-sane --version $DSTVERSION \
    --resources $RESOURCEDIR --package-path /tmp $PKG

rm /tmp/TWAIN-SANE-Interface.pkg
rm -rf $RESOURCEDIR

sudo rm -rf $DSTROOT
