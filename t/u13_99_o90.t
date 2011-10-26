#!/usr/bin/env perl

use Test::More tests => 1;

#TBD: Required: run tests from the main project dir.

#TBR my $project_dir = "~/p/qidtrace/";
my $program_under_test = "perl -I lib " . "bin/qidtrace -o 90 -m u13\@h2.net ";
my $infile = 'data/99-lines.mx';
my $test_output_filename = "u13_99_o90.out";
my $outdir = "tmp/";

my $test_out = `$program_under_test $infile` or die "Cannot run $program_under_test: [$!]";

open my $outfile, ">", "$outdir/$test_output_filename"  or die "Cannot open [$outdir/$outfile]."; 
print { $outfile } $test_out;

# Compare two files on disk: reference o/p to program under test o/p.
my $ref_out = "refout/$test_output_filename";
my $diff_out = `diff -s  "$outdir/$test_output_filename" $ref_out`;
like( $diff_out, qr{Files.*are.identical.*}, "Found all o/p lines for u13\@h2.net in 99-line i/p file; use 90-char o/p length.");

