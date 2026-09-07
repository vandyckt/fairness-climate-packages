function out = wMeanSem(X, w)
% Returns weighted mean and SEM for each column of X. Output: [2 x ncols]

    n_cols = size(X, 2);
    out    = zeros(2, n_cols);

    for i = 1:n_cols
        x_ = X(:,i);
        w_ = w;
        valid = ~isnan(x_) & ~isnan(w_);
        x_ = x_(valid);
        w_ = w_(valid);

        if isempty(x_)
            out(:,i) = NaN;
            continue
        end

        n         = length(w_);
        N         = sum(w_);
        wx        = w_ .* x_;
        out(1, i) = sum(wx) / N;   % weighted mean
        out(2, i) = sqrt((n*wx - sum(wx))' * (n*wx - sum(wx)) / (N^2 * n * (n-1)));  % weighted SEM
    end
end
