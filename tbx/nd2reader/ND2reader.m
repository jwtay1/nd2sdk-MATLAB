classdef ND2reader < handle
    %ND2READER  Class to read ND2 files
    %
    %  OBJ = ND2READER(filename) creates a new ND2reader object and opens
    %  the specified ND2 file for reading. This class uses the ND2 SDK
    %  available at https://nd2sdk.com.
    %
    %  OBJ = ND2reader creates an empty ND2reader object. An image file can
    %  be opened by using the method open.
    %
    %  Example:
    %
    %  %Open an image file called 'example.nd2'
    %  reader = ND2reader('example.nd2');
    %
    %  %Read and display the image at Z = 1, T = 3
    %  I = getImage(reader, 1, 3);
    %  imshow(I, [])
    %
    %  See also: open, getImage
        
    properties (SetAccess = private)
        
        filename
    
    end
    
    properties (Dependent)
        
        height
        width
        
        sizeZ
        sizeC
        sizeT
        sizeXY
        
        channelNames
        
        loopOrder  %Order that data is stored in

    end
    
    properties (Access = private)
        
        fileOpen logical = false;  %True = there is an open file
        
        fileHandle  %When file is opened, contains a lib.pointer object to the file handle
        pictureStructPtr  %When file is opened, contains a lib.s_LIMPICTURE object
        
        %Structs to hold necessary metadata
        fileAttributes  %File attributes (e.g. image height, width, number of channels)
        experimentParams  %Information about order of experiment, number of planes
        fileMetadata  %Information about the channels including name and emission wavelength
        
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
                    %Temporarily disable the C++ warnings that occur
                    s = warning;
                    warning('off', 'matlab:loadlibrary:cppoutput');                    
                    
                    [~, libWarn] = loadlibrary('nd2readsdk', 'Nd2ReadSdk.h'); %#ok<ASGLU>
                    
                    %Restore warning settings
                    warning(s);
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
            
