%CVON starts the COM link between Matlab and CODE V
%      and generates the workspace variable 'CodeV'
%
%   See also CVOFF, CVCMD, CVDB, CVIN, CVOPEN, CVSAVE 

if exist('cv','var'), 
    disp('CODE V appears to be running.');
    disp('This version of the CODE V toolkit runs only one instance of CodeV.'); 
    return
end

global cv%put global variable onto workspace
%disp('Starting CODE V...');
cv= actxserver('CODEV.Application'); %start COM link
cv.StartingDirectory=cd; %set current directory as starting directory
cv.StartCodeV; %start session of CODE V
%cv.StopCodeV; %stop session of CODE V
%disp(['CodeV is now running version: ' cv.CodeVVersion]);

% Copyright ? 2004-2005 United States Government as represented by the Administrator of the 
% National Aeronautics and Space Administration.  No copyright is claimed in the United States 
% under Title 17, U.S. Code. All Other Rights Reserved.
% 
% Authors: Joseph M. Howard, Blair L. Unger, Mark E. Wilson, NASA
% Revision Date: 2007.08.22       