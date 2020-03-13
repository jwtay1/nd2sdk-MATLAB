# ND2SDK for MATLAB

This project is to build a wrapper for the ND2 SDK to read proprietary 
Nikon microscope images. The SDK is available from Laboratory Imaging (see 
instructions below).

## Getting started

> These instructions were written for 64-bit Windows. However, I expect that
> it should be applicable to other operating systems.

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
3. Go to https://www.nd2sdk.com/
   - If you are a new user, select "New user" and proceed to create a new account
   - Otherwise, log in to your account
4. Download the SDK files for your operating system
   - At time of writing (2020-03-13), **SDK v1.1.0.0** is available for 32-bit and 64-bit windows, and 64-bit Linux
5. Extract the zip file to a temporary directory
6. Navigate to the ``Nd2ReadSdkStatic 1.1.0.0\bin`` sub-directory. There should be a number of .DLL files in the directory.
7. Copy the following to the files to the ``ext`` directory:
   - Nd2ReadSdk.h   
   - nd2readsdk.dll
   - limfile.dll   
   - tiff.dll
8. Check that everything is running by reading the demo file
```
  nd2reader_demo
```

## Issues

Please report issues using the [Issue Tracker](https://gitlab.com/jwtay/nd2reader-matlab/-/issues).