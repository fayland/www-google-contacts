package WWW::Google::Contacts;

# ABSTRACT: Google Contacts Data API

use warnings;
use strict;
use Carp qw/croak/;
use URI::Escape;
use LWP::UserAgent;
use Net::Google::AuthSub;
use XML::Simple ();

sub new {
    my $class = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };

    unless ( $args->{ua} ) {
        my $ua_args = delete $args->{ua_args} || {};
        $args->{ua} = LWP::UserAgent->new(%$ua_args);
    }
    $args->{authsub} ||= Net::Google::AuthSub->new(service => 'cp');
    $args->{xmls} ||= XML::Simple->new();
    
    bless $args, $class;
}

sub login {
    my ($self, $email, $pass) = @_;

    $email ||= $self->{email};
    $pass  ||= $self->{pass};
    $email or croak 'login(email, pass)2';
    $pass  or croak 'login(email, pass)';

    return 1 if $self->{_is_authed} and $self->{_is_authed} eq $email;

    my $resp = $self->{authsub}->login($email, $pass);
    unless ( $resp and $resp->is_success ) {
        return 0;
    }
    
    $self->{email} = $email;
    $self->{pass}  = $pass;
    $self->{_is_authed} = $email;
    return 1;
}

sub get_contacts {
    my ($self, $group, $args) = @_;

    $self->login() or croak 'Authentication failed';
    
    $group ||= 'full';
    my $url = sprintf( 'http://www.google.com/m8/feeds/contacts/default/%s?max-results=9999&v=3.0', uri_escape($group) );
    foreach my $key (%$args) {
        $url .= '&' . uri_escape($key) . '=' . uri_escape($args->{$key});
    }
    my $resp =$self->{ua}->get( $url, $self->{authsub}->auth_params );
    my $content = $resp->content;
    my $data = $self->{xmls}->XMLin($content, ForceArray => ['entry'], SuppressEmpty => undef);
    
    my @contacts;
    foreach my $id (keys %{ $data->{entry} } ) {
        my $d = $data->{entry}->{$id};
        my $name = $d->{'gd:name'}->{'gd:fullName'};
        my $updated = $d->{updated};
        my $groupMembershipInfo = $d->{'gContact:groupMembershipInfo'}->{'href'};

        my @emails;
        my $emails = $d->{'gd:email'};
        if ($emails) {
            @emails = ( ref($emails) eq 'ARRAY' ) ? @{$emails} : ($emails);
            @emails = map { $_->{address} } @emails;
        }

        push @contacts, {
            id => $id,
            name => $name,
            updated => $updated,
            emails  => \@emails,
            groupMembershipInfo => $groupMembershipInfo,
        };
    }
    
    return @contacts;
}

sub get_groups {
    my ($self) = @_;

    $self->login() or croak 'Authentication failed';
    
    my $url  = 'http://www.google.com/m8/feeds/groups/default/full?alt=json&v=3.0';
    my $resp =$self->{ua}->get( $url, $self->{authsub}->auth_params );
    my $content = $resp->content;
    my $data = $self->{xmls}->XMLin($content, ForceArray => ['entry'], SuppressEmpty => undef);
    
    my @groups = @{ $data->{feed}->{entry} };
    return @groups;
}

sub create_contact {
    my $self = shift;
    
    my $contact = scalar @_ % 2 ? shift : { @_ };
    
    my $data = {
        'atom:entry' => {
            'xmlns:atom' => 'http://www.w3.org/2005/Atom',
            'xmlns:gd'   => 'http://schemas.google.com/g/2005',
            'atom:category' => {
                'scheme' => 'http://schemas.google.com/g/2005#kind',
                'term'   => 'http://schemas.google.com/contact/2008#contact'
            },
            'gd:name' => {
                'gd:givenName'  => [ $contact->{givenName} ],
                'gd:familyName' => [ $contact->{familyName} ],
                'gd:fullName'   => [ $contact->{fullName} ],
            },
            'atom:content' => {
                type => 'text',
                content => $contact->{Notes},
            },
            'gd:email' => [
                {
                    rel => 'http://schemas.google.com/g/2005#work',
                    primary => 'true',
                    address => $contact->{primaryMail},
                    displayName => $contact->{displayName},
                },
                {
                    rel => 'http://schemas.google.com/g/2005#home',
                    address => $contact->{secondaryMail},
                }
            ],

        },
    };
    my $xml = $self->{xmls}->XMLout($data, KeepRoot => 1);
    
    my %headers = $self->{authsub}->auth_params;
    $headers{'Content-Type'} = 'application/atom+xml';
    my $url = 'http://www.google.com/m8/feeds/contacts/default/full';
    my $resp =$self->{ua}->post( $url, %headers, Content => $xml );
    return ($resp->code == 201) ? 1 : 0;
}

1;
__END__

=head1 SYNOPSIS

    use WWW::Google::Contacts;

    my $gcontacts = WWW::Google::Contacts->new();
    $gcontacts->login('fayland@gmail.com', 'pass') or die 'login failed';
    
    # create contact
    my $status = $gcontacts->create_contact( {
        givenName => 'FayTestG',
        familyName => 'FayTestF',
        fullName   => 'Fayland Lam',
        Notes     => 'just a note',
        primaryMail => 'primary@example.com',
        displayName => 'FayTest Dis',
        secondaryMail => 'secndary@test.com',
    } );
    print "Create OK" if $status;
    

=head1 DESCRIPTION
