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
        
        numComponents
        bitsPerComp
        widthBytes
    end
    
    properties (Access = private)
        
        fileOpen = false;
        fileHandle;
        
        pictureStructPtr;
        
        cleanup;
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
           
            %Read file metadata (JSON)
            fileAttribPtr = calllib('nd2readsdk', 'Lim_FileGetAttributes', obj.fileHandle);
            setdatatype(fileAttribPtr, 'int8Ptr', 500);
            fileAttribJSON = fileAttribPtr.Value;
            calllib('nd2readsdk', 'Lim_FileFreeString', fileAttribPtr);  %Deallocate the pointer
            
            %Trim the char string to the first null value (0)
            attribLen = find(fileAttribJSON == 0, 1, 'first') - 1;
            fileAttribJSON = char(fileAttribJSON(1:attribLen));
            fileAttribStruct = jsondecode(fileAttribJSON');
            
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
        
        
    end
    
end