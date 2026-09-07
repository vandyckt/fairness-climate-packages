function compose_and_export(fig_grid, row_labels, output_folder, sheet_name)
% Saves each individual figure as PNG and creates an index file.
% No Excel embedding — composites are saved as standalone PNGs per combination
% plus one HTML index file for easy navigation.

n_rows = size(fig_grid, 1);

sub_folder = fullfile(output_folder, sheet_name);
if ~exist(sub_folder, 'dir'), mkdir(sub_folder); end

% Save each panel as its own PNG (preserves all detail)
for r = 1:n_rows
        fname = sprintf('R%d.png', r);
        exportgraphics(fig_grid{r}, fullfile(sub_folder, fname), 'Resolution', 150);
        close(fig_grid{r});    
end

% HTML index for browsing
html_path = fullfile(sub_folder, 'index.html');
fid = fopen(html_path, 'w');
fprintf(fid, '<html><head><title>%s</title>\n', sheet_name);
fprintf(fid, '<style>table{border-collapse:collapse;}td,th{border:1px solid #888;padding:4px;vertical-align:top;}img{max-width:600px;}</style>\n');
fprintf(fid, '</head><body><h1>%s</h1>\n', sheet_name);
fprintf(fid, '<table><tr><th></th>');

for r = 1:n_rows
    fprintf(fid, '<tr><th>%s</th>', row_labels{r});
    fprintf(fid, '<td><img src="R%d.png"></td>', r);
    fprintf(fid, '</tr>\n');
end
fprintf(fid, '</table></body></html>\n');
fclose(fid);

fprintf('Saved %d panels and HTML index to %s\n', n_rows, sub_folder);
end