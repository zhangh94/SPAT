classdef CompanyEval < CompanySearch
    %COMPANYEVAL Class to perform analysis and evaluation of company financials
    %   Instantiation:
    %       1. Specify Stock Symbol Only
    %           ex. c = CompanyEval('NOC')
    %
    %       2. Specify Stock Symbol and Start Year
    %           ex. c = CompanyEval('NOC',2009)
    %           NOTE: Earliest start year is 2008
    %
    %
    %
    
    % TODO: Figure out better way to handle exceptions than returnFlag
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
                    if (b >= 2008);obj.search.startYr = b;
                    else obj.search.startYr = 2008;
                    end
                otherwise
            end
        end
        
        function obj = FullRun(obj)
            tic
            obj = Search(obj);
            obj = Eval(obj);
            ShowPlots(obj);
            disp(['Full run took ',num2str(toc),' seconds']);
        end
        
        function obj = HeadlessRun(obj)
            tic
            obj = Search(obj);
            obj = Eval(obj);
            disp(['Full run for ',obj.meta.symbol,...
                ' took ',num2str(toc),' seconds']);
        end
        
        function obj = Eval(obj)
            disp('Eval');
            if (~obj.returnFlag);obj = Analyze(obj);end
            if (~obj.returnFlag);obj = Evaluate(obj);end
        end
        
        function ShowPlots(obj)
            if (~obj.returnFlag);Plot(obj);end
        end
        
    end
    
    methods (Access = protected)
        
        function obj = Analyze(obj)
            
            yrsDiv = 0; % store number of years of continuous dividends
            obj.meta.YearsAvailableData = obj.search.endYr - obj.search.startYr;
            for i1 = obj.search.startYr:obj.search.endYr
                
                % handle if 3 years of data unavailable-------------------------
                if (obj.meta.YearsAvailableData < 3 && i1 == obj.search.startYr)
                    warning(['Only ',num2str(obj.meta.YearsAvailableData),...
                        ' years of financial data available.',...
                        'Investment not recommended']);
                    obj.returnFlag = true;
                    return;
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
                    obj.market.(yearField).ChangeInNumCommon= ...
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
                    obj.market.(yearField).Trailing3YrPERatio = ...
                        market.YrEndPrice/(calcs.Trailing3YrAvgEarnings/...
                        data.NumberOfDilutedShares);
                    
                    % trailing three year earning power
                    obj.calcs.Trailing3YrEarningPower = ...
                        1/obj.market.(yearField).Trailing3YrPERatio;
                    
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
            
            % check if full range of data is available
            if (obj.meta.YearsAvailableData < 10)
                obj.warnings = [obj.warnings;...
                    'Available data does not span 10 years.',...
                    ' Using ', num2str(obj.meta.YearsAvailableData),...
                    ' years of data instead'];
            end
            obj.passes = 0; obj.fails = 0;
            
            % store most recent data set for easier access
            yearField = ['Y', num2str(obj.search.endYr)];
            data = obj.data.(yearField);
            calcs = obj.calcs.(yearField);
            market = obj.market.(yearField);
            meta = obj.meta.(yearField);
            earliestCalcs = obj.calcs.(['Y',num2str(obj.search.startYr)]);
            
            % check how up to date current data is
            if (~strcmp(obj.search.currentDate,meta.PeriodEnded))
                obj.warnings = [obj.warnings;...
                    'Available data is not up to date. Most recent data is ',...
                    num2str(daysact(meta.PeriodEnded,obj.search.currentDate)),...
                    ' days old'];
            end
            
            % TODO: Remove after testing
            %             % check if total market cap data is available
            %             if (~data.value.totalMarketCap)
            %                 warnings = [warnings;'Total Market Cap data unavailable.'];
            %             end
            
            % open text file to write
            obj.fid = fopen(['.\Reports\',obj.meta.symbol,'_report.txt'],'w');
            if (~obj.fid);error('Error. File open error');end;
            
            %% Evaluations
            fprintf(obj.fid,['Performing Value Investing Evaluation for ',...
                obj.meta.name,'\r\n']);
            
            % DEFENSIVE INVESTOR CRITERIA------------------------------------------
            fprintf(obj.fid,'\r\nDEFENSIVE INVESTOR CRITERIA\r\n\r\n');
            
            % adequate size
            FilePrint(obj,'Adequate Size (Min $2B in Yearly Sales)');
            if(data.Revenues > 2E9);...
                    % TODO: Find alternative to storing return value (seems really
                % inefficient)
                obj = Pass(obj);else obj = Fail(obj);
            end;
            
            % Conservatively Financed
            FilePrint(obj,['Conservatively Financed ',...
                '(Book Value >= 1/2 Market Cap)']);
            if(calcs.BookValue >= 0.5*market.MarketCapTotal);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            
            % Current Assets to Current Liabilities Ratio
            FilePrint(obj,'Current Assets at Least Twice Current Liabilities');
            if(data.AssetsCurrent >= 2*data.LiabilitiesCurrent);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            
            % Dividend Record
            FilePrint(obj,'Dividend Record (10 Years Uninterrupted Payments)');
            if (calcs.YearsContinuousDividends >= obj.meta.YearsAvailableData);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            if (obj.meta.YearsAvailableData < 10)
                fprintf(obj.fid,['\tNOTE: Only ',...
                    num2str(obj.meta.YearsAvailableData),...
                    ' years of data available/used for dividend record\r\n']);
            end
            
            % Earnings Growth
            FilePrint(obj,'Earnings Growth (At Least 50%% in 10 Years)');
            growth = .5 * obj.meta.YearsAvailableData/10;
            if((calcs.Trailing3YrAvgEarnings - ...
                    earliestCalcs.Leading3YrAvgEarnings)/...
                    earliestCalcs.Leading3YrAvgEarnings >= growth);...
                    obj = Pass(obj);else obj = Fail(obj);
            end
            if (obj.meta.YearsAvailableData < 10)
                fprintf(obj.fid,['\tNOTE: Only ',...
                    num2str(obj.meta.YearsAvailableData),...
                    ' years of data available, ', num2str(growth),...
                    '%% growth used instead\r\n']);
            end
            
            % TODO: Earnings Stability
            
            % Long Term Debt Less Than Net Current Assets
            FilePrint(obj,'Long Term Debt < Net Current Assets');
            if(data.LongTermDebt < calcs.AssetsCurrentNet);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            
            % Long Term Debt Less Than 1/2 Total Capital
            FilePrint(obj,'Long Term Debt Less Than 1/2 Total Capital');
            if(data.LongTermDebt < 0.5*calcs.CapitalTotal);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            
            % Moderate P/E Ratio
            FilePrint(obj,'Moderate PE Ratio (< 15 Using 3 Yr Earnings)');
            if(market.Trailing3YrPERatio < 15);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            
            % Moderate Price-Book Ratio
            FilePrint(obj,'Moderate Price to Book Value Ratio');
            if(market.YrEndPrice < 1.5*market.PerShareBookValue);...
                    obj = Pass(obj);else obj = Fail(obj);end;
            
            % TODO: Safety Margin
            
            % ENTERPRISING INVESTOR CRITERIA---------------------------------------
            fprintf(obj.fid,'\r\nENTERPRISING INVESTOR CRITERIA\r\n\r\n');
            
            % Moderate Stock Price
            FilePrint(obj,'Moderate Stock Price (< 1/3 Book Value)');
            if (market.YrEndPrice < 0.3*market.PerShareBookValue);...
                    obj = Pass(obj);else obj = Fail(obj);
            end
            
            % Return on Invested Capital (At Least 10%)
            FilePrint(obj,'Return on Invested Capital (At Least 10%)');
            if (calcs.ReturnOnInvestedCapital >= 0.1);...
                    obj = Pass(obj);else obj = Fail(obj);
            end
            
            % MISC RED FLAGS-------------------------------------------------------
            fprintf(obj.fid,'\r\nMISC RED FLAGS\r\n\r\n');
            
            % TODO: High CEO Salary
            
            % Huge Cash Reserves
            if (data.Cash > 2E10);...
                    obj.Flag(['Huge Cash Reserves of ',...
                    num2str(data.Cash)]);
            end
            
            % Huge Market Value But Low Book Value
            if (market.MarketCapTotal > 5*calcs.BookValue)
                obj.Flag(['Huge Market Cap of ',num2str(market.MarketCapTotal),...
                    ' vs Low Book Value of ',num2str(calcs.BookValue)]);
            end
            
            % Income From Financing Exceeds Income From Operations
            tmp = [];
            for i1 = obj.search.startYr:obj.search.endYr
                if (obj.data.(['Y',num2str(i1)]).NetCashFromFinancing > ...
                        obj.data.(['Y',num2str(i1)]).NetCashFromOperating)
                    tmp = [tmp, ['Y', num2str(i1)],' '];
                end
            end
            if (~isempty(tmp))
                obj.Flag(['Financing Income > Operating Income in ',tmp]);
            end
            
            % Increase in shares of common
            tmp = [];
            for i1 = obj.search.startYr+1:obj.search.endYr
                if (obj.market.(['Y',num2str(i1)]).ChangeInNumCommon > 0);...
                        tmp = [tmp, ['Y', num2str(i1)],'(',num2str(...
                        obj.market.(['Y',num2str(i1)]).ChangeInNumCommon)...
                        ,')',' '];
                end
            end
            if (~isempty(tmp))
                obj.Flag(['Increase in Number of Common Shares in ',tmp]);
            end
            
            % No Income Tax Paid
            tmp = [];
            for i1 = obj.search.startYr:obj.search.endYr
                if (obj.data.(['Y',num2str(i1)]).IncomeTax <= 0)
                    tmp = [tmp, ['Y', num2str(i1)],' '];
                end
            end
            if (~isempty(tmp))
                obj.Flag(['No Income Tax Paid in ',tmp]);
            end
            
            % Unsafe Earnings Growth Growth
            % TODO: Report Earnings in flagged year?
            tmp = [];
            for i1 = (obj.search.startYr+1):obj.search.endYr
                if (obj.calcs.(['Y',num2str(i1)]).GrowthEarnings > 0.15)
                    tmp = [tmp, ['Y', num2str(i1)],'(',...
                        num2str(obj.calcs.(['Y',num2str(i1)]).GrowthEarnings)...
                        ,')',' '];
                end
            end
            if (~isempty(tmp))
                obj.Flag(['Unsafe Earnings Growth in ',tmp]);
            end
            
            % SUMMARY--------------------------------------------------------------
            fprintf(obj.fid,'\r\nSUMMARY\r\n');
            fprintf(obj.fid,['Tests: ',num2str(obj.fails + obj.passes), ...
                ' Fails: ',num2str(obj.fails),' Passes: ', ...
                num2str(obj.passes),'\r\n']);
            
            
            %% Close Out
            % print out warnings
            fprintf(obj.fid, ['\r\nEvaluations accumulated ',...
                num2str(length(obj.warnings)),' warnings/cautions\r\n\r\n']);
            
            for i1 = 1:length(obj.warnings)
                fprintf(obj.fid,[obj.warnings{i1},'\r\n']);
            end
            
            fclose(obj.fid);
            
        end
        
        function Plot(obj)
            
            % TODO: Make plot data selectable
            % plot Revenue, earnings, market price, adjusted market price
            for i1 = obj.search.startYr:obj.search.endYr
                yearField = ['Y',num2str(i1)];
                obj.plotData.Years = [obj.plotData.Years;i1];
                obj.plotData.Revenue = [obj.plotData.Revenue;...
                    obj.data.(yearField).Revenues];
                obj.plotData.NetIncome = [obj.plotData.NetIncome;...
                    obj.data.(yearField).NetIncomeLoss];
                obj.plotData.MarketPrice = [obj.plotData.MarketPrice;...
                    obj.market.(yearField).YrEndPrice];
                obj.plotData.MarketPriceAdj = [obj.plotData.MarketPriceAdj;...
                    obj.market.(yearField).YrEndPriceAdj];
            end
            
            figure
            % plot revenue and earnings
            subplot(3,1,1)
            hold all
            grid on
            plot(obj.plotData.Years, obj.plotData.Revenue)
            plot(obj.plotData.Years, obj.plotData.NetIncome)
            legend('Revenue','NetIncome')
            ylabel('Dollars(USD)')
            
            subplot(3,1,2)
            hold all
            grid on
            plot(obj.plotData.Years, obj.plotData.NetIncome)
            legend('NetIncome')
            ylabel('Dollars(USD)')
            
            % plot market price
            subplot(3,1,3)
            hold all
            grid on
            plot(obj.plotData.Years, obj.plotData.MarketPrice)
            plot(obj.plotData.Years, obj.plotData.MarketPriceAdj)
            legend('MarketPrice','MarketPriceAdj')
            ylabel('Dollars(USD)')
            xlabel('Year')
        end
    end
    
    properties (Access = private)
        passes; % number of passing evaluations
        fails; % number of failing evaluations
        warnings = {}; % warnings about analysis soundness
        flags = {}; % red flags found in company financials
        fid;
        passText = 'PASS';
        failText = 'FAIL';
    end
    
    methods (Access = private)
        function obj = Pass(obj)
            fprintf(obj.fid,[obj.passText,'\r\n']); obj.passes = obj.passes + 1;
        end
        
        function obj = Fail(obj)
            fprintf(obj.fid,[obj.failText,'\r\n']); obj.fails = obj.fails + 1;
        end
        
        function FilePrint(obj,str)
            % print test with result aligned right at 80 chars
            % If str will overflow 80 char, result is appened at end
            lineEnd = 80 - length(obj.passText) - length('|');
            strLen = length(str);
            
            format = ['%s%',num2str(lineEnd - length(str)),'c'];
            if (strLen > lineEnd)
                format = '%s%c';
            end
            fprintf(obj.fid,format,str,'|');
        end
        
        function Flag(obj,str)
            fprintf(obj.fid,['RED FLAG - ',str,'\r\n']);
        end
        
    end
end

