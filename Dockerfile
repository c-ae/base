FROM ubuntu:impish
# impish is 2010; as stated in the paper. You may choose 'focal' or 'jammy' for 20.04 LTS or 22.10 LTS

RUN apt update && apt upgrade -y
# installing deps
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#general deps, fiat deps, cryptopt deps
RUN apt install -y git make vim tar \
        coq jq libcoq-ocaml-dev make ocaml-findlib \
        autoconf clang curl g++ gcc gnuplot-nox libtool nasm pkg-config poppler-utils tmux

ENV asmlineversion 1.2.2
RUN curl -L https://github.com/0xADE1A1DE/AssemblyLine/releases/download/v${asmlineversion}/assemblyline-${asmlineversion}.tar.gz |\
        tar -xzf- -C /tmp/ && \
        cd /tmp/assemblyline-${asmlineversion} && ./configure && \
        make CFLAGS=-O3 all install && \
        ldconfig

# get and install fiat-crypto
COPY ./fiat-crypto /root/fiat-crypto
RUN make -j2 -C /root/fiat-crypto standalone-ocaml

# get and install cryptopt
COPY ./cryptopt /root/cryptopt
RUN make -C /root/cryptopt/src install
WORKDIR /root/cryptopt/src

# get latest version of Fiat-Binaries
RUN cp /root/fiat-crypto/src/ExtractionOCaml/unsaturated_solinas /root/cryptopt/src/automate/fiat-bridge/ && \
        cp /root/fiat-crypto/src/ExtractionOCaml/word_by_word_montgomery /root/cryptopt/src/automate/fiat-bridge/

# run the cryptopt tests
RUN make check -C /root/cryptopt/src




