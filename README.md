# OpenSSL Utility Toolkit
A collection of shell script toolkit using OpenSSL.

## Install OpenSSL
File `OpenSSL_Install.sh` can be directly invoked to install OpenSSL, with its
behavior controlled by `ENV_SETUP.sh`. On invocation, `OpenSSL_Install`
downloads the user specified version of OpenSSL (source code) with its shasum
and signature from OpenSSL official website, then it will attempt to build it,
saving both build log and error log in build directory. User shall be
responsible to install all the prerequisites in the build environment, make
sure that the settings of `ENV_SETUP` is appropriate (especially `CHOSEN_ARCH`
and `PREFIX`) and verify that the build is successful.

For configurations, here is a description of the configurables in `ENV_SETUP`:
  * `OPENSSL_VERSION`: targetted version of OpenSSL to be installed
  * `SHA_ALGORITHM`: SHA Algorithm to be used for package integrity check, `1` or `256` is allowed
  * `CHOSEN_ARCH`: In some machine, architecture could be recognized wrongly. Hence we make it user's responsibility in specifying the architecture.
  * `THREAD_COUNT`: Number of thread to be used for OpenSSL building
  * `REQUIRE_AUTHENTICITY`: Whether the authenticity of the source code is to be verified.
  * `PREFIX`: Where the package is to be installed.
