=head1 NAME

SGN::Controller::AJAX::Intercross - a REST controller class to provide the
functions for download and upload Intercross files

=head1 DESCRIPTION


=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut

package SGN::Controller::AJAX::Intercross;
use Moose;
use Try::Tiny;
use DateTime;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use Data::Dumper;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use List::MoreUtils qw /any /;
use List::MoreUtils 'none';
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::UploadFile;
use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddProgeny;
use CXGN::Pedigree::AddProgeniesExistingAccessions;
use CXGN::Pedigree::AddCrossInfo;
use CXGN::Pedigree::AddFamilyNames;
use CXGN::Pedigree::AddPopulations;
use CXGN::Pedigree::AddCrossTransaction;
use CXGN::Pedigree::ParseUpload;
use CXGN::Trial::Folder;
use CXGN::Trial::TrialLayout;
use CXGN::Stock::StockLookup;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use CXGN::Cross;
use JSON;
use Tie::UrlEncoder; our(%urlencode);
use LWP::UserAgent;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);
use Sort::Key::Natural qw(natsort);
BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub download_parents_file : Path('/ajax/intercross/download_parents_file') : ActionClass('REST') { }

sub download_parents_file_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $female_list_id = $c->req->param("female_list_id");
    my $male_list_id = $c->req->param("male_list_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $female_list = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $female_list_id});
    my $female_elements = $female_list->retrieve_elements_with_ids($female_list_id);

    my $male_list = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $male_list_id});
    my $male_elements = $male_list->retrieve_elements_with_ids($male_list_id);

    my @all_rows;
    foreach my $female (@$female_elements){
        push @all_rows, [$female->[0], '0', $female->[1]]
    }
    foreach my $male (@$male_elements){
        push @all_rows, [$male->[0], '1', $male->[1]]
    }
    print STDERR "ALL ROWS =".Dumper(\@all_rows)."\n";

    my $dl_token = $c->req->param("intercross_parents_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "intercross_parents_download_XXXXX", UNLINK=> 0);

    open(my $FILE, '> :encoding(UTF-8)', $tempfile) or die "Cannot open tempfile $tempfile: $!";

    print $FILE "codeId\tsex\tname\n";
    my $parent = 0;
    foreach my $row (@all_rows) {
        print $FILE $row;
        $parent++;
    }
    close $FILE;

    my $filename = "intercross_parents.txt";

    my $filename = "pedigree.txt";

    $c->res->content_type("application/text");
    $c->res->cookies->{$dl_cookie} = {
      value => $dl_token,
      expires => '+1m',
    };

    $c->res->header("Content-Disposition", qq[attachment; filename="$filename"]);

    my $output = "";
    open(my $F, "< :encoding(UTF-8)", $tempfile) || die "Can't open file $tempfile for reading.";
    while (<$F>) {
	$output .= $_;
    }
    close($F);

    $c->res->body($output);

}



1;
