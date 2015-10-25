package DBIx::Class::InflateColumn::Geometry::Point;

use strict;
use warnings;
use base qw/DBIx::Class/;
use namespace::clean;
use DBIx::Class::InflateColumn::Geometry::Util qw/decode_point coord_string/;
use DBIx::Class::InflateColumn::Geometry::Inflated::Point;

# VERSION
# ABSTRACT: Handle Point columns

sub register_column {
    my($self, $column, $info, @rest) = @_;

    $self->next::method($column, $info, @rest);

    return if !(defined $info->{'data_type'} && lc $info->{'data_type'} eq 'point');

    $self->inflate_column(
        $column => {
            inflate => sub {
                my($value, $object) = @_;
                my $result_source = $object;
                $result_source =~ s{^.*?Result::}{};
                $object->result_source->schema->storage->dbh_do(sub {
                    my($storage, $dbh, @args) = @_;

                    my %custom_radius = exists $info->{'geometry_radius'} ? (radius => $info->{'geometry_radius'}) : ();

                    DBIx::Class::InflateColumn::Geometry::Inflated::Point->new(%custom_radius, data => decode_point($dbh->selectrow_arrayref("SELECT AsText(?)", {}, $value)->[0]));
                });
            },
            deflate => sub {
                my $value = shift;
                my $textified = coord_string($value);

                return \qq{PointFromText('POINT($textified)')};
            },
        }
    );
}

1;
