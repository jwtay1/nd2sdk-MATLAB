classdef ND2reader
    %ND2READER  Class to read ND2 files
    %
    %  OBJ = ND2READER creates a new ND2reader object. The object can be
    %  used to read ND2 files.
    
    properties (SetAccess = private)
        
        filename
    
        height
        width
        
        sizeZ
        sizeC
        sizeT
        sizeXY
        
        numComponents
        bitsPerComp
        widthBytes
    end
    
    properties (Access = private)
        
        fileOpen = false;
        fileHandle;
        
        pictureStructPtr;
        
        cleanup;
        
        %Struct to hold metadata
        fileAttributes
        
        
    end
    
    methods
        
        function obj = ND2reader(varargin)
            %ND2READER  Constructor function
            %
            %  Checks for library files and loads the library on object
            %  creation. Also adds a cleanup function.
            
            %Load library files
            try
                if not(libisloaded('nd2readsdk'))
                    loadlibrary('nd2readsdk', 'Nd2ReadSdk.h')
                end
            catch ME
                if strcmp(ME.identifier, 'MATLAB:loadlibrary:FileNotFound')
                    %If a file not found error occured, write an error
                    %message directing the user to the ND2 SDK website.
                    error('ND2reader:LibraryFilesNotFound', ...
                        'Could not find the required library files. Please visit https://nd2sdk.com and download v1.1.0');
                else
                    %Rethrow the original error
                    rethrow(ME)
                end
            end
            
            %Specify a cleanup function
            %https://stackoverflow.com/questions/14057308/matlab-class-destructor-not-called-during-clear
            obj.cleanup = onCleanup(@()close(obj));
            
            %Open the image file (if specified)
            if ~isempty(varargin)
                if numel(varargin) == 1 && ischar(varargin{1})
                    obj = open(obj, varargin{1});
                else
                    error('ND2reader:IncorrectInput', ...
                        'Expected a string containing a single filename.');                    
                end
            end
            
        end
       
        function obj = open(obj, filename)
            %OPEN  Open an ND2 file for reading
            %
            %  OBJ = OPEN(OBJ, FILEPATH) will open the file specified for
            %  reading.
            %
            %  See also: close
            
            %Check that the file exists
            if ~exist(filename,'file')
                error('ND2reader:FileNotFound',...
                    'Could not find file %s. Provide the full filename or make sure the image folder is on the MATLAB path.',filename);
            end
            
            %Retrieve the full path to the file
            [fPath, fName, fExt] = fileparts(filename);
            
            if ~isempty(fPath)
                %Reconstruct the full path (this will correct any
                %system-dependent file separator strings)
                obj.filename = fullfile(fPath,[fName,fExt]);                
            else
                %Since the file must exist on the MATLAB path (we checked
                %this above), we can use which to determine the full path
                %to the file
                obj.filename = which(filename);
            end
            
            %Open the file
            fnamePtr = libpointer('voidPtr', [int8(obj.filename) 0]);
            obj.fileHandle = calllib('nd2readsdk', 'Lim_FileOpenForReadUtf8', fnamePtr);
            
            %Check if file was opened successfully
            if isNull(obj.fileHandle)
                error('ND2reader:openfile:FailedToOpen', ...
                    'Could not open file %s for reading. File not found or could be corrupted.', obj.filename)
            else
                obj.fileOpen = true;
            end
           
            %Read file metadata
            fileAttribJSON = fileGetAttributes(obj);
            fileAttribStruct = jsondecode(fileAttribJSON);
            
            %Populate file properties
            obj.width = fileAttribStruct.widthPx;
            obj.height = fileAttribStruct.heightPx;
            obj.bitsPerComp = fileAttribStruct.bitsPerComponentInMemory;
            obj.numComponents = fileAttribStruct.componentCount;
            obj.widthBytes = obj.width * obj.bitsPerComp * obj.bitsPerComp / 8;            
            
            %Create a pointer for the LIMPICTURE struct
            sm.uiWidth = fileAttribStruct.widthPx;
            sm.uiHeight = fileAttribStruct.heightPx;
            sm.uiBitsPerComp = fileAttribStruct.bitsPerComponentInMemory;
            sm.uiComponents = fileAttribStruct.componentCount;
            sm.uiWidthBytes = sm.uiWidth * sm.uiBitsPerComp * sm.uiBitsPerComp / 8;
            
            obj.pictureStructPtr = libpointer('s_LIMPICTURE', sm);

        end
        
        function I = getImage(obj, index)
            
            res = calllib('nd2readsdk', 'Lim_FileGetImageData', obj.fileHandle, index, obj.pictureStructPtr);
            
            if res < 0
                error('ND2reader:getImage:FailedToRead', ...
                    'Failed to read image file (error code: %.0f', res);                
            end
            
            pImageData = obj.pictureStructPtr.Value.pImageData;
            setdatatype(pImageData, 'uint16Ptr', obj.width * obj.height * obj.numComponents);
            
            I = pImageData.Value;
            I = reshape(I, obj.numComponents, obj.width, obj.height);
            
            %Have to rotate
            %Also colors is the first value - i.e. each channel is stored in sequence
            tmp = reshape(I(3, :, :), obj.width, obj.height);
            tmp = tmp';
            imshow(tmp, []);
            
        end
        
        function obj = close(obj)
            %CLOSE  Close the file
            %
            %  CLOSE(OBJ) closes the image file and releases memory. This
            %  function is called when the variable is cleared.            
            
            if obj.fileOpen
                calllib('nd2readsdk', 'Lim_DestroyPicture', obj.pictureStructPtr);
                calllib('nd2readsdk', 'Lim_FileClose', obj.fileHandle)
            end
            
            obj.fileHandle = [];
            
            %Clear all non-dependent properties to indicate that file is
            %closed
            C = metaclass(obj);
            P = C.Properties;
            for k = 1:length(P)
                if ~P{k}.Dependent
                    obj.(P{k}.Name) = [];
                end
            end
           
        end
        
        function index = getSeqIndexFromCoords(obj, coords)
            
