function logMessage(level, context, formatStr, varargin)
%LOGMESSAGE Write a formatted event to console.
%   logMessage(level, context, formatStr, ...)
%
%   PseudoCT-style output:
%   [2026-07-31 11:35:23] SUCCESS Conversion completed
%
%   Levels: INFO, SUCCESS, WARN, ERROR

timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
message = sprintf(formatStr, varargin{:});
message = regexprep(message, '[\r\n]+', ' | ');

if isempty(context)
    fprintf(1, '[%s] %-7s %s\n', timestamp, upper(level), message);
else
    fprintf(1, '[%s] %-7s [%s] %s\n', timestamp, upper(level), context, message);
end
end
