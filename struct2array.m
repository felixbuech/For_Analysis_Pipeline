function valueArray = struct2array(inputStruct)
%STRUCT2ARRAY Convert structure to an array. Assumes that struct values are
%of uniform or heterogeneous type.

% Copyright 2021 The MathWorks, Inc.

narginchk(1,1);

% Convert structure to cell
valueCellArray = struct2cell(inputStruct);

% Construct an array
valueArray = [valueCellArray{:}];