classdef testND2reader < matlab.unittest.TestCase
    
    
    methods (Test)
        
        function testGetImage_noWarnings(test)
            
            NR = ND2reader('D:\Projects\nd2sdk-matlab\test.nd2');
            
            assertWarningFree(test, @() getImage(NR, 1));
            
        end
        
        
    end
    
    
end