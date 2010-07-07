package WWW::Google::Contacts::ContactList;

use Moose;
use WWW::Google::Contacts::Contact;

extends 'WWW::Google::Contacts::Base';

with 'WWW::Google::Contacts::Roles::List';

sub baseurl { 'http://www.google.com/m8/feeds/contacts/default' }

sub next {
    my $self = shift;
    return undef unless ( @{ $self->elements } );
    my $next = shift @{ $self->elements };
    my $contact = WWW::Google::Contacts::Contact->new( server => $self->server );
    return $contact->set_from_server( $next );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
