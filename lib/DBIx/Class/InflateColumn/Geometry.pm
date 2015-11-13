package DBIx::Class::InflateColumn::Geometry;

use strict;
use warnings;
use base qw/DBIx::Class/;
use namespace::clean;
use DBIx::Class::InflateColumn::Geometry::Util qw/inflate_any_geometry deflate_any_geometry/;
use DBIx::Class::InflateColumn::Geometry::Exceptions;
use Mojo::Util 'dumper';
# VERSION
# ABSTRACT: Handle any Geometry type

sub register_column {
    my($self, $column, $info, @rest) = @_;

    $self->next::method($column, $info, @rest);

    return if !(defined $info->{'data_type'} && lc $info->{'data_type'} eq 'geometry');

    $self->inflate_column(
        $column => {
            inflate => sub {
                my($value, $object) = @_;
                my $result_source = $object;
                $result_source =~ s{^.*?Result::}{};
                $object->result_source->schema->storage->dbh_do(sub {
                    my($storage, $dbh, @args) = @_;

                    my %custom_radius = exists $info->{'geometry_radius'} ? (radius => $info->{'geometry_radius'}) : ();

                    inflate_any_geometry(%custom_radius, data => $dbh->selectrow_arrayref("SELECT AsText(?)", {}, $value)->[0]);
                });
            },
            deflate => sub {
                return deflate_any_geometry(shift);
            },
        }
    );
}

1;
