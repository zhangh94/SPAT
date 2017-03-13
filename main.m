%{
Author: Frank Zhang
Created: 3/3/17
Updated: 3/3/17

Main script for analyzing a company's financials
Currently works only with the financial datasets provided by the SEC
%}

% close all; clear; clc; format compact;
% 
% %% Parameters
% % TODO: Make a user popup with fields that can be input
% 
% % specify name or cik number
% % search.company = 'Northrop Grumman';
% % search.cik = 0;
% % search.symbol = 'NOC'; % specify symbol to obtain market data
% 
% search.company = 'Apple Inc';
% search.cik = 0;
% search.symbol = 'AAPL';
% 
% % specify range of years (currently limited between 2009-2016)
% % Set to 0 to search all available years
% % NOTE: Years refer to calendar year at start of each fiscal year
% search.startYr = 2007;
% search.endYr = 2016;
% search.dataLimit = [2016 3];
% 
% % specify filing type
% % TODO: Eventually remove this parameter and automatically do 10-K and the
% % last 4 10-Qs
% search.filing = '10-K';
% 
% % specify analysis type;
% search.type = 'Value';
% 
% %% Configuration
% search.ndxStartYr = 2002; % specify first year of SEC .index files
% search.dataSetStartYr = 2009; % specify 1st yr of financial data set files
% 
% c = clock;
% search.currentYear = c(1);
% % set start and end years (if given 0 as parameter)
% if (~search.startYr); search.startYr = search.ndxStartYr; end; 
% if (~search.endYr); search.endYr = search.currentYear; end;
% 
% % set company search by cik or name
% if (~search.cik)
%     search.cikFlag = false;
%     search.company = upper(search.company);
%     search.param = search.company;
% else
%     search.cikFlag = true;
%     search.param = num2str(search.cik);
% end
% %% Document Search and Data Extraction
% 
% % TODO: Check if company dataset already exists (ex. NOC)
% % document search
% [company, search] = DocumentSearch(search);
% 
% % document extraction
[company, search] = DocumentParse(company, search);

%% Data Analysis
company = AnalyzeCompany(company,search);
company = EvaluateCompany(company,search);