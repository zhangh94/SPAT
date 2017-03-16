function [ company, search] = APIParse( company, search )
%Function to parse the intrinio Web API for financial data
%   Input
%
%   Output
%
%

%% fill in years prior to 2009 (likely 2007-2009)

% set weboptions and API credentials
options = weboptions;
options.Username = search.API.Username;
options.Password = search.API.Password;


for i1 = search.APIStartYr:search.dataSetStartYr
    incompleteFlag = false;
    yearField = ['Y',num2str(i1)];
    
    % download all 3 financial statements for the year
    statements = {'balance_sheet','cash_flow_statement','income_statement'};
    data = [];
    for j1 = 1:length(statements);
        url = ['https://api.intrinio.com/financials/standardized?identifier=',...
            company.symbol,'&statement=',statements{j1},'&fiscal_year=',...
            num2str(i1),'&fiscal_period=FY'];
        tmp = webread(url,options);
        
        % throw warning if data is missing
        if (isempty(tmp.data))
            warning(['WEB API data unavailable for ',company.name,' ',...
                statements{j1},' Y', num2str(i1)]);
            incompleteFlag = true;
        end
        
        % group data together for parsing
        data = [data;tmp.data];
    end
    
    % parse and fill
    company.data.(yearField).data = DictionarySearch(data);
    data = company.data.(yearField).data;
    
    % supplement diluted eps
    company.data.(yearField).data.NumberOfDilutedSharesOutstanding = ...
        data.NetIncomeLoss/data.EarningsPerShareDiluted;
    
    % obtain liabilities data if liabilities is grouped with equity
    if (~data.Liabilities && data.LiabilitiesAndStockholdersEquity)
        company.data.(yearField).data.Liabilities = ...
            data.LiabilitiesAndStockholdersEquity - ...
            data.StockholdersEquity;
    end
    
end

%% fill in years after 2015
for i1 = search.endYr:search.currentYr
    incompleteFlag = false;
    yearField = ['Y',num2str(i1)];
    
    % download all 3 financial statements for the year
    statements = {'balance_sheet','cash_flow_statement','income_statement'};
    data = [];
    
    for j1 = 1:length(statements);
        url = ['https://api.intrinio.com/financials/standardized?identifier=',...
            company.symbol,'&statement=',statements{j1},'&fiscal_year=',...
            num2str(i1),'&fiscal_period=FY'];
        tmp = webread(url,options);
        
        % throw warning if data is missing
        if (isempty(tmp.data))
            warning(['WEB API data unavailable for ',company.name,' ',...
                statements{j1},' Y', num2str(i1)]);
            incompleteFlag = true;
        end
        
        % group data together for parsing
        data = [data;tmp.data];
    end
    
    if (incompleteFlag);continue;end; % if data is missing, go onto next year
    
    % parse and fill
    company.data.(yearField).data = DictionarySearch(data);
    data = company.data.(yearField).data;
    
    % supplement diluted eps
    company.data.(yearField).data.NumberOfDilutedSharesOutstanding = ...
        data.NetIncomeLoss/data.EarningsPerShareDiluted;
    
    % obtain liabilities data if liabilities is grouped with equity
    if (~data.Liabilities && data.LiabilitiesAndStockholdersEquity)
        company.data.(yearField).data.Liabilities = ...
            data.LiabilitiesAndStockholdersEquity - ...
            data.StockholdersEquity;
    end
    search.endYr = i1;
end



%% fill in past 4 quarters


end

