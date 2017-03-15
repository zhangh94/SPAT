function [ company ] = EvaluateCompany( company, search )
%Function to evaluate a company's investment prospects
%   Inputs
%
%
%   Outputs
%
%

warnings = {};
% check if full range of data is available
numYears = 10;
if (search.analysisStartYr > (search.currentYear-numYears))
    numYears = search.endYr - search.analysisStartYr;
    warnings = [warnings;'Available data does not span 10 years.',...
        ' Using ', num2str(numYears),...
        ' years of data instead'];
end

% store most recent data set for easier access
yearField = ['Y', num2str(search.endYr)];
data = company.data.(yearField);
pastData = company.data.(['Y',num2str(search.analysisStartYr)]);

% check how up to date current data is
if (search.currentYear ~= search.endYr)
    warnings = [warnings;...
        'Available data is not up to date. Most recent data is ',...
        num2str(daysact(data.reportPeriod,search.currentDate)),...
        ' days old'];
end

% check if total market cap data is available
if (~data.value.totalMarketCap)
   warnings = [warnings;'Total Market Cap data unavailable.'];
end

% open text file to write
fid = fopen([company.name,'_report.txt'],'w');

% TODO: Determine better alternative to nested function
fails = 0;
passes = 0;
    function Pass()
        fprintf(fid,'PASS\r\n'); passes = passes + 1;
    end
    function Fail()
        fprintf(fid,'FAIL\r\n'); fails = fails + 1;
    end
    function FilePrint(str)
        % print test with result aligned right at 80 chars
        % If str will overflow 80 char, result is appened at end
        lineEnd = 80 - length('FAIL') - length('|');
        strLen = length(str);
        
        format = ['%s%',num2str(lineEnd - length(str)),'c'];
        if (strLen > lineEnd)
            format = '%s%c';
        end
        fprintf(fid,format,str,'|');
        
    end
    function Flag(str)
        fprintf(fid,['RED FLAG - ',str,'\r\n']);
    end


%% Value Investing Evaluation

