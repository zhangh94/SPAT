classdef CompanyEval < CompanySearch
    %COMPANYEVAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        % constructor
        function obj = CompanyEval(a,b)
            switch nargin % error
                case 0
                    error(message('MATLAB:narginchk:notEnoughInputs'));
                case 1 % only specify company
                    obj.meta.symbol = a;
                case 2 % specify company and start year
                    obj.meta.symbol = a;
                    obj.search.startYr = b;
                otherwise
            end
        end
        
        function obj = Eval(obj)
            disp('Eval');
            obj = Analyze(obj);
            obj = Evaluate(obj);
            obj = Plot(obj);
        end
        
    end
    
    methods (Access = protected)
        
        function obj = Analyze(obj)                        
            
            yrsDiv = 0; % store number of years of continuous dividends
            yrsData = obj.search.endYr - obj.search.startYr; % yrs of data available
            for i1 = obj.search.startYr:obj.search.endYr
                
                % handle if 3 years of data unavailable-------------------------                
                if (yrsData < 3 && i1 == obj.search.startYr)
                    error(['Only ',num2str(yrsData),...
                        ' years of financial data available.',...
                        'Investment not recommended']);                    
                end
                yearField = ['Y',num2str(i1)];
                data = obj.data.(yearField);
                market = obj.market.(yearField);
                calcs = struct(); % create temporary struct for easier access
                
                %% Company Value
                
                % assets current net
                calcs.AssetsCurrentNet = ...
                    data.AssetsCurrent - data.LiabilitiesCurrent;
                
                % assets fixed (long term assets/noncurrent assets)
                calcs.AssetsFixed = ...
                    data.Assets - data.AssetsCurrent;
                
                % assets net
                calcs.AssetsNet = ...
                    data.Assets - data.Liabilities;
                
                % book value tangible
                calcs.BookValue = ...
                    data.Assets - data.Goodwill - data.Liabilities;
                
                % capital total
                calcs.CapitalTotal = ...
                    data.LongTermDebt + ...
                    data.StockholdersEquity;
                
                % capital working
                calcs.CapitalWorking = ...
                    data.AssetsCurrent - data.LiabilitiesCurrent;
                
                % TODO: owners earnings
                
                
                %% Market Conditions
                
                % market cap basic
                obj.market.(yearField).MarketCapBasic = ...
                    market.YrEndPrice * data.NumberOfBasicShares;
                
                % market cap total
                obj.market.(yearField).MarketCapTotal = ...
                    market.YrEndPrice * data.NumberOfDilutedShares;
                
                % per share book value (diluted
                obj.market.(yearField).PerShareBookValue = ...
                    calcs.BookValue/data.NumberOfDilutedShares;
                
                
                % net assets per share (diluted)
                obj.market.(yearField).PerShareAssetsNet = ...
                    calcs.AssetsNet/data.NumberOfDilutedShares;
                
                % Price-Earnings Ratio basic
                obj.market.(yearField).PEBasic = ...
                    market.YrEndPrice/data.EPSBasic;
                
                % Price-Earnings Ratio diluted
                obj.market.(yearField).PEDiluted = ...
                    market.YrEndPrice/data.EPSDiluted;
                
                % years continuous dividends
                if (~isnan(data.DividendsCommonStock))
                    yrsDiv = yrsDiv + 1;
                    
                    % dividend yield at year end price
                    calcs.DividendYield = ...
                        data.DividendsPerShare/market.YrEndPrice;
                else
                    yrsDiv = 0;
                    obj.data.(yearField).DividendsCommonStock = 0;
                    data.DividendsCommonStock = 0;
                end;
                
                %% Profitability
                
                % dividend payout rate
                calcs.DividendPayoutRate = ...
                    data.DividendsCommonStock/data.NetIncomeLoss;
                
                % operating margin
                calcs.OperatingMargin = data.NetCashFromOperating/data.Revenues;
                
                % ratio cash flow operating to assets total
                calcs.RatioOperatingCashFlowToAssets = ...
                    data.NetCashFromOperating/data.Assets;
                
                % ratio asset liability
                calcs.RatioAssetLiability = data.Assets/data.Liabilities;
                
                % ratio price assets net
                calcs.RatioPriceAssetsNet = ...
                    market.YrEndPrice/...
                    obj.market.(yearField).PerShareAssetsNet;
                
                % ratio price book value
                calcs.RatioPriceBookValue = ...
                    market.YrEndPrice/...
                    obj.market.(yearField).PerShareBookValue;
                
                % TODO: Is longterm debt all the debt?
                % ratio working capital debt
                calcs.RatioWorkingCaptialDebt = ...
                    calcs.CapitalWorking/data.LongTermDebt;
                
                % return on net asset capital
                calcs.ReturnOnAssetsNet = ...
                    data.NetIncomeLoss/calcs.AssetsNet;
                
                % return on book value
                calcs.ReturnOnBookValue = ...
                    data.NetIncomeLoss/calcs.BookValue;
                
                % TODO: ROIC numerator is actually (netIncome - dividends) so factor in
                % preferred stock dividends
                % return on invested capital
                calcs.ReturnOnInvestedCapital = ...
                    (data.NetIncomeLoss - data.DividendsCommonStock)/...
                    (calcs.CapitalWorking - data.Cash + calcs.AssetsFixed);
                
                % return on sales
                calcs.ReturnOnSales = ...
                    data.NetIncomeLoss/data.Revenues;
                
                
                %% Change From Last Year
                if (i1 ~= obj.search.startYr)
                    
                    % store last year's data for easy access
                    prevData = obj.data.(['Y',num2str(i1-1)]);
                    
                    % change in number of common shares
                    obj.market.(yearField).ChangeInNumberCommonShares= ...
                        (data.NumberOfBasicShares - ...
                        prevData.NumberOfBasicShares)/...
                        prevData.NumberOfBasicShares;
                    
                    % diluted EPS growth/loss
                    calcs.GrowthEPSDiluted = ...
                        (data.EPSDiluted - prevData.EPSDiluted)/...
                        prevData.EPSDiluted;
                    
                    % earnings growth/loss
                    calcs.GrowthEarnings = ...
                        (data.NetIncomeLoss - prevData.NetIncomeLoss)/...
                        prevData.NetIncomeLoss;
                end
                
                %% Current Year                                               
                if (i1 == obj.search.endYr) 
                    % trailing three year earnings
                    calcs.Trailing3YrAvgEarnings = ...
                        mean([data.NetIncomeLoss, prevData.NetIncomeLoss, ...
                        obj.data.(['Y',num2str(i1 - 2)]).NetIncomeLoss]);
                    
                    % trailing three year PERatio (PE /w trailing 3 yr earnings)
                    calcs.Trailing3YrPERatio = ...
                        market.YrEndPrice/(calcs.Trailing3YrAvgEarnings/...
                        data.NumberOfDilutedShares);
                    
                    % trailing three year earning power
                    obj.market.(yearField).Trailing3YrEarningPower = ...
                        1/calcs.Trailing3YrPERatio;
                    
                    % years of continuous dividend payment
                    calcs.YearsContinuousDividends = yrsDiv;
                    
                elseif (i1 == obj.search.startYr)
                    
                    % leading three years earnings
                    calcs.Leading3YrAvgEarnings = ...
                        mean([data.NetIncomeLoss, ...
                        obj.data.(['Y',num2str(i1 + 1)]).NetIncomeLoss, ...
                        obj.data.(['Y',num2str(i1 + 2)]).NetIncomeLoss]);
                end
                obj.calcs.(yearField) = calcs;
            end           
        end
        
        function obj = Evaluate(obj)
            
        end
        
        function obj = Plot(obj)
            
        end
        
        
        
    end
    
end

