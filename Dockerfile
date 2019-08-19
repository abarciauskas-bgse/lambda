FROM lambci/lambda:build-python3.7 as builder

ARG http_proxy
ARG CURL_VERSION=7.63.0
ARG GDAL_VERSION=3.0.1
ARG GEOS_VERSION=3.7.2
ARG PROJ_VERSION=6.1.1
ARG LASZIP_VERSION=3.4.1
ARG GEOTIFF_VERSION=1.5.1
ARG PDAL_VERSION=master
ARG ENTWINE_VERSION=2.1.0
ARG DESTDIR="/build"
ARG PREFIX="/usr"
ARG PARALLEL=2


RUN \
  rpm --rebuilddb && \
  yum makecache fast && \
  yum install -y \
    automake16 \
    libpng-devel \
    nasm wget tar zlib-devel curl-devel zip libjpeg-devel rsync git ssh bzip2 automake \
    jq-libs jq-devel jq xz-devel openssl-devel ninja-build wget \
        glib2-devel libtiff-devel pkg-config libcurl-devel;   # required for pkg-config



RUN \
    yum install -y iso-codes && \
    curl -O http://vault.centos.org/6.5/SCL/x86_64/scl-utils/scl-utils-20120927-11.el6.centos.alt.x86_64.rpm && \
    curl -O http://vault.centos.org/6.5/SCL/x86_64/scl-utils/scl-utils-build-20120927-11.el6.centos.alt.x86_64.rpm && \
    curl -O http://mirror.centos.org/centos/6/extras/x86_64/Packages/centos-release-scl-rh-2-3.el6.centos.noarch.rpm && \
    curl -O http://mirror.centos.org/centos/6/extras/x86_64/Packages/centos-release-scl-7-3.el6.centos.noarch.rpm && \
    rpm -Uvh *.rpm  && \
    rm *.rpm &&  \
    yum install -y devtoolset-7-gcc-c++ devtoolset-7-make devtoolset-7-build ;

SHELL [ "/usr/bin/scl", "enable", "devtoolset-7"]

RUN gcc --version


RUN \
    wget https://github.com/Kitware/CMake/releases/download/v3.15.1/cmake-3.15.1.tar.gz \
    && tar -zxvf cmake-3.15.1.tar.gz \
    && cd cmake-3.15.1 \
    && ./bootstrap --parallel=${PARALLEL} --prefix=/usr \
    && make -j ${PARALLEL} \
    && make install DESTDIR=/ \
    && cd / \
    && rm -rf cmake*


RUN git clone https://github.com/LASzip/LASzip.git laszip \
    && cd laszip \
    && git checkout ${LASZIP_VERSION} \
    && cmake  \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr/ \
        -DCMAKE_BUILD_TYPE="Release" \
     .  \
    && ninja -j ${PARALLEL} \
    && ninja install \
    && DESTDIR=/ ninja install \
    && cd / \
    && rm -rf laszip*



RUN \
    wget http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 && \
    tar xjf geos*bz2 && \
    cd geos*  \
    && cmake  \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr/ \
        -DCMAKE_BUILD_TYPE="Release" \
     .  \
    && ninja -j ${PARALLEL} \
    && ninja install \
    && DESTDIR=/ ninja install \
    && cd / \
    && rm -rf geos*

RUN git clone https://github.com/OSGeo/PROJ.git --branch ${PROJ_VERSION} proj \
    && cd proj \
    && ./autogen.sh \
    && ./configure --prefix=/usr \
    && make -j ${PARALLEL} \
    && make install \
    && DESTDIR=/ make install \
    && cd / \
    && rm -rf /proj*

RUN git clone --branch master https://github.com/OSGeo/libgeotiff.git --branch ${GEOTIFF_VERSION} \
    && cd libgeotiff/libgeotiff \
    && ./autogen.sh \
    && ./configure --prefix=/usr --with-proj=/usr \
    && make -j ${PARALLEL} \
    && make install \
    && DESTDIR=/ make install \
    && cd / \
    && rm -rf /libgeotiff*


RUN git clone --branch release/ https://github.com/OSGeo/gdal.git --branch v${GDAL_VERSION} \
    &&    cd gdal/gdal \
    && ./configure --prefix=/usr \
            --mandir=/usr/share/man \
            --includedir=/usr/include/gdal \
            --with-threads \
            --with-grass=no \
            --with-hide-internal-symbols=yes \
            --with-rename-internal-libtiff-symbols=yes \
            --with-rename-internal-libgeotiff-symbols=yes \
            --with-libtiff=/usr/ \
            --with-geos=/usr/bin/geos-config \
            --with-geotiff=/usr \
            --with-proj=/usr \
            --with-ogdi=no \
            --with-curl \
            --with-ecw=no \
            --with-mrsid=no \
    && make -j ${PARALLEL} \
    && make install \
    && DESTDIR=/ make install \
    && cd / \
    && rm -rf /gdal*


