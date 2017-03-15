%{
Author: Frank Zhang
Created: 3/3/17
Updated: 3/3/17

Main script for analyzing a company's financials
Currently works only with the financial datasets provided by the SEC
%}

close all; clear; clc; format compact;

%% Parameters
% TODO: Make a user popup with fields that can be input

% specify name or cik number
% search.company = 'BOEING CO';
% search.symbol = 'BA'; % specify symbol to obtain market data

% search.company = 'RAYTHEON CO';
% search.symbol = 'RTN'; % specify symbol to obtain market data

search.company = 'LOCKHEED MARTIN CORP';
search.symbol = 'LMT'; % specify symbol to obtain market data

% search.company = 'Northrop Grumman';
% search.symbol = 'NOC'; % specify symbol to obtain market data

% search.company = 'Apple Inc';
% search.symbol = 'AAPL';

% specify range of years (currently limited between 2009-2016)
% Set to 0 to search all available years
% NOTE: Years refer to calendar year at start of each fiscal year
search.startYr = 2007;
search.endYr = 2016;
search.dataLimit = [2016 3];

% specify filing type
% TODO: Eventually remove this parameter and automatically do 10-K and the
% last 4 10-Qs
search.filing = '10-K';

% specify analysis type;
search.type = 'Value';

%% Configuration
search.ndxStartYr = 2002; % specify first year of SEC .index files
search.dataSetStartYr = 2009; % specify 1st yr of financial data set files

search.currentDate = date;
search.currentYear = year(search.currentDate);
% set start and end years (if given 0 as parameter)
if (~search.startYr); search.startYr = search.ndxStartYr; end; 
if (~search.endYr); search.endYr = search.currentYear; end;

search.company = upper(search.company);

%% Document Search and Data Extraction

% TODO: Check if company dataset already exists (ex. NOC)
% document search
[company, search] = DocumentSearch(search);

% document extraction
[company, search] = DocumentParse(company, search);

%% Data Analysis
company = AnalyzeCompany(company,search);
company = EvaluateCompany(company,search);