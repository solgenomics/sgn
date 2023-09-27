=head1 NAME

CXGN::PrivateCompany -


=head1 DESCRIPTION


=head1 AUTHOR

=cut

package CXGN::PrivateCompany;

use Moose;

use Data::Dumper;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'private_company_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'is_storing_or_editing' => (
    isa => 'Bool',
    is => 'rw',
    default => 0
);

has 'private_company_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_description' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_contact_email' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_contact_person_first_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_contact_person_last_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_contact_person_phone' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_address_street' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_address_street_2' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_address_state' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_address_city' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_address_zipcode' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_address_country' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_create_date' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_type_cvterm_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'private_company_type_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'private_company_members' => (
    isa => 'ArrayRef[ArrayRef[Str]]',
    is => 'rw',
);

#### If user id provided:

has 'sp_person_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'sp_person_access_cvterm_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'sp_person_access_cvterm_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'sp_person_administrator_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

sub BUILD {
    my $self = shift;

    if ($self->private_company_id){
        if (!$self->is_storing_or_editing) {
            my $q = "SELECT private_company.private_company_id, private_company.name, private_company.description, private_company.contact_email, private_company.contact_person_first_name, private_company.contact_person_last_name, private_company.contact_person_phone, private_company.address_street, private_company.address_street_2, private_company.address_state, private_company.city, private_company.address_zipcode, private_company.address_country, private_company.create_date, private_company_type.cvterm_id, private_company_type.name
                FROM sgn_people.private_company AS private_company
                JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
                WHERE private_company_id=?;";
            my $h = $self->schema->storage->dbh()->prepare($q);
            $h->execute($self->private_company_id);
            my ($private_company_id, $name, $description, $email, $first_name, $last_name, $phone, $address, $address2, $state, $city, $zipcode, $country, $create_date, $company_type_id, $company_type_name) = $h->fetchrow_array();
            $h = undef;

            $self->private_company_name($name);
            $self->private_company_description($description);
            $self->private_company_contact_email($email);
            $self->private_company_contact_person_first_name($first_name);
            $self->private_company_contact_person_last_name($last_name);
            $self->private_company_contact_person_phone($phone);
            $self->private_company_address_street($address);
            $self->private_company_address_street_2($address2);
            $self->private_company_address_state($state);
            $self->private_company_address_city($city);
            $self->private_company_address_zipcode($zipcode);
            $self->private_company_address_country($country);
            $self->private_company_create_date($create_date);
            $self->private_company_type_cvterm_id($company_type_id);
            $self->private_company_type_name($company_type_name);

            my @members;
            my $q2 = "SELECT p.sp_person_id, p.username, p.first_name, p.last_name, user_type.cvterm_id, user_type.name
                FROM sgn_people.private_company AS private_company
                JOIN sgn_people.private_company_sp_person AS sp ON(private_company.private_company_id=sp.private_company_id)
                JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
                JOIN cvterm AS user_type ON(sp.type_id=user_type.cvterm_id)
                JOIN sgn_people.sp_person AS p ON(p.sp_person_id=sp.sp_person_id)
                WHERE private_company.private_company_id=? AND sp.is_private='f';";
            my $h2 = $self->schema->storage->dbh()->prepare($q2);
            $h2->execute($self->private_company_id);
            while (my ($sp_person_id, $sp_username, $sp_first_name, $sp_last_name, $sp_user_type_id, $sp_user_type_name) = $h2->fetchrow_array()){
                push @members, [$sp_person_id, $sp_username, $sp_first_name, $sp_last_name, $sp_user_type_id, $sp_user_type_name];
            }
            $h2 = undef;

            $self->private_company_members(\@members);
        }

        if ($self->sp_person_id) {
            my $default_company_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'default_access', 'company_type')->cvterm_id();
            my $private_company_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'private_access', 'company_type')->cvterm_id();

            my $q3 = "SELECT user_type.cvterm_id, user_type.name
                FROM sgn_people.private_company AS private_company
                JOIN sgn_people.private_company_sp_person AS p ON(private_company.private_company_id=p.private_company_id)
                JOIN cvterm AS user_type ON(p.type_id=user_type.cvterm_id)
                WHERE private_company.private_company_id=? AND p.sp_person_id=? AND p.is_private='f' AND private_company.type_id IN(?,?);";
            my $h3 = $self->schema->storage->dbh()->prepare($q3);
            $h3->execute($self->private_company_id,$self->sp_person_id,$default_company_type_id,$private_company_type_id);
            my ($user_type_id, $user_type_name) = $h3->fetchrow_array();
            $h3 = undef;

            $self->sp_person_access_cvterm_id($user_type_id);
            $self->sp_person_access_cvterm_name($user_type_name);
        }
    }
    return $self;
}

