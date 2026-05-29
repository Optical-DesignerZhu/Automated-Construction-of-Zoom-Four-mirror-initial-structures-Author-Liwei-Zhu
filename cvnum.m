function [nums,numf,numw,numz] = cvnum()
%CVNUM  gets number of surfaces, field points, wavelengths, and zooms 
%       defined for the current lens in CodeV
%
%   function [nums,numf,numw,numz] = cvnum()
% 
%   See also CVLENSDATA 
%

global cv
%nums = invoke(CodeV,'GetSurfaceCount')-1; %want number of surfaces not including object
%numf = invoke(CodeV,'GetFieldCount');
%numw = invoke(CodeV,'GetWavelengthCount');
%numz = invoke(CodeV,'GetZoomCount');
nums = cv.SurfaceCount -1;
numf = cv.FieldCount ;
numw = cv.WavelengthCount;
numz = cv.ZoomCount;
if nargout<1
    disp(['Number of surfaces = ' int2str(nums)]);
    disp(['Number of fields   = ' int2str(numf)]);
    disp(['Number of waves    = ' int2str(numw)]);
    disp(['Number of zooms    = ' int2str(numz)]);
end

% Copyright ? 2004-2005 United States Government as represented by the Administrator of the 
% National Aeronautics and Space Administration.  No copyright is claimed in the United States 
% under Title 17, U.S. Code. All Other Rights Reserved.
% 
% Authors: Joseph M. Howard, Blair L. Unger, Mark E. Wilson, NASA
% Revision Date: 2007.08.22     