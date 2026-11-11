package SGN::Controller::AJAX::VarietySheet;

=head1 NAME

SGN::Controller::AJAX::VarietySheet - endpoints for the commercial variety sheet editor

=head1 DESCRIPTION

Used by /tools/variety_sheet (mason/tools/variety_sheet/index.mas and
js/source/entries/variety_sheet.js). See L<CXGN::VarietySheet>.

=cut

use Moose;
use JSON::XS;
use Try::Tiny;
use List::Util qw(any);
use CXGN::VarietySheet;
use CXGN::Stock;
use SGN::Image;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub _schema {
    my ($self, $c) = @_;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    return $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
}

sub _person_id {
    my ($self, $c) = @_;
    return $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
}

# curators, breeders and submitters can make sheets
sub _can_edit {
    my ($self, $c) = @_;
    return 0 unless $c->user();
    return (any { $_ eq 'curator' || $_ eq 'breeder' || $_ eq 'submitter' } $c->user->roles()) ? 1 : 0;
}

sub _is_curator {
    my ($self, $c) = @_;
    return $c->user() && $c->user->check_roles('curator') ? 1 : 0;
}

sub _fail {
    my ($self, $c, $msg) = @_;
    $c->stash->{rest} = { error => $msg };
    $c->detach();
}

sub _require_editor {
    my ($self, $c) = @_;
    $self->_fail($c, 'You must be logged in to edit variety sheets.') unless $c->user();
    $self->_fail($c, 'Only curators, breeders and submitters can edit variety sheets.') unless $self->_can_edit($c);
}

sub _int_list {
    my $v = shift;
    return () unless defined $v;
    return grep { /^\d+$/ } (ref $v eq 'ARRAY' ? @$v : split /,/, $v);
}