sub get_users_private_companies {
    my $self = shift;
    my $sp_person_id = shift;
    my $include_members = shift;

    my $default_company_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'default_access', 'company_type')->cvterm_id();
    my $private_company_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'private_access', 'company_type')->cvterm_id();

    my $q;
    my $h;
    if ($sp_person_id) {
        my $q0 = "SELECT s.administrator
            FROM sgn_people.sp_person AS s
            WHERE s.sp_person_id=?;";
        my $h0 = $self->schema->storage->dbh()->prepare($q0);
        $h0->execute($sp_person_id);
        my ($person_administrator) = $h0->fetchrow_array();

        if ($person_administrator && $person_administrator eq 'site_admin') {
            $q = "SELECT private_company.private_company_id, private_company.name, private_company.description, private_company.contact_email, private_company.contact_person_first_name, private_company.contact_person_last_name, private_company.contact_person_phone, private_company.address_street, private_company.address_street_2, private_company.address_state, private_company.city, private_company.address_zipcode, private_company.address_country, private_company.create_date, private_company_type.cvterm_id, private_company_type.name, user_type.cvterm_id, user_type.name
                FROM sgn_people.private_company AS private_company
                LEFT JOIN sgn_people.private_company_sp_person AS p ON(private_company.private_company_id=p.private_company_id AND p.sp_person_id=? AND p.is_private='f')
                JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
                LEFT JOIN cvterm AS user_type ON(p.type_id=user_type.cvterm_id)
                WHERE private_company_type.cvterm_id IN(?,?);";
            $h = $self->schema->storage->dbh()->prepare($q);
            $h->execute($sp_person_id,$default_company_type_id,$private_company_type_id);
        } else {
            $q = "SELECT private_company.private_company_id, private_company.name, private_company.description, private_company.contact_email, private_company.contact_person_first_name, private_company.contact_person_last_name, private_company.contact_person_phone, private_company.address_street, private_company.address_street_2, private_company.address_state, private_company.city, private_company.address_zipcode, private_company.address_country, private_company.create_date, private_company_type.cvterm_id, private_company_type.name, user_type.cvterm_id, user_type.name
                FROM sgn_people.private_company AS private_company
                JOIN sgn_people.private_company_sp_person AS p ON(private_company.private_company_id=p.private_company_id)
                JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
                JOIN cvterm AS user_type ON(p.type_id=user_type.cvterm_id)
                WHERE p.sp_person_id=? AND p.is_private='f' AND private_company_type.cvterm_id IN(?,?);";
            $h = $self->schema->storage->dbh()->prepare($q);
            $h->execute($sp_person_id,$default_company_type_id,$private_company_type_id);
        }
    }
    else {
        $q = "SELECT private_company.private_company_id, private_company.name, private_company.description, private_company.contact_email, private_company.contact_person_first_name, private_company.contact_person_last_name, private_company.contact_person_phone, private_company.address_street, private_company.address_street_2, private_company.address_state, private_company.city, private_company.address_zipcode, private_company.address_country, private_company.create_date, private_company_type.cvterm_id, private_company_type.name
            FROM sgn_people.private_company AS private_company
            JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
            WHERE private_company_type.cvterm_id IN(?);";
        $h = $self->schema->storage->dbh()->prepare($q);
        $h->execute($default_company_type_id);
    }

    my $q2 = "SELECT p.sp_person_id, p.username, p.first_name, p.last_name, user_type.cvterm_id, user_type.name
        FROM sgn_people.private_company AS private_company
        JOIN sgn_people.private_company_sp_person AS sp ON(private_company.private_company_id=sp.private_company_id)
        JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
        JOIN cvterm AS user_type ON(sp.type_id=user_type.cvterm_id)
        JOIN sgn_people.sp_person AS p ON(p.sp_person_id=sp.sp_person_id)
        WHERE private_company.private_company_id=? AND sp.is_private='f';";
    my $h2 = $self->schema->storage->dbh()->prepare($q2);

    #print STDERR $q."\n";
    my @private_companies;
    my @private_companies_ids;
    while (my ($private_company_id, $name, $description, $email, $first_name, $last_name, $phone, $address, $address2, $state, $city, $zipcode, $country, $create_date, $company_type_id, $company_type_name, $user_type_id, $user_type_name) = $h->fetchrow_array()){

        my @members;
        if ($include_members) {
            $h2->execute($private_company_id);
            while (my ($sp_person_id, $sp_username, $sp_first_name, $sp_last_name, $sp_user_type_id, $sp_user_type_name) = $h2->fetchrow_array()){
                push @members, [$sp_person_id, $sp_username, $sp_first_name, $sp_last_name, $sp_user_type_id, $sp_user_type_name];
            }
        }

        push @private_companies, [$private_company_id, $name, $description, $email, $first_name, $last_name, $phone, $address, $address2, $state, $city, $zipcode, $country, $create_date, $company_type_id, $company_type_name, $user_type_id, $user_type_name, \@members];
        push @private_companies_ids, $private_company_id;
    }
    $h = undef;
    $h2 = undef;
    # print STDERR Dumper \@private_companies;

    my %allowed_private_company_ids = map {$_=>1} @private_companies_ids;
    my %allowed_private_company_access;
    my %private_company_access_is_private;
    foreach (@private_companies) {
        my $private_company_id = $_->[0];
        my $user_access = $_->[17];
        my $company_access = $_->[15];
        $allowed_private_company_access{$private_company_id} = $user_access;
        if ($company_access eq 'private_access') {
            $private_company_access_is_private{$private_company_id} = 1;
        }
        else {
            $private_company_access_is_private{$private_company_id} = 0;
        }
    }

    return (\@private_companies, \@private_companies_ids, \%allowed_private_company_ids, \%allowed_private_company_access, \%private_company_access_is_private);
}

