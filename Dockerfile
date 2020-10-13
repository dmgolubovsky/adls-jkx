# This Dockerfile builds an image with Ardour and some other goodies installed.


# Pull the base image and install the dependencies per the source package;
# this is a good approximation of what is needed.

from ubuntu:18.04 as base-ubuntu

run cp /etc/apt/sources.list /etc/apt/sources.list~
run sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
run apt -y update
run apt install -y --no-install-recommends software-properties-common apt-utils
run add-apt-repository ppa:apt-fast/stable
run apt -y update
run env DEBIAN_FRONTEND=noninteractive apt-get -y install apt-fast
run echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections
run echo debconf apt-fast/dlflag boolean true | debconf-set-selections
run echo debconf apt-fast/aptmanager string apt-get | debconf-set-selections

run echo "MIRRORS=( 'http://archive.ubuntu.com/ubuntu, http://de.archive.ubuntu.com/ubuntu, http://ftp.halifax.rwth-aachen.de/ubuntu, http://ftp.uni-kl.de/pub/linux/ubuntu, http://mirror.informatik.uni-mannheim.de/pub/linux/distributions/ubuntu/' )" >> /etc/apt-fast.conf

run apt-fast -y update && apt-fast -y upgrade

# Based on the dependencies, butld Ardour proper. In the end create a tar binary bundle.

from base-ubuntu as ardour

run apt-fast install -y libboost-dev libasound2-dev libglibmm-2.4-dev libsndfile1-dev
run apt-fast install -y libcurl4-gnutls-dev libarchive-dev liblo-dev libtag-extras-dev
run apt-fast install -y vamp-plugin-sdk librubberband-dev libudev-dev libnfft3-dev
run apt-fast install -y libaubio-dev libxml2-dev libusb-1.0-0-dev
run apt-fast install -y libpangomm-1.4-dev liblrdf0-dev libsamplerate0-dev
run apt-fast install -y libserd-dev libsord-dev libsratom-dev liblilv-dev
run apt-fast install -y libgtkmm-2.4-dev libsuil-dev libjack-jackd2-dev libcwiid-dev

run apt-fast install -y wget curl git

run mkdir /build-ardour
workdir /build-ardour

run git clone https://github.com/Ardour/ardour.git

workdir ardour

run git checkout 6.0

workdir /build-ardour/ardour
run ./waf configure --no-phone-home --with-backend=alsa,jack --optimize --ptformat --cxx11
run ./waf build -j 4
run ./waf install
run apt-fast install -y chrpath rsync unzip
run ln -sf /bin/false /usr/bin/curl
workdir tools/linux_packaging
run ./build --public --strip some
run ./package --public --singlearch

# Final assembly. Pull all parts together.

from base-ubuntu as adls

# No recommended and/or suggested packages here

run echo "APT::Get::Install-Recommends \"false\";" >> /etc/apt/apt.conf
run echo "APT::Get::Install-Suggests \"false\";" >> /etc/apt/apt.conf
run echo "APT::Install-Recommends \"false\";" >> /etc/apt/apt.conf
run echo "APT::Install-Suggests \"false\";" >> /etc/apt/apt.conf

# Install Ardour from the previously created bundle.

run mkdir -p /install-ardour
workdir /install-ardour
copy --from=ardour /build-ardour/ardour/tools/linux_packaging/Ardour-6.0.0-x86_64.tar .
run tar xvf Ardour-6.0.0-x86_64.tar
workdir Ardour-6.0.0-x86_64

# Install some libs that were not picked by bundlers - mainly X11 related.

run apt -y install gtk2-engines-pixbuf libxfixes3 libxinerama1 libxi6 libxrandr2 libxcursor1 libsuil-0-0
run apt -y install libxcomposite1 libxdamage1 liblzo2-2 libkeyutils1 libasound2 libgl1 libusb-1.0-0
run apt -y install libglibmm-2.4-1v5 libsamplerate0 libsndfile1 libfftw3-single3 libvamp-sdk2v5 \
                   libvamp-hostsdk3v5
run apt -y install liblo7 libaubio5 liblilv-0-0 libtag1v5-vanilla libpangomm-1.4-1v5 libcairomm-1.0-1v5
run apt -y install libgtkmm-2.4-1v5 libcurl3-gnutls libarchive13 liblrdf0 librubberband2 libcwiid1

# First time it will fail because one library was not copied properly.

run echo -ne "n\nn\nn\nn\nn\nn\nn\nn\n" | env NOABICHECK=1 ./.stage2.run
#run env NOABICHECK=1 ./.stage2.run || true

# Copy the missing libraries

run cp /usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/engines/libpixmap.so /opt/Ardour-6.0.0/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_x11_in_gtk2.so /opt/Ardour-6.0.0/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_qt5_in_gtk2.so /opt/Ardour-6.0.0/lib

# It will ask questions, say no.