%             LIMFILEAPI LIMBOOL Lim_FileGetSeqIndexFromCoords (
% LIMFILEHANDLE hFile,
% const LIMUINT * coords,
% LIMSIZE coordCount,
% LIMUINT * seqIdx )
% Converts coordinates into sequence index.

%             %Create a pointer for the output
             indexPtr = libpointer('uint32Ptr', 0);
            
            %Get the coordinate size
            sizeCoords = calllib('nd2readsdk', 'Lim_FileGetCoordSize', obj.fileHandle);
            
            res = calllib('nd2readsdk', 'Lim_FileGetSeqIndexFromCoords', ...
                obj.fileHandle,...
                coords,...
                uint64(sizeCoords), ...
                indexPtr);
            
            %If res == 0 then fail, otherwise success
            
            index = indexPtr.Value;           
            
        end
        
    end
    
    methods
        
        function jsonStr = fileGetAttributes(obj)
            %FILEGETATTRIBUTES  Get file attributes as a JSON string
            %
            %  J = FILEGETATTRIBUTES(OBJ) returns the file attributes as a
            %  JSON-formatted string J. The JSON string can be decoded
            %  using the MATLAB function jsondecode.
            %
            %  The metadata in the file attributes are always present in
            %  the ND2 file and provides necessary information on image
            %  data.
            %
            %  List of attributes:
            %
            %     bitsPerComponentInMemory - Bits allocated to hold each
            %                                component (channel)
            %     bitsPerComponentInMemory - Bits allocated to hold each
            %                                component
            %     bitsPerComponentSignificant - Bits effectively used by 
            %                                   each component (not used 
            %                                   bits must be zero)
            %     componentCount - Number of components in a pixel
            %     compressionLevel - (optional) If compression is used the 
            %                        level of compression
            %     compressionType - (optional) Type of compression: 
            %                       "lossless" or "lossy"
            %     heightPx - Height of the image
            %     pixelDataType - Underlying data type "unsigned" or 
            %                     "float"
            %     sequenceCount - Number of image frames in the file
            %     tileHeightPx - (optional) Suggested tile height if saved 
            %                    as tiled
            %     tileWidthPx - (optional) Suggested tile width if saved as
            %                   tiled
            %     widthBytes - Number of bytes from the beginning of one 
            %                  line to the next one
            %     widthPx - Width of the image
            %
            %  Example:
            %     %Read the attributes of the opened file
            %     str = fileGetAttributes(obj);
            %     
            %     %Convert the string into a struct
            %     attrib = jsondecode(str);
            %
            %  See also: jsondecode
            
            jsonStr = readMetadata(obj, 'attributes');
            
        end
        
        function jsonStr = fileGetExperiment(obj)
            %FILEGETEXPERIMENT  Retrieve experiment parameters
            %
            %  J = FILEGETEXPERIMENT(OBJ) returns the experiment parameters
            %  which describes how the acquisition was set up. This
            %  information is necessary for knowing the order that the
            %  images are stored in.
            
            jsonStr = readMetadata(obj, 'experiment');
            
        end
        
        function jsonStr = fileGetFrameMetadata(obj, frameIndex)
            %FILEGETFRAMEMETADATA  Retrieve metadata of current frame
            %
            %  J = FILEGETFRAMEMETADATA(OBJ, I) returns the metadata of the
            %  specified frame at index I.
            
            jsonStr = readMetadata(obj, 'frame', frameIndex);
            
        end
        
        function jsonStr = fileGetTextInfo(obj)
            %FILEGETTEXTINFO  Retrieve text metadata present in the file
            %
            %  J = FILEGETTEXTINFO(OBJ) returns text metadata present in
            %  the file.
            
            jsonStr = readMetadata(obj, 'textinfo');
            
        end
        
        function jsonStr = fileGetMetadata(obj)
            %FILEGETMETADATA  Retrieve file metadata
            %
            %  J = FILEGETMETADATA(OBJ) returns the metadata of the file.
            
            jsonStr = readMetadata(obj, 'metadata');
            
        end
        
    end
    
    methods
        
        function jsonStr = readMetadata(obj, type, varargin)
            %READMETADATA  Read metadata information
            %
            %
            %  S = READMETADATA(OBJ, TYPE)
            
            
            %Check file is open
            if isempty(obj.fileHandle)
                error('ND2reader:fileGetExperiment:FileNotOpen', ...
                    'Open a file first.');
            end
            
            switch lower(type)
                
                case 'attributes'
                    
                    %Read file attributes
                    strPtr = calllib('nd2readsdk', 'Lim_FileGetAttributes', obj.fileHandle);
                    
                    ptrLen = 500;
                    ptrLenIncrement = 500;
                
                case 'experiment'
                    
                    %Read experiment metadata
                    strPtr = calllib('nd2readsdk', 'Lim_FileGetExperiment', obj.fileHandle);
                    
                    ptrLen = 10000;
                    ptrLenIncrement = 5000;
                    
                case 'frame'
                    if isempty(varargin)
                        error('ND2reader:readMetadata:FrameIndexNotFound', ...
                            'Please specify a frame index to get metadata from.');                    
                    end
                    
                    strPtr = calllib('nd2readsdk', 'Lim_FileGetFrameMetadata', obj.fileHandle, uint32(varargin{1}));
                    
                    ptrLen = 5000;
                    ptrLenIncrement = 2500;
                    
                case 'textinfo'
                    
                    strPtr = calllib('nd2readsdk', 'Lim_FileGetTextinfo', obj.fileHandle);
                    
                    ptrLen = 5000;
                    ptrLenIncrement = 2500;
                    
                case 'metadata'
                    
                    %Read file metadata
                    strPtr = calllib('nd2readsdk', 'Lim_FileGetMetadata', obj.fileHandle);
                    
                    ptrLen = 5000;
                    ptrLenIncrement = 2000;
            end
                                
            %The strings can have variable lengths and there doesn't seem
            %to be a way to tell MATLAB how long they are, so loop until we
            %find a null character.
            strLen = [];
            
            while isempty(strLen)
                
                setdatatype(strPtr, 'int8Ptr', ptrLen);
                jsonStr = strPtr.Value;
                strLen = find(jsonStr == 0, 1, 'first') - 1;
                
                ptrLen = ptrLen + ptrLenIncrement;
            end
            
            %Truncate the char string to the first null value (0)
            jsonStr = char(jsonStr(1:strLen))';
            
            %Deallocate the pointer
            calllib('nd2readsdk', 'Lim_FileFreeString', strPtr);
            
        end
        
        
        
    end
    
    
end










