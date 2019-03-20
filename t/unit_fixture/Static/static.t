use strict;
use warnings;
use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

#All static files used by sgn should be here (css,xml,js,etc)



#Called by application from: sgn/mason/site/header/head.mas
#These files are available on all site pages
$mech->get_ok($_) for
    qw(
        /css/new_sgn.css
        /documents/sgn_sol_search.xml
        /css/jquery-sgn-theme/jquery-ui-1.10.3.custom.css
        /css/jstree/themes/default/style.min.css
        /css/fullcalendar.min.css
        /documents/inc/datatables/jquery.dataTables.css
        /css/bootstrap.min.css
        /css/bootstrap-toggle/bootstrap-toggle.min.css
        /css/ladda-themeless.min.css
        /css/daterangepicker.css
        /css/buttons/buttons.bootstrap.min.css
        /js/jquery.js
        /js/jqueryui.js
        /js/sgn.js
        /js/jquery/simpletooltip.js
        /js/jquery/cookie.js
        /js/jquery/dataTables.js
        /js/jquerymigrate.js
        /js/CXGN/Effects.js
        /js/CXGN/Page/FormattingHelpers.js
        /js/CXGN/UserPrefs.js
        /js/CXGN/Page/Toolbar.js
        /js/CXGN/List.js
        /js/CXGN/Login.js
        /js/bootstrap_min.js
        /js/CXGN/BreedersToolbox/HTMLSelect.js
        /js/bootstrap-toggle_min.js
    );

#Called by application from sgn/mason/brapiclient/*.mas
$mech->get_ok($_) for
    qw(
        /js/brapi/Table.js
    );

#Called by application from sgn/mason/breeders_toolbox/breeder_search*
$mech->get_ok($_) for
    qw(
        /js/CXGN/BreederSearch.js
        /js/spin_min.js
        /js/ladda_min.js
    );

#Called by application from sgn/mason/breeders_toolbox/cross/index.mas
$mech->get_ok($_) for
    qw(
        /js/thickbox.js
        /js/CXGN/Phenome/Tools.js
        /js/CXGN/BreedersToolbox/CrossDetailPage.js
    );

#Called by application from sgn/mason/breeders_toolbox/crosses.mas
$mech->get_ok($_) for
    qw(
        /js/jquery/iframe-post-form.js
        /js/CXGN/BreedersToolbox/Crosses.js
        /js/jstree/dist/jstree.js
        /js/CXGN/TrialTreeFolders.js
    );

#Called by application from sgn/mason/breeders_toolbox/genotyping_trials/detail.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Trial.js
        /js/CXGN/BreedersToolbox/GenotypingTrial.js
    );

#Called by application from sgn/mason/breeders_toolbox/genotyping_trials/trials.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/BreedersToolbox/AddTrial.js
        /js/CXGN/BreedersToolbox/UploadTrial.js
    );

#Called by application from sgn/mason/breeders_toolbox/index.mas
$mech->get_ok($_) for
    qw(
        /js/icon_nav.js
    );

#Called by application from sgn/mason/breeders_toolbox/manage_accessions.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/BreedersToolbox/Accessions.js
        /js/CXGN/BreedersToolbox/UploadPedigrees.js
        /js/jquery/dataTables-bootstrap-min.js
    );

#Called by application from sgn/mason/breeders_toolbox/projects.mas and sgn/mason/breeders_toolbox/trialtree.mas and sgn/mason/breeders_toolbox/trialtreefolders.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/BreedersToolbox/AddTrial.js
        /js/CXGN/BreedersToolbox/UploadTrial.js
        /js/CXGN/BreedersToolbox/Trial.js
        /js/CXGN/Trial.js
        /js/CXGN/TrialTreeFolders.js
    );

#Called by application from sgn/mason/breeders_toolbox/selection_index.mas
$mech->get_ok($_) for
    qw(
        /js/jquery/dataTables-min.js
        /js/jquery/dataTables-buttons-min.js
        /js/jszip-min.js
        /js/pdfmake/pdfmake-min.js
        /js/pdfmake/vfs_fonts.js
        /js/buttons/bootstrap-min.js
        /js/buttons/html5-min.js
        /js/buttons/print-min.js
        /js/buttons/colvis-min.js
        /js/CXGN/SelectionIndex.js
    );

#Called by application from sgn/mason/breeders_toolbox/trial.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Trial.js
        /js/moment_min.js
        /js/daterangepicker.js
    );

#Called by application from sgn/mason/breeders_toolbox/trial/phenotype_summary.mas
$mech->get_ok($_) for
    qw(
        /js/d3/d3Min.js
        /js/SGN/Histogram.js
    );

#Called by application from sgn/mason/breeders_toolbox/trial/trial_coords.mas
$mech->get_ok($_) for
    qw(
        /js/kinetics/kinetic.js
    );

#Called by application from sgn/mason/breeders_toolbox/upload_phenotype*.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/BreedersToolbox/UploadPhenotype.js
    );

#Called by application from sgn/mason/calendar*.mas
$mech->get_ok($_) for
    qw(
        /js/calendar/moment_min.js
        /js/calendar/fullcalendar_min.js
        /js/calendar/fullcalendar_gcal_min.js
        /js/calendar/bootstrap_datepicker_min.js
        /css/datepicker.css
    );

#Called by application from sgn/mason/chado/cvterm.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/AJAX/Ontology.js
        /js/CXGN/Phenome/Qtl.js
    );

