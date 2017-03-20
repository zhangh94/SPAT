classdef CompanySearch < CompanyData
    %COMPANYSEARCH Method container class to perform search operations
    %   Detailed explanation goes here
    
    properties
        
    end
    
    properties (Access = protected)
        
        % store default intrinio API username and password
        %         API = struct(...
        %             'Username','6040823b62b6d0c110c089bff308acee',...
        %             'Password','581659fa5c9382f65e5cb5ab1f38fecd');
        
        API = struct(...
            'Username','fe6a8bf594e575134ba4d605b4625cc0',...
            'Password','6a737298fef3de13bddf5f7647724cc1');
        
    end
    
    methods
        
        % constructor
        function obj = CompanySearch(a,b)
            switch nargin
                case 1 % only specify company
                    obj.meta.symbol = a;
                case 2 % specify company and start year
                    obj.meta.symbol = a;
                    obj.search.startYr = b;
                otherwise
            end
        end
        
        function obj = Search(obj)
            disp('Search');
            obj = obj.SearchAPI();
            
            if (~obj.returnFlag)
                obj = obj.SearchMeta();
                obj = obj.SearchMarket();
            end
        end
        
        % TODO: Remove this tester method
        function PrintData(obj)
            disp(['Company ',obj.meta.name,' (',obj.meta.symbol,')']);
            disp(['Search from ', num2str(obj.search.startYr),...
                ' to ', num2str(obj.search.endYr)]);
            disp(['API Username: ',obj.API.Username]);
            disp(['API Password: ',obj.API.Password]);
        end
    end
    
    methods (Access = protected)
        
        function obj = SearchAPI(obj)
            % Search Intrinio API to collect financial data for company
            % If API call returns blank data field, data assumed to not exist
            disp('SearchAPI');
            statements = {'balance_sheet','cash_flow_statement','income_statement'};
            options = weboptions;
            options.Username = obj.API.Username;
            options.Password = obj.API.Password;
            
            % get company name and cik
            meta = webread(['https://api.intrinio.com/companies?identifier=',...
                obj.meta.symbol],options);
            if (isempty(meta))
                obj.returnFlag = true;
                warning('Company listing not found for %s', obj.meta.symbol);
                return;
            end
            obj.meta.name = meta.name;
            obj.meta.cik = meta.cik;
            
            for i1 = obj.search.startYr:obj.search.currentYr
                if (obj.search.startYr == obj.search.currentYr)
                    obj.returnFlag = true;
                    warning('Company financials not found for %s', obj.meta.symbol);
                    return;
                end
                noData = false;
                endYr = false;
                data = [];
                ndx = 1;
                yearField = ['Y',num2str(i1)];
                
                while (ndx <= length(statements))
                    
                    url = ['https://api.intrinio.com/financials/standardized',...
                        '?identifier=',obj.meta.symbol,...
                        '&statement=',statements{ndx},...
                        '&fiscal_year=',num2str(i1),...
                        '&fiscal_period=','FY'];
                    tmp = webread(url,options);
                    
                    % break off if data is incomplete or set endYr
                    if (isempty(tmp.data))
                        noData = true;
                        if (i1 == obj.search.startYr);
                            obj.search.startYr = i1 + 1;
                        else
                            obj.search.endYr = i1 - 1;
                            endYr = true;
                            warning(['Company financial information ends in',...
                                ' Y',num2str(i1-1)]);
                        end
                        break;
                    end
                    
                    % group data together for parsing
                    data = [data;tmp.data];
                    ndx = ndx + 1;
                end
                
                % if endYr is set, break, elseif data is missing, on to next year
                if (endYr);break;elseif (noData);continue;end;
                
                % else continue to fill in data
                % TODO: Store particular fields for particular years?
                postData = obj.DictionarySearch(data, yearField);
                postData = obj.AmendData(postData);
                
                % store in CompanyData container
                obj.data.(yearField) = postData;
                
                % set the new endYr
                obj.search.endYr = i1;
            end
        end
        
        function obj = SearchMeta(obj)
            % Use Intrinio API to collect meta data for SEC 10-K filings
            disp('SearchMeta');
            options = weboptions;
            options.Username = obj.API.Username;
            options.Password = obj.API.Password;
            options.Timeout = 30;
            
            % API call to obtain master metadataset
            url = ['https://api.intrinio.com/companies/filings?',...
                'identifier=',obj.meta.symbol,...
                '&report_type=','10-K',...
                '&start_date=',num2str(obj.search.startYr),'-01-01',...
                '&end_date=',num2str(obj.search.endYr+1),'-12-31'];
            
            metadata = webread(url,options);
            
            % file data from master metadataset
            % TODO: Perform checks to make sure correct data is stored
            for i1 = 1:length(metadata.data)
                yearField = ['Y',num2str(obj.search.endYr - i1 + 1)];
                
                % store data and perform some formatting fixes
                obj.meta.(yearField).FilingDate = ...
                    datestr(metadata.data(i1).filing_date);
                obj.meta.(yearField).PeriodEnded = ...
                    datestr(metadata.data(i1).period_ended);
                obj.meta.(yearField).asn = metadata.data(i1).accno;
                obj.meta.(yearField).ReportURL = metadata.data(i1).report_url;
                
            end
        end
        
        function obj = SearchMarket(obj)
            disp('SearchMarket');
            yahooFinance = yahoo; % open connection to yahoo finance API;
            for i1 = obj.search.startYr:obj.search.endYr
                yearField = ['Y',num2str(i1)];
                                
                % find last business day in report period
                if (~isfield(obj.meta,(yearField)))
                    warning(['No meta data available for ',yearField,...
                        '. Possibly before IPO date. Skipping...']);
                    obj.search.startYr = i1 + 1;
                    continue;
                end
                meta = obj.meta.(yearField);
                
                obj.meta.(yearField).LastBusDay = datestr(lbusdate(...
                    year(meta.PeriodEnded), month(meta.PeriodEnded)));
                
                % market price on last business day of period
                try 
                    data = fetch(yahooFinance, obj.meta.symbol,...
                        obj.meta.(yearField).LastBusDay);
                catch ME
                    % if no data found, throw warning and set price to nan
                    if(strcmp(ME.identifier,'datafeed:yahoo:fetchError'))
                        warning(['While fetching market data for ',yearField]);
                        warning(message(ME.identifier));
                        obj.market.(yearField).YrEndPrice = nan;
                        obj.market.(yearField).YrEndPriceAdj = nan;
                        continue;
                    else
                        % if some other exception, dont handle
                        rethrow(ME);
                    end                                                            
                end
                obj.market.(yearField).YrEndPrice = data(5); % closing price
                obj.market.(yearField).YrEndPriceAdj = data(7); % adjusted price                
            end
            close(yahooFinance); %close connection to yahoo finance
        end
    end
    
    methods (Access = private)
        
        function outData = DictionarySearch(~, data,yearField)
            % Compare API data struct against a dictionary to store relevant
            % fields
            
            % create an empty struct
            outData = struct();
            
            % load in data dictionary and ignore comment lines
            fid = fopen('Dictionary.txt', 'r');
            rawText = textscan(fid,'%s','Delimiter','\n','CommentStyle','%');
            rawText = rawText{1};
            fclose(fid);
            
            % split the data dictionary to try all possible names
            exp = '\|';
            splitDict = regexp(rawText, exp, 'split');
            
            for j1 = 1:length(splitDict)
                exp = splitDict{j1}(2:end);
                
                % try each variation of dictionary entry
                for k1 = 1:length(exp)
                    
                    % check if entry exists
                    found = logical(strcmp({data.tag},exp{k1}));
                    if (any(found)) %if match is found
                        outData.(splitDict{j1}{1}) = ...
                            data(found).value;
                        continue; % store only first match
                    end
                end
                
                % set value to NaN if not found
                if (~isfield(outData,splitDict{j1}{1}))
                    outData.(splitDict{j1}{1}) = nan;
                    warning([splitDict{j1}{1},' not found for ',yearField]);
                end
            end
        end
        
        function outData = AmendData(~, data)
            % Manually attempt to fix API data set
            
            outData = data;
            
            % fill in number of diluted shares
            if (data.NumberOfBasicShares == data.NumberOfDilutedShares && ...
                    data.EPSBasic ~= data.EPSDiluted)
                outData.NumberOfDilutedShares = data.NetIncomeLoss/...
                    data.EPSDiluted;
            end
            
            % fill in liabilities
            if (isnan(data.Liabilities) && ...
                    ~isnan(data.LiabilitiesAndStockholdersEquity))
                outData.Liabilities = ...
                    data.LiabilitiesAndStockholdersEquity - ...
                    data.StockholdersEquity;
            end
        end
        
    end
end

