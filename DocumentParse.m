function [ company, search ] = DocumentParse( company, search )
%Function to parse the SEC data sets for company info
%   Input
%
%   Output
%

endYr = search.endYr;
tic
% yahooFinance = yahoo; % open connection to yahoo finance API;

% throw warning if data predates financial dataset
startYr = search.startYr;
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
    
    fid = fopen(filename,'r');
    rawText = textscan(fid,'%s','Delimiter','\n');
    rawText = rawText{1};
    asn = company.data.(yearField).asn;
    len = length(rawText);
    fclose(fid); % close file
        
    % loop through the raw data and keep relevant data
    while (~endNdx && ndx < len)
        exp = asn;
        found = regexp(rawText{ndx},exp);
        
        if (~isempty(found) && ~beginNdx); beginNdx = ndx; %scan 1st entry
        elseif (isempty(found) && beginNdx); endNdx = ndx - 1; %stop at last entry
        end
        ndx = ndx + 1; %increment counter
    end
    
    % throw warning if no data is found
    if (beginNdx == endNdx)
        warning(['Company not found for ',yearField]);
        continue;
    end
    
    % keep only relevant data
    rawData = rawText(beginNdx:endNdx);
    
    company.data.(yearField).data = DictionarySearch(rawData);
    
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
    
    % obtain extra information from web API
    % TODO: Encompass web API calls into a function
    
    
    %dividends per share declared
    if (~data.CommonStockDividendsPerShare)
        statement = 'income_statement';
        url = ['https://api.intrinio.com/financials/standardized?identifier=',...
            company.symbol,'&statement=',statement,'&fiscal_year=',...
            num2str(i1),'&fiscal_period=FY'];
        options = weboptions;
        options.Username = search.API.Username;
        options.Password = search.API.Password;
        
        dat = webread(url,options);
        company.data.(yearField).data.CommonStockDividendsPerShare = ...
            dat.data(logical(strcmp({dat.data.tag},...
            'cashdividendspershare'))).value;
    end
    
    search.endYr = i1;
    t2 = toc;
    disp(['Documents for ', company.name, ' ', num2str(i1),...
        ' parsed in ',num2str(t2-t1),' seconds']);
end


end


