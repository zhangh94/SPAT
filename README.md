# SPAT
Stock Picking Analysis Tool

Automated tool which can:
1. Find and gather financial information for a company specified by only stock symbol
2. Compute fundamental analysis parameters
3. Evaluate specified company according to Value Investing principals outlined by Benjamin Graham
4. Output evaluations and visual aids in human readable format

Example (using APPLE INC)
```MATLAB
% run example
symbol = 'AAPL'; % APPLE INC
mkdir Reports; % create output directories
mkdir Datasets;
addpath('./Reports','./Datasets'); % add output directories to path
c = CompanyEval('AAPL');
c = c.FullRun();

% Outputs
% AAPL_report.txt
% AAPL.mat
% plots
```
