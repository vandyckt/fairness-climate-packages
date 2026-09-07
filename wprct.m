function prctX = wprct(X, w, p)
% WPRCT Weighted percentiles, computed column-wise.
%
%   prctX = wprct(X, w, p) returns the weighted percentiles of each
%   column of X, using sample weights w.
%
%   Inputs:
%     X - data matrix (n x m), each column is a separate variable
%     w - weight vector (n x 1), must match number of rows in X
%     p - desired percentile(s) (0-100), scalar or vector
%         e.g. 50 for median, or [10 20 30 ... 100] for decile cutpoints
%
%   Output:
%     prctX - matrix (length(p) x m) of weighted percentiles
%             rows correspond to percentiles, columns to variables
%             e.g. if p = [10 50 90] and X has 2 columns,
%             prctX is 3x2: each row is one percentile, each col is one variable
%
%   Method:
%     For each column, the data is sorted and a cumulative distribution
%     function (CDF) is built using the sample weights. The percentile
%     value is then found by interpolating along this weighted CDF.
%
%   Example:
%     Data:    [100, 200, 300]
%     Weights: [1,   3,   1]
%     Total weight = 5
%     Cumulative:  [0.2, 0.8, 1.0]
%     Median (p=50) falls at 0.5 on the CDF, which interpolates
%     between 100 (at 0.2) and 200 (at 0.8), giving 150.

    % Convert percentages to proportions: 50 -> 0.5, [10 20 ... 100] -> [0.1 0.2 ... 1.0]
    p = p / 100;

    nCols = size(X, 2);   % number of variables (columns in X)
    nP = length(p);        % number of percentiles requested
    prctX = NaN(nP, nCols);

    for col = 1:nCols
        x = X(:, col);

        % Remove NaN entries for this column
        % Each column handled independently so NaNs in one variable
        % don't discard data from other variables
        valid = ~isnan(x);
        xv = x(valid);
        wv = w(valid);

        % Skip if no valid data remains
        if isempty(xv)
            continue
        end

        % Sort data in ascending order; reorder weights to match
        % e.g. x = [300, 100, 200], w = [1, 1, 3]
        %   -> X_sorted = [100, 200, 300], w_sorted = [1, 3, 1]
        [X_sorted, idx] = sort(xv);
        w_sorted = wv(idx);

        % Build the weighted CDF: cumulative share of total weight
        % e.g. w_sorted = [1, 3, 1], sum = 5
        %   -> p_cumW = [0.2, 0.8, 1.0]
        % Interpretation: 20% of population has value <= 100,
        %                 80% has value <= 200, 100% has value <= 300
        p_cumW = cumsum(w_sorted) / sum(w_sorted);
        p_cumW(end) = 1;  % enforce exact 1.0 to avoid floating-point issues

        % Interpolate to find values at desired percentile(s)
        % p can be a scalar (e.g. 0.5 for median) or a vector
        % (e.g. [0.1 0.2 ... 1.0] for decile cutpoints)
        % interp1 handles both cases, returning same shape as p
        prctX(:, col) = interp1(p_cumW, X_sorted, p);
    end
end