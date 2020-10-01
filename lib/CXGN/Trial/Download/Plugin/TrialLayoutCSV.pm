
package CXGN::Trial::Download::Plugin::TrialLayoutCSV;

=head1 NAME

CXGN::Trial::Download::Plugin::TrialLayoutCSV

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a trial's layout (as used from CXGN::Trial::Download->trial_download):

A trial's layout can optionally include treatment and phenotype summary
information, mapping to treatment_project_ids and trait_list.
These keys can be ignored if you don't need them in the layout.

As a XLS:
my $plugin = "TrialLayoutExcel";

As a CSV:
my $plugin = "TrialLayoutCSV";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    trial_list => \@trial_ids,
    trait_list => \@trait_list,
    filename => $tempfile,
    format => $plugin,
    data_level => $data_level,
    treatment_project_ids => \@treatment_project_ids,
    selected_columns => $selected_cols,
});
my $error = $download->download();
my $file_name = $trial_id . "_" . "$what" . ".$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);


=head1 AUTHORS

=cut

use Moose::Role;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use Data::Dumper;

sub validate { 
    return 1;
}

sub download { 
    my $self = shift;
    my @trial_ids = $self->trial_id() ? ($self->trial_id()) : ();
    if ($self->trial_list) {
        push @trial_ids, (@{$self->trial_list});
    }

    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();

    my $it = 0;
    foreach my $trial_id (@trial_ids) {
        my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $trial_id });
        my $treatments = $trial->get_treatments();

        my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
            schema => $self->bcs_schema,
            trial_id => $trial_id,
            data_level => $self->data_level,
            treatment_project_ids => $self->treatment_project_ids,
            selected_columns => $self->selected_columns,
            selected_trait_ids => $self->trait_list,
        });
        my $output = $trial_layout_download->get_layout_output();
        if ($output->{error_messages}){
            return $output;
        }
        my @output_array = @{$output->{output}};
        if ($it > 0) {
            my $header = shift @output_array;
        }
        no warnings 'uninitialized';
        foreach my $l (@output_array){
            print $F '"';
            print $F join '","', @$l;
            print $F '"';
            print $F "\n";
        }
        $it++;
    }

    close($F);
}

1;
