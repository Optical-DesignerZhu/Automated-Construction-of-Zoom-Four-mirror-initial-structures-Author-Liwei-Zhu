function cvdraw(view,s,z,savestr)
%CVDRAW draws the current lens in Matlab
%
%   function cvdraw(view,s,z,save);
%
%   INPUTS: view = type of view, 1=YZ, 2=XZ, 3=perspective (default=1)
%           s = surface range to be displayed (default=1:image)
%           z = zoom to plot, (default=1)
%           save = switch to save plot file 0=no, 1=yes, (default=0)
%
%   OUTPUT: Plot of current lens. Opens with the CodeV plot viewer.
%           If the save option is chosen, a plot file is saved in the
%           \graphics subdirectory of the toolkit.
%
%   See also:

if nargin<1, view = 1; end
if nargin<2, s=1:cvnum; end
if nargin<3, z=1; end
if nargin<4, savestr=0; end

view_type = {'PLC S1 YZ','PLC S1 XZ','VPT S1 -37.8 26.6'};
view = view_type{view};

filename = ['view_' datestr(now,'yyyymmdd_HHMMSS') '.plt'];

%cvcmd(['GRA ' cvpath '\graphics\' filename ]); 
cvcmd(['GRA '  filename ]); 
cvcmd(['vie; HAT  YES;AAP  YES;' view ';' ...
    'sur s' num2str(min(s)) '..' num2str(max(s)) ' z' num2str(z) ';' ...
    ' ;go;']);
cvcmd('GRA T');
%cvcmd(['GCV JPG ' cvpath '\graphics\' filename]);
cvcmd(['GCV PNG '  filename]);

pause(0.1);
%winopen([ cvpath '\graphics\' filename]);
% A = imread(['C:\CVUSER\' [filename(1:end-4) '.png']]);
% image(A);
% if savestr==0,
%     pause(1);
%delete( ['C:\CVUSER\' filename]);
end

