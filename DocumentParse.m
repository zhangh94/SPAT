function [ company, search ] = DocumentParse( company, search )
%Function to parse the SEC data sets for company info
%   Input
%
%   Output
%

endYr = search.endYr;
tic
yahooFinance = yahoo; % open connection to yahoo finance API;

% throw warning if data predates financial dataset
if (search.startYr < search.dataSetStartYr)
    startYr = search.dataSetStartYr;
    search.analysisStartYr = startYr;
    
    warning(['Search Start Year, ',num2str(search.startYr),...
        ', predates the SEC financial data sets. ',...
        'Starting data collection in ',num2str(startYr),' instead...']);
end;

for i1 = startYr:1:endYr
    t1 = toc;
    beginNdx = 0;
    endNdx = 0;
    ndx = 1;
    
    % open dataset
    yearField = ['Y',num2str(i1)];
    filename = [num2str(i1+1),'_q',...
        num2str(company.data.(yearField).filingQuarter),...
        '_raw.txt'];
    
    % throw warning if data is not available (will still store locations)
    if (((i1+1) > search.dataLimit(1)) || ...
            (i1 == search.dataLimit(1) && qtr > search.dataLimit(2)))
        warning(['Data for ',company.name, ' in ',yearField,...
            ' unavailable. Document Parse will skip this year']);
        continue;
    end
    
    % store header location
    company.data.(yearField).headerLocation = ...
        ['https://www.sec.gov/Archives/edgar/data/',...
        company.cik,'/',...
        strrep(company.data.(yearField).asn,'-',''),...
        '/',company.data.(yearField).asn,'.hdr.sgml'];
    
    % TODO: Make this section way more robust
    % TODO: Get price on report period if its a business day
    % TODO: Account for price adjustments (splits, etc.)
    % store period of report
    headerText = textscan(...
        webread(company.data.(yearField).headerLocation),...
        '%s','Delimiter','\n');
    headerText = headerText{1};
    periodText = headerText{...
        logical(~cellfun(@isempty,regexpi(headerText,'<PERIOD>')))};
    company.data.(yearField).reportPeriod = datestr(datenum(...
        strrep(periodText,'<PERIOD>',''),'yyyymmdd'));
    
    % find last business day in report period
    company.data.(yearField).reportLastBusDay = ...
        datestr(lbusdate(...
        year(company.data.(yearField).reportPeriod), ...
        month(company.data.(yearField).reportPeriod)));
    
    % market price on last business day of period
    fdata = fetch(yahooFinance, company.symbol, 'Close', ...
        company.data.(yearField).reportLastBusDay);
    company.data.(yearField).data.MarketPriceMonthEnd = fdata(2);
    
    fid = fopen(filename,'r');
    rawText = textscan(fid,'%s','Delimiter','\n');
    rawText = rawText{1};
    asn = company.data.(yearField).asn;
    len = length(rawText);
    fclose(fid); % close file
    
    % TODO: Add warning/error if no data is found
    % loop through the raw data and keep relevant data
    while (~endNdx && ndx < len)
        exp = asn;
        found = regexp(rawText{ndx},exp);
        
        if (~isempty(found) && ~beginNdx); beginNdx = ndx; %scan 1st entry
        elseif (isempty(found) && beginNdx); endNdx = ndx - 1; %stop at last entry
        end
        ndx = ndx + 1; %increment counter
    end
    
    % keep only relevant data
    if (beginNdx == endNdx)
        warning(['Company not found for ',yearField]);
        continue;
    end
    rawData = rawText(beginNdx:endNdx);
    % TODO: parse relevant data and save information
    % TODO: Make this a function
    % TODO Combine this into the while loop?
    exp = '\t';
    splitStr = regexp(rawData,exp,'split');
    
    % load in data dictionary and ignore comment lines
    fid = fopen('Dictionary.txt', 'r');
    rawText = textscan(fid,'%s','Delimiter','\n','CommentStyle','%');
    rawText = rawText{1};
    fclose(fid);
    
    % split the data dictionary to try all possible names
    exp = '\|';
    splitDict = regexp(rawText, exp, 'split');
    
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
                company.data.(yearField).data.(splitDict{j1}{1}) = ...
                    str2double(splitStr{row(end)}(8));
                continue; % store only first match
            end
        end
        
        % set value to 0 if not found
        if (~isfield(company.data.(yearField).data,splitDict{j1}{1}))
            company.data.(yearField).data.(splitDict{j1}{1}) = false;
        end
        found = [];
    end
    
    % perform some spot adjustments for reporting inconsistencies
    data = company.data.(yearField).data;
    
    % obtain number of shares from EPS
    if (~data.NumberOfSharesOutstandingBasic && data.EarningsPerShareBasic)
        company.data.(yearField).data.NumberOfSharesOutstandingBasic = ...
            data.NetIncomeLoss/data.EarningsPerShareBasic;
    end
    
    % obtain diluted number of shares from diluted EPS
    if (~data.NumberOfDilutedSharesOutstanding && ...
            data.EarningsPerShareDiluted)
        company.data.(yearField).data.NumberOfDilutedSharesOutstanding = ...
            data.NetIncomeLoss/data.EarningsPerShareDiluted;
    end
    
    % obtain liabilities data if liabilities is grouped with equity
    if (~data.Liabilities && data.LiabilitiesAndStockholdersEquity)
        company.data.(yearField).data.Liabilities = ...
            data.LiabilitiesAndStockholdersEquity - ...
            data.StockholdersEquity;
    end
    
    % dividends per share declared
    if (~data.CommonStockDividendsPerShare && ...
            data.DividendsCommonStock)
        company.data.(yearField).data.CommonStockDividendsPerShare = ...
            data.DividendsCommonStock/...
            company.data.(yearField).data.NumberOfSharesOutstandingBasic;
    end
    
    search.endYr = i1;
    t2 = toc;
    disp(['Documents for ', company.name, ' ', num2str(i1),...
        ' parsed in ',num2str(t2-t1),' seconds']);
end

close(yahooFinance); %close connection to yahoo finance
end


