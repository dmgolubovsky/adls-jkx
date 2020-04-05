# This Dockerfile builds an image with Ardour and some other goodies installed.
# Jack is omitted on purpose: ALSA gives better latency when playing on a MIDI keyboard
# and feeding MIDI to synth plugins.


# Pull the base image and install the dependencies per the source package;
# this is a good approximation of what is needed.

from ubuntu:18.04 as adls

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

# Install kx-studio packages

workdir /install-kx

# Install required dependencies if needed
run apt-fast -y install apt-transport-https gpgv wget

# Download package file
run wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_10.0.3_all.deb

# Install it
run dpkg -i kxstudio-repos_10.0.3_all.deb

run apt-fast -y update

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install kxstudio-meta-all \
                        kxstudio-meta-audio-applications guitarix-lv2 avw.lv2 ir.lv2 lv2vocoder \
                        kxstudio-meta-audio-plugins kxstudio-meta-audio-plugins-collection \
                        ardour vim alsa-utils zita-ajbridge zenity mda-lv2 padthv1-lv2 samplv1-lv2 \
                        so-synth-lv2 swh-lv2 synthv1-lv2 whysynth wsynth-dssi xsynth-dssi phasex \
                        iem-plugin-suite-vst hydrogen-drumkits hydrogen-data 

run rm -rf /install-kx

# Finally clean up

run apt-fast clean
run apt-get clean autoclean
run apt-get autoremove -y
run rm -rf /var/lib/apt
run rm -rf /var/lib/dpkg
run rm -rf /var/lib/cache
run rm -rf /var/lib/log
run rm -rf /tmp/*
copy .qmidiarprc /root

from scratch

copy --from=adls / /

