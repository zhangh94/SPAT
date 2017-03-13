function [ company, search ] = DocumentSearch( search )
%Function to search the SEC EDGAR index files for document Accession #
%   Input
%
%   Output

% TODO: Reorder this into a class?

% check if company id is given via cik or name
if (search.cikFlag)
    ndx = 1;
    company.cik = search.param;
else
    ndx = 2;
    company.name = search.param;
end; % search by cik or name

% declare/intialize some variables
company.symbol = search.symbol;
tmpIndex = 'tmp_master.idx';
tmp = '';
qtr = 1; % sets the starting search quarter
endYr = search.endYr; % store expected endYr for financial data
tic
for i1 = search.startYr:1:endYr
    t1 = toc;
    found = false;
    % pull the master.idx file for the year
    yearField = ['Y',num2str(i1)];
    
    % TODO: If data is 
    % throw warning if data is not available (will still store locations)
    if ((i1+1) > search.dataLimit(1))
        warning(['Data for ',company.name, ' in ',yearField,...
            ' unavailable from financial dataset',...
            ' because expected filing date is ', ...
            num2str(i1+1),' QTR', num2str(qtr)]);
    end
    if ((i1+1) >= search.dataLimit(1) && qtr > search.dataLimit(2))
        warning(['Attempting to access future data in ', yearField, ...
            ' QTR', num2str(qtr),'. Skipping...']);
        continue;
    end
    % TODO: Encapsulate this into a function
    for j1 = 1:1:4
        
        % TODO: Stop the searching for the year once 10-k has been found. Store
        % QTR the statement was found in
        options = weboptions;
        options.Timeout = 30;
        websave(tmpIndex,...
            ['http://www.sec.gov/Archives/edgar/full-index/',num2str(i1 + 1),...
            '/QTR',num2str(mod((qtr + j1 - 2),4) + 1),'/master.idx'],options);
        
        % TODO: Encapsulate this into a function too
        % search for 10-k statement
        % read file in
        fid = fopen(tmpIndex,'r');
        rawText = textscan(fid,'%s','Delimiter','\n');
        rawText = rawText{1};
        fclose(fid);
        delete('tmp_master.idx');
        % Search for data with regex
        for k1 = 1:length(rawText)
            
            % split by delimiter
            exp = '\|';
            splitStr = regexp(rawText{k1}, exp, 'split');
            if (length(splitStr) < 5); continue; end; % skip invalid string
            exp = search.param;
            
            % TODO: Handle 10-K/A and 10-K/DE
            % search by cik or name
            if(~isempty(regexp(splitStr{ndx}, exp,'ONCE')) && ...
                    ~isempty(regexp(splitStr{3},...
                    ['^',search.filing,'$'],'ONCE')))
                
                % TODO: Why is CIK different/data is weird before 2001?
                if (i1 == search.startYr)
                    tmp = splitStr{(1 + 2) - ndx}; end;
                
                % store information
                company.data.(yearField).form = splitStr{3};
                company.data.(yearField).filingDate = datestr(splitStr{4});
                company.data.(yearField).rawTextLocation = ...
                    ['https://www.sec.gov/Archives/',splitStr{5}];
                
                % extract out ascension number
                exp = '\/';
                splitStr = regexp(splitStr{5}, exp, 'split');
                exp = '\.';
                splitStr = regexp(splitStr{4}, exp, 'split');
                company.data.(yearField).asn = splitStr{1};
                
                found = true;
                qtr = mod((qtr + j1 - 2),4) + 1; % update found quarter
                company.data.(yearField).filingQuarter = qtr;
                break;
            end
            % TODO: add search for previous 4 10-Q before startYr
        end
        if (found); break;end; % stop searching year if 10-K is found
       
    end
    
    % Check if company wasnt found
    if (~found); 
        warning(['Documents for company not found in ', yearField,...
            '. Company Name or CIK may be incorrect or company may not',...
            ' exist yet. Stopping Search...']);
        break;
    end
            
    t2 = toc;
    disp(['Document search for ', company.name, ' ', num2str(i1),... 
        ' completed in ',num2str(t2-t1),' seconds']);
    search.endYr = i1; % store last year data was sucessfully gathered
end

% store cik/name
if (search.cikFlag)
    company.name = tmp;
    search.company = tmp;
else
    company.cik = tmp;
    search.cik = tmp;
end;
end

