#!/usr/bin/env bash
# This script is released under MIT License
# Maintainer: HE Chong

# Thanks to Dave Dopson for the solution of obtaining script directory
function SCRIPT_LOC
{
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    echo "$DIR"
}

source `SCRIPT_LOC`/ENV_SETUP.sh

#---------------BEGIN OF SETUP
OPENSSL_DOWNLOAD_SOURCE="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
OPENSSL_PGP_SIGN_SOURCE="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.asc"
OPENSSL_SHASUM_SOURCE="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.sha${SHA_ALGORITHM}"

BUILD_DIR="./opensslBuild"
BUILD_LOG="build.log"
ERROR_LOG="error.log"

OPENSSL_CONFIGURE_ARGUMENTS=( ${CHOSEN_ARCH} "no-shared" \
    "--prefix=$PREFIX" "--openssldir=$PREFIX"\
    "no-ssl2" "no-ssl3" "no-dtls"\
    )

#---------------END OF SETUP

#---------------BEGIN ERROR CODE
ERR_FAILED_TO_DOWNLOAD=-1
ERR_CHECK_FAILE=-2
#---------------END OF ERROR

#---------------BEGIN SUPPORT FUNCTION
function CHECK_DOWNLOAD
{
    result=`echo $1 | xxd -r -p | grep "does not exist"`
    [ ! -z "result" ] && [ ! -z "$1" ]
}

SHASUM_PROG=( "shasum" "-a" "${SHA_ALGORITHM}" ) # default SHASUM Program
function CHECK_SHASUM # usage: CHECK_SHASUM <package_name> <correct_shasum>
{
    SHASUM_FROM_PACKAGE=`${SHASUM_PROG[@]} $1 | awk '{printf $1}'`
    if [ "$SHASUM_FROM_PACKAGE" != "$2" ]; then
        echo "    Package Integrity Check Failed."
        echo "        Correct SHASUM: $2"
        echo "        Package SHASUM: $SHASUM_FROM_PACKAGE"
        exit -1
    else
        echo "Package Integrity check passing"
    fi
}

PGP_KEY_SERVER="hkps://hkps.pool.sks-keyservers.net"
KEYRING_FILE="$BUILD_DIR/SVR_Keyring"
GPG_COMMAND=( "gpg" "--no-default-keyring" "--keyring" "$KEYRING_FILE" )
SLEEP_TIME=1
function CHECK_AUTHENTICITY # usage CHECK_AUTHENTICITY <package_name> <signature_name>
{
    echo
    ${GPG_COMMAND[@]} --verify $2 $1
    RV="$?"
    if [ "$RV" -eq "2" ]; then
        KEY_FINGERPRINT=`${GPG_COMMAND[@]} --verify $2 $1 2>&1 | grep "using RSA key" | awk '{printf $NF}'`
        echo "${GPG_COMMAND[@]} --keyserver ${PGP_KEY_SERVER} --recv-keys $KEY_FINGERPRINT"
        ${GPG_COMMAND[@]} --keyserver ${PGP_KEY_SERVER} --recv-keys $KEY_FINGERPRINT
        CHECK_AUTHENTICITY $1 $2
    elif [ "$RV" -eq "1" ]; then
        echo Signature Verification Failed.
        exit -1
    else
        echo Signature Verification Passed.
        echo WARNING: current solution DO NOT check the validity of the signer. Proceed at your own risk!!!
        echo "(Wait for $SLEEP_TIME seconds before proceed, cancel procedure with Ctrl-C...)"
        sleep $SLEEP_TIME
    fi
}

#---------------END OF SUPPORT FUNCTION

#---------------BEGIN OF PROCEDURE
echo
echo "Released Source Code Fetching:"
echo "Fetch ShaSum"
OPENSSL_SHASUM=`curl $OPENSSL_SHASUM_SOURCE 2>/dev/null | tr -d "\n"`
if CHECK_DOWNLOAD `echo "$OPENSSL_SHASUM" | xxd -p | tr -d "\n"` ; then 
    echo "ShaSum ($OPENSSL_SHASUM) fetched."
else
    printf "Failed to download ShaSum from:\
    \n    $OPENSSL_SHASUM_SOURCE \n" && exit -1
