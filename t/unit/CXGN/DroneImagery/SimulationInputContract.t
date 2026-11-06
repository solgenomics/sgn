use strict;use warnings;use utf8;use Test::More;use File::Temp qw(tempfile);use Text::CSV;use CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation;
my($out,$path)=tempfile(UNLINK=>1);my@values=('0','01','NA','Rep, "A"',"block\tline\nnext",'репліка',0,12.5);
CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::_write_model_csv_row($out,\@values);close$out;
open(my$in,'<:encoding(UTF-8)',$path)or die$!;my$csv=Text::CSV->new({binary=>1});is_deeply($csv->getline($in),\@values,'actual shared model producer preserves zero, leading zero, NA, quotes, tabs/newlines and UTF-8');ok(!$csv->getline($in)&&$csv->eof,'quoted newline remains one complete model record');close$in;
done_testing;