sub _json_body {
    my ($self, $c) = @_;
    my $raw = $c->req->param('data');
    if (!defined $raw && $c->req->body) {
        my $fh = $c->req->body;
        local $/;
        seek($fh, 0, 0) if ref $fh;
        $raw = ref $fh ? <$fh> : $fh;
    }
    my $d = eval { decode_json($raw // '') };
    $self->_fail($c, 'Invalid request data.') unless ref $d eq 'HASH';
    return $d;
}

=head2 /ajax/variety_sheet/find_accession?name=

Resolves an accession name (or synonym / released variety name) to its stock_id.

=cut

sub find_accession : Path('/ajax/variety_sheet/find_accession') Args(0) {
    my ($self, $c) = @_;
    my $name = $c->req->param('name') // '';
    $name =~ s/^\s+|\s+$//g;
    $self->_fail($c, 'Type an accession name.') unless length $name;
    my $schema = $self->_schema($c);
    my $accession = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $rows = $schema->storage->dbh->selectall_arrayref(
        "SELECT s.stock_id, s.uniquename, 'name' FROM stock s WHERE s.type_id=? AND s.is_obsolete='f' AND lower(s.uniquename)=lower(?)
         UNION
         SELECT s.stock_id, s.uniquename, c.name FROM stockprop sp JOIN cvterm c ON c.cvterm_id=sp.type_id JOIN stock s ON s.stock_id=sp.stock_id
          WHERE s.type_id=? AND s.is_obsolete='f' AND c.name IN ('stock_synonym','released_variety_name') AND lower(sp.value)=lower(?)",
        undef, $accession, $name, $accession, $name);
    $self->_fail($c, "No accession named '$name' was found.") unless @$rows;
    my %seen;
    $c->stash->{rest} = { matches => [ grep { !$seen{$_->{stock_id}}++ } map { { stock_id => $_->[0] + 0, name => $_->[1], matched_as => $_->[2] } } @$rows ] };
}

=head2 /ajax/variety_sheet/accession_summary?stock_id=

Everything the editor needs about one accession.

=cut

sub accession_summary : Path('/ajax/variety_sheet/accession_summary') Args(0) {
    my ($self, $c) = @_;
    my ($stock_id) = _int_list($c->req->param('stock_id'));
    $self->_fail($c, 'stock_id is required.') unless $stock_id;
    my $schema = $self->_schema($c);
    my $r = CXGN::VarietySheet->accession_summary($schema, $stock_id);
    $self->_fail($c, $r->{error}) if $r->{error};
    $r->{images} = $self->_images($c, $schema, $stock_id);
    $r->{can_edit} = $self->_can_edit($c);
    $r->{can_save_names} = ($c->user() && (any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'breeder' } $c->user->roles())) ? 1 : 0;
    $c->stash->{rest} = $r;
}

# accession images first, then images of its plots/plants
sub _images {
    my ($self, $c, $schema, $stock_id) = @_;
    my $dbh = $schema->storage->dbh();
    my @rel = grep { defined } map { my $r = SGN::Model::Cvterm->get_cvterm_row($schema, $_, 'stock_relationship'); $r ? $r->cvterm_id : undef } qw(plot_of plant_of subplot_of);
    my $rel_in = @rel ? join(',', @rel) : 'NULL';
    my $rows = $dbh->selectall_arrayref(
        "SELECT DISTINCT ON (md.image_id) md.image_id, md.name, md.description, md.original_filename, s.stock_id, s.uniquename,
                (s.stock_id = ?) AS own, si.display_order, to_char(md.create_date, 'YYYY-MM-DD')
           FROM phenome.stock_image si
           JOIN metadata.md_image md ON md.image_id=si.image_id AND md.obsolete='f'
           JOIN stock s ON s.stock_id=si.stock_id
          WHERE si.stock_id=? OR si.stock_id IN (SELECT subject_id FROM stock_relationship WHERE object_id=? AND type_id IN ($rel_in))
          ORDER BY md.image_id", undef, $stock_id, $stock_id, $stock_id);
    my @images;
    for my $r (sort { ($b->[6] ? 1 : 0) <=> ($a->[6] ? 1 : 0) || ($a->[7] // 1e9) <=> ($b->[7] // 1e9) || $b->[0] <=> $a->[0] } @$rows) {
        last if @images >= 400;
        my ($id, $name, $desc, $file, $sid, $sname, $own, undef, $date) = @$r;
        my ($medium, $large) = eval {
            my $img = SGN::Image->new($dbh, $id, $c);
            ($img->get_image_url('medium'), $img->get_image_url('large'));
        };
        next unless $medium;
        push @images, { image_id => $id + 0, name => $name, description => $desc, filename => $file, date => $date,
                        url => $medium, url_large => $large, stock_id => $sid + 0, stock_name => $sname, own => $own ? 1 : 0 };
    }
    return \@images;
}

=head2 /ajax/variety_sheet/check_name?name=&stock_id=

=cut

sub check_name : Path('/ajax/variety_sheet/check_name') Args(0) {
    my ($self, $c) = @_;
    my $name = $c->req->param('name') // '';
    my ($stock_id) = _int_list($c->req->param('stock_id'));
    $self->_fail($c, 'name and stock_id are required.') unless length($name) && $stock_id;
    $c->stash->{rest} = CXGN::VarietySheet->check_name($self->_schema($c), $name, $stock_id);
}

=head2 /ajax/variety_sheet/analysis_traits?analysis_id=

=cut

sub analysis_traits : Path('/ajax/variety_sheet/analysis_traits') Args(0) {
    my ($self, $c) = @_;
    my ($id) = _int_list($c->req->param('analysis_id'));
    $self->_fail($c, 'analysis_id is required.') unless $id;
    $c->stash->{rest} = { traits => CXGN::VarietySheet->analysis_traits($self->_schema($c), $id) };
}

=head2 POST /ajax/variety_sheet/performance

data = { stock_id, checks:[ids], traits:[ids], direction:{trait_id:'higher'|'lower'},
         source:'trials'|'analysis', analysis_id, year_min, year_max }

=cut

sub performance : Path('/ajax/variety_sheet/performance') Args(0) {
    my ($self, $c) = @_;
    my $d = $self->_json_body($c);
    my ($stock_id) = _int_list($d->{stock_id});
    my @checks = _int_list($d->{checks});
    my @traits = _int_list($d->{traits});
    $self->_fail($c, 'stock_id is required.') unless $stock_id;
    $self->_fail($c, 'Choose at least one trait.') unless @traits;
    $self->_fail($c, 'Choose at most 10 checks.') if @checks > 10;
    $self->_fail($c, 'Choose at most 40 traits.') if @traits > 40;
    my %dir = map { $_ => ($d->{direction}{$_} // '') eq 'lower' ? 'lower' : 'higher' } @traits;
    my $schema = $self->_schema($c);
    my $r;
    if (($d->{source} // '') eq 'analysis') {
        my ($aid) = _int_list($d->{analysis_id});
        $self->_fail($c, 'Choose an analysis.') unless $aid;
        $r = CXGN::VarietySheet->analysis_performance($schema, $aid, $stock_id, \@checks, \@traits, { direction => \%dir });
    } else {
        $r = CXGN::VarietySheet->trial_performance($schema, $stock_id, \@checks, \@traits,
            { direction => \%dir, year_min => $d->{year_min}, year_max => $d->{year_max} });
    }
    $self->_fail($c, $r->{error}) if $r->{error};
    $r->{computed_on} = do { my @t = localtime; sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]) };
    $c->stash->{rest} = $r;
}

=head2 GET /ajax/variety_sheet/list[?stock_id=]

Published sheets plus the user's own drafts (curators see all).

=cut

sub list : Path('/ajax/variety_sheet/list') Args(0) {
    my ($self, $c) = @_;
    my ($stock_id) = _int_list($c->req->param('stock_id'));
    my $f = { stock_id => $stock_id };
    if (!$self->_is_curator($c)) {
        my $pid = $self->_person_id($c);
        if ($pid) { $f->{visible_to} = $pid } else { $f->{published} = 1 }
    }
    my $rows = CXGN::VarietySheet->list_sheets($self->_schema($c), $f);
    my $pid = $self->_person_id($c) // -1;
    $_->{can_edit} = ($self->_is_curator($c) || ($_->{sp_person_id} // -2) == $pid) ? 1 : 0 for @$rows;
    $c->stash->{rest} = { sheets => $rows };
}

=head2 GET /ajax/variety_sheet/get?sheet_id=

=cut

sub get_sheet : Path('/ajax/variety_sheet/get') Args(0) {
    my ($self, $c) = @_;
    my ($id) = _int_list($c->req->param('sheet_id'));
    $self->_fail($c, 'sheet_id is required.') unless $id;
    my $row = CXGN::VarietySheet->get_sheet($self->_schema($c), $id);
    $self->_fail($c, 'Variety sheet not found.') unless $row;
    my $pid = $self->_person_id($c) // -1;
    my $own = ($row->{sp_person_id} // -2) == $pid;
    $self->_fail($c, 'This variety sheet is a draft that belongs to another user.')
        unless $row->{status} eq 'published' || $own || $self->_is_curator($c);
    $row->{can_edit} = ($own || $self->_is_curator($c)) ? 1 : 0;
    $c->stash->{rest} = $row;
}

=head2 POST /ajax/variety_sheet/save

data = { sheet_id?, stock_id, status:'draft'|'published', sheet:{...},
         name_options:{ released_variety_name:0|1, synonym:0|1 } }

Saves the sheet and, if asked, stores the commercial name on the accession.

=cut

sub save : Path('/ajax/variety_sheet/save') Args(0) {
    my ($self, $c) = @_;
    $self->_require_editor($c);
    my $d = $self->_json_body($c);
    my $schema = $self->_schema($c);
    my ($stock_id) = _int_list($d->{stock_id});
    my ($sheet_id) = _int_list($d->{sheet_id});
    my $sheet = $d->{sheet};
    $self->_fail($c, 'stock_id is required.') unless $stock_id;
    $self->_fail($c, 'Sheet content is missing.') unless ref $sheet eq 'HASH';
    my $status = ($d->{status} // '') eq 'published' ? 'published' : 'draft';
    my $name = $sheet->{commercial_name} // '';
    $name =~ s/^\s+|\s+$//g;
    $self->_fail($c, 'A commercial name is required.') unless length $name;
    $self->_fail($c, 'The commercial name is too long (max 100 characters).') if length($name) > 100;
    $sheet->{commercial_name} = $name;
    my $size = length(encode_json($sheet));
    $self->_fail($c, 'The sheet is too large.') if $size > 2_000_000;

    my $accession_type = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my ($accession_name) = $schema->storage->dbh->selectrow_array(
        "SELECT uniquename FROM stock WHERE stock_id=? AND type_id=? AND is_obsolete='f'", undef, $stock_id, $accession_type);
    $self->_fail($c, "Accession $stock_id not found.") unless $accession_name;

    my $pid = $self->_person_id($c);
    if ($sheet_id) {
        my $row = CXGN::VarietySheet->get_sheet($schema, $sheet_id);
        $self->_fail($c, 'Variety sheet not found.') unless $row;
        $self->_fail($c, 'Only the owner of this sheet or a curator can change it.')
            unless ($row->{sp_person_id} // -1) == $pid || $self->_is_curator($c);
        $self->_fail($c, 'The sheet belongs to a different accession.') unless $row->{stock_id} == $stock_id;
    }

    # commercial name on the accession
    my @name_messages;
    my $opts = $d->{name_options} || {};
    if ($opts->{released_variety_name} || $opts->{synonym}) {
        my $check = CXGN::VarietySheet->check_name($schema, $name, $stock_id);
        if (@{ $check->{conflicts} }) {
            $self->_fail($c, "The name '$name' is already used by " . join(', ', map { "$_->{name} (as $_->{as})" } @{ $check->{conflicts} })
                . ". Choose another name or keep it on the sheet only.");
        }
        my $stock_row = $schema->resultset('Stock::Stock')->find({ stock_id => $stock_id });
        my @added;
        if ($opts->{released_variety_name} && !$check->{already_released_name}) {
            $stock_row->create_stockprops({ released_variety_name => $name }, { autocreate => 1 });
            push @added, 'released variety name';
        }
        if ($opts->{synonym} && !$check->{already_synonym} && !$check->{already_name}) {
            $stock_row->create_stockprops({ stock_synonym => $name }, { autocreate => 1 });
            push @added, 'synonym';
        }
        if (@added) {
            my $note = "Variety sheet: added '$name' as " . join(' and ', @added);
            try {
                CXGN::Stock->new({ schema => $schema, stock_id => $stock_id, is_saving => 1, sp_person_id => $pid,
                                   user_name => $c->user->get_object()->get_username(), modification_note => $note })->store();
            } catch { print STDERR "VarietySheet: could not record stock modification: $_\n"; };
            push @name_messages, "Saved '$name' on $accession_name as " . join(' and ', @added) . '.';
        }
    }

    $sheet->{stock_id} = $stock_id + 0;
    $sheet->{accession_name} = $accession_name;
    my $id = CXGN::VarietySheet->save_sheet($schema, {
        sheet_id => $sheet_id, stock_id => $stock_id, sp_person_id => $pid, commercial_name => $name, status => $status, sheet => $sheet });

    $c->stash->{rest} = { success => 1, sheet_id => $id + 0, status => $status, url => "/variety_sheet/$id", messages => \@name_messages };
}

=head2 POST /ajax/variety_sheet/delete  (sheet_id)

=cut

sub delete : Path('/ajax/variety_sheet/delete') Args(0) {
    my ($self, $c) = @_;
    $self->_require_editor($c);
    my ($id) = _int_list($c->req->param('sheet_id'));
    $self->_fail($c, 'sheet_id is required.') unless $id;
    my $schema = $self->_schema($c);
    my $row = CXGN::VarietySheet->get_sheet($schema, $id);
    $self->_fail($c, 'Variety sheet not found.') unless $row;
    $self->_fail($c, 'Only the owner of this sheet or a curator can delete it.')
        unless ($row->{sp_person_id} // -1) == $self->_person_id($c) || $self->_is_curator($c);
    CXGN::VarietySheet->delete_sheet($schema, $id);
    $c->stash->{rest} = { success => 1 };
}

1;
