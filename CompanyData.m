classdef CompanyData
    %COMPANYDATA Data container class for a single company
    %   CompanyData class contains the following structs
    %       calcs - company financial ratios (ex. ROIC, etc.)
    %       data - company fundamentals (ex. assets, net income, revenue, etc.)
    %       market - company market and per share data (ex. EPS, PE, price)
    %       meta - metadata about 10-K filings
    
    properties
        calcs = struct();
        data = struct();
        market = struct();
        meta = struct();                    
    end
    
    properties (Access = protected)
        search = struct();
        plotData = struct(...
                'Years',[],...
                'Revenue',[],...
                'NetIncome',[],...
                'MarketPrice',[],...
                'MarketPriceAdj',[]);
    end
    
    methods
        % constructor
        function obj = CompanyData(a)            
            % set current year, day, month, fiscal quarter
           obj.search.currentDate = date();
           obj.search.currentYr = year(obj.search.currentDate);
           obj.search.currentMth = month(obj.search.currentDate);
           obj.search.endYr = obj.search.currentYr;
           
           % TODO: Replace this with R2016a quarter() 
           obj.search.currentQtr = ...
               quarter(datetime(year(date),month(date),day(date)));
           
           % set default startYr or custom
           if nargin == 0
               % default startYr set at first full year of API data
               obj.search.startYr = 2008; 
           else
               obj.search.startYr = a;
           end               
        end   
    end    
end

