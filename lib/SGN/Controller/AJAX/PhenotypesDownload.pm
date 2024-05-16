
=head1 NAME

SGN::Controller::AJAX::PhenotypesDownload - a REST controller class to provide the
backend for downloading phenotype spreadsheets

=head1 DESCRIPTION

Downloading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesDownload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use List::MoreUtils qw /any /;
use SGN::View::ArrayElements qw/array_elements_simple_view/;
use CXGN::Stock::StockTemplate;
use JSON -support_by_pp;
use CXGN::Phenotypes::CreateSpreadsheet;
use CXGN::Trial::Download;
use Tie::UrlEncoder; our(%urlencode);
use Data::Dumper;
use JSON qw( decode_json );

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub create_phenotype_spreadsheet :  Path('/ajax/phenotype/create_spreadsheet') : ActionClass('REST') { }

sub create_phenotype_spreadsheet_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->forward('create_phenotype_spreadsheet_POST');
}

sub create_phenotype_spreadsheet_POST : Args(0) {
    print STDERR "phenotype download controller\n";
    my ($self, $c) = @_;
    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to download a phenotype spreadsheet." };
        return;
    }

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my @trial_ids = @{_parse_list_from_json($c->req->param('trial_ids'))};
    #print STDERR Dumper \@trial_ids;
    my $format = $c->req->param('format') || "ExcelBasic";
    my $include_notes = $c->req->param('include_notes');
    my $data_level = $c->req->param('data_level') || "plots";
    my $file_format = $c->req->param('create_spreadsheet_phenotype_file_format') || "detailed";
    my $sample_number = $c->req->param('sample_number');
    if ($sample_number eq '') {$sample_number = undef};
    my $predefined_columns = $c->req->param('predefined_columns') ? decode_json $c->req->param('predefined_columns') : [];
    my $trial_stock_type = $c->req->param('trial_stock_type');
    #print STDERR Dumper $sample_number;
    #print STDERR Dumper $predefined_columns;
   
    my $trial_name = "";
    foreach (@trial_ids){
        my $trial = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id), trial_id => $_ });
	      $trial_name = $trial->get_name();
	      $trial_name =~ s/ /\_/g;

        if ($data_level eq 'plants') {
            if (!$trial->has_plant_entries()) {
                $c->stash->{rest} = { error => "The requested trial (".$trial->get_name().") does not have plant entries. Please create the plant entries first." };
                return;
            }
        }
        if ($data_level eq 'subplots' || $data_level eq 'plants_subplots') {
            if (!$trial->has_subplot_entries()) {
                $c->stash->{rest} = { error => "The requested trial (".$trial->get_name().") does not have subplot entries." };
                return;
            }
        }
        if ($data_level eq 'tissue_samples') {
            if (!$trial->has_tissue_sample_entries()) {
                $c->stash->{rest} = { error => "The requested trial (".$trial->get_name().") does not have tissue sample entries. Please create the tissue sample entries first." };
                return;
            }
        }
    }

    my @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
    my $dir = $c->tempfiles_subdir('/download');
    my $rel_file = $c->tempfile( TEMPLATE => "download/$trial_name"."_phenotype_collectionXXXX");
    $rel_file = substr $rel_file, 0, -4;
    my $tempfile = $c->config->{basepath}."/".$rel_file.".xlsx";
    my $create_spreadsheet = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trial_list => \@trial_ids,
        trait_list => \@trait_list,
        filename => $tempfile,
        format => $format,
        data_level => $data_level,
        include_notes => $include_notes,
        sample_number => $sample_number,
        predefined_columns => $predefined_columns,
        trial_stock_type => $trial_stock_type,
    });

    $create_spreadsheet->download();

    print STDERR "DOWNLOAD FILENAME = ".$create_spreadsheet->filename()."\n";
    print STDERR "RELATIVE  = $rel_file\n";

    #Add postcomposed terms from selected predefined_columns
    if (scalar(@$predefined_columns)>0){
        my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
        my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
        my $composable_cvterm_format = $c->config->{composable_cvterm_format};
        my @allowed_composed_cvs_minus_trait = grep { $_ ne 'trait' } @allowed_composed_cvs;
        my %id_hash;
        for my $i (0 .. scalar @$predefined_columns){
            my $cv_type = $allowed_composed_cvs_minus_trait[$i];
            foreach my $selected_term (values %{$predefined_columns->[$i]}){
                my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $selected_term)->cvterm_id();
                push @{$id_hash{$cv_type}}, $cvterm_id;
            }
        }
        my @trait_cvterm_ids;
        foreach (@trait_list){
            push @trait_cvterm_ids, SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $_)->cvterm_id();
        }
        $id_hash{'trait'} = \@trait_cvterm_ids;
        #print STDERR Dumper \%id_hash;
        my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, \%id_hash);
        my %new_traits;
        foreach (@{$traits->{new_traits}}){
            $new_traits{$_->[1]} = join ',', @{$_->[0]};
        }
        #print STDERR Dumper \%new_traits;
        my $new_terms;
        eval {
            my $onto = CXGN::Onto->new({ schema => $schema });
            $new_terms = $onto->store_composed_term(\%new_traits);
        };
        if ($@) {
            die "An error occurred saving the new trait details: $@";
        }
        #print STDERR Dumper $new_terms;
    }

    $c->stash->{rest} = { filename => $urlencode{$rel_file.".xlsx"} };
}

sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
      #my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
      my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}

#########
1;
#########
