%Test

if not(libisloaded('nd2readsdk'))
    loadlibrary('nd2readsdk', 'Nd2ReadSdk.h')
end

libfunctionsview nd2readsdk
%%

%https://www.mathworks.com/help/matlab/matlab_external/working-with-pointers.html

p = libpointer('voidPtr', [int16('test.nd2') 0]);
fileHandle = calllib('nd2readsdk', 'Lim_FileOpenForRead', p);


[fileattrib, test] = calllib('nd2readsdk', 'Lim_FileGetAttributes', fileHandle);
setdatatype(fileattrib, 'int8Ptr', 500);

fileattrib_str = fileattrib.Value;

attrib_len = find(fileattrib_str == 0, 1, 'first') - 1;  %Truncate trailing zero
fileattrib_str = char(fileattrib_str(1:attrib_len));
fileattrib_val = jsondecode(fileattrib_str');

%Create an image pointer
sm.uiWidth = fileattrib_val.widthPx;
sm.uiHeight = fileattrib_val.heightPx;
sm.uiBitsPerComp = fileattrib_val.bitsPerComponentInMemory;
sm.uiComponents = fileattrib_val.componentCount;
sm.uiWidthBytes = sm.uiWidth * sm.uiBitsPerComp * sm.uiBitsPerComp / 8;


pPicture = libpointer('s_LIMPICTURE', sm);

%pPicture = libpointer;

sz = calllib('nd2readsdk', 'Lim_InitPicture', pPicture, ...
    fileattrib_val.widthPx, fileattrib_val.heightPx, ...
    fileattrib_val.bitsPerComponentInMemory, fileattrib_val.componentCount);


res = calllib('nd2readsdk', 'Lim_FileGetImageData', fileHandle, 0, pPicture);

pImageData = pPicture.Value.pImageData;
setdatatype(pImageData, 'uint16Ptr', sm.uiWidth * sm.uiHeight * sm.uiComponents);

image = pImageData.Value;
image = reshape(image, sm.uiComponents, sm.uiWidth, sm.uiHeight);

%Have to rotate
%Also colors is the first value - i.e. each channel is stored in sequence
tmp = reshape(image(3, :, :), sm.uiWidth, sm.uiHeight);
tmp = tmp';
imshow(tmp, []);

calllib('nd2readsdk', 'Lim_DestroyPicture', pPicture);


% LIMFILEAPI LIMSIZE Lim_InitPicture (
% LIMPICTURE *pPicture,
% LIMUINT width,
% LIMUINT height,
% LIMUINT bpc,
% LIMUINT components )


% LIMFILEAPI LIMRESULT Lim_FileGetImageData (
% LIMFILEHANDLE hFile,
% LIMUINT uiSeqIndex,
% LIMPICTURE *pPicture )

% img = libpointer(



%Lim_destroypicture (limpicture *ppicture)


calllib('nd2readsdk', 'Lim_FileClose', fileHandle)


%     % Metadata = calllib('Nd2ReadSdk','Lim_FileGetMetadata',FilePointer);
% %     % setdatatype(Metadata,'uint8Ptr',5000)
% %     % MetadataValue=Metadata.Value';
% %     % Metadatalength=find(MetadataValue==0,1);
% %     % MetadataJson=char(MetadataValue(1:Metadatalength-1));
% % 
% %     ImageStru.uiBitsPerComp = AttibutesStru.bitsPerComponentInMemory;
% %     ImageStru.uiComponents = AttibutesStru.componentCount;
% %     ImageStru.uiWidthBytes = AttibutesStru.widthBytes;
% %     ImageStru.uiHeight = AttibutesStru.heightPx;
% %     ImageStru.uiWidth = AttibutesStru.widthPx;
% %           
% %     if ImageStru.uiWidthBytes==ImageStru.uiWidth*ImageStru.uiComponents*ImageStru.uiBitsPerComp/8
% %     else
% %         warning('off','backtrace')
% %         warning('Image width is not fit the bytes of width. Reset image width.')
% %         warning('on','backtrace')
% %         ImageStru.uiWidth=ImageStru.uiWidthBytes/ImageStru.uiComponents/(ImageStru.uiBitsPerComp/8);
% %     end
% %     
% %     ImagePointer = libpointer('s_LIMPICTUREPtr', ImageStru);
% % 
% %     calllib('Nd2ReadSdk', 'Lim_InitPicture', ImagePointer, ImageStru.uiWidth, ImageStru.uiHeight, ImageStru.uiBitsPerComp, ImageStru.uiComponents);
% % 
% %     [~, ~, ImageReadOut] = calllib('Nd2ReadSdk', 'Lim_FileGetImageData', FilePointer, uint32(0), ImagePointer);
% %     setdatatype(ImageReadOut.pImageData, 'uint16Ptr', ImageStru.uiWidth * ImageStru.uiHeight * ImageStru.uiComponents)
% % end