%             %Specify a cleanup function
%             %https://stackoverflow.com/questions/14057308/matlab-class-destructor-not-called-during-clear
%             obj.cleanup = onCleanup(@()close(obj));
            
            %Open the image file (if specified)
            if ~isempty(varargin)
                if numel(varargin) == 1 && ischar(varargin{1})
                    open(obj, varargin{1});
                else
                    error('ND2reader:IncorrectInput', ...
                        'Expected a string containing a single filename.');                    
                end
            end
            
        end
       
        %--- Getters ---%
        function height = get.height(obj)
            
            if obj.fileOpen
                
                height = double(obj.fileAttributes.heightPx);
                
            else
                
                height = NaN;
                
            end
            
        end
        
        function width = get.width(obj)
            
            if obj.fileOpen
                
                width = double(obj.fileAttributes.widthPx);
                
            else
                
                width = NaN;
                
            end
            
        end
        
        function sizeC = get.sizeC(obj)
            
            if obj.fileOpen
                
                sizeC = double(obj.fileAttributes.componentCount);
                
            else
                
                sizeC = 0;
                
            end
            
        end
        
        function loopOrder = get.loopOrder(obj)
            
            if obj.fileOpen
                
                loopOrder = {obj.experimentParams.type};
                
            else
                
                loopOrder = '';
                
            end
            
            
        end
        
        function sizeT = get.sizeT(obj)
            
            if obj.fileOpen
                
                %Look for a 'TimeLoop' type
                types = {obj.experimentParams.type};
                loc = ismember(types, 'TimeLoop');
                
                if any(loc)
                    
                    sizeT = double(obj.experimentParams(loc).count);
                    
                else
                   
                    sizeT = 1;
                    
                end
                
            else
                
                sizeT = 0;
                
            end
            
        end
        
        function sizeZ = get.sizeZ(obj)
            
            if obj.fileOpen
                
                %Look for a 'ZStackLoop' type
                types = {obj.experimentParams.type};
                loc = ismember(types, 'ZStackLoop');
                
                if any(loc)
                    
                    sizeZ = double(obj.experimentParams(loc).count);
                    
                else
                    
                    sizeZ = 1;
                    
                end
                
            else
                
                sizeZ = 0;
                
            end
            
            
        end
        
        function sizeXY = get.sizeXY(obj)
            
            if obj.fileOpen
                
                %Look for a 'XYPosLoop' type
                types = {obj.experimentParams.type};
                loc = ismember(types, 'XYPosLoop');
                
                if any(loc)
                    
                    sizeXY = double(obj.experimentParams(loc).count);
                    
                else
                    
                    sizeXY = 1;
                    
                end
                
            else
                
                sizeXY = 0;
                
            end
            
        end
        
        function channelNames = get.channelNames(obj)
            
            if obj.fileOpen
                
                channelNames = cell(1, obj.sizeC);
                
                for iC = 1:obj.sizeC
                    channelNames{iC} = obj.fileMetadata.channels(iC).channel.name;                    
                end
                
            else
                
                channelNames = '';
                
            end
            
        end
        
        
        %--- File functions ---%
        
        function open(obj, filename)
            %OPEN  Open an ND2 file for reading
            %
            %  OPEN(OBJ, FILEPATH) will open the file specified for
            %  reading.
            %
            %  See also: close
            
            %Check if there is a current file open. If there is, close it
            %and open the new file.
            if obj.fileOpen
                
                close(obj);
                
            end
            
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
           
            %Populate file attributes
            fileAttribs = readMetadata(obj, 'attributes');
            obj.fileAttributes = jsondecode(fileAttribs);
            
            %Populate experiment parameters (acquisition loops)
            expParams = readMetadata(obj, 'experiment');
            obj.experimentParams = jsondecode(expParams);
            
            %Populate the metadata (channel information)
            fileMd = readMetadata(obj, 'metadata');
            obj.fileMetadata = jsondecode(fileMd);
            
            %Initialize the picture structure
            initializePicture(obj);

        end
        
        function close(obj)
            %CLOSE  Close the file
            %
            %  CLOSE(OBJ) closes the image file and releases memory. This
            %  function is called when the variable is cleared.            
            
            %Destroy any open pictures
            if ~isempty(obj.pictureStructPtr)
                
                calllib('nd2readsdk', 'Lim_DestroyPicture', obj.pictureStructPtr);
                
                obj.pictureStructPtr = [];
            end
            
            %Close any open file handles
            if ~isempty(obj.fileHandle)
                
                if isa(obj.fileHandle, 'lib.pointer') && ~isNull(obj.fileHandle)
                    calllib('nd2readsdk', 'Lim_FileClose', obj.fileHandle);
                end
                
                obj.fileHandle = [];
            end
            
            %Clear properties
            obj.filename = '';
            obj.fileOpen = false;
            
            %Struct to hold metadata
            obj.fileAttributes = [];
            obj.experimentParams = [];
            obj.fileMetadata = [];
            
        end
        
        %--- Image functions ---%
        
        function I = getImage(obj, varargin)
            %GETIMAGE  Get image
            %
            %  I = getImage(obj, index) returns the image plane specified
            %  by index.
            %
            %  I = getImage(obj, iZ, iT, iXY) returns the image at the
            %  coordinates specified.
            %
            %  The image I will contain all channels of the selected image
            %  plane.

            %Parse input parameter
            if numel(varargin) >= 2 && numel(varargin) <= 3
                
                %Convert the coordinates to index
                iZ = varargin{1};
                iT = varargin{2};
                
                if numel(varargin) == 3
                    iXY = varargin{3};
                end
                
                index = getSeqIndexFromCoords(obj, iZ, iT, iXY);
                
            elseif numel(varargin) == 1
                
                index = varargin{1};
                
            else
                
                error('ND2reader:getImage:InvalidArgument', ...
                    'Expected either 3 coordinates or a single index.');
                
            end
            
                        
            res = calllib('nd2readsdk', 'Lim_FileGetImageData', obj.fileHandle, index, obj.pictureStructPtr);
            
            if res < 0
                error('ND2reader:getImage:FailedToRead', ...
                    'Failed to read image file (error code: %.0f)', res);                
            end
            
            pImageData = obj.pictureStructPtr.pImageData;
                        
            I = pImageData;
            I = reshape(I, obj.sizeC, obj.width, obj.height);
            
            %Swap the order of the matrix to be height x width x channel
            I = permute(I, [2, 3, 1]);

        end
        
        function I = getPlane(obj, iZ, channel, iT, varargin)
            %GETPLANE  Get an image plane (channel)
            %
            %  I = GETPLANE(OBJ, iZ, iC, iT) returns the image at the
            %  coordinates specified. iZ is the Z-plane, iC is the channel,
            %  and iT is the timepoint.
            %
            %  I = GETPLANE(OBJ, iZ, iC, iT, iXY) allows the XY coordinate
            %  to be specified as well.
            %
            %  This function provides backwards compatibility for the
            %  BioFormatsImage toolbox. However, note that the ND2 SDK
            %  reads all channels in at once so it might be more efficient
            %  to use this capability.
            %
            %  See also: getImage           
            
            %Check if iXY is provided. If not, default to 1.
            if numel(varargin) == 1
                iXY = varargin{1};
            elseif numel(varargin) == 0
                iXY = 1;
            else
                error('ND2reader:getPlane:InvalidXYcoord', ...
                    'Invalid XY coordinate. Expected a single number');                
            end
            
            %Resolve channel name
            if ischar(channel)
                
                iC = find(ismember(obj.channelNames, channel));
                
                if isempty(iC)
                    error('ND2reader:getPlane:InvalidChannelName', ...
                        'Could not find a channel named %s.', ...
                        channel);
                end
            else
                iC = channel;
            end            
            
            %Get the full image
            I = getImage(obj, iZ, iT, iXY);
            
            %Return requested subset of channels
            I = I(:, :, iC);
                        
        end
        
        function delete(obj)
            %DELETE  Delete object
            %
            %  DELETE(OBJ) closes the file and releases resources by
            %  calling appropriate destructor functions. This function is
            %  called automaticallly by MATLAB when the variable is
            %  cleared.
            
            close(obj)
            
        end
        
        %--- Metadata ---%
        
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
        
        function deltaT = getTimeLoopPeriod(obj)
            %GETTIMELOOPPERIOD  Returns the time between frames in a time loop
            %
            %  T = GETTIMELOOPPERIOD(OBJ) returns the time loop period
            %  (time between frames) in seconds. This function returns
            %  a value if a 'TimeLoop' exists in the experiment, otherwise
            %  it throws a warning and returns NaN.
            %
            %  See also: fileGetExperiment
            
            if ~obj.fileOpen
                
                error('ND2reader:getTimeLoopPeriod:FileNotOpen', ...
                    'Open a file first.');
                
            end
            
            loc = ismember(obj.loopOrder, 'TimeLoop');
            
            if ~isempty(loc)
                
                deltaT = obj.experimentParams(loc).parameters.periodMs / 1000;                
                
            else
                
                warning('ND2reader:getTimeLoopPeriod:TimeLoopNotFound', ...
                    'This image file does not contain a time loop.');
                
                deltaT = NaN;
                
            end
            
        end
        
        function xyLoc = getXYlocation(obj)
            %GETXYLOCATION  Returns XY locations for a multipoint acquisition
            %
            %  S = GETXYLOCATION(OBJ) returns information about the PFS
            %  offset and the stage position in microns for a multipoint
            %  acquistion. If the image file does not contain a multipoint
            %  acquisition ('XYPosLoop'), a warning is thrown and the
            %  returned value will be NaN.
            %
            %  The returned value S will be a struct containing the
            %  following fields:
            %     stagePositionUm - Position of the point in microns
            %     pfsOffset - Perfect Focus offset
            %     name (optional) - Name of the point
            %
            %  See also: fileGetExperiment
            
            if ~obj.fileOpen
                
                error('ND2reader:getXYlocations:FileNotOpen', ...
                    'Open a file first.');
                
            end
            
            loc = ismember(obj.loopOrder, 'XYPosLoop');
            
            if ~isempty(loc)
                
                xyLoc = obj.experimentParams(loc).parameters.points;                
                
            else
                
                warning('ND2reader:getXYlocations:XYPosLoopNotFound', ...
                    'This image file does not contain multiple XY points.');
                
                xyLoc = NaN;
                
            end
            
        end
                
        function channelInfo = getChannelInfo(obj, channel)
            %GETCHANNELINFO  Returns metadata about the channel
            %
            %  S = GETCHANNELINFO(OBJ, CHANNEL) returns metadata about the
            %  specified channel.
            
            if ~obj.fileOpen
                
                error('ND2reader:getChannelInfo:FileNotOpen', ...
                    'Open a file first.');
                
            end
            
            %Resolve channel name
            if ischar(channel)
                
                iC = find(ismember(obj.channelNames, channel));
                
                if isempty(iC)
                    error('ND2reader:getChannelInfo:InvalidChannelName', ...
                        'Could not find a channel named %s.', ...
                        channel);
                end
                
            else
                
                iC = channel;
                
            end   
            
            channelInfo = obj.fileMetadata.channels(iC).channel;
            
        end
        
        function jsonStr = readMetadata(obj, type, varargin)
            %READMETADATA  Read metadata information
            %
            %  S = READMETADATA(OBJ, 'attributes') returns data about the
            %  file attributes such as image size and number of channels.
            %
            %  S = READMETADATA(OBJ, 'experiment') returns data about the
            %  acquisition settings such as number and type of loops.
            %
            %  S = READMETADATA(OBJ, 'textinfo') returns the text
            %  information about the image. This is similar
            %
            %  S = READMETADATA(OBJ, 'metadata') returns data about the
            %  channels including emission wavelength and microscope
            %  objective settings.
            %
            %  S = READMETADATA(OBJ, 'frame', F) returns metadata about the
            %  selected frame including channels, emission wavelength, and
            %  position. The information here is similar to 'metadata' but
            %  is specific to the frame. The frame can be specified in
            %  several different ways: If F is a single number, then the it
            %  is treated as the image sequence index. Alternatively, F can
            %  be the Z, T, and XY coordinates: S = READMETADATA(OBJ,
            %  'frame', iZ, iT, iXY).
            
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
                        
                    elseif numel(varargin) == 1
                        %Single index
                        index = varargin{1};                        
                        
                    elseif numel(varargin) > 1
                        %Coordinates - expect iZ, iT, (iXY - optional)
                        iZ = varargin{1};
                        iT = varargin{2};
                        
                        if numel(varargin) == 2
                            iXY = 1;
                        elseif numel(varargin) == 3
                            iXY = varargin{3};
                        else
                            error('ND2reader:readMetadata:TooManyCoordinates', ...
                                'Expected at most three coordinates: iZ, iT, iXY');
                        end
                        
                        index = getSeqIndexFromCoords(obj, iZ, iT, iXY);
                        
                    end
                    
                    strPtr = calllib('nd2readsdk', 'Lim_FileGetFrameMetadata', obj.fileHandle, uint32(index));
                    
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
    
    methods (Access = private)
        %These private methods are mostly the SDK functions translated into
        %MATLAB.
        %
        %Equivalent typedefs in MATLAB (libpointer)
        %
        %  LIMCHAR - uint8
        %  LIMCHAR * LIMSTR or LIMCHAR const * LIMCSTR - uint8Ptr or char array
        %  LIMWCHAR
        %  LIMWCHAR * LIMWSTR or LIMCHAR const * LIMWSTR
        %  LIMUINT - uint32
        %  LIMUINT64 - uint64
        %  LIMSIZE
        %  LIMINT - int32
        %  LIMBOOL
        %  LIMRESULT - uint8
        %  _LIMPICTURE LIMPICTURE - s_LIMPICTURE
        %  LIMFILEHANDLE - voidPtr
        %  See: https://www.mathworks.com/help/matlab/matlab_external/passing-arguments-to-shared-library-functions.html
        
        function initializePicture(obj)
            %INITIALIZEPICTURE  Initialize a pointer to the picture
            %
            %  INITIALIZEPICTURE(OBJ) initializes the pointer to the
            %  picture struct. The pointer is stored in the property ''.
            
            %Create a pointer for the LIMPICTURE struct
            sm.uiWidth = 0;
            sm.uiHeight = 0;
            sm.uiBitsPerComp = 0;
            sm.uiComponents = 0;
            sm.uiWidthBytes = 0;
            
            obj.pictureStructPtr = libstruct('s_LIMPICTURE', sm);
            
            calllib('nd2readsdk', 'Lim_InitPicture', ...
                obj.pictureStructPtr, ...
                obj.fileAttributes.widthPx, ...
                obj.fileAttributes.heightPx, ...
                obj.fileAttributes.bitsPerComponentInMemory, ...
                obj.fileAttributes.componentCount);
                
            setdatatype(obj.pictureStructPtr.pImageData, 'uint16Ptr', obj.width * obj.height * obj.sizeC);
            
        end
       
        function index = getSeqIndexFromCoords(obj, iZ, iT, iXY)
            %GETSEQINDEXFROMCOORDS  Get sequence index from coordinates
            %
            %  INDEX = GETSEQINDEXFROMCOORDS(OBJ, iZ, iT, iXY) returns
            %  the image sequence index from the coordinates supplied.
            %
            %  The order of the planes (or 'loops') can be determined by
            %  inspecting the experiment metadata. 
            
            %  Note: Channel doesn't actually matter since the SDK always
            %  returns every component
            
            %Set default XY position to 1. This is to maintain
            %compatibility with the BioFormatsImage toolbox.
            if nargin == 4
                iXY = 1;                
            end            
            
            %Reorder the coordinates
            coords = zeros(1, numel(obj.loopOrder));
            
            for ii = 1:numel(obj.loopOrder)
                
                switch obj.loopOrder{ii}
                    
                    case 'XYPosLoop'
                        
                        coords(ii) = iXY;
                        
                    case 'ZStackLoop'
                        
                        coords(ii) = iZ;
                        
                    case 'TimeLoop'
                        
                        coords(ii) = iT;
                end
                
            end
            
            %Create a pointer for the output
            indexPtr = libpointer('uint32Ptr', 0);
            
            %Get the coordinate size
            sizeCoords = calllib('nd2readsdk', 'Lim_FileGetCoordSize', obj.fileHandle);
            
            %Get sequence index
            % LIMBOOL Lim_FileGetSeqIndexFromCoords (
            %     LIMFILEHANDLE hFile,
            %     const LIMUINT * coords,
            %     LIMSIZE coordCount,
            %     LIMUINT * seqIdx )
            res = calllib('nd2readsdk', 'Lim_FileGetSeqIndexFromCoords', ...
                obj.fileHandle,...
                coords - 1,...  %Subtract 1 because C indexing starts from zero
                uint64(sizeCoords), ...
                indexPtr);
            
            %If res == 0 then fail, otherwise success
            if res <= 0
                error('ND2reader:getSeqIndexFromCoords:FailedToGetIndex', ...
                    'Failed to get index. Check that coordinates are valid.');                
            end
                        
            index = double(indexPtr.Value);
            
        end
        
    end
    
    
end










