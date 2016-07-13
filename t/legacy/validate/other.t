use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "homepage"                                 => "/",
        'tomato bac tpf'                           => '/sequencing/agp.pl',
        'tomato bac tpf'                           => '/sequencing/tpf.pl',
        'tomato bac tpf chr 12'                    => '/sequencing/tpf.pl?chr=12',

        'unigene standalone six-frame translation' => '/tools/sixframe_translate.pl?unigene_id=573435',
        "library detail page"                      => "/content/library_info.pl?library=MXLF",

        "people detail page"                       => "/solpeople/personal-info.pl?sp_person_id=208&action=view",

        "genome browser bac list"                  => "/genomes/Solanum_lycopersicum/genome_data.pl?chr=2",
        # "Gbrowse example"                        => "/gbrowse/gbrowse/tomato_bacs/?name=C02HBa0016A12.1",
        "BLAST page"                               => "/tools/blast/",

        "insitu db"                                => "/insitu/",
        "insitu search page"                       => "/insitu/search.pl",
        "insitu search"                            => "/insitu/search.pl?w773_experiment_name=&w773_exp_tissue=&w773_exp_stage=&w773_exp_description=&w773_probe_name=&w773_probe_identifier=&w773_image_name=&w773_image_description=&w773_person_first_name=&w773_person_last_name=&w773_organism_name=&w773_common_name=#",
        "insitu detail page"                       => "/insitu/detail/experiment.pl?experiment_id=89&action=view",


        "biosource detail page for sample"         => "/biosource/sample.pl?id=1",

        "Locus ajax form"                          => "/jsforms/locus_ajax_form.pl",
        "Locus editors"                            => "/phenome/editors_note.pl",

        'sol100 page'                              => '/organism/sol100/view',
        "SGN data overview"                        => "/organism/all/view",

        "outreach index"                           => "/outreach/",
        "organism page for tomato"                 => "/chado/organism.pl?organism_id=1",
        "contact"                                  => "/contact/form",
        "seed BAC guidelines"                      => '/solanaceae-project/seed_bac_selection.pl',
        "caps designer input"                      => '/tools/caps_designer/caps_input.pl',
        "intron finder"                            => '/tools/intron_detection/find_introns.pl',
        "display intron"                           => '/tools/intron_detection/display_introns.pl',
        "about clustal file"                       => '/about/clustal_file.pl',
        'chado cvterm page'                        => '/cvterm/47499/view',
        "SGN pubs"                                 => "/help/publications.pl",
        "SGN events"                               => '/sgn-events',
        "AFRI-SOL"                                 => '/solanaceae-project/afri-sol', 
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
