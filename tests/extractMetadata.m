%EXTRACTMETADATA  Extract and save file metadata
clearvars
clc

fn = 'D:\Projects\nd2sdk-matlab\test.nd2';
%fn = 'D:\Projects\2020Feb Photodamage\data\ChannelRed,Cy5,RFP_Seq0000.nd2';
%fn = 'D:\Projects\2019Dec Kralj Diauxic PEC\Data\20200317 100x_lacZ_glugal\20200317_100x_lacZ_glugal.nd2';


if not(libisloaded('nd2readsdk'))
    loadlibrary('nd2readsdk', 'Nd2ReadSdk.h')
end

p = libpointer('voidPtr', [int16(fn) 0]);
fileHandle = calllib('nd2readsdk', 'Lim_FileOpenForRead', p);

%File attributes
fileattrib = calllib('nd2readsdk', 'Lim_FileGetAttributes', fileHandle);
setdatatype(fileattrib, 'int8Ptr', 500);

fileattrib_str = fileattrib.Value;

attrib_len = find(fileattrib_str == 0, 1, 'first') - 1;  %Truncate trailing zero
fileattrib_str = char(fileattrib_str(1:attrib_len));
fileAttributes = jsondecode(fileattrib_str');

calllib('nd2readsdk', 'Lim_FileFreeString', fileattrib);
% 


%Experiment
fileexpt = calllib('nd2readsdk', 'Lim_FileGetExperiment', fileHandle);
setdatatype(fileexpt, 'int8Ptr', 10000);

fileexpt_str = fileexpt.Value;

fileexpt_len = find(fileexpt_str == 0, 1, 'first') - 1;  %Truncate trailing zero
fileexpt_str = char(fileexpt_str(1:fileexpt_len));
fileExperiment = jsondecode(fileexpt_str');

calllib('nd2readsdk', 'Lim_FileFreeString', fileexpt);

%Get frame metadata
filemd = calllib('nd2readsdk', 'Lim_FileGetFrameMetadata', fileHandle, uint8(0));

setdatatype(filemd, 'int8Ptr', 10000);

filemd_str = filemd.Value;

filemd_len = find(filemd_str == 0, 1, 'first') - 1;  %Truncate trailing zero
filemd_str = char(filemd_str(1:filemd_len));
frameMetadata = jsondecode(filemd_str');
calllib('nd2readsdk', 'Lim_FileFreeString', filemd);

%Get sequence count
fileInfo = calllib('nd2readsdk', 'Lim_FileGetTextinfo', fileHandle);

setdatatype(fileInfo, 'int8Ptr', 100000);

fileInfo_str = fileInfo.Value;

fileInfo_len = find(fileInfo_str == 0, 1, 'first') - 1;  %Truncate trailing zero
fileInfo_str = char(fileInfo_str(1:fileInfo_len));
fileTextInfo = jsondecode(fileInfo_str');

%Get frame metadata
filemd = calllib('nd2readsdk', 'Lim_FileGetMetadata', fileHandle);

setdatatype(filemd, 'int8Ptr', 50000);

filemd_str = filemd.Value;

filemd_len = find(filemd_str == 0, 1, 'first') - 1;  %Truncate trailing zero
filemd_str = char(filemd_str(1:filemd_len));
fileMetadata = jsondecode(filemd_str');
calllib('nd2readsdk', 'Lim_FileFreeString', filemd);




calllib('nd2readsdk', 'Lim_FileFreeString', fileInfo);

size = calllib('nd2readsdk', 'Lim_FileGetCoordSize', fileHandle);


calllib('nd2readsdk', 'Lim_FileClose', fileHandle);

save('metadata.mat', 'fileAttributes', 'fileExperiment', 'fileMetadata', 'frameMetadata', 'fileTextInfo');




