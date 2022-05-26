# ND2 Reader for MATLAB

Welcome to the ND2 Reader MATLAB Toolbox Project! 

The purpose of this project is to develop a MATLAB toolbox to read ND2 images from Nikon microscopes. This project utilizes the official ND2 SDK from Nikon Laboratory Imaging.

## Getting started

Visit the [releases](https://github.com/jwtay1/nd2sdk-MATLAB/releases) page and download the latest version. 

Note that the toolbox currently only supports 64-bit Windows. However, other version should be supported by changing the libraries (see below).

### Support for 32-bit Windows, Linux, and Mac

The code should support other operating systems. However, you will need to download and install the drivers from https://www.nd2sdk.com/.

> These instructions were written for 64-bit Windows. However, I expect that
> it should be applicable to other operating systems. The libraries will have a different extension
> e.g. on Linux they are .so files and on Mac they are .dylib files.

1. Go to https://www.nd2sdk.com/
   - If you are a new user, select "New user" and proceed to create a new account
   - Otherwise, log in to your account
2. Download the SDK files for your operating system
   - At time of writing (2022-05-26), **SDK v1.7.2.0** is available.
3. Extract the zip file to a temporary directory, then run the installer.
4. Navigate to the ``nd2readsdk-shared\bin`` sub-directory. There should be a number of .DLL files in the directory. Copy all the files from this directory to the ``ext`` directory.
5. In the ``include`` folder, copy the file ``Nd2ReadSdk.h`` to the ``ext`` directory.
6. Check that everything is running by reading the demo file
   ```matlab
   nd2reader_demo
   ```

## Development

1. In Git, clone the repository:
```
git clone git@gitlab.com:jwtay/nd2reader-matlab.git
```
2. In MATLAB, add the sub-directory ``nd2reader`` to the path:
``` matlab
cd nd2reader-matlab
p = genpath('nd2reader');
addpath(p)
```
3. Run the demo file
```
  nd2reader_demo
```

## Issues

Please report issues using the [Issue Tracker](https://github.com/jwtay1/nd2sdk-MATLAB/issues).