if (strcmpi(search.type,'VALUE'))
    
    fprintf(fid,['Performing Value Investing Evaluation for ',...
        company.name,'\r\n']);
    
    % growth plots---------------------------------------------------------
    
    % display benchmarks table with rating (green, yellow, red)
    
    % DEFENSIVE INVESTOR CRITERIA------------------------------------------
    fprintf(fid,'\r\nDEFENSIVE INVESTOR CRITERIA\r\n\r\n');
    
    % adequate size
    FilePrint('Adequate Size (Min $2B in Yearly Sales)');
    if(data.data.SalesRevenueNet > 10E9);Pass();else Fail();end;
    
    % Conservatively Financed
    FilePrint('Conservatively Financed (Book Value >= 1/2 of Market Cap)');
    if(data.value.bookValue >= 0.5*data.value.totalMarketCap);...
            Pass();else Fail();end;
    
    % Current Assets to Current Liabilities Ratio
    FilePrint('Current Assets at Least Twice Current Liabilities');
    if(data.data.AssetsCurrent >= 2*data.data.LiabilitiesCurrent);...
            Pass();else Fail();end;
    
    % Dividend Record
    FilePrint('Dividend Record (10 Years Uninterrupted Payments)');
    if (data.profitability.yearsContinuousDividends >= numYears);...
            Pass();else Fail();end;
    if (numYears < 10); fprintf(fid,['\tNOTE: Only ',num2str(numYears),...
            ' years of data available and used for dividend record\r\n']);
    end
    
    % Earnings Growth
    FilePrint('Earnings Growth (At Least 50%% in 10 Years)');
    growth = .5 * numYears/10;
    if((data.value.averageEarningsPast3Years - ...
            pastData.value.averageEarningsFuture3Years)/...
            pastData.value.averageEarningsFuture3Years >= growth);...
            Pass();else Fail();
    end
    if (numYears < 10); fprintf(fid,['\tNOTE: Only ',num2str(numYears),...
            ' years of data available, ', num2str(growth),...
            '%% growth used instead\r\n']);
    end
    
    % TODO: Earnings Stability
    
    % Long Term Debt Less Than Net Current Assets
    FilePrint('Long Term Debt < Net Current Assets');
    if(data.data.LongTermDebt < data.value.netCurrentAssets);...
            Pass();else Fail();end;
    
    % Long Term Debt Less Than 1/2 Total Capital
    FilePrint('Long Term Debt Less Than 1/2 Total Capital');
    if(data.data.LongTermDebt < 0.5*data.value.totalCapital);...
            Pass();else Fail();end;
    
    % Moderate P/E Ratio
    FilePrint('Moderate PE Ratio (< 15 Using 3 Yr Earnings)');
    if(data.market.diluted3YearEarningsPERatio < 15);...
            Pass();else Fail();end;
    
    % Moderate Price-Book Ratio
    FilePrint('Moderate Price to Book Value Ratio');
    if(data.data.MarketPriceMonthEnd < ...
            1.5*data.profitability.bookValuePerShareDiluted);...
            Pass();else Fail();
    end
    
    % TODO: Safety Margin
    
    % ENTERPRISING INVESTOR CRITERIA---------------------------------------
    fprintf(fid,'\r\nENTERPRISING INVESTOR CRITERIA\r\n\r\n');
    
    % Moderate Stock Price
    FilePrint('Moderate Stock Price (< 1/3 Book Value)');
    if (data.data.MarketPriceMonthEnd < ...
            0.3*data.profitability.bookValuePerShareDiluted);...
            Pass();else Fail();
    end
    
    % Return on Invested Capital (At Least 10%)
    FilePrint('Return on Invested Capital (At Least 10%)');
    if (data.profitability.returnOnInvestedCapital >= 0.1);...
            Pass();else Fail();end;
    
    % MISC RED FLAGS-------------------------------------------------------
    fprintf(fid,'\r\nMISC RED FLAGS\r\n\r\n');
        
    % TODO: High CEO Salary
    
    % Huge Cash Reserves
    if (data.data.CashAndCashEquivalents > 2E10);...
            Flag(['Huge Cash Reserves of ',...
            num2str(data.data.CashAndCashEquivalents)]);
    end

    % Huge Market Value But Low Book Value
    if (data.value.totalMarketCap > 5*data.value.bookValue)
        Flag(['Huge Market Cap of ',num2str(data.value.totalMarketCap),...
            ' vs Low Book Value of ',num2str(data.value.bookValue)]);
    end
    
    % Income From Financing Exceeds Income From Operations
    tmp = [];
    for i1 = search.analysisStartYr:search.endYr
       if (company.data.(['Y',num2str(i1)]).data.NetCashFromFinancing > ...
               company.data.(['Y',num2str(i1)]).data.NetCashFromOperating)
          tmp = [tmp, ['Y', num2str(i1)],' '];
       end
        
    end
    if (~isempty(tmp))
       Flag(['Financing Income > Operating Income in ',tmp]); 
    end
    
    % No Income Tax Paid
    tmp = [];
    for i1 = search.analysisStartYr:search.endYr
       if (company.data.(['Y',num2str(i1)]).data.IncomeTax <= 0)
          tmp = [tmp, ['Y', num2str(i1)],' '];
       end
        
    end
    if (~isempty(tmp))
       Flag(['No Income Tax Paid in ',tmp]); 
    end
    
    % Unsafe Earnings Growth Growth
    % TODO: Report Earnings in flagged year?
    tmp = [];
    for i1 = (search.analysisStartYr+1):search.endYr
       if (company.data.(['Y',num2str(i1)]).profitability.earningsGrowth...
               > 0.15)
          tmp = [tmp, ['Y', num2str(i1)],' '];
       end
        
    end
    if (~isempty(tmp))
       Flag(['Unsafe Earnings Growth in ',tmp]); 
    end
    
    % SUMMARY--------------------------------------------------------------
    fprintf(fid,'\r\nSUMMARY\r\n');
    fprintf(fid,['Tests: ',num2str(fails + passes), ' Fails: ',...
        num2str(fails),' Passes: ', num2str(passes),'\r\n']);
end

%% Close Out
% print out warnings
fprintf(fid, ['\r\nEvaluations accumulated ',num2str(length(warnings)), ...
    ' warnings/cautions\r\n\r\n']);

for i1 = 1:length(warnings)
    fprintf(fid,[warnings{i1},'\r\n']);
end

fclose(fid);

end

