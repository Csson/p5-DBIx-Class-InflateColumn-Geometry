package DBIx::Class::InflateColumn::Geometry::MultiPolygon;

use strict;
use warnings;
use base qw/DBIx::Class/;
use namespace::clean;
use DBIx::Class::InflateColumn::Geometry::Util ':multipolygon';
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiPolygon;

# VERSION
# ABSTRACT: Handle MultiPolygon columns

sub register_column {
    my($self, $column, $info, @rest) = @_;

    $self->next::method($column, $info, @rest);

    return if !(defined $info->{'data_type'} && lc $info->{'data_type'} eq 'multipolygon');

    $self->inflate_column(
        $column => {
            inflate => sub {
                my($value, $object) = @_;
                my $result_source = $object;
                $result_source =~ s{^.*?Result::}{};
                $object->result_source->schema->storage->dbh_do(sub {
                    my($storage, $dbh, @args) = @_;

                    my %custom_radius = exists $info->{'geometry_radius'} ? (radius => $info->{'geometry_radius'}) : ();

                    DBIx::Class::InflateColumn::Geometry::Inflated::MultiPolygon->new(%custom_radius, data => decode_multipolygon($dbh->selectrow_arrayref("SELECT AsText(?)", {}, $value)->[0]));
                });
            },
            deflate => sub {
                return deflate_multipolygon(shift);
            },
        }
    );
}

1;

=pod

=head1 SYNOPSIS

    package My::Schema::Result::Country;

    use DBIx::Class::Candy -components => [qw/InflateColumn::Geometry::MultiPolygon/];
    
    # other columns

    column boundary => {
        data_type => 'multipolygon',
        geom_mp_radius => 6_371_009,
    };

=head1 DESCRIPTION

Use this inflator to easily translate between Perl structures and MultiPolygons.

    my $schema = My::Schema->connect(...);

    # Lets say you have a multi polygon in a Perl array reference:

    my $borders = [
        [
            [
                [10, 60], [20, 60] [20, 70], [10, 70], [10, 60],
            ],
            [
                [14, 62], [16, 62] [16, 64], [14, 64], [14, 62],
                [18, 67], [19, 67] [19, 68], [18, 68], [18, 67],
            ]
        ],
        [
            [
                [5, 50], [7, 50] [7, 53], [5, 53], [5, 50],
            ],
        ]
    ];

    # Then you use it:
    $schema->Country->create({
        ...,
        boundary => $borders,
    });

    # And later...
    my $borders_from_db = $schema->resultset('Country')->search->first->boundary->polygons;

    # $borders_from_db is identical to $borders

    # Spherical area calculated on geom_mp_radius
    print $schema->resultset('Country')->search->first->boundary->area

=head2 Configuration

B<C<data_type>>

C<data_type> should be set to 'multipolygon'.

B<C<geom_mp_radius>>

C<geom_mp_radius> defines the spherical radius used for the L<area> method.

The default value is 6,371,009 meters, which is the mean Earth's L<mean radius|https://en.wikipedia.org/wiki/Earth_radius#Mean_radius>.

=head1 INFLATION

When you inflate the column, you get back a L<DBIx::Class::InflateColumn::Core::MultiPolygonInfo> object.

=head1 COMPATIBILITY

This module has (so far) been tested on MariaDB 10.1.7, and should be compatible with all Mysql versions, and Mysql derivatives, that has geospatial functionality.

The following database functions are used:

=for :list
* AsText
* MultiPolygonFromText
* MultiPolygon
