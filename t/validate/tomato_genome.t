use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "tomato genome data home"                  => "/genomes/Solanum_lycopersicum/genome_data.pl",
        "tomato genome publication page"           => "/genomes/Solanum_lycopersicum/publications.pl",
        "tomato genome index page"                 => "/genomes/Solanum_lycopersicum/",

        "bac search page"                          => "/search/direct_search.pl?search=bacs",
        "bac search"                               => "/maps/physical/clone_search.pl?w98e_page=0&w98e_id=&w98e_seqstatus=&w98e_estlenrange=gt&w98e_estlen1=&w98e_estlen2=&w98e_genbank_accession=&w98e_chromonum=&w98e_end_annotation=&w98e_map_id=&w98e_offsetrange=gt&w98e_offset1=&w98e_offset2=&w98e_linkage_group_name=&w98e_il_project_id=&w98e_il_bin_name=",
        "bac detail page"                          => "/maps/physical/clone_info.pl?id=3468&w98e_page=0&w98e_seqstatus=complete",
        "bac detail page 2"                        => "/maps/physical/clone_info.pl?id=119416",

);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