#run echo -ne "n\nn\nn\nn\nn\nn\nn\nn\n" | env NOABICHECK=1 ./.stage2.run

# Delete the unpacked bundle

run rm -rf /install-ardour

# Install kx-studio packages

workdir /install-kx

# Install required dependencies if needed
run apt-fast -y install apt-transport-https gpgv wget

# Download package file
run wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_10.0.3_all.deb

# Install it
run dpkg -i kxstudio-repos_10.0.3_all.deb

run apt-fast -y update

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install kxstudio-meta-all a2jmidid jackd2 \
                        kxstudio-meta-audio-applications guitarix-lv2 avw.lv2 ir.lv2 lv2vocoder \
                        kxstudio-meta-audio-plugins kxstudio-meta-audio-plugins-collection \
                        vim alsa-utils zita-ajbridge zenity mda-lv2 padthv1-lv2 samplv1-lv2 \
                        so-synth-lv2 swh-lv2 synthv1-lv2 whysynth wsynth-dssi xsynth-dssi phasex \
                        iem-plugin-suite-vst hydrogen-drumkits hydrogen-data qmidiarp guitarix-common \
                        aj-snapshot amsynth

run rm -rf /install-kx

# Build Musescore 3.5 from git

from base-ubuntu as mscore

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install cmake qtbase5-dev qtwebengine5-dev qttools5-dev \
                        libqt5svg5-dev libqt5xmlpatterns5-dev qtquickcontrols2-5-dev lame libmp3lame-dev \
                        libqt5webenginecore5 qt5-default git qml-module-qtgraphicaleffects qml-module-qtquick-controls 

workdir /bld_mscore

run git clone https://github.com/musescore/MuseScore.git

workdir MuseScore

run git checkout v3.5

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install g++ libasound2-dev libjack-jackd2-dev libsndfile1-dev \
                        zlib1g-dev


workdir my-build-dir

# run grep -r "import QtQuick.Controls" ..

# run for f in `grep -lr "import QtQuick.Controls" ..` ; do sed -i 's/import QtQuick.Controls 2\.1/import QtQuick.Controls 2\.0/g' $f ; done

run sed -i 's/QuickTemplates2/\#QuickTemplates2/g' ../build/FindQt5.cmake


run cmake .. -DCMAKE_INSTALL_PREFIX=/install-mscore -DBUILD_PULSEAUDIO=OFF -DBUILD_PORTAUDIO=OFF \
             -DBUILD_TELEMETRY_MODULE=OFF -DBUILD_LAME=OFF

run cmake -j4 --build . 

run cmake --build . --target install

run rm /install-mscore/share/mscore-3.5/sound/MuseScore_General.sf3

run ls -l /install-mscore

# Build espeak from git

from base-ubuntu as bld-espeak

run apt-fast install -y autoconf automake libtool make libsonic-dev git

workdir /src
run git clone https://github.com/espeak-ng/espeak-ng.git
workdir espeak-ng
run git checkout 1.50
run ./autogen.sh
run ./configure --prefix=/usr/local
run make
run mkdir /install-espeak
run env DESTDIR=/install-espeak make install
run ls -l /install-espeak/usr/local

# Build SooperLooper from git

from ardour as sl

run env DEBIAN_FRONTEND=noninteractive apt-get install -y git build-essential libjack-jackd2-dev \
        libtool-bin libwxgtk3.0-gtk3-dev libncurses-dev
run mkdir /build-sl /install-sl
workdir /build-sl
run git clone https://github.com/essej/sooperlooper.git
workdir sooperlooper
run git checkout v1_7_4
run bash autogen.sh
run ./configure --prefix=/usr
run make
run make install DESTDIR=/install-sl

# Install sooperlooper

from adls as adls-sl

copy --from=sl /install-sl /

copy --from=mscore /install-mscore /usr/local

copy --from=bld-espeak /install-espeak/usr/local /usr/local

run env DEBIAN_FRONTEND=noninteractive apt-fast install --no-install-recommends -y \
        liblo7 libwxgtk3.0-gtk3-0v5 libsigc++-2.0-0v5 libsamplerate0 libasound2 libfftw3-double3 \
        librubberband2 libsndfile1 drumkv1 audacity locales less libsonic0 libqt5webenginewidgets5 \
        libqt5xmlpatterns5 libqt5webenginecore5 libqt5quick5 libqt5qml5 libqt5quickcontrols2-5 \
        libqt5quicktemplates2-5 libqt5quickwidgets5 qml-module-qtgraphicaleffects qml-module-qtquick-controls

run locale-gen en_US.UTF-8

# Finally clean up

run apt-fast clean
run apt-get clean autoclean
run apt-get autoremove -y
run rm -rf /var/lib/apt
run rm -rf /var/lib/dpkg
run rm -rf /var/lib/cache
run rm -rf /var/lib/log
run rm -rf /var/cache
run rm -rf /tmp/*
copy .qmidiarprc /root

from scratch

copy --from=adls-sl / /

