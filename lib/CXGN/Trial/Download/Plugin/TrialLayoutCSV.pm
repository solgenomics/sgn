
package CXGN::Trial::Download::Plugin::TrialLayoutCSV;

use Moose::Role;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use Data::Dumper;

sub validate { 
    return 1;
}

sub download { 
    my $self = shift;
    
    my $trial_layout = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $design = $trial_layout->get_design();

    my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $treatments = $trial->get_treatments();

    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();

    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $self->bcs_schema,
        trial_id => $self->trial_id,
        data_level => $self->data_level,
        treatment_project_ids => $self->treatment_project_ids,
        selected_columns => $self->selected_columns,
        selected_trait_ids => $self->trait_list,
        selected_trait_names => $self->selected_trait_names
    });
    my $output = $trial_layout_download->get_layout_output();
    if ($output->{error_messages}){
        return $output;
    }
    my @output_array = @{$output->{output}};
    foreach my $l (@output_array){
        print $F '"';
        print $F join '","', @$l;
        print $F '"';
        print $F "\n";
    }

    close($F);
}

1;