sub store_private_company {
    my $self = shift;

    my $name = $self->private_company_name();
    my $description = $self->private_company_description();
    my $email = $self->private_company_contact_email();
    my $first_name = $self->private_company_contact_person_first_name();
    my $last_name = $self->private_company_contact_person_last_name();
    my $phone = $self->private_company_contact_person_phone();
    my $address = $self->private_company_address_street();
    my $address2 = $self->private_company_address_street_2();
    my $state = $self->private_company_address_state();
    my $city = $self->private_company_address_city();
    my $zipcode = $self->private_company_address_zipcode();
    my $country = $self->private_company_address_country();
    my $company_type_id = $self->private_company_type_cvterm_id();
    my $sp_person_id = $self->sp_person_id();

    if (!$name) {
        return {error => "No company name given!"};
    }
    if (!$description) {
        return {error => "No company description given!"};
    }
    if (!$email) {
        return {error => "No company email given!"};
    }
    if (!$first_name) {
        return {error => "No company first name given!"};
    }
    if (!$last_name) {
        return {error => "No company last name given!"};
    }
    if (!$phone) {
        return {error => "No company phone given!"};
    }
    if (!$address) {
        return {error => "No company address given!"};
    }
    if (!$state) {
        return {error => "No company state given!"};
    }
    if (!$city) {
        return {error => "No company city given!"};
    }
    if (!$zipcode) {
        return {error => "No company zipcode given!"};
    }
    if (!$country) {
        return {error => "No company country given!"};
    }
    if (!$company_type_id) {
        return {error => "No company type_id given!"};
    }
    if (!$sp_person_id) {
        return {error => "No sp_person_id given!"};
    }

    my $q0 = "SELECT private_company_id FROM sgn_people.private_company WHERE name=?;";
    my $h0 = $self->schema->storage->dbh()->prepare($q0);
    $h0->execute($name);
    my ($private_company_id_check) = $h0->fetchrow_array();
    if ($private_company_id_check) {
        return {error => "There is already a company with the name: $name! Cannot save a new company with the same name!"};
    }

    my $q = "INSERT INTO sgn_people.private_company (name, description, contact_email, contact_person_first_name, contact_person_last_name, contact_person_phone, address_street, address_street_2, address_state, city, address_zipcode, address_country, type_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($name, $description, $email, $first_name, $last_name, $phone, $address, $address2, $state, $city, $zipcode, $country, $company_type_id);

    $h0->execute($name);
    my ($private_company_id) = $h0->fetchrow_array();
    $self->private_company_id($private_company_id);

    my $company_curator_access_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'curator_access', 'company_person_type')->cvterm_id();
    my $q1 = "INSERT INTO sgn_people.private_company_sp_person (private_company_id, sp_person_id, type_id) VALUES (?,?,?);";
    my $h1 = $self->schema->storage->dbh()->prepare($q1);
    $h1->execute($private_company_id, $sp_person_id, $company_curator_access_type_id);

    $h0 = undef;
    $h = undef;
    $h1 = undef;

    return {success => 1};
}

