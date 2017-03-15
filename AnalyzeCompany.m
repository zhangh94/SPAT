function [ company ] = AnalyzeCompany( company, search )
%Function to compute value investing benchmarks from company financial data
%   Input
%
%   Output
%
%

% TODO: F-Score, M-Score, Graham's Value
yDiv = 0; % years of continuous dividend payout
for i1 = search.analysisStartYr:search.endYr
    yearField = ['Y',num2str(i1)];
    data = company.data.(yearField).data;
    
    
    %% Value
    
    % basic market cap
    company.data.(yearField).value.basicMarketCap = ...
        data.MarketPriceMonthEnd * data.NumberOfSharesOutstandingBasic;
    
    % book value
    company.data.(yearField).value.bookValue = ...
        data.Assets - data.Goodwill - data.Liabilities;
    
    % fixed assets (long term assets)
    company.data.(yearField).value.fixedAssets = ...
        data.Assets - data.AssetsCurrent;
    
    % net assets
    company.data.(yearField).value.netAssets = ...
        data.Assets - data.Liabilities;
    
    % net current assets
    company.data.(yearField).value.netCurrentAssets = ...
        data.AssetsCurrent - data.LiabilitiesCurrent;
    
    % TODO: owners earnings
    
    % total capital
    company.data.(yearField).value.totalCapital = ...
        data.LongTermDebt + data.LongTermDebtCurrent + ...
        data.StockholdersEquity;
    
    % total market cap
    company.data.(yearField).value.totalMarketCap = ...
        data.MarketPriceMonthEnd * data.NumberOfDilutedSharesOutstanding;
    
    % working capital
    company.data.(yearField).value.workingCapital = ...
        data.AssetsCurrent - data.LiabilitiesCurrent;
    
    % store variable for easier access
    value = company.data.(yearField).value;
    
    %% Market Conditions
    
    % basic Price-Earnings Ratio
    company.data.(yearField).market.basicPERatio = ...
        data.MarketPriceMonthEnd/(data.EarningsPerShareBasic);
    
    % diluted Price-Earnings Ratio
    company.data.(yearField).market.dilutedPERatio = ...
        data.MarketPriceMonthEnd/(data.EarningsPerShareDiluted);
    
    if (data.DividendsCommonStock > 0)
        yDiv = yDiv + 1;
        
        % dividend yield at year end price
        company.data.(yearField).market.dividendYield = ...
        data.CommonStockDividendsPerShare/...
        data.MarketPriceMonthEnd;
            
    else
        yDiv = 0;
        company.data.(yearField).data.DividendsCommonStock = 0;
        data.DividendsCommonStock = 0;
    end;
        
    % store variable for easier access
    market = company.data.(yearField).market;
    
    %% Profitability
    
    % asset-liability ratio
    company.data.(yearField).profitability.assetLiabilityRatio = ...
        data.Assets/data.Liabilities;
    
    % book value per share (diluted)
    company.data.(yearField).profitability.bookValuePerShareDiluted = ...
        value.bookValue/data.NumberOfDilutedSharesOutstanding;
    
    % dividend payout rate
        company.data.(yearField).profitability.dividendPayoutRate = ...
        data.DividendsCommonStock/data.NetIncomeLoss;
    
    % net assets per share (diluted)
    company.data.(yearField).profitability.netAssetsPerShareDiluted = ...
        value.netAssets/data.NumberOfDilutedSharesOutstanding;
    
    % operating cash flow to total assets margin
    company.data.(yearField).profitability.operatingCashToAssetsRatio = ...
        data.NetCashFromOperating/data.Assets;
    
    % operating margin
    company.data.(yearField).profitability.operatingMargin = ...
        data.NetCashFromOperating/...
        data.SalesRevenueNet;
    
    % price-net asset ratio
    company.data.(yearField).profitability.priceNetAssetRatio = ...
        data.MarketPriceMonthEnd/(value.netAssets/...
        data.NumberOfDilutedSharesOutstanding);
    
    % price-book value ratio
    company.data.(yearField).profitability.priceBookValueRatio = ...
        data.MarketPriceMonthEnd/(value.bookValue/...
        data.NumberOfDilutedSharesOutstanding);
    
    % return on book value capital
    company.data.(yearField).profitability.returnOnBookValueCapital = ...
        data.NetIncomeLoss/value.bookValue;
    
    % return on net asset capital
    company.data.(yearField).profitability.returnOnNetAssetCapital = ...
        data.NetIncomeLoss/value.netAssets;
    
    % TODO: ROIC numerator is actually (netIncome - dividends) so factor in
    % preferred stock dividends
    % return on invested capital
    company.data.(yearField).profitability.returnOnInvestedCapital = ...
        (data.NetIncomeLoss - data.DividendsCommonStock)/...
        (value.workingCapital - data.CashAndCashEquivalents + ...
        value.fixedAssets);
    
    % return on sales
    company.data.(yearField).profitability.returnOnSales = ...
        data.NetIncomeLoss/data.SalesRevenueNet;
    
    % working capital to debt ratio
    company.data.(yearField).profitability.workingCaptialDebtRatio = ...
        value.workingCapital/data.LongTermDebt;
    
    %% Change From Last Year
    if (i1 ~= search.analysisStartYr)
        
        % store last year's data for easy access
        lYearData = company.data.(['Y',num2str(i1-1)]).data;
        
        % change in number of common shares
        company.data.(yearField).market.changeInCommonShares = ...
            (data.NumberOfSharesOutstandingBasic - ...
            lYearData.NumberOfSharesOutstandingBasic)/...
            lYearData.NumberOfSharesOutstandingBasic;
        
        % diluted EPS growth/loss
        company.data.(yearField).profitability.dilutedEPSGrowth = ...
            (data.EarningsPerShareDiluted - ...
            lYearData.EarningsPerShareDiluted)/...
            lYearData.EarningsPerShareDiluted;
        
        % earnings growth/loss
        company.data.(yearField).profitability.earningsGrowth = ...
            (data.NetIncomeLoss - ...
            lYearData.NetIncomeLoss)/...
            lYearData.NetIncomeLoss;
    end
    
    %% Current Year
    
    % TODO: Catch if endYr data unavailable
    if (i1 == search.endYr) %% TODO: Catch case if 3 years data unavailable
        
        % three year average earnings for most recent year
        company.data.(yearField).value.averageEarningsPast3Years = ...
            mean([data.NetIncomeLoss, ...
            lYearData.NetIncomeLoss, ...
            company.data.(['Y',num2str(i1 - 2)]).data.NetIncomeLoss]);
        
        % diluted PERatio using three year earnings
        company.data.(yearField).market.diluted3YearEarningsPERatio = ...
            data.MarketPriceMonthEnd/...
            (company.data.(yearField).value.averageEarningsPast3Years/...
            data.NumberOfDilutedSharesOutstanding);
        
        % earning power for most recent year
        company.data.(yearField).profitability.earningPower = ...
            1/company.data.(yearField).market.diluted3YearEarningsPERatio;
        
        % years of continuous dividend payment
        company.data.(yearField).profitability.yearsContinuousDividends = ...
            yDiv;
        
    elseif (i1 == search.analysisStartYr) 
        % TODO: Change this to use 3 years trailing data 
        % three year average earnings for beginning year
        company.data.(yearField).value.averageEarningsFuture3Years = ...
            mean([data.NetIncomeLoss, ...
            company.data.(['Y',num2str(i1 + 1)]).data.NetIncomeLoss, ...
            company.data.(['Y',num2str(i1 + 2)]).data.NetIncomeLoss]);
    end
    
    
end


% save company struct
filename = [company.name,'.mat'];
save(strrep(filename,' ','_'),'company');
end

