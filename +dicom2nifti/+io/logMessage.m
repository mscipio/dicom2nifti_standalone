function logMessage(level, context, formatString, varargin)
%LOGMESSAGE Write one timestamped, leveled console event.
%#ok<*DATST,*TNOW1> datestr/now are intentional for MATLAB R2019 support.

message = sprintf(formatString, varargin{:});
message = regexprep(message, '[\r\n]+', ' | ');
if isempty(context)
    fprintf(1, '[%s] %-7s %s\n', ...
        datestr(now, 'yyyy-mm-dd HH:MM:SS'), upper(level), message);
else
    fprintf(1, '[%s] %-7s [%s] %s\n', ...
        datestr(now, 'yyyy-mm-dd HH:MM:SS'), upper(level), context, message);
end
end
