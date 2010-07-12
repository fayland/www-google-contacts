package WWW::Google::Contacts::Roles::CRUD;

use Moose::Role;
use Carp qw( croak );
use XML::Simple ();

requires 'create_url';

has raw_data_for_backwards_compability => ( is => 'rw' );
has server => ( is => 'ro', required => 1 );

sub as_xml {
    my $self = shift;
    my $entry = {
        entry => {
            'xmlns' => 'http://www.w3.org/2005/Atom',
            'xmlns:gd' => 'http://schemas.google.com/g/2005',
            'xmlns:gContact' => 'http://schemas.google.com/contact/2008',
            %{ $self->to_xml_hashref },
        },
    };
    my $xmls = XML::Simple->new;
    my $xml = $xmls->XMLout( $entry, KeepRoot => 1 );
    return $xml;
}

sub create_or_update {
    my $self = shift;
    if ( $self->has_id ) {
        return $self->update;
    }
    else {
        return $self->create;
    }
}

sub create {
    my $self = shift;

    my $xml = $self->as_xml;
    my $res = $self->server->post( $self->create_url, $xml );
    my $xmls = XML::Simple->new;
    my $data = $xmls->XMLin($res->content, SuppressEmpty => undef);
    $self->_set_id( $data->{ id } );
    1;
}

sub retrieve {
    my $self = shift;
    croak "No id set" unless $self->id;

    my $res = $self->server->get( $self->id );
    my $xmls = XML::Simple->new;
    my $data = $xmls->XMLin($res->content, SuppressEmpty => undef);
    $self->raw_data_for_backwards_compability( $data );
    $self->set_from_server( $data );
    $self;
}

sub update {
    my $self = shift;
    croak "No id set" unless $self->id;

    my $xml = $self->as_xml;
    $self->server->put( $self->id, $xml );
    $self;
}

sub delete {
    my $self = shift;
    croak "No id set" unless $self->id;

    $self->server->delete( $self->id );
    1;
}

1;
