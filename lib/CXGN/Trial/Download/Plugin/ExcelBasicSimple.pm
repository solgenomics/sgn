package CXGN::Trial::Download::Plugin::ExcelBasicSimple;

=head1 NAME

CXGN::Trial::Download::Plugin::ExcelBasicSimple

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a trial's xls spreadsheet for collecting phenotypes (as used
from SGN::Controller::AJAX::PhenotypesDownload->create_phenotype_spreadsheet):

my $rel_file = $c->tempfile( TEMPLATE => 'download/downloadXXXXX');
my $tempfile = $c->config->{basepath}."/".$rel_file.".xls";
my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_list => \@trial_ids,
    trait_list => \@trait_list,
    filename => $tempfile,
    format => "ExcelBasicSimple",
    data_level => $data_level,
    sample_number => $sample_number,
});
$create_spreadsheet->download();
$c->stash->{rest} = { filename => $urlencode{$rel_file.".xls"} };


=head1 AUTHORS

=cut

use Moose::Role;
use JSON;
use Data::Dumper;
use Excel::Writer::XLSX;

sub verify {
    my $self = shift;
    return 1;
}


sub download {
    my $self = shift;

    my $schema = $self->bcs_schema();
    my @trial_ids = @{$self->trial_list()};
    my @trait_list = @{$self->trait_list()};
    my $spreadsheet_metadata = $self->file_metadata();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $self->filename() =~ /(\.[^.]+)$/;
    my $workbook;

    if ($extension eq '.xlsx') {
        $workbook = Excel::Writer::XLSX->new($self->filename());
    }
    else {
        $workbook = Spreadsheet::WriteExcel->new($self->filename());
    }

    my $ws = $workbook->add_worksheet();

    # generate worksheet headers
    #
    my $bold = $workbook->add_format();
    $bold->set_bold();

    my @column_headers = ('observationunit_name');
    my $num_col_before_traits = scalar(@column_headers);

    for(my $n=0; $n<scalar(@column_headers); $n++) {
        $ws->write(0, $n, $column_headers[$n]);
    }

    my $line = 1;
    foreach (@trial_ids){
        my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_} );
        my $trial_name = $trial->get_name;
        my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $_, experiment_type=>'field_layout'});
        my $design = $trial_layout->get_design();

        if (!$design) {
            return "No design found for trial: ".$trial_name;
        }
        my %design = %{$design};

        if ($self->data_level eq 'plots') {

            my @ordered_plots = sort { $a <=> $b} keys(%design);
            for(my $n=0; $n<@ordered_plots; $n++) {
                my %design_info = %{$design{$ordered_plots[$n]}};

                $ws->write($line, 0, $design_info{plot_name});
                $line++;
            }
        } elsif ($self->data_level eq 'plants') {

            my @ordered_plots = sort { $a <=> $b} keys(%design);
            for(my $n=0; $n<@ordered_plots; $n++) {
                my %design_info = %{$design{$ordered_plots[$n]}};
                my $plant_names = $design_info{plant_names};

                my $sampled_plant_names;
                if ($self->sample_number) {
                    my $sample_number = $self->sample_number;
                    foreach (@$plant_names) {
                        if ( $_ =~ m/_plant_(\d+)/) {
                            if ($1 <= $sample_number) {
                                push @$sampled_plant_names, $_;
                            }
                        }
                    }
                } else {
                    $sampled_plant_names = $plant_names;
                }

                foreach (@$sampled_plant_names) {
                    $ws->write($line, 0, $_);
                    $line++;
                }
            }
        } elsif ($self->data_level eq 'subplots') {

            my @ordered_plots = sort { $a <=> $b} keys(%design);
            for(my $n=0; $n<@ordered_plots; $n++) {
                my %design_info = %{$design{$ordered_plots[$n]}};
                my $subplot_names = $design_info{subplot_names};

                my $sampled_subplot_names;
                if ($self->sample_number) {
                    my $sample_number = $self->sample_number;
                    foreach (@$subplot_names) {
                        if ( $_ =~ m/_subplot_(\d+)/) {
                            if ($1 <= $sample_number) {
                                push @$sampled_subplot_names, $_;
                            }
                        }
                    }
                } else {
                    $sampled_subplot_names = $subplot_names;
                }

                foreach (@$sampled_subplot_names) {
                    $ws->write($line, 0, $_);
                    $line++;
                }
            }
        } elsif ($self->data_level eq 'plants_subplots') {

            my @ordered_plots = sort { $a <=> $b} keys(%design);
            for(my $n=0; $n<@ordered_plots; $n++) {
                my %design_info = %{$design{$ordered_plots[$n]}};
                my $subplot_plant_names = $design_info{subplots_plant_names};
                foreach my $s (sort keys %$subplot_plant_names){
                    my $plant_names = $subplot_plant_names->{$s};

                    foreach (sort @$plant_names) {
                        $ws->write($line, 0, $_);
                        $line++;
                    }
                }
            }
        } elsif ($self->data_level eq 'tissue_samples') {

            my @ordered_plots = sort { $a <=> $b} keys(%design);
            for(my $n=0; $n<@ordered_plots; $n++) {
                my %design_info = %{$design{$ordered_plots[$n]}};
                my $tissue_sample_plant_names = $design_info{plants_tissue_sample_names};
                foreach my $s (sort keys %$tissue_sample_plant_names){
                    my $tissue_sample_names = $tissue_sample_plant_names->{$s};

                    foreach (sort @$tissue_sample_names) {
                        $ws->write($line, 0, $_);
                        $line++;
                    }
                }
            }
        }
    }

    # write traits and format trait columns
    #
    my $lt = CXGN::List::Transform->new();

    my $transform = $lt->transform($schema, "traits_2_trait_ids", \@trait_list);

    if (@{$transform->{missing}}>0) {
    	print STDERR "Warning: Some traits could not be found. ".join(",",@{$transform->{missing}})."\n";
    }
    my @trait_ids = @{$transform->{transform}};

    my %cvinfo = ();
    foreach my $t (@trait_ids) {
        my $trait = CXGN::Trait->new( { bcs_schema=> $schema, cvterm_id => $t });
        $cvinfo{$trait->display_name()} = $trait;
        #print STDERR "**** Trait = " . $trait->display_name . "\n\n";
    }

    #print STDERR "Self include notes is ".$self->include_notes."\n";
    if ( $self->include_notes() && $self->include_notes() ne 'false') {
        push @trait_list, 'notes';
    }


    for (my $i = 0; $i < @trait_list; $i++) {
        #if (exists($cvinfo{$trait_list[$i]})) {
            #$ws->write(5, $i+6, $cvinfo{$trait_list[$i]}->display_name());
            $ws->write(0, $i+$num_col_before_traits, $trait_list[$i]);
        #}
        #else {
        #    print STDERR "Skipping output of trait $trait_list[$i] because it does not exist\n";
        #    next;
        #}

        for (my $n = 0; $n < $line; $n++) {
            if ($cvinfo{$trait_list[$i]}) {
                my $format = $cvinfo{$trait_list[$i]}->format();
                if ($format eq "numeric") {
                    $ws->data_validation($n+1, $i+$num_col_before_traits, { validate => "any" });
                }
                elsif ($format =~ /\,/) {  # is a list
                    $ws->data_validation($n+1, $i+$num_col_before_traits, {
                        validate => 'list',
                        value    => [ split ",", $format ]
                    });
                }
            }
        }
    }

    $workbook->close();

}

1;
