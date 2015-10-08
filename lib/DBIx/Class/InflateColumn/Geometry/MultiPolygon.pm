package DBIx::Class::InflateColumn::Geometry::MultiPolygon;

use strict;
use warnings;
use DBIx::Class::InflateColumn::MultiPolygon::Info;

# VERSION
# ABSTRACT: Work easier with MultiPolygons

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

                    DBIx::Class::InflateColumn::Geometry::MultiPolygon::Info->new(%custom_radius, multi => decode_multipolygon($dbh->selectrow_arrayref("SELECT AsText(?)", {}, $value)->[0]));
                });
            },
            deflate => sub {
                my $value = shift;

                my $multipolygon = [];

                foreach my $group (@$value) {
                    my $textified = [ map { coord_string($_) } @$group ];

                    # The first element in this array ref is the outer ring,
                    # the following are the inner rings
                    push @$multipolygon => '(' . (join ",\n" => @$textified) . ')';
                }
                my $multipolygons_string = join ",\n" => @$multipolygon;

                return \qq{MultiPolygonFromText('MULTIPOLYGON($multipolygons_string)')};
            },
        }
    );
}


sub coord_string {
    my $polygon = shift;
    return '(' . (join ', ' => map { "$_->[0] $_->[1]" } @$polygon) . ')';
}

sub decode_multipolygon {
    my $multipolygon_astext = shift;
    $multipolygon_astext =~ s{^MultiPolygon\(}{}i;
    $multipolygon_astext = substr $multipolygon_astext, 0, -1;

    my $polygon_groups = [split m{\)\),\(\(}, $multipolygon_astext];

    my $multipolygon = [];

    foreach my $polygon_group (@$polygon_groups) {
        my $group = [];

        my $actual_polygons = [ split m{\),\(}, $polygon_group ];

        foreach my $actual_polygon (@$actual_polygons) {
            $actual_polygon =~ s{^\(+}{};
            $actual_polygon =~ s{\)+$}{};

            my $pairs = [map { my($long, $lat) = split / / => $_; { long => $long, lat => $lat } } split ',' => $actual_polygon];

            push @$group => $pairs;
        }
        push @$multipolygon => $group;
    }
    return $multipolygon;

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
