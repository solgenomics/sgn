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
use CXGN::List::Validate;
use CXGN::List;
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
    my @female_accessions;
    my @male_accessions;
    foreach my $female (@$female_elements){
        push @female_accessions, $female->[1];
        push @all_rows, [$female->[0], '0', $female->[1]]
    }
    foreach my $male (@$male_elements){
        push @male_accessions, $male->[1];
        push @all_rows, [$male->[0], '1', $male->[1]]
    }

    my $list_error_message;
    my $female_validator = CXGN::List::Validate->new();
    my @female_accessions_missing = @{$female_validator->validate($schema,'uniquenames',\@female_accessions)->{'missing'}};
    if (scalar(@female_accessions_missing) > 0) {
        $list_error_message = "The following female parents did not pass validation: ".join("\n", @female_accessions_missing);
        $c->stash->{rest} = { error => $list_error_message };
        $c->detach();
    }

    my $male_validator = CXGN::List::Validate->new();
    my @male_accessions_missing = @{$male_validator->validate($schema,'uniquenames',\@male_accessions)->{'missing'}};
    if (scalar(@male_accessions_missing) > 0) {
        $list_error_message = "The following male parents did not pass validation: ".join("\n", @male_accessions_missing);
        $c->stash->{rest} = { error => $list_error_message };
        $c->detach();
    }

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    my $template_file_name = 'intercross_parents';
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory_name = "intercross_parents_files";
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$template_file_name.".csv");
    my $archive_path = $c->config->{archive_path};
    my $file_destination =  catfile($archive_path, $archived_file_name);
    print STDERR "FILE DESTINATION =".Dumper($file_destination)."\n";

    my $dbh = $c->dbc->dbh();
    my %errors;
    my @error_messages;

    my $dir = $c->tempfiles_subdir('/download');
    my $rel_file = $c->tempfile( TEMPLATE => 'download/intercross_parentsXXXXX');
    my $tempfile = $c->config->{basepath}."/".$rel_file.".csv";
    print STDERR "TEMPFILE =".Dumper($tempfile)."\n";
    open(my $FILE, '> :encoding(UTF-8)', $tempfile) or die "Cannot open tempfile $tempfile: $!";

    my @headers = qw(codeId sex name);
    my $formatted_header = join(',',@headers);
    print $FILE $formatted_header."\n";
    my $parent = 0;
    foreach my $row (@all_rows) {
        my @row_array = ();
        my @row_array = @$row;
        my $csv_format = join(',',@row_array);
        print STDERR "EACH CSV FORMAT =".Dumper($csv_format)."\n";
        print $FILE $csv_format."\n";
        $parent++;
    }
    close $FILE;

    open(my $F, "<", $tempfile) || die "Can't open file ".$self->tempfile();
    binmode $F;
    my $md5 = Digest::MD5->new();
    $md5->addfile($F);
    close($F);

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory_name));
    }

    my $md_row = $metadata_schema->resultset("MdMetadata")->create({
        create_person_id => $user_id,
    });
    $md_row->insert();
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($file_destination),
        dirname => dirname($file_destination),
        filetype => 'profile template xls',
        md5checksum => $md5->hexdigest(),
        metadata_id => $md_row->metadata_id(),
    });
    $file_row->insert();
    my $file_id = $file_row->file_id();

    move($tempfile,$file_destination);
    unlink $tempfile;

    my $result = $file_row->file_id;

    print STDERR "FILE =".Dumper($file_destination)."\n";
    print STDERR "FILE ID =".Dumper($file_id)."\n";
    $c->stash->{rest} = {
        success => 1,
        result => $result,
        file => $file_destination,
        file_id => $file_id,
    };

}



1;