sub edit_private_company {
    my $self = shift;
    my $private_company_id = $self->private_company_id();
    my $name = $self->private_company_name();
    my $description = $self->private_company_description();
    my $email = $self->private_company_contact_email();
    my $first_name = $self->private_company_contact_person_first_name();
    my $last_name = $self->private_company_contact_person_last_name();
    my $phone = $self->private_company_contact_person_phone();
    my $address = $self->private_company_address_street();
    my $address2 = $self->private_company_address_street_2();
    my $state = $self->private_company_address_state();
    my $city = $self->private_company_address_city();
    my $zipcode = $self->private_company_address_zipcode();
    my $country = $self->private_company_address_country();
    my $company_type_id = $self->private_company_type_cvterm_id();
    my $sp_person_id = $self->sp_person_id();

    if (!$name) {
        return {error => "No company name given!"};
    }
    if (!$description) {
        return {error => "No company description given!"};
    }
    if (!$email) {
        return {error => "No company email given!"};
    }
    if (!$first_name) {
        return {error => "No company first name given!"};
    }
    if (!$last_name) {
        return {error => "No company last name given!"};
    }
    if (!$phone) {
        return {error => "No company phone given!"};
    }
    if (!$address) {
        return {error => "No company address given!"};
    }
    if (!$state) {
        return {error => "No company state given!"};
    }
    if (!$city) {
        return {error => "No company city given!"};
    }
    if (!$zipcode) {
        return {error => "No company zipcode given!"};
    }
    if (!$country) {
        return {error => "No company country given!"};
    }
    if (!$company_type_id) {
        return {error => "No company type_id given!"};
    }
    if (!$sp_person_id) {
        return {error => "No sp_person_id given!"};
    }

    if ($self->sp_person_access_cvterm_name ne 'curator_access') {
        return {error => "Curator access is required to edit a company!"};
    }

    my $q = "SELECT private_company.private_company_id, private_company.name, private_company.description, private_company.contact_email, private_company.contact_person_first_name, private_company.contact_person_last_name, private_company.contact_person_phone, private_company.address_street, private_company.address_street_2, private_company.address_state, private_company.city, private_company.address_zipcode, private_company.address_country, private_company.create_date, private_company_type.cvterm_id, private_company_type.name
        FROM sgn_people.private_company AS private_company
        JOIN cvterm AS private_company_type ON(private_company.type_id=private_company_type.cvterm_id)
        WHERE private_company_id=?;";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($private_company_id);
    my ($private_company_id_saved, $name_saved, $description_saved, $email_saved, $first_name_saved, $last_name_saved, $phone_saved, $address_saved, $address2_saved, $state_saved, $city_saved, $zipcode_saved, $country_saved, $create_date_saved, $company_type_id_saved, $company_type_name_saved) = $h->fetchrow_array();
    $h = undef;

    if ($name ne $name_saved) {
        my $q0 = "SELECT private_company_id FROM sgn_people.private_company WHERE name=?;";
        my $h0 = $self->schema->storage->dbh()->prepare($q0);
        $h0->execute($name);
        my ($private_company_id_check) = $h0->fetchrow_array();
        $h0 = undef;
        if ($private_company_id_check) {
            return {error => "There is already a company with the name: $name! Cannot save company with the same name!"};
        }
    }

    my $q1 = "UPDATE sgn_people.private_company SET name=?, description=?, contact_email=?, contact_person_first_name=?, contact_person_last_name=?, contact_person_phone=?, address_street=?, address_street_2=?, address_state=?, city=?, address_zipcode=?, address_country=?, type_id=? WHERE private_company_id=?;";
    my $h1 = $self->schema->storage->dbh()->prepare($q1);
    $h1->execute($name, $description, $email, $first_name, $last_name, $phone, $address, $address2, $state, $city, $zipcode, $country, $company_type_id, $private_company_id);
    $h1 = undef;

    return {success => 1};
}

