function [ company ] = MarketDataParse( company, search )
%Function to search for market data using the yahoo Finance API
%   Input
%
%   Output
%
%

yahooFinance = yahoo; % open connection to yahoo finance API;
for i1 = search.startYr:search.endYr
    
    yearField = ['Y',num2str(i1)];
    
    % store header location
    company.data.(yearField).headerLocation = ...
        ['https://www.sec.gov/Archives/edgar/data/',...
        company.cik,'/',...
        strrep(company.data.(yearField).asn,'-',''),...
        '/',company.data.(yearField).asn,'.hdr.sgml'];
    
    % TODO: Make this section way more robust
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
    
end
close(yahooFinance); %close connection to yahoo finance

end

