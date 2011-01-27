use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "homepage"                                 => "/",

        "Trait list"                               => "/chado/trait_list.pl?index=Z",
        'tomato bac tpf'                           => '/sequencing/agp.pl',
        'tomato bac tpf'                           => '/sequencing/tpf.pl',
        'tomato bac tpf chr 12'                    => '/sequencing/tpf.pl?chr=12',

        'unigene standalone six-frame translation' => '/tools/sixframe_translate.pl?unigene_id=573435',
        "library detail page"                      => "/content/library_info.pl?library=MXLF",

        "people detail page"                       => "/solpeople/personal-info.pl?sp_person_id=208&action=view",

        "genome browser bac list"                  => "/genomes/Solanum_lycopersicum/genome_data.pl?chr=2",
        # "Gbrowse example"                        => "/gbrowse/gbrowse/tomato_bacs/?name=C02HBa0016A12.1",
        "BLAST page"                               => "/tools/blast/",

        "Tree Browser input page"                  => "/tools/tree_browser/",
        "Tree Browser sample tree"                 => "/tools/tree_browser/?tree_string=%281%3A0%2E020058%2C%28%28%28%28%28%282%3A0%2E051985%2C6%3A0%2E002761%29%3A0%2E027131%2C11%3A0%2E405224%29%3A0%2E042208%2C15%3A0%2E067923%29%3A0%2E046508%2C%288%3A1%2E655e%2D08%2C10%3A0%2E155643%29%3A0%2E083277%29%3A0%2E096957%2C9%3A0%2E119609%29%3A0%2E124781%2C%28%283%3A0%2E066341%2C%28%28%284%3A0%2E013384%2C7%3A0%2E007637%29%3A0%2E019214%2C%2016%3A0%2E085744%29%3A0%2E020811%2C12%3A0%2E025839%29%3A0%2E168755%29%3A0%2E086288%2C13%3A0%2E170910%29%3A0%2E016660%29%3A0%2E027472%2C%285%3A0%2E005652%2C14%3A0%2E043026%29%3A0%2E014920%29%3B",

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

);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