sub add_private_company_member {
    my $self = shift;
    my $new_member = shift;
    my $person_administrator = $self->sp_person_administrator_type() || '';
    my $private_company_id = $self->private_company_id();
    my $new_member_sp_person_id = $new_member->[0];
    my $new_member_access_type_name = $new_member->[1];

    if (!$new_member_sp_person_id) {
        return {error => "No member person given!"};
    }
    if (!$new_member_access_type_name) {
        return {error => "No member access type given!"};
    }

    if ($person_administrator ne 'site_admin' && $self->sp_person_access_cvterm_name ne 'curator_access') {
        return {error => "Curator access is required to add members to a company!"};
    }

    my $company_user_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $new_member_access_type_name, 'company_person_type')->cvterm_id();

    my $q3 = "SELECT p.private_company_sp_person_id, user_type.cvterm_id, user_type.name
        FROM sgn_people.private_company AS private_company
        JOIN sgn_people.private_company_sp_person AS p ON(private_company.private_company_id=p.private_company_id)
        JOIN cvterm AS user_type ON(p.type_id=user_type.cvterm_id)
        WHERE private_company.private_company_id=? AND p.sp_person_id=? AND p.is_private='f';";
    my $h3 = $self->schema->storage->dbh()->prepare($q3);
    $h3->execute($private_company_id,$new_member_sp_person_id);
    my ($private_company_sp_person_id, $user_type_id, $user_type_name) = $h3->fetchrow_array();
    $h3 = undef;

    if ($private_company_sp_person_id) {
        my $q_update = "UPDATE sgn_people.private_company_sp_person SET type_id=? WHERE private_company_sp_person_id=?;";
        my $h_update = $self->schema->storage->dbh()->prepare($q_update);
        $h_update->execute($company_user_type_id,$private_company_sp_person_id);
        $h_update = undef;
    }
    else {
        my $q = "INSERT INTO sgn_people.private_company_sp_person (type_id,private_company_id,sp_person_id) VALUES (?,?,?);";
        my $h = $self->schema->storage->dbh()->prepare($q);
        $h->execute($company_user_type_id,$private_company_id,$new_member_sp_person_id);
        $h = undef;
    }

    return {success => 1};
}

sub remove_private_company_member {
    my $self = shift;
    my $remove_sp_person_id = shift;
    my $private_company_id = $self->private_company_id();

    if (!$remove_sp_person_id) {
        return {error => "No member person given!"};
    }

    if ($self->sp_person_access_cvterm_name ne 'curator_access') {
        return {error => "Curator access is required to add members to a company!"};
    }

    my $q0 = "SELECT user_type.cvterm_id, user_type.name
        FROM sgn_people.private_company AS private_company
        JOIN sgn_people.private_company_sp_person AS p ON(private_company.private_company_id=p.private_company_id)
        JOIN cvterm AS user_type ON(p.type_id=user_type.cvterm_id)
        WHERE private_company.private_company_id=? AND p.sp_person_id=?;";
    my $h0 = $self->schema->storage->dbh()->prepare($q0);
    $h0->execute($private_company_id,$remove_sp_person_id);
    my ($user_access_type_id, $user_access_type_name) = $h0->fetchrow_array();
    $h0 = undef;

    my $sp_person_administrator_type = $self->sp_person_administrator_type() || '';

    if ($sp_person_administrator_type ne 'site_admin' && $user_access_type_name eq 'curator_access') {
        return {error => "Cannot remove curators from a company!"};
    }

    my $q = "DELETE FROM sgn_people.private_company_sp_person WHERE private_company_id=? AND sp_person_id=?;";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($private_company_id,$remove_sp_person_id);
    $h = undef;

    return {success => 1};
}

sub edit_private_company_member {
    my $self = shift;
    my $edit_sp_person = shift;
    my $private_company_id = $self->private_company_id();
    my $edit_sp_person_id = $edit_sp_person->[0];
    my $edit_access_type = $edit_sp_person->[1];
    if (!$edit_sp_person_id) {
        return {error => "No member person given!"};
    }

    if ($self->sp_person_access_cvterm_name ne 'curator_access') {
        return {error => "Curator access is required to add members to a company!"};
    }

    my $company_user_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $edit_access_type, 'company_person_type')->cvterm_id();

    my $q0 = "SELECT p.private_company_sp_person_id, user_type.cvterm_id, user_type.name
        FROM sgn_people.private_company AS private_company
        JOIN sgn_people.private_company_sp_person AS p ON(private_company.private_company_id=p.private_company_id)
        JOIN cvterm AS user_type ON(p.type_id=user_type.cvterm_id)
        WHERE private_company.private_company_id=? AND p.sp_person_id=?;";
    my $h0 = $self->schema->storage->dbh()->prepare($q0);
    $h0->execute($private_company_id,$edit_sp_person_id);
    my ($private_company_sp_person_id, $user_access_type_id, $user_access_type_name) = $h0->fetchrow_array();
    $h0 = undef;

    my $sp_person_administrator_type = $self->sp_person_administrator_type() || '';

    if ($sp_person_administrator_type ne 'site_admin' && $user_access_type_name eq 'curator_access') {
        return {error => "Cannot edit curators access to a company!"};
    }

    my $q = "UPDATE sgn_people.private_company_sp_person SET type_id=? WHERE private_company_id=? AND sp_person_id=?;";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($company_user_type_id,$private_company_id,$edit_sp_person_id);
    $h = undef;

    return {success => 1};
}

1;
