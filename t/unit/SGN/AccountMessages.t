package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use SGN::I18N;
use SGN::Controller::AJAX::User;

# Actual controller methods, synthetic language markers and real SGN::I18N.
# Database/authentication/persistence/email dependencies below are capture-only
# fakes; no real accounts, reset tokens or email messages are written or sent.
my %source = (
    incorrect_credentials => 'Login credentials are incorrect. Please try again.',
    disabled_account => 'This account has been deactivated due to %{reason}. Please contact the database administrator to re-instate the account.',
    login_success => 'Login successful', logout_success => 'User successfully logged out.',
    mirror_registration => 'This site is a mirror site and does not support adding users. Please go to the main site to create an account.',
    username_short => 'Username is too short. Username must be %{minimum} or more characters',
    username_spaces => 'Username must not contain spaces',
    username_exists => 'Username "%{username}" is already in use. Please pick a different username.',
    password_short => 'Password is too short. Password must be %{minimum} or more characters',
    password_mismatch => 'Password and confirm password do not match.',
    password_username => 'Password must not be the same as your username.',
    email_invalid => 'Email address is invalid.', email_exists => 'Email address is already associated with an account.',
    first_name_required => 'You must enter a first name or initial.', last_name_required => 'You must enter a last name.',
    creation_failed => 'Account creation failed for the following reason(s): %{reasons}',
    admin_confirmation => 'Your account has been created but first must be confirmed by the site administrators.  You will receive an email once your account has been confirmed.',
    email_confirmation => 'To continue, you must confirm that we can reach you via email address "%{email}". An email has been sent with a URL to confirm this address. Please check your email for this message and use the link to confirm your email address.',
    account_created => "Account was created with username \"%{username}\".\n\n%{confirmation}\n\nYou will be able to login once your account has been confirmed.",
    forgot_requested => 'Username email requested. If you have an account on this database with this email, you will receive a message that includes the username associated with this email address.  If you do not have an account with this email address, you will not receive a message.',
    reset_requested => 'Password reset email requested. If you have an account on this database with this email, you will receive a message with a password reset link.  If you do not have an account with this email address, you will not receive a message.',
    reset_confirm_mismatch => 'Please enter the same password in the confirm password field!',
    password_updated => 'The password was successfully updated.',
);
my %prefix = (en => '', uk => 'Українська: ', es => 'Español: ', ar => 'العربية: ');
my $catalog_root = tempdir(CLEANUP => 1);
my $json = JSON::PP->new->utf8->canonical;
for my $locale (qw(uk es ar)) {
    make_path("$catalog_root/$locale");
    my %messages = map {("account.server.$_\x04$source{$_}" => {plural => undef, forms => [$prefix{$locale}.$source{$_}]})} keys %source;
    open my $out, '>:raw', "$catalog_root/$locale/sgn.json" or die $!;
    print {$out} $json->encode({schema => 1, api => 1, locale => $locale, direction => $locale eq 'ar' ? 'rtl' : 'ltr',
        sourceRevision => '0' x 64, nplurals => 1, pluralForms => 'nplurals=1; plural=0;', pluralAst => {type => 'NUM', val => 0}, messages => \%messages});
    close $out;
}
sub expected {
    my ($locale, $key, $vars) = @_;
    my $text = $prefix{$locale}.$source{$key}; $vars ||= {};
    $text =~ s/%\{([a-zA-Z_][a-zA-Z0-9_]*)\}/exists($vars->{$1}) ? $vars->{$1} : die("Missing expected variable $1")/ge;
    return $text;
}
{
    package Local::AccountMessages::DB;
    sub new { bless {state => $_[1]}, $_[0] }
    sub dbh { $_[0] }
    sub prepare {
        my ($self, $query) = @_;
        die 'Unexpected database query' unless $query eq 'SELECT sp_person_id FROM sgn_people.sp_person WHERE confirm_code=?;';
        push @{$self->{state}{queries}}, $query;
        return bless {state => $self->{state}}, 'Local::AccountMessages::Statement';
    }
    sub selectrow_array {
        my ($self, $query, $attributes, @values) = @_;
        my $expected = 'UPDATE sgn_people.sp_person SET password = crypt(?, gen_salt(\'bf\')), confirm_code = NULL WHERE sp_person_id = ? AND confirm_code = ? RETURNING sp_person_id';
        die 'Unexpected reset update' unless $query eq $expected;
        push @{$self->{state}{atomic_updates}}, [$query, @values];
        return 900001 if $values[0] eq $self->{state}{expected_reset_password}
            && $values[1] == 900001 && $values[2] eq $self->{state}{stored_reset_token};
        return;
    }
    our $AUTOLOAD;
    sub AUTOLOAD { die 'Real database access is forbidden by this presentation test' }
    sub DESTROY {}
    package Local::AccountMessages::Statement;
    sub execute { push @{$_[0]->{state}{query_arguments}}, $_[1]; return 1 }
    sub fetchrow_array { return 900001 }
    package Local::AccountMessages::Request;
    sub new { bless {params => $_[1]}, $_[0] }
    sub param { $_[0]->{params}{$_[1]} }
    sub params { $_[0]->{params} }
    sub method { 'POST' }
    sub body_parameters { $_[0]->{params} }
    sub referer { '/unit/referer?plain=1' }
    package Local::AccountMessages::Context;
    sub new {
        my ($class, $locale, $root, $params, $config, $state) = @_;
        bless {request => Local::AccountMessages::Request->new($params || {}), stash => {},
            config => {main_production_site_url => 'https://example.invalid', project_name => 'Unit SGN', %{$config || {}}},
            translator => SGN::I18N->new(locale => $locale, catalog_root => $root), database => Local::AccountMessages::DB->new($state)}, $class;
    }
    sub req { $_[0]->{request} } sub stash { $_[0]->{stash} } sub config { $_[0]->{config} }
    sub i18n { $_[0]->{translator} } sub dbc { $_[0]->{database} } sub dbic_schema { $_[0]->{database} }
    sub user { undef } sub detach { die "unit detach\n" }
    package Local::AccountMessages::Login;
    sub new { bless {state => $_[1]}, $_[0] }
    sub login_user { my ($self, @args) = @_; push @{$self->{state}{login_calls}}, \@args; return $self->{state}{login_info} || {} }
    sub logout_user { $_[0]->{state}{logout_calls}++; return }
    package Local::AccountMessages::Person;
    sub new { bless {state => $_[1], username => 'Unit fixture person'}, $_[0] }
    sub get_username { $_[0]->{state}{existing_username} || $_[0]->{username} }
    sub get_sp_person_id { 900001 }
    sub get_private_email { $_[0]->{state}{private_email} || 'stored-account@example.invalid' }
    sub set_username { $_[0]->{username} = $_[1] } sub set_pending_email { $_[0]->{email} = $_[1] }
    sub set_disabled { $_[0]->{state}{disabled} = $_[1] } sub set_organization { $_[0]->{organization} = $_[1] }
    sub set_first_name { $_[0]->{first_name} = $_[1] } sub set_last_name { $_[0]->{last_name} = $_[1] }
    sub store { $_[0]->{state}{stores}++; return 900001 }
    sub update_password { push @{$_[0]->{state}{password_updates}}, $_[1]; return }
    sub update_confirm_code { push @{$_[0]->{state}{confirmation_updates}}, $_[1]; return }
    package Local::AccountMessages::ExistingLogin;
    sub new { bless {username => $_[1]}, $_[0] } sub get_username { $_[0]->{username} }
}
my $state;
my %english_mail;
my $controller = SGN::Controller::AJAX::User->new;
my $plain = 'Опис_已更新_العربية <img src=x onerror=unit()> & "%{other}"';
my $username = 'Сорт_已更新_العربية';
my $email = 'unit+Опис_已更新_العربية@example.invalid';
sub context { Local::AccountMessages::Context->new($_[0], $catalog_root, $_[1], $_[2], $state) }
sub valid_registration { {first_name => 'Unit', last_name => 'Fixture', username => 'unituser', password => 'unit-password',
    confirm_password => 'unit-password', email_address => 'unit@example.invalid', organization => 'Unit organization'} }
