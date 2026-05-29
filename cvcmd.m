function [output,cmd] = cvcmd(cmd)
%CVCMD  sends command to CODE V command line
%
%   function  [output,cmd] = cvcmd(cmd)
%
%   cmd = CodeV command line script to be executed
%   Output is text returned from CodeV command line
%
%   See also CVON, CVOFF, CVDB, CVIN, CVOPEN, CVSAVE
%

global cv

%          invoke(CodeV,'Command',''); % Send null string to reset CV output
%output = invoke(CodeV,'Command',cmd);
output = cv.Command(cmd);
