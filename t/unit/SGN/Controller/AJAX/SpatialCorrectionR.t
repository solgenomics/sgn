# The actual spatial correction R script on a simulated randomized field whose true plot values are
# known: value = accession effect + plot noise ("truth") + a smooth field trend. The corrected value
# of every plot must be close to its truth, and neighbouring plots must get nearly the same adjustment.
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use IPC::Run qw(run);

my ($rscript) = grep { -x $_ } map { File::Spec->catfile($_, 'Rscript') } File::Spec->path;
plan skip_all => 'Rscript is not installed' unless $rscript;
plan skip_all => 'The R packages of the spatial correction are not installed'
    unless run([$rscript, '-e', 'suppressMessages({library(SpATS); library(spdep); library(dplyr)})'], '>', \my $ignored, '2>', \my $missing);
my $directory = tempdir('SpatialCorrectionRXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $script = File::Spec->rel2abs('R/Spatial_Correction.R');

# 100 accessions x 6 replicates on 20 rows x 30 columns; the file is not in field order and
# one plot has no value.
write_file("$directory/simulate.R", <<'R');
set.seed(20261117)
directory <- commandArgs(trailingOnly = TRUE)[1]
trend <- function(r, c) 1.5 * sin(r / 6) + 1.2 * cos(c / 7) + 0.004 * (r - 10) * (c - 15) - 2.5 * exp(-((r - 15)^2 + (c - 22)^2) / 18)
d <- expand.grid(rowNumber = 1:20, colNumber = 1:30)
d$replicate <- (d$colNumber - 1) %/% 5 + 1
effect <- rnorm(100)
d$accession <- NA
for (replicate in 1:6) d$accession[d$replicate == replicate] <- sample(1:100)
d$truth <- 10 + effect[d$accession] + rnorm(nrow(d), 0, 0.6)
d$Yield <- d$truth + trend(d$rowNumber, d$colNumber)
d$observationUnitName <- paste0("plot_", d$rowNumber, "_", d$colNumber)
d$germplasmName <- paste0("G", d$accession)
d$blockNumber <- d$replicate
d$plotNumber <- seq_len(nrow(d))
d$Yield[7] <- NA
d <- d[sample(nrow(d)), ]
write.table(d[, c("observationUnitName", "germplasmName", "rowNumber", "colNumber", "replicate", "blockNumber", "plotNumber", "Yield")],
            file.path(directory, "field.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
write.table(d[, c("observationUnitName", "truth")], file.path(directory, "field.truth"), sep = "\t", quote = FALSE, row.names = FALSE)
write.table(data.frame(trait = "Yield", quality = "good data", Moran_pvalue = 0, spatial_correction_needed = "YES"),
            file.path(directory, "field.txt.spatial_correlation_summary"), sep = "\t", row.names = FALSE)
R
write_file("$directory/compare.R", <<'R');
directory <- commandArgs(trailingOnly = TRUE)[1]
out <- read.delim(file.path(directory, "field.txt.spatially_corrected"))
missing <- out[out$observationUnitName == "plot_7_1", ]
missing_ok <- nrow(missing) == 1 && is.na(missing$Yield) &&
              is.na(missing$Yield_spatially_corrected) && is.na(missing$Yield_spatial_adjustment)
m <- merge(out, read.delim(file.path(directory, "field.truth")), by = "observationUnitName")
m <- m[!is.na(m$Yield), ]
next_plot <- m[match(paste0("plot_", m$rowNumber + 1, "_", m$colNumber), m$observationUnitName), ]
cat(nrow(out), cor(m$Yield, m$truth), cor(m$Yield_spatially_corrected, m$truth),
    mean(abs(m$Yield_spatial_adjustment - next_plot$Yield_spatial_adjustment), na.rm = TRUE),
    max(abs(m$Yield_spatially_corrected - m$Yield - m$Yield_spatial_adjustment)),
    as.integer(missing_ok), sep = "\n")
R

my ($out, $err);
ok(run([$rscript, "$directory/simulate.R", $directory], '>', \$out, '2>', \$err), 'the field is simulated') or BAIL_OUT($err);

for my $as_random (0, 1) {
    my $mode = $as_random ? 'random genotype effect' : 'fixed genotype effect';
    subtest $mode => sub {
        ok(run([$rscript, $script, "$directory/field.txt", "$directory/field.txt.spatial_correlation_summary", 1, $as_random, 0.67, 'x'],
            '>', \$out, '2>', \$err), 'the spatial correction script completes') or return diag($err);
        ok(run([$rscript, "$directory/compare.R", $directory], '>', \$out, '2>', \$err),
            'the result is read back') or return diag($err);
        my ($plots, $raw, $corrected, $step, $drift, $missing_ok) = split /\n/, $out;

        is($plots, 600, 'every plot has a result line');
        cmp_ok($raw, '<', 0.8, sprintf('the raw plot values are far from the truth (r = %.2f)', $raw));
        cmp_ok($corrected, '>', 0.95, sprintf('the corrected value of each plot is close to its truth (r = %.2f)', $corrected));
        cmp_ok($step, '<', 0.5, sprintf('neighbouring plots get nearly the same adjustment (mean difference %.2f)', $step));
        cmp_ok($drift, '<', 1e-9, 'adjustment = corrected - original');
        is($missing_ok, 1, 'the plot with no observed value keeps NA in both derived columns');
    };
}

done_testing();