fi

if [ ! -d $BUILD_DIR ]; then
    echo "Create Directory $BUILD_DIR"
    mkdir -p $BUILD_DIR
fi

if [ "${REQUIRE_AUTHENTICITY}" -eq 1 ]; then
    echo "Fetch PGP Signature"
    curl $OPENSSL_PGP_SIGN_SOURCE 2>/dev/null > $BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz.asc
    if CHECK_DOWNLOAD  \
        `cat $BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz.asc | xxd -p | tr -d "\n"`
    then
        echo "Signature fetched:"
        cat $BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz.asc
    else
        printf "Failed to download Signature from:\
        \n    $OPENSSL_SHASUM_SOURCE \n" && exit -1
    fi
fi

echo
echo "Fetch package"
curl $OPENSSL_DOWNLOAD_SOURCE 2>/dev/null > $BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz

if CHECK_DOWNLOAD `cat $BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz | xxd -p | tr -d "\n"`
then
    echo OpenSSL Package fetched
    echo Check Package integrity
    CHECK_SHASUM "$BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz" ${OPENSSL_SHASUM}

    if [ "${REQUIRE_AUTHENTICITY}" -eq 1 ]; then
        echo Check Package authenticity
        CHECK_AUTHENTICITY "$BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz" "$BUILD_DIR/openssl-$OPENSSL_VERSION.tar.gz.asc"
    else
        echo "WARNING: Authenticity Verification bypassed by user setting!"
        sleep $SLEEP_TIME
    fi
else
    printf "Failed to download package from:\
    \n    $OPENSSL_DOWNLOAD_SOURCE \n" && exit -1
fi

echo
echo Build and install OpenSSL under prefix:
echo "    $PREFIX"
cd $BUILD_DIR
echo enter $BUILD_DIR
echo untar package
tar -xf openssl-$OPENSSL_VERSION.tar.gz || exit 1
echo enter $BUILD_DIR/openssl-$OPENSSL_VERSION
cd openssl-$OPENSSL_VERSION || exit 1

printf "#---------------Begin Configure\n" >../$BUILD_LOG
printf "#---------------Begin Configure\n" >../$ERROR_LOG
chmod +x ./Configure
CONFIG_CMD="./Configure ${OPENSSL_CONFIGURE_ARGUMENTS[@]}"
echo "$CONFIG_CMD"
echo "$CONFIG_CMD" >> ../$BUILD_LOG
./Configure ${OPENSSL_CONFIGURE_ARGUMENTS[@]} >>../$BUILD_LOG 2>>../$ERROR_LOG || exit 1
printf "#---------------End of Configure\n" >>../$BUILD_LOG
printf "#---------------End of Configure\n" >>../$ERROR_LOG

echo clean existing build
make clean >/dev/null
echo 

echo make dependencies
printf "\n#---------------Begin Make Depend\n" >>../$BUILD_LOG
printf "\n#---------------Begin Make Depend\n" >>../$ERROR_LOG
make depend >>../$BUILD_LOG 2>>../$ERROR_LOG || exit 1
printf "#---------------End of Make Depend\n" >>../$BUILD_LOG
printf "#---------------End of Make Depend\n" >>../$ERROR_LOG

echo make all
printf "\n#---------------Begin Make All\n" >>../$BUILD_LOG
printf "\n#---------------Begin Make All\n" >>../$ERROR_LOG
make -j$THREAD_COUNT all >>../$BUILD_LOG 2>>../$ERROR_LOG || exit 1
printf "#---------------End of Make ALL\n" >>../$BUILD_LOG
printf "#---------------End of Make All\n" >>../$ERROR_LOG

echo make install
printf "\n#---------------Begin Make Install\n" >>../$BUILD_LOG
printf "\n#---------------Begin Make Install\n" >>../$ERROR_LOG
make install >>../$BUILD_LOG 2>>../$ERROR_LOG || exit 1
printf "#---------------End of Make Install\n" >>../$BUILD_LOG
printf "#---------------End of Make Install\n" >>../$ERROR_LOG
echo
echo Installation Success.
echo OpenSSL successfully installed in:
echo "    $PREFIX"