RUN \
    wget https://github.com/facebook/zstd/releases/download/v1.4.2/zstd-1.4.2.tar.gz \
    && tar zxvf zstd-1.4.2.tar.gz \
    && cd zstd-1.4.2/build/cmake \
    && mkdir -p _build \
    && cd _build \
    && cmake  \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr/ \
        -DCMAKE_BUILD_TYPE="Release" \
     ..  \
    && ninja -j ${PARALLEL} \
    && ninja install \
    && DESTDIR=/ ninja install \
    && cd / \
    && rm -rf zstd*

RUN \
    wget http://apache.mirrors.hoobly.com//xerces/c/3/sources/xerces-c-3.2.2.tar.gz \
    && tar zxvf xerces-c-3.2.2.tar.gz \
    && cd xerces-c-3.2.2 \
    && mkdir -p _build \
    && cd _build \
    && cmake .. \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
    && ninja -j ${PARALLEL} \
    && ninja install \
    && DESTDIR= ninja install \
    && cd / \
    && rm -rf xerces*

RUN \
    git clone https://github.com/PDAL/PDAL.git --branch ${PDAL_VERSION} \
    && cd PDAL \
    && git checkout $PDAL_VERSION \
    && mkdir -p _build \
    && cd _build \
    && cmake .. \
        -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="-std=c++11" \
        -DCMAKE_MAKE_PROGRAM=make \
        -DBUILD_PLUGIN_I3S=ON \
        -DBUILD_PLUGIN_E57=ON \
        -DWITH_LASZIP=ON \
        -DWITH_ZSTD=ON \
        -DCMAKE_LIBRARY_PATH:FILEPATH="$DESTDIR/usr/lib" \
        -DCMAKE_INCLUDE_PATH:FILEPATH="$DESTDIR/usr/include" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DWITH_TESTS=OFF \
        -DCMAKE_INSTALL_LIBDIR=lib \
    && make  -j ${PARALLEL} \
    && make  install \
    && make install DESTDIR=/ \
    && cd / \
    && rm -rf pdal*

RUN \
    git clone https://github.com/connormanning/entwine.git --branch ${ENTWINE_VERSION} \
    && cd entwine \
    && mkdir -p _build \
    && cd _build \
    && cmake -G "Ninja" \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release .. \
    && ninja -j ${PARALLEL} \
    && ninja install \
    && DESTDIR=/ ninja install \
    && cd / \
    && rm -rf entwine*

RUN rm /build/usr/lib/*.la ; rm /build/usr/lib/*.a
RUN rm /build/usr/lib64/*.a
RUN ldconfig
ADD package-pdal.sh /


#            --disable-driver-airsar \
#            --disable-driver-arg  \
#            --disable-driver-blx  \
#            --disable-driver-bsb \
#            --disable-driver-cals \
#            --disable-driver-ceos \
#            --disable-driver-ceos2 \
#            --disable-driver-coasp \
#            --disable-driver-cosar \
#            --disable-driver-ctg \
#            --disable-driver-dimap \
#            --disable-driver-elas \
#            --disable-driver-ingr \
#            --disable-driver-jdem \
#            --disable-driver-r \
#            --disable-driver-pds \
#            --disable-driver-prf \
#            --disable-driver-rmf \
#            --disable-driver-safe \
#            --disable-driver-saga \
#            --disable-driver-sigdem \
#            --disable-driver-sgi \
#            --disable-driver-zmap \
#            --disable-driver-cad \
#            --disable-driver-dgn \
#            --disable-driver-edigeo \
#            --disable-driver-geoconcept \
#            --disable-driver-georss \
#            --disable-driver-gtm \
#            --disable-driver-htf \
#            --disable-driver-jml \
#            --disable-driver-openair \
#            --disable-driver-rec \
#            --disable-driver-segukooa \
#            --disable-driver-segy \
#            --disable-driver-selafin \
#            --disable-driver-xplane \
#            --disable-driver-eeda \
#            --disable-driver-plmosaic \
#            --disable-driver-rda \
#            --disable-driver-vdv \
#            --disable-driver-sxf \
#            --disable-driver-sua \
#            --disable-driver-amigocloud \
#            --disable-driver-daas  \
#            --disable-driver-elastic  \
#            --disable-driver-gft  \
#            --disable-driver-ngw  \
#            --disable-driver-plscenes  \
#            --disable-driver-rasterlite  \
#            --disable-driver-vfk  \