sub reset_fakes { $state = {mail => [], login_calls => [], lookup_calls => [], queries => [], query_arguments => [], atomic_updates => [],
    token_lookups => [], stored_reset_token => 'ResetTokenAB1234', expected_reset_password => '1234567', stores => 0,
    password_updates => [], confirmation_updates => [], logout_calls => 0, token_requests => 0, @_} }
{
    no warnings qw(redefine once);
    local *CXGN::Login::new = sub { Local::AccountMessages::Login->new($state) };
    local *CXGN::People::Login::get_login = sub {push @{$state->{lookup_calls}}, ['username', $_[2]]; Local::AccountMessages::ExistingLogin->new($state->{existing_username})};
    local *CXGN::People::Login::get_login_by_email = sub {push @{$state->{lookup_calls}}, ['email', $_[2]]; @{$state->{person_ids} || []}};
    local *CXGN::People::Login::get_login_by_token = sub {
        my ($class, $dbh, $token) = @_;
        push @{$state->{token_lookups}}, $token;
        return $token eq $state->{stored_reset_token} ? 900001 : undef;
    };
    local *CXGN::People::Login::new = sub { Local::AccountMessages::Person->new($state) };
    local *CXGN::People::Person::new = sub { Local::AccountMessages::Person->new($state) };
    local *CXGN::Contact::send_email = sub { push @{$state->{mail}}, [@_]; return };
    local *SGN::Controller::AJAX::User::tempname = sub { $state->{token_requests}++; return 'unit-confirmation-fixture' };
    for my $locale (qw(en uk es ar)) {
        subtest "$locale account presentation preserves branch contracts" => sub {
            reset_fakes(login_info => {incorrect_password => 1, account_disabled => $plain});
            my $c = context($locale, {username => $username, password => 'unit-fake-password', goto_url => '/unit/destination'});
            $controller->login($c);
            is_deeply($c->stash->{rest}, {error => expected($locale, 'incorrect_credentials')}, 'Wrong credentials retain error-only response');
            is_deeply($state->{login_calls}, [[$username, 'unit-fake-password']], 'Credential data reaches captured dependency unchanged');
            reset_fakes(login_info => {account_disabled => $plain});
            $c = context($locale, {username => $username, password => 'unit-fake-password', goto_url => '/unit/destination'});
            $controller->login($c);
            is_deeply($c->stash->{rest}, {error => expected($locale, 'disabled_account', {reason => $plain})}, 'Disabled reason remains Unicode and HTML-like plain data');
            reset_fakes(login_info => {});
            $c = context($locale, {username => $username, password => 'unit-fake-password', goto_url => '/'});
            $controller->login($c);
            is_deeply($c->stash->{rest}, {message => expected($locale, 'login_success'), goto_url => '/unit/referer?plain=1'}, 'Success preserves referer destination behavior');
            $controller->logout($c);
            is_deeply($c->stash->{rest}, {message => expected($locale, 'logout_success')}, 'Logout message uses requested locale');
            is($state->{logout_calls}, 1, 'Logout dependency invoked exactly once');
            reset_fakes(); $c = context($locale, valid_registration(), {is_mirror => 1}); $controller->new_account($c);
            is($c->stash->{message}, expected($locale, 'mirror_registration'), 'Mirror registration message unchanged in English');
            is($c->stash->{template}, '/system_message.mas', 'Mirror template canonical');
            is($state->{stores} + $state->{token_requests} + @{$state->{mail}}, 0, 'Mirror branch stops before stores, tokens or mail');
            my @failures = (
                ['six-character username', {username => 'abcdef'}, {}, ['username_short']],
                ['username spaces', {username => 'unit user'}, {}, ['username_spaces']],
                ['duplicate Unicode username', {username => $username}, {existing_username => $username}, ['username_exists']],
                ['six-character password', {password => 'abcdef', confirm_password => 'abcdef'}, {}, ['password_short']],
                ['password mismatch', {confirm_password => 'different-password'}, {}, ['password_mismatch']],
                ['password equals username', {password => 'unituser', confirm_password => 'unituser'}, {}, ['password_username']],
                ['invalid email', {email_address => 'not-an-email'}, {}, ['email_invalid']],
                ['associated email', {}, {person_ids => [900001]}, ['email_exists']],
                ['missing first name', {first_name => ''}, {}, ['first_name_required']],
                ['missing last name', {last_name => ''}, {}, ['last_name_required']],
                ['seven-character thresholds accepted', {username => 'abcdefg', password => '1234567', confirm_password => '1234567', last_name => ''}, {}, ['last_name_required']],
                ['ordered multiple failures', {username => 'abcdef', password => 'short', confirm_password => 'other', email_address => '', first_name => '', last_name => ''}, {}, [qw(username_short password_short password_mismatch email_invalid first_name_required last_name_required)]],
            );
            for my $case (@failures) {
                my ($label, $overrides, $fake_state, $keys) = @$case; reset_fakes(%$fake_state);
                my $params = {%{valid_registration()}, %$overrides}; $c = context($locale, $params); $controller->new_account($c);
                my $reasons = join(', ', map {expected($locale, $_, {minimum => 7, username => $params->{username}})} @$keys);
                is_deeply($c->stash->{rest}, {error => expected($locale, 'creation_failed', {reasons => $reasons})}, "$label preserves exact failure order and substitutions");
                is($state->{stores} + @{$state->{password_updates}} + @{$state->{confirmation_updates}} + $state->{token_requests} + @{$state->{mail}}, 0, "$label stops before persistence or delivery");
            }
            for my $admin (0, 1) {
                reset_fakes(); my $params = {%{valid_registration()}, username => $username, email_address => $email};
                $c = context($locale, $params, {user_registration_admin_confirmation => $admin, user_registration_admin_confirmation_email => $admin ? 'admin@example.invalid' : ''});
                $controller->new_account($c);
                my $confirmation = expected($locale, $admin ? 'admin_confirmation' : 'email_confirmation', {email => $email});
                is_deeply($c->stash->{rest}, {message => expected($locale, 'account_created', {username => $username, confirmation => $confirmation})}, 'Registration preserves paragraphs and Unicode variables');
                is($state->{disabled}, 'unconfirmed account', 'Unconfirmed account status remains canonical');
                is($state->{stores}, 2, 'User and person stores captured only in memory');
                is(scalar @{$state->{mail}}, 1, 'One email captured without delivery');
                is($state->{mail}[0][2], $admin ? 'user_registration_admin_confirmation_email' : $email, 'Admin/user recipient branch unchanged');
                is($state->{mail}[0][0], '[Unit SGN] Email Address Confirmation Request', 'Untouched mail subject remains English');
                like($state->{mail}[0][1], qr/This message is sent to confirm the email address/, 'Untouched mail body remains English');
                if ($locale eq 'en') { $english_mail{"registration-$admin"} = [map {[@$_]} @{$state->{mail}}] }
                else { is_deeply($state->{mail}, $english_mail{"registration-$admin"}, 'Locale preserves entire confirmation mail content and recipient') }
            }
            for my $method (qw(forgot_username reset_password)) {
                my @acks;
                for my $ids ([], [900001, 900002]) {
                    reset_fakes(person_ids => $ids);
                    my $param = $method eq 'forgot_username' ? 'forgot_username_email' : 'password_reset_email';
                    $c = context($locale, {$param => $email}); $controller->$method($c);
                    my $key = $method eq 'forgot_username' ? 'forgot_requested' : 'reset_requested';
                    is_deeply($c->stash->{rest}, {message => expected($locale, $key)}, "$method privacy acknowledgement has exact shape");
                    push @acks, $c->stash->{rest}{message};
                    is_deeply($state->{lookup_calls}, [['email', $email]], "$method preserves plain lookup argument");
                    is($state->{stores} + @{$state->{password_updates}}, 0, "$method makes no user/password stores");
                    is(scalar @{$state->{mail}}, @$ids ? ($method eq 'forgot_username' ? 1 : scalar @$ids) : 0, "$method delivery condition captured only in memory");
                    if ($method eq 'reset_password' && @$ids) {
                        is_deeply([map { $_->[2] } @{$state->{mail}}],
                            [('stored-account@example.invalid') x scalar(@$ids)],
                            'reset mail goes to each stored account address, not the request address');
                    }
                    is(scalar @{$state->{confirmation_updates}}, $method eq 'reset_password' ? scalar @$ids : 0, "$method token-update count captured only in memory");
                    my $mail_key = $method . '-' . scalar(@$ids);
                    if ($locale eq 'en') { $english_mail{$mail_key} = [map {[@$_]} @{$state->{mail}}] }
                    else { is_deeply($state->{mail}, $english_mail{$mail_key}, "$method preserves whole English mail content and delivery destinations") }
                }
                is($acks[0], $acks[1], "$method response does not reveal account existence");
            }
            for my $case (['short', '123456', '123456', 'password_short'], ['mismatch', '1234567', 'different', 'reset_confirm_mismatch']) {
                reset_fakes(); $c = context($locale, {token => 'ResetTokenAB1234', new_password => $case->[1], confirm_password => $case->[2]});
                my $ok = eval {$controller->process_reset_password_form($c); 1};
                ok(!$ok && $@ eq "unit detach\n", 'Reset validation uses original detach branch');
                is_deeply($c->stash->{rest}, {error => expected($locale, $case->[3], {minimum => 7})}, "$case->[0] reset response translates exact existing text");
                is(@{$state->{token_lookups}} + @{$state->{atomic_updates}} + @{$state->{password_updates}} + @{$state->{confirmation_updates}}, 0, 'Early reset failure performs no lookup or persistence');
            }
            reset_fakes(); $c = context($locale, {token => 'ResetTokenAB1234', new_password => '1234567', confirm_password => '1234567'});
            $controller->process_reset_password_form($c);
            is_deeply($c->stash->{rest}, {message => expected($locale, 'password_updated')}, 'Exactly seven-character reset passes existing threshold');
            is_deeply($state->{token_lookups}, ['ResetTokenAB1234'], 'Exact generated-form reset token reaches the lookup unchanged');
            is_deeply($state->{atomic_updates}, [[
                'UPDATE sgn_people.sp_person SET password = crypt(?, gen_salt(\'bf\')), confirm_code = NULL WHERE sp_person_id = ? AND confirm_code = ? RETURNING sp_person_id',
                '1234567', 900001, 'ResetTokenAB1234'
            ]], 'Single-use password update binds password, person id and reset token atomically');
            is(scalar @{$state->{password_updates}}, 0, 'No legacy password setter bypasses the atomic update');
            is(scalar @{$state->{confirmation_updates}}, 0, 'No legacy token update bypasses the atomic clear');
            is(scalar @{$state->{mail}}, 0, 'Password completion sends no email');
        };
    }
}
done_testing;
