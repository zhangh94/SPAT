function [ outData ] = DictionarySearch( rawData )
%Function to parse a raw data set and compare it against the master dictionary
%   Input
%
%   Output
%
%

% create an empty struct
outData = struct();

% load in data dictionary and ignore comment lines
fid = fopen('Dictionary.txt', 'r');
rawText = textscan(fid,'%s','Delimiter','\n','CommentStyle','%');
rawText = rawText{1};
fclose(fid);

% split the data dictionary to try all possible names
exp = '\|';
splitDict = regexp(rawText, exp, 'split');

% handle raw cell data from SEC financial data sets
if (iscell(rawData))
    % TODO Combine this into the while loop?
    exp = '\t';
    splitStr = regexp(rawData,exp,'split');
    
    % load in data dictionary and ignore comment lines
    fid = fopen('Dictionary.txt', 'r');
    rawText = textscan(fid,'%s','Delimiter','\n','CommentStyle','%');
    rawText = rawText{1};
    fclose(fid);
    
    % split the data strings
    data = cell(length(splitStr),9);
    for j1 = 1:length(splitStr)
        data(j1,:) = splitStr{j1};
    end
    
    found = []; % clear the found array so it can become a cell
    % iterate through each dictionary entry to find data
    for j1 = 1:length(splitDict)
        exp = strcat(strcat('^',splitDict{j1}(2:end)),'$');
        
        % try each variation of dictionary entry
        for k1 = 1:length(exp)
            found(:,k1) = ~cellfun(@isempty,(regexpi(data(:,2),exp{k1})));
            if (sum(found(:,k1))) %if match is found
                % find the index
                row = find(found(:,k1));
                
                % TODO: Implement logic to determine appropriate field to store
                % store appropriate field (currently largest ndx value)
                outData.(splitDict{j1}{1}) = ...
                    str2double(splitStr{row(end)}(8));
                continue; % store only first match
            end
        end
        
        % set value to 0 if not found
        if (~isfield(outData,splitDict{j1}{1}))
            outData.(splitDict{j1}{1}) = false;
        end
        found = [];
    end
    
    % handle raw struct data
elseif (isstruct(rawData))
    
    for j1 = 1:length(splitDict)
        exp = splitDict{j1}(2:end);
        
        % try each variation of dictionary entry
        for k1 = 1:length(exp)
            
            % check if entry exists
            found = logical(strcmp({rawData.tag},exp{k1}));
            if (any(found)) %if match is found
                                
                % TODO: Implement logic to determine appropriate field to store
                % store appropriate field (currently largest ndx value)
                outData.(splitDict{j1}{1}) = ...
                    rawData(found).value;
                continue; % store only first match
            end
        end
        
        % set value to 0 if not found
        if (~isfield(outData,splitDict{j1}{1}))
            outData.(splitDict{j1}{1}) = false;
        end
        
    end
    
else
    warning(['Input into DictionarySearch is of unsupported type: ',class(rawData)]);
end

end