#Called by application from sgn/mason/chado/publication.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Phenome/Publication.js
    );

#Called by application from sgn/mason/cview/*.mas
$mech->get_ok($_) for
    qw(
        /js/MochiKit/Async.js
    );

#Called by application from sgn/mason/fieldbook/home.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/BreedersToolbox/FieldBook.js
    );

#Called by application from sgn/mason/genefamily/manual*.mas
$mech->get_ok($_) for
    qw(
        /js/popup.js
        /js/CXGN/Phenome/Locus.js
        /js/CXGN/Sunshine/NetworkBrowser.js
    );

#Called by application from sgn/mason/solgs*.mas
$mech->get_ok($_) for
    qw(
        /css/solgs/solgs.css
        /js/solGS/solGS.js
        /js/solGS/pca.js
        /js/solGS/listTypeSelectionPopulation.js
        /js/solGS/searchTrials.js
        /js/solGS/searchTraits.js
        /js/solGS/combineTrials.js
        /js/solGS/traitGebvFlot.js
        /js/solGS/phenotypeDataFlot.js
        /js/solGS/combinePopulations.js
        /js/solGS/analysisStatus.js
        /js/solGS/correlation.js
        /js/solGS/linePlot.js
        /js/solGS/histogram.js
        /js/solGS/normalDistribution.js
        /js/solGS/geneticGain.js
        /js/solGS/selectionIndex.js
        /js/solGS/ajaxAutocomplete.js
        /js/solGS/selectionPopulations.js
        /js/solGS/gebvPhenoRegression.js
        /js/flot/flot.js
        /js/flot/categories.js
        /js/flot/tooltip.js
        /js/flot/navigate.js
        /js/flot/selection.js
        /js/flot/axisLabels.js
        /js/statistics/simple_statistics.js
    );

#Called by application from sgn/mason/page/form.mas, sgn/mason/solgs/page/form.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Page/Form/JSFormPage.js
        /js/MochiKit/Logging.js
    );

#Called by application from sgn/mason/solgs/util/*.mas
$mech->get_ok($_) for
    qw(
        /js/MochiKit/DOM.js
        /js/Text/Markup.js
    );

#Called by application from sgn/mason/page/*.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Page/Comments.js
        /js/CXGN/Page/Form/JSFormPage.js
    );

#Called by application from sgn/mason/search/features.mas
$mech->get_ok($_) for
    qw(
        /js/SGN/Search/Feature.js
    );

#Called by application from sgn/mason/secretom/*.mas
$mech->get_ok($_) for
    qw(
        /js/jquery/colorbox.js
    );

#Called by application from sgn/mason/stock/index.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Stock.js
    );

#Called by application from sgn/mason/tools/blast/index.mas
$mech->get_ok($_) for
    qw(
        /js/CXGN/Blast.js
    );

#Called by application from sgn/mason/tools/expression/index.mas
$mech->get_ok($_) for
    qw(
        /js/sprintf.js
        /js/Text/Markup.js
    );

#Called by application from sgn/mason/tools/vigs/input.mas
$mech->get_ok($_) for
    qw(
        /js/sprintf.js
        /js/Text/Markup.js
        /js/tools/vigs.js
    );


#SITE SPECIFICS



$mech->get_ok($_) for
    qw(
        /img/sgn_logo_icon.png
    );

#Called from cassava/mason/*
$mech->get_ok($_) for
    qw(
        /css/nextgen-cassava-base-new.css
        /documents/inc/jquery-cassava-theme/jquery-ui-1.10.3.custom.css
        /documents/img/cassava/nextgen_cassava_icon.png
        /static/documents/img/cassava/cassavabase.gif
    );

#Called from cassbase/mason/*
$mech->get_ok($_) for
    qw(
        /css/nextgen-cassava-base-new.css
        /documents/inc/jquery-cassava-theme/jquery-ui-1.10.3.custom.css
        /documents/img/CASSbase/cass_logo_4c.gif
    );

#Called from citrusgreening/mason/*
$mech->get_ok($_) for
    qw(
        /css/citrusgreening.css
        /img/citrusgreening/cg_logo_icon.png
        /documents/img/citrusgreening/cg_logo.png
        /documents/img/citrusgreening/cg_name.png
    );

#Called from fernbase/mason/*
$mech->get_ok($_) for
    qw(
        /css/nextgen-cassava-base-new.css
        /documents/inc/jquery-cassava-theme/jquery-ui-1.10.3.custom.css
        /documents/img/fernbase/fern.png
    );

#Called from musabase/mason/*,
$mech->get_ok($_) for
    qw(
        /css/nextgen-cassava-base-new.css
        /documents/inc/jquery-cassava-theme/jquery-ui-1.10.3.custom.css
        /documents/img/sgn_transparent_logo.png
    );

#Called from sweetpotatobase/mason/*,
$mech->get_ok($_) for
    qw(
        /css/nextgen-cassava-base-new.css
        /documents/inc/jquery-cassava-theme/jquery-ui-1.10.3.custom.css
        /documents/img/sweetpotatobase/sweetpotatobase_logo.png
    );

#Called from yambase/mason/*,
$mech->get_ok($_) for
    qw(
        /css/nextgen-cassava-base-new.css
        /documents/inc/jquery-cassava-theme/jquery-ui-1.10.3.custom.css
        /documents/img/AfricaYamLogo.jpg
    );


done_testing;
